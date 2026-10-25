// Package personal runs a private, client-authoritative world. Its journal must
// never be imported into the shared MMORPG runner.
package personal

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/universe"
)

type Session struct {
	World         *core.World
	State         core.State
	Journal       []core.Command
	restoredCount int
}

// Checkpoint is a disposable startup cache; the journal remains the source of
// truth. Invalid caches are ignored and the complete journal is replayed.
type Checkpoint struct {
	Count    int        `json:"count"`
	Universe string     `json:"universe"`
	Prefix   string     `json:"prefix"`
	Digest   string     `json:"digest"`
	State    core.State `json:"state"`
}

func journalDigest(commands []core.Command) string {
	b, _ := json.Marshal(commands)
	return fmt.Sprintf("%x", sha256.Sum256(b))
}

func (s *Session) Checkpoint() Checkpoint {
	return Checkpoint{len(s.Journal), s.World.Fingerprint(), journalDigest(s.Journal), s.State.Digest(), s.State}
}

type Response struct {
	Status int `json:"status"`
	Body   any `json:"body"`
}

func Open(definition []byte, commands []core.Command) (*Session, error) {
	return OpenCached(definition, commands, nil)
}

func OpenCached(definition []byte, commands []core.Command, cache *Checkpoint) (*Session, error) {
	w, err := universe.Parse(definition)
	if err != nil {
		return nil, err
	}
	s := &Session{World: w, State: core.NewState(w)}
	start := 0
	if cache != nil && cache.Count > 0 && cache.Count <= len(commands) && cache.Universe == w.Fingerprint() && cache.State.Revision == int64(cache.Count) && cache.Digest == cache.State.Digest() && cache.Prefix == journalDigest(commands[:cache.Count]) {
		start = cache.Count
		s.restoredCount = start
		s.State = cache.State
		s.Journal = append(s.Journal, commands[:start]...)
	}
	for i, c := range commands[start:] {
		if _, err := s.Apply(c); err != nil {
			return nil, fmt.Errorf("journal command %d: %w", start+i, err)
		}
	}
	return s, nil
}

func (s *Session) Apply(c core.Command) (core.Delta, error) {
	next, delta, err := s.World.Step(s.State, c)
	if err == nil && !delta.Duplicate {
		s.State = next
		s.Journal = append(s.Journal, c)
	}
	return delta, err
}

func (s *Session) Request(path string, body json.RawMessage) Response {
	if path == "/tick" {
		c := core.Command{Version: 1, Origin: "system", Kind: "tick", RequestID: fmt.Sprintf("tick:%d", s.State.Tick+1)}
		d, err := s.Apply(c)
		return result(d, err)
	}
	if path == "/v1/commands" {
		var c core.Command
		if err := json.Unmarshal(body, &c); err != nil {
			return result(nil, err)
		}
		d, err := s.Apply(c)
		return result(d, err)
	}
	id := core.ID(strings.Split(strings.TrimPrefix(strings.TrimPrefix(path, "/v1/views/"), "/v1/affordances/"), "?")[0])
	if strings.HasPrefix(path, "/v1/views/") {
		v, ok := s.World.View(&s.State, id, 30)
		if !ok {
			return Response{404, map[string]string{"error": "unknown_observer"}}
		}
		return Response{200, v}
	}
	if strings.HasPrefix(path, "/v1/affordances/") {
		return Response{200, map[string]any{"affordances": s.World.Affordances(&s.State, id)}}
	}
	return Response{404, map[string]string{"error": "unsupported_local_operation"}}
}

func result(body any, err error) Response {
	if err != nil {
		return Response{409, map[string]string{"error": err.Error()}}
	}
	return Response{200, body}
}
