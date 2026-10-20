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
		return compare(e.Num[c.Num.K], c.Num.Op, c.Num.V)
	case c.Tag != nil:
		e, ok := s.Entities[resolve(c.Tag.E, b)]
		return ok && e.Tag[c.Tag.K] == c.Tag.V
	case c.Beat != nil:
		return s.Arcs[c.Beat.Arc].Beats[c.Beat.Beat].State == c.Beat.State
	case c.In != nil:
		e, ok := s.Entities[resolve(c.In.E, b)]
		return ok && e.Region != "" && e.Region == resolve(c.In.Region, b)
	case c.Near != nil:
		return w.near(s, resolve(c.Near.A, b), resolve(c.Near.B, b))
	case c.Chance != nil:
		roll := pick(c.Chance.Seed+"|"+string(b["self"])+"|"+strconv.FormatInt(int64(s.Tick), 10)+"|"+strconv.FormatInt(s.Seq, 10), 1000)
		return int64(roll) < c.Chance.Permille
	case c.Time != nil:
		h := w.Hour(s)
		if c.Time.From <= c.Time.To {
			return h >= c.Time.From && h < c.Time.To
		}
		return h >= c.Time.From || h < c.Time.To
	case c.Rel != nil:
		return compare(s.Relations[relKey(resolve(c.Rel.A, b), resolve(c.Rel.B, b))], c.Rel.Op, c.Rel.V)
	}
	return true
}

// Hour is the in-game hour (0-23), or -1 when the universe has no days.
func (w *World) Hour(s *State) int64 {
	if w.U.DayLength < 1 {
		return -1
	}
	return int64(s.Tick%w.U.DayLength) * 24 / int64(w.U.DayLength)
}

func compare(x int64, op string, v int64) bool {
	switch op {
	case "<":
		return x < v
	case "<=":
		return x <= v
	case "==":
		return x == v
	case "!=":
		return x != v
	case ">=":
		return x >= v
	default:
		return x > v
	}
}

func relKey(a, b ID) string { return string(a) + "|" + string(b) }

// near: a is where b is, or inside b when b is itself a place.
func (w *World) near(s *State, a, b ID) bool {
	ea, ok := s.Entities[a]
	if !ok || ea.Region == "" {
		return false
	}
	if ea.Region == b {
		return true
	}
	eb, ok := s.Entities[b]
	return ok && eb.Region == ea.Region
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
		case "relate":
			// What E feels about To, remembered per pair (Nemesis-style memory).
			a, to := resolve(e.E, b), resolve(e.To, b)
			if a == "" || to == "" {
				continue
			}
			k := relKey(a, to)
			x := s.Relations[k] + e.D
			if e.Min != nil && x < *e.Min {
				x = *e.Min
			}
			if e.Max != nil && x > *e.Max {
				x = *e.Max
			}
			s.Relations[k] = x
		case "relocate":
			id, to := resolve(e.E, b), resolve(e.To, b)
			if ent, ok := s.Entities[id]; ok && w.regions[s.Entities[to].Kind] {
				ent.Region = to
				s.Entities[id] = ent
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
