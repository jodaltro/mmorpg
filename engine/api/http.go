// Package api exposes a world through a small, versioned HTTP contract.
// Any client (Unity, Unreal, Godot, web, a bot) talks to the same endpoints:
// commands in, per-observer views and a push stream out. Clients never see
// rules or the database, and never receive another player's private data.
package api

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path/filepath"
	"sort"
	"strconv"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/sim"
)

const Version = 1

// CommandRequest is the public command contract (v1). Ticks and advisor
// resolutions are internal and cannot be submitted here.
type CommandRequest struct {
	Version          int                `json:"version"`
	RequestID        string             `json:"requestId"`
	Origin           string             `json:"origin"` // player | adapter
	Kind             string             `json:"kind"`   // join | move | act | accept | decline | abandon
	Actor            core.ID            `json:"actor"`
	Name             string             `json:"name,omitempty"`
	Region           core.ID            `json:"region,omitempty"`
	Spot             string             `json:"spot,omitempty"`
	Action           string             `json:"action,omitempty"`
	Args             map[string]core.ID `json:"args,omitempty"`
	Quest            string             `json:"quest,omitempty"`
	ExpectedRevision *int64             `json:"expectedRevision,omitempty"`
}

type CommandResponse struct {
	Version   int          `json:"version"`
	Revision  int64        `json:"revision"`
	Tick      core.Tick    `json:"tick"`
	Duplicate bool         `json:"duplicate,omitempty"`
	Events    []core.Event `json:"events"`
}

type StreamMessage struct {
	Version  int          `json:"version"`
	Revision int64        `json:"revision"`
	Tick     core.Tick    `json:"tick"`
	Events   []core.Event `json:"events"`
}

// PlayerSummary lists a character that exists in the world, for a start
// screen ("continue as..."). Only public facts: name and region.
type PlayerSummary struct {
	ID         core.ID `json:"id"`
	Name       string  `json:"name"`
	Region     core.ID `json:"region,omitempty"`
	RegionName string  `json:"regionName,omitempty"`
}

type PlayersResponse struct {
	Version int             `json:"version"`
	Tick    core.Tick       `json:"tick"`
	Players []PlayerSummary `json:"players"`
}

// ResetRequest starts a new world. Confirm must be "new-world" so a stray
// call cannot wipe progress; the old world stays archived on disk.
type ResetRequest struct {
	Player  string `json:"player,omitempty"`
	Version int    `json:"version"`
	Confirm string `json:"confirm"`
}

type ResetResponse struct {
	Version  int       `json:"version"`
	Archived string    `json:"archived,omitempty"`
	Tick     core.Tick `json:"tick"`
	Revision int64     `json:"revision"`
}

type errorBody struct {
	Version int    `json:"version"`
	Error   string `json:"error"`
}

// Handler serves the contract with development options: the origin in the
// body is trusted, which is only acceptable on loopback.
func Handler(r *sim.Runner) http.Handler { return HandlerWith(r, Options{}) }

// HandlerWith serves the contract. With Options.Public every actor-bound call
// needs the bearer token issued by POST /v1/session for that actor.
//
// AdapterKey enables server-authoritative play: only the trusted game server
// can confirm adapter commands. Without it, the legacy prototype still allows
// both origins for the bearer token's own actor.
func HandlerWith(r *sim.Runner, o Options) http.Handler {
	a := newAuth(o)
	mux := http.NewServeMux()
	if o.NakamaURL != "" {
		mux.Handle("/nakama/", nakamaProxy(o.NakamaURL))
	}
	w := r.World()
	mux.HandleFunc("POST /v1/session", func(rw http.ResponseWriter, q *http.Request) {
		a.session(rw, q, r)
	})
	mux.HandleFunc("GET /v1/health", func(rw http.ResponseWriter, _ *http.Request) {
		// status is ok, starting (no tick yet) or stalled (ticks stopped coming):
		// the call itself always answers 200, so a watchdog reads the status.
		m := r.Metrics()
		reply(rw, 200, map[string]any{"version": Version, "status": m.Status, "universe": m.Universe, "tick": m.Tick, "revision": m.Revision, "uptimeSeconds": m.UptimeSeconds, "lastTickAgeSeconds": m.LastTickAgeSeconds})
	})
	if !o.Public {
		mux.HandleFunc("GET /v1/metrics", func(rw http.ResponseWriter, _ *http.Request) {
			reply(rw, 200, map[string]any{"version": Version, "metrics": r.Metrics()})
		})
	}
	mux.HandleFunc("GET /v1/chronicle", func(rw http.ResponseWriter, q *http.Request) {
		s := r.Snapshot()
		reply(rw, 200, w.Chronicle(&s, limit(q)))
	})
	mux.HandleFunc("GET /v1/views/{id}", func(rw http.ResponseWriter, q *http.Request) {
		if !a.allow(rw, q, q.PathValue("id"), false) {
			return
		}
		s := r.Snapshot()
		v, ok := w.View(&s, core.ID(q.PathValue("id")), limit(q))
		if !ok {
			reply(rw, 404, errorBody{Version, "unknown_observer"})
			return
		}
		reply(rw, 200, v)
	})
	// What the observer could try now, from what they can tell (no hidden facts).
	mux.HandleFunc("GET /v1/affordances/{id}", func(rw http.ResponseWriter, q *http.Request) {
		if !a.allow(rw, q, q.PathValue("id"), false) {
			return
		}
		s := r.Snapshot()
		id := core.ID(q.PathValue("id"))
		if _, ok := s.Entities[id]; !ok {
			reply(rw, 404, errorBody{Version, "unknown_observer"})
			return
		}
		reply(rw, 200, map[string]any{"version": Version, "tick": s.Tick, "affordances": w.Affordances(&s, id)})
	})
	mux.HandleFunc("GET /v1/players", func(rw http.ResponseWriter, _ *http.Request) {
		s := r.Snapshot()
		out := PlayersResponse{Version: Version, Tick: s.Tick, Players: []PlayerSummary{}}
		for id, e := range s.Entities {
			if e.Kind != w.U.PlayerKind {
				continue
			}
			p := PlayerSummary{ID: id, Name: e.Name, Region: e.Region}
			if reg, ok := s.Entities[e.Region]; ok {
				p.RegionName = reg.Name
			}
			out.Players = append(out.Players, p)
		}
		sort.Slice(out.Players, func(i, j int) bool { return out.Players[i].ID < out.Players[j].ID })
		reply(rw, 200, out)
	})
	mux.HandleFunc("POST /v1/world/reset", func(rw http.ResponseWriter, q *http.Request) {
		if o.Public && !o.TestReset {
			reply(rw, 403, errorBody{Version, "reset_disabled"})
			return
		}
		var in ResetRequest
		if !decode(rw, q, &in) {
			return
		}
		if !a.allow(rw, q, in.Player, false) {
			return
		}
		if in.Version != Version || in.Confirm != "new-world" {
			reply(rw, 400, errorBody{Version, "confirm_required"})
			return
		}
		archived, err := r.Reset()
		if err != nil {
			reply(rw, 503, errorBody{Version, "world_unavailable"})
			return
		}
		s := r.Snapshot()
		if archived != "" {
			archived = filepath.Base(archived) // never expose server paths
		}
		reply(rw, 200, ResetResponse{Version: Version, Archived: archived, Tick: s.Tick, Revision: s.Revision})
	})
	mux.HandleFunc("POST /v1/commands", func(rw http.ResponseWriter, q *http.Request) {
		var in CommandRequest
		if !decode(rw, q, &in) {
			return
		}
		if !a.allow(rw, q, string(in.Actor), false) {
			return
		}
		if in.Origin == "adapter" && a.adapterKey != "" && !a.isAdapter(q) {
			reply(rw, 403, errorBody{Version, "server_authority"})
			return
		}
		if in.Version != Version || in.Origin != "player" && in.Origin != "adapter" ||
			in.Kind != "join" && in.Kind != "move" && in.Kind != "act" && in.Kind != "accept" && in.Kind != "decline" && in.Kind != "abandon" {
			reply(rw, 400, errorBody{Version, "invalid_contract"})
			return
		}
		d, err := r.Submit(core.Command{Version: 1, RequestID: in.RequestID, Origin: in.Origin, Kind: in.Kind, Actor: in.Actor,
			Name: in.Name, Region: in.Region, Spot: in.Spot, Action: in.Action, Args: in.Args, Quest: in.Quest, ExpectedRevision: in.ExpectedRevision})
		if errors.Is(err, core.ErrRejected) {
			reply(rw, 409, errorBody{Version, err.Error()})
			return
		}
		if err != nil {
			reply(rw, 503, errorBody{Version, "world_unavailable"})
			return
		}
		reply(rw, 200, CommandResponse{Version: Version, Revision: d.Revision, Tick: d.Tick, Duplicate: d.Duplicate, Events: visible(d.Events, in.Actor)})
	})
	mux.HandleFunc("GET /v1/stream/{id}", func(rw http.ResponseWriter, q *http.Request) {
		id := core.ID(q.PathValue("id"))
		if !a.allow(rw, q, string(id), true) {
			return
		}
		s := r.Snapshot()
		v, ok := w.View(&s, id, 50)
		if !ok {
			reply(rw, 404, errorBody{Version, "unknown_observer"})
			return
		}
		fl, ok := rw.(http.Flusher)
		if !ok {
			reply(rw, 500, errorBody{Version, "streaming_unsupported"})
			return
		}
		ch, cancel := r.Subscribe()
		defer cancel()
		rw.Header().Set("Content-Type", "text/event-stream")
		rw.Header().Set("Cache-Control", "no-store")
		send(rw, "view", v)
		fl.Flush()
		beat := time.NewTicker(15 * time.Second)
		defer beat.Stop()
		for {
			select {
			case <-q.Context().Done():
				return
			case <-beat.C:
				fmt.Fprint(rw, ": keepalive\n\n")
				fl.Flush()
			case d, open := <-ch:
				if !open {
					return
				}
				send(rw, "delta", StreamMessage{Version: Version, Revision: d.Revision, Tick: d.Tick, Events: visible(d.Events, id)})
				fl.Flush()
			}
		}
	})
	var h http.Handler = mux
	if o.Web != "" {
		top := http.NewServeMux()
		top.Handle("/v1/", mux)
		if o.NakamaURL != "" {
			top.Handle("/nakama/", mux)
		}
		top.Handle("/", staticHandler(o.Web))
		h = top
	}
	if o.Public {
		h = a.limited(h)
	}
	h = guard(h)
	if o.Public && o.EdgeSecret != "" {
		h = edgeOnly(o.EdgeSecret, h)
	}
	return h
}

// guard refuses browser cross-origin calls: only an Origin whose host is the
// host being served (the page and the API share one origin) gets through;
// native game clients send no Origin.
func guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, q *http.Request) {
		if origin := q.Header.Get("Origin"); origin != "" {
			u, err := url.Parse(origin)
			if err != nil || u.Host == "" || u.Host != q.Host {
				reply(rw, 403, errorBody{Version, "cross_origin_refused"})
				return
			}
		}
		next.ServeHTTP(rw, q)
	})
}

func visible(events []core.Event, observer core.ID) []core.Event {
	out := []core.Event{}
	for _, e := range events {
		if e.Public || e.Holder != "" && e.Holder == observer {
			out = append(out, e)
		}
	}
	return out
}

func limit(q *http.Request) int {
	n, err := strconv.Atoi(q.URL.Query().Get("limit"))
	if err != nil || n <= 0 || n > 500 {
		return 100
	}
	return n
}

func decode(rw http.ResponseWriter, q *http.Request, out any) bool {
	body, err := io.ReadAll(io.LimitReader(q.Body, 16<<10+1))
	if err != nil || len(body) > 16<<10 {
		reply(rw, 413, errorBody{Version, "body_too_large"})
		return false
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if dec.Decode(out) != nil || dec.More() {
		reply(rw, 400, errorBody{Version, "invalid_json"})
		return false
	}
	return true
}

func send(rw io.Writer, event string, v any) {
	b, _ := json.Marshal(v)
	fmt.Fprintf(rw, "event: %s\ndata: %s\n\n", event, b)
}

func reply(rw http.ResponseWriter, status int, v any) {
	rw.Header().Set("Content-Type", "application/json")
	rw.WriteHeader(status)
	json.NewEncoder(rw).Encode(v)
}
