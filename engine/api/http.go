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

type errorBody struct {
	Version int    `json:"version"`
	Error   string `json:"error"`
}

// Handler serves the contract. Origin in the body is trusted, which is only
// acceptable on loopback for development; a deployment must derive it from
// authentication (player token vs game-server credential).
func Handler(r *sim.Runner) http.Handler {
	mux := http.NewServeMux()
	w := r.World()
	mux.HandleFunc("GET /v1/health", func(rw http.ResponseWriter, _ *http.Request) {
		s := r.Snapshot()
		reply(rw, 200, map[string]any{"version": Version, "status": "ok", "universe": s.Universe, "tick": s.Tick, "revision": s.Revision})
	})
	mux.HandleFunc("GET /v1/chronicle", func(rw http.ResponseWriter, q *http.Request) {
		s := r.Snapshot()
		reply(rw, 200, w.Chronicle(&s, limit(q)))
	})
	mux.HandleFunc("GET /v1/views/{id}", func(rw http.ResponseWriter, q *http.Request) {
		s := r.Snapshot()
		v, ok := w.View(&s, core.ID(q.PathValue("id")), limit(q))
		if !ok {
			reply(rw, 404, errorBody{Version, "unknown_observer"})
			return
		}
		reply(rw, 200, v)
	})
	mux.HandleFunc("POST /v1/commands", func(rw http.ResponseWriter, q *http.Request) {
		var in CommandRequest
		if !decode(rw, q, &in) {
			return
		}
		if in.Version != Version || in.Origin != "player" && in.Origin != "adapter" ||
			in.Kind != "join" && in.Kind != "move" && in.Kind != "act" && in.Kind != "accept" && in.Kind != "decline" && in.Kind != "abandon" {
			reply(rw, 400, errorBody{Version, "invalid_contract"})
			return
		}
		d, err := r.Submit(core.Command{Version: 1, RequestID: in.RequestID, Origin: in.Origin, Kind: in.Kind, Actor: in.Actor,
			Name: in.Name, Region: in.Region, Action: in.Action, Args: in.Args, Quest: in.Quest, ExpectedRevision: in.ExpectedRevision})
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
	return guard(mux)
}

// guard refuses browser cross-origin calls; native game clients send no Origin.
func guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, q *http.Request) {
		if q.Header.Get("Origin") != "" {
			reply(rw, 403, errorBody{Version, "cross_origin_refused"})
			return
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
