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
	Kind             string        `json:"kind"`   // tick | join | move | act | accept | decline | abandon | resolve
	Actor            ID            `json:"actor,omitempty"`
	Name             string        `json:"name,omitempty"`
	Region           ID            `json:"region,omitempty"` // join: where the newcomer arrives; move: the region the game server saw the actor enter
	Spot             string        `json:"spot,omitempty"`   // move: the named spot the actor is at now (within the region), or empty
	Action           string        `json:"action,omitempty"`
	Args             map[string]ID `json:"args,omitempty"`
	Quest            string        `json:"quest,omitempty"`
	Decision         string        `json:"decision,omitempty"`
	Choice           string        `json:"choice,omitempty"`
	Provider         string        `json:"provider,omitempty"`
	Model            string        `json:"model,omitempty"`
	Call             string        `json:"call,omitempty"`       // provider call id, for audit
	Confidence       *float64      `json:"confidence,omitempty"` // advisor self-reported confidence
	LatencyMS        int64         `json:"latencyMs,omitempty"`
	Cost             *float64      `json:"cost,omitempty"` // USD reported by the provider
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
	allowed := map[string][]string{"tick": {"system"}, "join": {"system", "adapter"}, "move": {"system", "adapter"}, "act": {"player", "adapter"},
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
	case "move":
		err = w.move(&s, c, cause)
	case "act":
		if err = w.act(&s, c.Origin, c.Actor, c.Action, c.Args, cause); err == nil {
			w.completeFor(&s, c.Actor, cause)
			if s.Entities[c.Actor].Kind == w.U.PlayerKind {
				w.witness(&s, c.Actor, addressedBy(w, c.Args)...)
				// A deed can reveal a quest at once, like a system window
				// popping up right after the player did something.
				w.refreshOffers(&s, c.Actor, cause)
				w.offer(&s, c.Actor, cause)
			}
		}
	case "accept", "decline", "abandon":
		err = w.questCommand(&s, c, cause)
	case "resolve":
		d, ok := s.Decisions[c.Decision]
		if !ok {
			return prev, Delta{}, reject("unknown decision")
		}
		err = w.decide(&s, d, c.Choice, audit(c), cause)
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

// audit keeps advisor metadata with the decision event. It is data from
// the advisor, recorded for analysis; it never changes what is applied.
func audit(c Command) map[string]string {
	m := map[string]string{"provider": c.Provider, "model": c.Model}
	if c.Call != "" {
		m["call"] = c.Call
	}
	if c.Confidence != nil {
		m["confidence"] = strconv.FormatFloat(*c.Confidence, 'f', 3, 64)
	}
	if c.LatencyMS > 0 {
		m["latencyMs"] = strconv.FormatInt(c.LatencyMS, 10)
	}
	if c.Cost != nil {
		m["cost"] = strconv.FormatFloat(*c.Cost, 'f', 9, 64)
	}
	return m
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
	if c.Region != "" { // the game server says where the newcomer arrives
		if place, ok := s.Entities[c.Region]; !ok || !w.regions[place.Kind] {
			return reject("region")
		}
		seed.Region = c.Region
	}
	if len(seed.Name) > 64 {
		return reject("name")
	}
	s.Entities[c.Actor] = newEntity(seed)
	w.emit(s, Event{Kind: "join", Actor: c.Actor, Holder: c.Actor, Text: s.Entities[c.Actor].Name})
	w.findPlace(s, c.Actor, ID(s.Entities[c.Actor].Region))
	w.apply(s, w.U.OnJoin, Bind{"self": c.Actor}, "join")
	w.codexTick(s, c.Actor, "join")
	return nil
}

// move records the region where the game server saw an actor. Exact
// positions stay in the client; the world only needs coarse places. Moving
// can make an NPC nearby call the player with a quest right away.
func (w *World) move(s *State, c Command, cause string) error {
	ent, ok := s.Entities[c.Actor]
	place, isPlace := s.Entities[c.Region]
	if !ok || !isPlace || !w.regions[place.Kind] {
		return reject("move")
	}
	if c.Spot != "" && c.Spot != OpenGround && w.spotRegion(c.Spot) != c.Region {
		return reject("spot") // a spot only exists inside its own region
	}
	if ps, ok := w.passageBetween(ent.Region, c.Region); ok && ent.Region != c.Region && ent.Kind == w.U.PlayerKind && !w.passageOpen(s, c.Actor, ps) {
		return reject("passage") // the way is closed to a cell without the key
	}
	if ent.Region == c.Region {
		if ent.Tag["spot"] != c.Spot {
			setSpot(&ent, c.Spot)
			s.Entities[c.Actor] = ent
		}
		return nil
	}
	ent.Region = c.Region
	setSpot(&ent, c.Spot)
	s.Entities[c.Actor] = ent
	w.count(s, c.Actor, "move")
	w.findPlace(s, c.Actor, ID(c.Region))
	w.codexTick(s, c.Actor, cause)
	w.emit(s, Event{Kind: "moved", Actor: c.Actor, Holder: c.Actor, Text: place.Name, Cause: cause, Data: map[string]string{"region": string(c.Region)}})
	if ent.Kind == w.U.PlayerKind {
		w.refreshOffers(s, c.Actor, cause)
		w.completeFor(s, c.Actor, cause)
		w.offer(s, c.Actor, cause)
	}
	return nil
}

func (w *World) act(s *State, origin string, actor ID, action string, args map[string]ID, cause string) error {
	switch action { // the engine's own verbs for learning
	case actExamine:
		return w.examine(s, origin, actor, args, cause)
	case actTell:
		return w.tellBelief(s, origin, actor, args, cause)
	case actMark:
		return w.leaveMark(s, origin, actor, args, cause)
	case actAgree:
		return w.agreeMark(s, origin, actor, args, cause)
	case actEvolve:
		return w.chooseMutation(s, origin, actor, args, cause)
	case actFindNiche:
		return w.findNiche(s, origin, actor, args, cause)
	case actRefuseE:
		return w.refuseMutation(s, origin, actor, cause)
	case actDifferentiate:
		return w.differentiate(s, origin, actor, args, cause)
	case actEnterDungeon:
		return w.enterDungeon(s, origin, actor, args, cause)
	case actClearRoom:
		return w.clearRoom(s, origin, actor, cause)
	case actFailDungeon:
		return w.failRun(s, origin, actor, cause)
	case actLeaveDungeon:
		return w.leaveRun(s, origin, actor, cause)
	}
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
	w.count(s, actor, a.ID)
	w.apply(s, a.Effects, b, cause)
	w.learn(s, actor, a.Tags, 1)
	return nil
}

// findPlace records, privately, that who has found the place.
func (w *World) findPlace(s *State, who, place ID) {
	if w.U.Discovered == "" || place == "" || s.Entities[who].Kind != w.U.PlayerKind {
		return
	}
	k := factKey(who, w.U.Discovered, who, place)
	if _, ok := s.Facts[k]; !ok {
		s.Facts[k] = Fact{Holder: who, P: w.U.Discovered, S: who, O: place, At: s.Tick, Cause: "visit"}
	}
}

func setSpot(e *Entity, spot string) {
	if spot == "" {
		delete(e.Tag, "spot")
		return
	}
	e.Tag["spot"] = spot
}

func (w *World) spotRegion(id string) ID {
	for _, sp := range w.U.Spots {
		if sp.ID == id {
			return sp.Region
		}
	}
	return ""
}

// addressedBy lists the people an action is directed at (its npc/person arguments):
// they always know who is speaking to them.
func addressedBy(w *World, args map[string]ID) []ID {
	var out []ID
	for _, id := range args {
		out = append(out, id)
	}
	slices.Sort(out)
	return out
}

// OpenGround is the spot a game server reports when the actor is in a region but at no named spot:
// nobody is close enough to notice what they do (unlike an empty spot, which means "not reported").
const OpenGround = "-"
