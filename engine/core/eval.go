package core

import (
	"maps"
	"strconv"
	"strings"
)

func resolve(r string, b Bind) ID {
	if strings.HasPrefix(r, "$") {
		return b[r[1:]]
	}
	return ID(r)
}

func (w *World) truth(s *State, p *Pattern, b Bind) (string, bool) {
	holder := ID("")
	if p.Private {
		holder = b["self"]
		if holder == "" {
			return "", false
		}
	}
	subj := resolve(p.S, b)
	if subj == "" {
		return "", false
	}
	obj := ID("")
	if p.O != "" {
		if obj = resolve(p.O, b); obj == "" {
			return "", false
		}
	}
	return factKey(holder, p.P, subj, obj), true
}

// Holds evaluates a condition. Fact and Num read the truth; Knows reads
// beliefs. NPC goals should be written with Knows so they act on what they
// know, not on what is true.
func (w *World) Holds(s *State, c Cond, b Bind) bool {
	switch {
	case c.All != nil:
		for _, x := range c.All {
			if !w.Holds(s, x, b) {
				return false
			}
		}
		return true
	case c.Any != nil:
		for _, x := range c.Any {
			if w.Holds(s, x, b) {
				return true
			}
		}
		return false
	case c.Not != nil:
		return !w.Holds(s, *c.Not, b)
	case c.Fact != nil:
		k, ok := w.truth(s, c.Fact, b)
		if !ok {
			return false
		}
		_, exists := s.Facts[k]
		return exists
	case c.Knows != nil:
		who := c.Knows.Who
		if who == "" {
			who = "$self"
		}
		holder := resolve(who, b)
		k, ok := w.truth(s, &Pattern{P: c.Knows.P, S: c.Knows.S, O: c.Knows.O}, b)
		if !ok || holder == "" {
			return false
		}
		bel, has := s.Beliefs[holder][k]
		return has && bel.Holds == !c.Knows.False
	case c.Num != nil:
		e, ok := s.Entities[resolve(c.Num.E, b)]
		if !ok {
			return false
		}
		x := e.Num[c.Num.K]
		switch c.Num.Op {
		case "<":
			return x < c.Num.V
		case "<=":
			return x <= c.Num.V
		case "==":
			return x == c.Num.V
		case "!=":
			return x != c.Num.V
		case ">=":
			return x >= c.Num.V
		default:
			return x > c.Num.V
		}
	case c.Tag != nil:
		e, ok := s.Entities[resolve(c.Tag.E, b)]
		return ok && e.Tag[c.Tag.K] == c.Tag.V
	case c.Beat != nil:
		return s.Arcs[c.Beat.Arc].Beats[c.Beat.Beat].State == c.Beat.State
	}
	return true
}

// patterns collects the world fact patterns a condition reads; an agent
// whose attempt fails observes them, so a stale belief gets corrected.
func patterns(c Cond, out *[]Pattern) {
	for _, x := range c.All {
		patterns(x, out)
	}
	for _, x := range c.Any {
		patterns(x, out)
	}
	if c.Not != nil {
		patterns(*c.Not, out)
	}
	if c.Fact != nil && !c.Fact.Private {
		*out = append(*out, *c.Fact)
	}
}

func (w *World) render(s *State, text string, b Bind) string {
	if !strings.Contains(text, "{") {
		return text
	}
	for _, k := range sortedKeys(b) {
		name := string(b[k])
		if e, ok := s.Entities[b[k]]; ok {
			name = e.Name
		}
		text = strings.ReplaceAll(text, "{"+k+"}", name)
	}
	return text
}

func (w *World) emit(s *State, e Event) {
	s.Seq++
	e.Seq = s.Seq
	e.At = s.Tick
	s.Events = append(s.Events, e)
	if over := len(s.Events) - w.U.Limits.MaxEvents; over > 0 {
		s.Events = append([]Event(nil), s.Events[over:]...)
	}
}

// apply runs effects in order. Effects never fail: the validator already
// rejected anything a world could not execute; unbound references are no-ops.
func (w *World) apply(s *State, list []Effect, b Bind, cause string) {
	self := b["self"]
	for _, e := range list {
		if e.If != nil && !w.Holds(s, *e.If, b) {
			continue
		}
		switch e.Op {
		case "assert", "retract":
			k, ok := w.truth(s, e.Fact, b)
			if !ok {
				continue
			}
			if e.Op == "retract" {
				delete(s.Facts, k)
				continue
			}
			if _, exists := s.Facts[k]; !exists {
				h := ID("")
				if e.Fact.Private {
					h = self
				}
				o := ID("")
				if e.Fact.O != "" {
					o = resolve(e.Fact.O, b)
				}
				s.Facts[k] = Fact{Holder: h, P: e.Fact.P, S: resolve(e.Fact.S, b), O: o, At: s.Tick, Cause: cause}
			}
		case "adjust":
			id := resolve(e.E, b)
			ent, ok := s.Entities[id]
			if !ok {
				continue
			}
			x := ent.Num[e.K] + e.D
			if e.Min != nil && x < *e.Min {
				x = *e.Min
			}
			if e.Max != nil && x > *e.Max {
				x = *e.Max
			}
			ent.Num[e.K] = x
			s.Entities[id] = ent
		case "set":
			id := resolve(e.E, b)
			if ent, ok := s.Entities[id]; ok {
				ent.Tag[e.K] = w.render(s, e.V, b)
				s.Entities[id] = ent
			}
		case "observe":
			if self == "" {
				continue
			}
			if p, ok := w.belief(s, e.Fact, b, "observation", ""); ok {
				s.believe(self, p)
			}
		case "inform":
			to := resolve(e.To, b)
			k, ok := w.truth(s, e.Fact, b)
			if !ok || to == "" || self == "" {
				continue
			}
			// You can only pass on what you believe, true or not.
			if mine, has := s.Beliefs[self][k]; has {
				mine.Source, mine.From, mine.At = "communication", self, s.Tick
				s.believe(to, mine)
			}
		case "schedule":
			s.Seq++
			s.Schedules = append(s.Schedules, Scheduled{Key: "s" + strconv.FormatInt(s.Seq, 10), Due: s.Tick + e.After, Rule: e.Rule, Bind: maps.Clone(b), Cause: cause})
			sortSchedules(s.Schedules)
		case "emit":
			ev := Event{Kind: e.Event, Actor: self, Public: e.Public, Text: w.render(s, e.Text, b), Cause: cause}
			if !e.Public {
				ev.Holder = self
			}
			w.emit(s, ev)
			if e.Reveals != nil {
				if p, ok := w.belief(s, e.Reveals, b, "publication", self); ok {
					for _, id := range sortedIDs(s.Entities) {
						if w.perceives[s.Entities[id].Kind] {
							s.believe(id, p)
						}
					}
				}
			}
		}
	}
}

// belief snapshots the current truth of a world fact as a belief.
func (w *World) belief(s *State, p *Pattern, b Bind, source string, from ID) (Belief, bool) {
	k, ok := w.truth(s, &Pattern{P: p.P, S: p.S, O: p.O}, b)
	if !ok {
		return Belief{}, false
	}
	_, holds := s.Facts[k]
	o := ID("")
	if p.O != "" {
		o = resolve(p.O, b)
	}
	return Belief{P: p.P, S: resolve(p.S, b), O: o, Holds: holds, Source: source, From: from, At: s.Tick}, true
}
