// Command worldsim validates, simulates and serves universes.
//
//	worldsim validate <universe.json>
//	worldsim simulate -universe <file> -ticks 120 -players 3
//	worldsim serve -universe <file> -data <dir> -listen 127.0.0.1:8095 -tick 1s -advisor none|deterministic|jev
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/api"
	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/sim"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "validate":
		if len(os.Args) != 3 {
			usage()
		}
		if _, err = universe.Load(os.Args[2]); err == nil {
			fmt.Println("ok")
		}
	case "simulate":
		err = simulate(os.Args[2:])
	case "serve":
		err = serve(os.Args[2:])
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: worldsim validate <universe.json> | simulate [flags] | serve [flags]")
	os.Exit(2)
}

// simulate runs a headless world in memory with scripted players that look
// around, accept whatever they are offered and report occurrences.
func simulate(args []string) error {
	fs := flag.NewFlagSet("simulate", flag.ExitOnError)
	path := fs.String("universe", "", "universe.json")
	n := fs.Int("ticks", 120, "ticks to run")
	players := fs.Int("players", 3, "scripted players")
	fs.Parse(args)
	w, err := universe.Load(*path)
	if err != nil {
		return err
	}
	r, err := sim.Open(w, &store.Memory{}, sim.Options{})
	if err != nil {
		return err
	}
	defer r.Close()
	ids := []core.ID{}
	for i := 1; i <= *players; i++ {
		id := core.ID("p" + strconv.Itoa(i))
		ids = append(ids, id)
		r.Submit(core.Command{Version: 1, RequestID: "join-" + string(id), Origin: "adapter", Kind: "join", Actor: id, Name: "Jogador " + strconv.Itoa(i)})
	}
	seq := 0
	submit := func(c core.Command) {
		seq++
		c.Version, c.RequestID = 1, "sim-"+strconv.Itoa(seq)
		r.Submit(c) // rejections are normal: players try things
	}
	for t := 0; t < *n; t++ {
		r.Tick()
		s := r.Snapshot()
		for i, id := range ids {
			if (t+i)%4 != 0 {
				continue
			}
			pursuing := false
			for _, q := range s.Quests {
				if q.Holder == id && q.State == "offered" {
					submit(core.Command{Origin: "player", Kind: "accept", Actor: id, Quest: q.Key})
				}
				pursuing = pursuing || q.Holder == id && q.State == "active"
			}
			for _, a := range w.U.Actions {
				origin := "player"
				if len(a.By) > 0 && a.By[0] == "adapter" {
					origin = "adapter"
				}
				if len(a.Params) == 0 && (contains(a.By, "player") || contains(a.By, "adapter")) {
					if !contains(a.By, "player") {
						origin = "adapter"
						if !pursuing {
							continue // a game server only reports what players actually do
						}
					}
					submit(core.Command{Origin: origin, Kind: "act", Actor: id, Action: a.ID})
				}
				if len(a.Params) == 1 && contains(a.By, "player") {
					for _, other := range sortedEntities(s, a.Params[0].Kind) {
						submit(core.Command{Origin: "player", Kind: "act", Actor: id, Action: a.ID, Args: map[string]core.ID{a.Params[0].Name: other}})
					}
				}
			}
		}
	}
	s := r.Snapshot()
	c := w.Chronicle(&s, 0)
	fmt.Printf("%s - tick %d, revision %d\n\n", w.U.Name, s.Tick, s.Revision)
	for _, e := range c.Events {
		fmt.Printf("[%4d] %s\n", e.At, e.Text)
	}
	for _, st := range c.Story {
		fmt.Printf("\n%s (done=%v)\n", st.Title, st.Done)
		for _, ch := range st.Chronicle {
			fmt.Printf("  - %s: %v (tick %d)\n", ch.Title, ch.By, ch.At)
		}
	}
	fmt.Println()
	for _, id := range ids {
		v, _ := w.View(&s, id, 0)
		done := 0
		for _, q := range v.Quests {
			if q.State == "done" {
				done++
			}
		}
		fmt.Printf("%s: title=%q quests done=%d beliefs=%d num=%v\n", v.Self.Name, v.Self.Tag["title"], done, len(v.Beliefs), v.Self.Num)
		for _, q := range v.Quests {
			fmt.Printf("    %-10s %s\n", q.State, q.Title)
		}
	}
	fmt.Printf("\ndigest %s\n", s.Digest())
	return nil
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

func sortedEntities(s core.State, kind string) []core.ID {
	out := []core.ID{}
	for id, e := range s.Entities {
		if e.Kind == kind {
			out = append(out, id)
		}
	}
	for i := range out {
		for j := i + 1; j < len(out); j++ {
			if out[j] < out[i] {
				out[i], out[j] = out[j], out[i]
			}
		}
	}
	return out
}

func serve(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	path := fs.String("universe", "", "universe.json")
	data := fs.String("data", "data", "directory for the command log")
	listen := fs.String("listen", "127.0.0.1:8095", "loopback address")
	every := fs.Duration("tick", time.Second, "world tick interval")
	mode := fs.String("advisor", "none", "none | deterministic | jev")
	envFile := fs.String("env-file", ".env", "local file with OPENROUTER_API_KEY (jev only)")
	jevTimeout := fs.Duration("jev-timeout", 5*time.Second, "per-call Jev timeout")
	fs.Parse(args)
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || !net.ParseIP(host).IsLoopback() {
		return errors.New("development server listens on loopback only: origins are trusted without authentication")
	}
	w, err := universe.Load(*path)
	if err != nil {
		return err
	}
	var adv advisor.Advisor
	switch *mode {
	case "none":
	case "deterministic":
		adv = advisor.Deterministic{}
	case "jev":
		key, err := advisor.ResolveKey(*envFile)
		if err != nil || key == "" {
			return errors.New("jev advisor needs OPENROUTER_API_KEY (environment or -env-file)")
		}
		adv = &advisor.Jev{APIKey: key, Timeout: *jevTimeout}
	default:
		return errors.New("unknown advisor")
	}
	if err := os.MkdirAll(*data, 0o700); err != nil {
		return err
	}
	l, err := store.OpenFile(filepath.Join(*data, w.U.ID+".jsonl"), w.U.ID, w.Fingerprint())
	if err != nil {
		return err
	}
	r, err := sim.Open(w, l, sim.Options{Advisor: adv, AdvisorTimeout: *jevTimeout + time.Second})
	if err != nil {
		return err
	}
	defer r.Close()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	srv := &http.Server{Addr: *listen, Handler: api.Handler(r), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		<-ctx.Done()
		sctx, c := context.WithTimeout(context.Background(), 3*time.Second)
		defer c()
		srv.Shutdown(sctx)
	}()
	go r.Run(ctx, *every)
	fmt.Printf("%s at tick %d, serving http://%s (advisor=%s)\n", w.U.Name, r.Snapshot().Tick, *listen, *mode)
	if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
