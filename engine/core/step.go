package core

import (
	"errors"
	"fmt"
	"slices"
	"strconv"
	"strings"
)

// Command is the only way to change a world. Origin is set by the trusted
// boundary (API/auth or runtime), never chosen freely by a game client.
type Command struct {
	Version          int           `json:"version"`
	RequestID        string        `json:"requestId"`
	Origin           string        `json:"origin"` // system | player | adapter | advisor
	Kind             string        `json:"kind"`   // tick | join | act | accept | decline | abandon | resolve
	Actor            ID            `json:"actor,omitempty"`
	Name             string        `json:"name,omitempty"`
	Action           string        `json:"action,omitempty"`
	Args             map[string]ID `json:"args,omitempty"`
	Quest            string        `json:"quest,omitempty"`
	Decision         string        `json:"decision,omitempty"`
	Choice           string        `json:"choice,omitempty"`
	Provider         string        `json:"provider,omitempty"`
	Model            string        `json:"model,omitempty"`
	ExpectedRevision *int64        `json:"expectedRevision,omitempty"`
}

// Delta is what a command changed, for push to clients and advisors.
type Delta struct {
	Revision  int64      `json:"revision"`
	Tick      Tick       `json:"tick"`
	Duplicate bool       `json:"duplicate,omitempty"`
	Events    []Event    `json:"events"`
	Decisions []Decision `json:"decisions,omitempty"`
}

var ErrRejected = errors.New("rejected")

func reject(reason string) error { return fmt.Errorf("%w: %s", ErrRejected, reason) }

const receiptWindow = 4096

func validID(s string) bool {
	if s == "" || len(s) > 128 {
		return false
	}
	for _, c := range s {
		if !(c >= 0x61 && c <= 0x7a || c >= 0x41 && c <= 0x5a || c >= 0x30 && c <= 0x39 || strings.ContainsRune("-_.:", c)) {
			return false
		}
	}
	return true
}

// Step applies one command to a copy of the state. A rejected command has
// no effect. Step is pure and deterministic: replaying the same commands
// from NewState reproduces the same Digest.
func (w *World) Step(prev State, c Command) (State, Delta, error) {
	if c.Version != 1 || !validID(c.RequestID) {
		return prev, Delta{}, reject("contract")
	}
	if c.Kind != "tick" {
		if _, dup := prev.Receipts[c.RequestID]; dup {
			return prev, Delta{Revision: prev.Revision, Tick: prev.Tick, Duplicate: true}, nil
		}
	}
	if c.ExpectedRevision != nil && *c.ExpectedRevision != prev.Revision {
		return prev, Delta{}, reject("revision")
	}
	allowed := map[string][]string{"tick": {"system"}, "join": {"system", "adapter"}, "act": {"player", "adapter"},
		"accept": {"player"}, "decline": {"player"}, "abandon": {"player"}, "resolve": {"advisor"}}
	if !slices.Contains(allowed[c.Kind], c.Origin) {
		return prev, Delta{}, reject("origin")
	}
	s := prev.Clone()
	seq0 := s.Seq
	cause := "cmd:" + c.RequestID
	var err error
	switch c.Kind {
	case "tick":
		if c.RequestID != "tick:"+strconv.FormatInt(int64(prev.Tick)+1, 10) {
			return prev, Delta{}, reject("tick sequence")
		}
		w.tick(&s, cause)
	case "join":
		err = w.join(&s, c)
	case "act":
		if err = w.act(&s, c.Origin, c.Actor, c.Action, c.Args, cause); err == nil {
			w.completeFor(&s, c.Actor, cause)
		}
	case "accept", "decline", "abandon":
		err = w.questCommand(&s, c, cause)
	case "resolve":
		d, ok := s.Decisions[c.Decision]
		if !ok {
			return prev, Delta{}, reject("unknown decision")
		}
		err = w.decide(&s, d, c.Choice, c.Provider, c.Model, cause)
	}
	if err != nil {
		return prev, Delta{}, err
	}
	s.Revision++
	if c.Kind != "tick" {
		s.Receipts[c.RequestID] = s.Revision
		if s.Revision%receiptWindow == 0 {
			for k, r := range s.Receipts {
				if r <= s.Revision-receiptWindow {
					delete(s.Receipts, k)
				}
			}
		}
	}
	d := Delta{Revision: s.Revision, Tick: s.Tick, Events: []Event{}}
	for _, e := range s.Events {
		if e.Seq > seq0 {
			d.Events = append(d.Events, e)
		}
	}
	for _, id := range sortedKeys(s.Decisions) {
		if _, old := prev.Decisions[id]; !old {
			d.Decisions = append(d.Decisions, s.Decisions[id])
		}
	}
	return s, d, nil
}

func (w *World) join(s *State, c Command) error {
	if !validID(string(c.Actor)) {
		return reject("actor id")
	}
	if _, exists := s.Entities[c.Actor]; exists {
		return reject("actor exists")
	}
	seed := w.U.Player
	seed.ID = c.Actor
	seed.Name = c.Name
	if len(seed.Name) > 64 {
		return reject("name")
	}
	s.Entities[c.Actor] = newEntity(seed)
	w.emit(s, Event{Kind: "join", Actor: c.Actor, Holder: c.Actor, Text: s.Entities[c.Actor].Name})
	return nil
}

func (w *World) act(s *State, origin string, actor ID, action string, args map[string]ID, cause string) error {
	a, ok := w.actions[action]
	if !ok || !slices.Contains(a.By, origin) {
		return reject("action")
	}
	ent, ok := s.Entities[actor]
	if !ok || origin == "player" && ent.Kind != w.U.PlayerKind {
		return reject("actor")
	}
	if len(args) != len(a.Params) {
		return reject("arguments")
	}
	b := Bind{"self": actor}
	for _, p := range a.Params {
		id := args[p.Name]
		if e, ok := s.Entities[id]; !ok || e.Kind != p.Kind {
			return reject("argument " + p.Name)
		}
		b[p.Name] = id
	}
	if !w.Holds(s, a.Requires, b) {
		return reject("requirements")
	}
	w.apply(s, a.Effects, b, cause)
	return nil
}
