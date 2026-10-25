// Command worldsim validates, simulates and serves universes.
//
//	worldsim validate <universe.json>
//	worldsim simulate -universe <file> -ticks 120 -players 3
//	worldsim serve -universe <file> -data <dir> -listen 127.0.0.1:8095 -tick 1s -advisor none|deterministic|jev [-public] [-web <dir>]
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
	"strings"
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
	mode := fs.String("advisor", "none", "none | deterministic | jev")
	envFile := fs.String("env-file", ".env", "local file with OPENROUTER_API_KEY (jev only)")
	pace := fs.Duration("pace", 0, "wall-clock time per tick (give async advisors time to answer)")
	fs.Parse(args)
	w, err := universe.Load(*path)
	if err != nil {
		return err
	}
	adv, err := pickAdvisor(*mode, *envFile, 8*time.Second)
	if err != nil {
		return err
	}
	r, err := sim.Open(w, &store.Memory{}, sim.Options{Advisor: adv, AdvisorTimeout: 10 * time.Second})
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
		if *pace > 0 {
			time.Sleep(*pace)
		}
		r.Tick()
		s := r.Snapshot()
		places := []core.ID{}
		for _, id := range sortedEntitiesOfKinds(s, w.U.RegionKinds) {
			places = append(places, id)
		}
		for i, id := range ids {
			if len(places) > 0 && (t+i)%6 == 0 {
				// The game server reports where each player wanders.
				submit(core.Command{Origin: "adapter", Kind: "move", Actor: id, Region: places[(t/6+i)%len(places)]})
			}
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
	r.Drain()
	s = r.Snapshot()
	report(s)
	fmt.Printf("\ndigest %s\n", s.Digest())
	return nil
}

// report summarizes who decided what and how varied the world was.
func report(s core.State) {
	defs := map[string]bool{}
	perPlayer := map[core.ID]map[string]bool{}
	states := map[string]int{}
	for _, q := range s.Quests {
		defs[q.Def] = true
		if perPlayer[q.Holder] == nil {
			perPlayer[q.Holder] = map[string]bool{}
		}
		perPlayer[q.Holder][q.Def] = true
		states[q.State]++
	}
	counts := map[string]int{}
	for _, e := range s.Events {
		counts[e.Kind]++
	}
	fmt.Printf("\nvariety: %d distinct quests offered; per player:", len(defs))
	for _, id := range sortedKeysID(perPlayer) {
		fmt.Printf(" %s=%d", id, len(perPlayer[id]))
	}
	fmt.Printf("\nquest states: %v\n", states)
	hidden := 0
	for _, q := range s.Quests {
		if strings.HasPrefix(q.Title, "Quest oculta") {
			hidden++
		}
	}
	rel := []string{}
	for _, k := range sortedRelKeys(s.Relations) {
		rel = append(rel, fmt.Sprintf("%s=%d", k, s.Relations[k]))
	}
	fmt.Printf("rumors heard=%d hidden quests offered=%d relations: %v\n", counts["rumor"], hidden, rel)
	fmt.Printf("updates (stages)=%d failed=%d unique-lost=%d story=%d happenings=%d\n",
		counts["quest-updated"], counts["quest-failed"], counts["beat-lost"], counts["story"], countHappenings(s))
	type agg struct {
		n, lat       int64
		conf, cost   float64
		nconf, ncost int64
	}
	by := map[string]*agg{}
	keys := []string{}
	for _, e := range s.Events {
		if e.Kind != "decision" {
			continue
		}
		k := e.Data["kind"] + "/" + e.Data["provider"]
		if by[k] == nil {
			by[k] = &agg{}
			keys = append(keys, k)
		}
		a := by[k]
		a.n++
		if v, err := strconv.ParseInt(e.Data["latencyMs"], 10, 64); err == nil {
			a.lat += v
		}
		if v, err := strconv.ParseFloat(e.Data["confidence"], 64); err == nil {
			a.conf += v
			a.nconf++
		}
		if v, err := strconv.ParseFloat(e.Data["cost"], 64); err == nil {
			a.cost += v
			a.ncost++
		}
	}
	fmt.Println("\ndecisions (kind/provider): count, mean latency, mean confidence, total cost")
	for _, k := range keys {
		a := by[k]
		conf := 0.0
		if a.nconf > 0 {
			conf = a.conf / float64(a.nconf)
		}
		fmt.Printf("  %-22s %4d  %5dms  %.2f  $%.6f\n", k, a.n, a.lat/a.n, conf, a.cost)
	}
}

func sortedKeysID[V any](m map[core.ID]V) []core.ID {
	out := []core.ID{}
	for k := range m {
		out = append(out, k)
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

func sortedRelKeys(m map[string]int64) []string {
	out := []string{}
	for k := range m {
		out = append(out, k)
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

func countHappenings(s core.State) int {
	n := 0
	by := map[string]int{}
	for _, e := range s.Events {
		if e.Kind == "decision" && e.Data["kind"] == "world" {
			by[e.Data["choice"]]++
			if e.Data["choice"] != "none" {
				n++
			}
		}
	}
	fmt.Printf("director choices: %v\n", by)
	return n
}

func pickAdvisor(mode, envFile string, timeout time.Duration) (advisor.Advisor, error) {
	switch mode {
	case "none":
		return nil, nil
	case "deterministic":
		return advisor.Deterministic{}, nil
	case "jev":
		key, err := advisor.ResolveKey(envFile)
		if err != nil || key == "" {
			return nil, errors.New("jev advisor needs OPENROUTER_API_KEY (environment or -env-file)")
		}
		return &advisor.Jev{APIKey: key, Timeout: timeout}, nil
	}
	return nil, errors.New("unknown advisor")
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

func sortedEntitiesOfKinds(s core.State, kinds []string) []core.ID {
	out := []core.ID{}
	for _, k := range kinds {
		out = append(out, sortedEntities(s, k)...)
	}
	return out
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
	every := fs.Duration("tick", time.Second, "world tick interval (default: the universe's tickSeconds, else 1s)")
	mode := fs.String("advisor", "none", "none | deterministic | jev")
	envFile := fs.String("env-file", ".env", "local file with OPENROUTER_API_KEY (jev only)")
	jevTimeout := fs.Duration("jev-timeout", 5*time.Second, "per-call Jev timeout")
	onChange := fs.String("on-universe-change", "refuse", "refuse | new-world: what to do when the saved world was made with another version of the universe (new-world archives it, nothing is deleted)")
	edgeSecret := fs.String("edge-secret", os.Getenv("HOSPEDEIRO_EDGE_SECRET"), "public mode: only requests carrying this secret in X-Edge-Secret are served (default: $HOSPEDEIRO_EDGE_SECRET)")
	testReset := fs.Bool("test-reset", false, "temporary testing: allow authenticated players to reset the shared world")
	public := fs.Bool("public", false, "public mode (behind a tunnel on loopback): bearer tokens required, reset off, rate limits on")
	adapterKey := fs.String("adapter-key", os.Getenv("HOSPEDEIRO_ADAPTER_KEY"), "server-only credential for authoritative adapter commands")
	nakamaURL := fs.String("nakama", "", "optional loopback Nakama endpoint (HTTP + WebSocket proxy at /nakama/)")
	web := fs.String("web", "", "directory of static files (the web client) served at /")
	fs.Parse(args)
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || !net.ParseIP(host).IsLoopback() {
		return errors.New("development server listens on loopback only: origins are trusted without authentication")
	}
	w, err := universe.Load(*path)
	if err != nil {
		return err
	}
	tickSet := false
	fs.Visit(func(f *flag.Flag) { tickSet = tickSet || f.Name == "tick" })
	if !tickSet && w.U.TickSeconds > 0 {
		*every = time.Duration(w.U.TickSeconds * float64(time.Second))
	}
	adv, err := pickAdvisor(*mode, *envFile, *jevTimeout)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(*data, 0o700); err != nil {
		return err
	}
	file := filepath.Join(*data, w.U.ID+".jsonl")
	l, err := store.OpenFile(file, w.U.ID, w.Fingerprint())
	if errors.Is(err, store.ErrMismatch) && *onChange == "new-world" {
		// Replaying old commands under new rules would build another world, so
		// the old one is kept aside and a new one starts from this universe.
		archived, aerr := store.Archive(file)
		if aerr != nil {
			return aerr
		}
		fmt.Printf("the universe changed: previous world archived as %s, starting a new world\n", filepath.Base(archived))
		l, err = store.OpenFile(file, w.U.ID, w.Fingerprint())
	}
	if err != nil {
		if errors.Is(err, store.ErrMismatch) {
			return fmt.Errorf("%w: the saved world was made with another version of the universe (use -on-universe-change new-world to archive it and start a new one)", err)
		}
		return err
	}
	r, err := sim.Open(w, l, sim.Options{Advisor: adv, AdvisorTimeout: *jevTimeout + time.Second})
	if err != nil {
		return err
	}
	defer r.Close()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	key, err := api.LoadOrCreateKey(*data)
	if err != nil {
		return err
	}
	if *web != "" {
		if st, serr := os.Stat(*web); serr != nil || !st.IsDir() {
			return fmt.Errorf("-web %q is not a directory", *web)
		}
	}
	srv := &http.Server{Addr: *listen, Handler: api.HandlerWith(r, api.Options{Public: *public, TestReset: *testReset, Key: key, Web: *web, EdgeSecret: *edgeSecret, AdapterKey: *adapterKey, NakamaURL: *nakamaURL}), ReadHeaderTimeout: 5 * time.Second}
	go func() {
		<-ctx.Done()
		sctx, c := context.WithTimeout(context.Background(), 3*time.Second)
		defer c()
		srv.Shutdown(sctx)
	}()
	go r.Run(ctx, *every)
	fmt.Printf("%s at tick %d, serving http://%s (advisor=%s, public=%v, web=%q)\n", w.U.Name, r.Snapshot().Tick, *listen, *mode, *public, *web)
	if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
