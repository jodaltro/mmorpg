package core

import (
	"slices"
	"strconv"
	"strings"
)

func happeningKey(id string) string { return "happening|" + id }

func (w *World) happening(id string) (Happening, bool) {
	i := slices.IndexFunc(w.U.Happenings, func(h Happening) bool { return h.ID == id })
	if i < 0 {
		return Happening{}, false
	}
	return w.U.Happenings[i], true
}

func (w *World) happeningReady(s *State, h Happening) bool {
	return s.Cooldowns[happeningKey(h.ID)] <= s.Tick && w.Holds(s, h.When, Bind{})
}

// direct creates a world decision when the director is due: the advisor
// picks which eligible happening occurs now.
func (w *World) direct(s *State) {
	d := w.U.Director
	if d == nil || s.Tick%d.Every != 0 {
		return
	}
	for _, x := range s.Decisions {
		if x.Kind == "world" {
			return
		}
	}
	opts := []Option{}
	for _, h := range w.U.Happenings {
		if w.happeningReady(s, h) {
			opts = append(opts, Option{ID: h.ID, Title: h.Title, Desc: h.Desc})
		}
	}
	if len(opts) == 0 {
		return
	}
	id := "world:" + strconv.FormatInt(int64(s.Tick), 10)
	def := opts[pick(id, len(opts))].ID
	if d.AllowNone {
		opts = append(opts, Option{ID: "none", Title: "Nothing happens", Desc: "Keep the world quiet for now."})
	}
	ctx := w.storySoFar(s)
	ctx = append(ctx, w.indicators(s)...)
	ctx = append(ctx, w.recentPublic(s, 8)...)
	s.Decisions[id] = Decision{ID: id, Kind: "world", Subject: "director", Options: opts, Default: def,
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
}

// occur applies a chosen happening after revalidating it.
func (w *World) occur(s *State, id, cause string) error {
	if id == "none" {
		return nil
	}
	h, ok := w.happening(id)
	if !ok || !w.happeningReady(s, h) {
		return reject("happening no longer valid")
	}
	if h.Cooldown > 0 {
		s.Cooldowns[happeningKey(id)] = s.Tick + h.Cooldown
	}
	w.apply(s, h.Effects, Bind{}, "happening:"+id)
	return nil
}

// indicators summarize the visible state of non-player entities.
func (w *World) indicators(s *State) []string {
	out := []string{}
	for _, id := range sortedIDs(s.Entities) {
		e := s.Entities[id]
		if e.Kind == w.U.PlayerKind || len(e.Num) == 0 {
			continue
		}
		parts := []string{}
		for _, k := range sortedKeys(e.Num) {
			parts = append(parts, k+"="+strconv.FormatInt(e.Num[k], 10))
		}
		out = append(out, "state "+e.Name+": "+strings.Join(parts, ", "))
	}
	players := 0
	for _, e := range s.Entities {
		if e.Kind == w.U.PlayerKind {
			players++
		}
	}
	return append(out, "players in world: "+strconv.Itoa(players))
}
