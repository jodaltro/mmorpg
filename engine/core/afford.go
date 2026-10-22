package core

import (
	"slices"
	"strings"
)

// Affordance is something an observer could try now: an intent (origin
// "player") or an occurrence a game server would confirm (origin "adapter").
// It is computed only from what the observer can tell — where people are,
// their own skills, numbers, deeds, beliefs, private facts and the hour —
// never from hidden world facts or other minds. Unknown conditions count as
// "maybe", so listing an affordance reveals nothing; the authority still
// validates the attempt against the truth.
type Affordance struct {
	Action string        `json:"action"`
	Title  string        `json:"title"`
	Origin string        `json:"origin"`
	Args   map[string]ID `json:"args,omitempty"`
	With   ID            `json:"with,omitempty"` // entity the action is about (an NPC or a landmark)
	Region ID            `json:"region,omitempty"`
	Tags   []string      `json:"tags,omitempty"`
}

// Affordances lists what p could plausibly do from where they are.
func (w *World) Affordances(s *State, p ID) []Affordance {
	self, ok := s.Entities[p]
	if !ok {
		return nil
	}
	out := []Affordance{}
	for _, a := range w.U.Actions {
		origin := ""
		switch {
		case slices.Contains(a.By, "player"):
			origin = "player"
		case slices.Contains(a.By, "adapter"):
			origin = "adapter"
		default:
			continue
		}
		var expand func(i int, b Bind)
		expand = func(i int, b Bind) {
			if i == len(a.Params) {
				if !w.plausible(s, a.Requires, b, p) {
					return
				}
				af := Affordance{Action: a.ID, Origin: origin, Title: w.render(s, actionTitle(a), b), Region: self.Region, Tags: a.Tags}
				if len(a.Params) > 0 {
					af.Args = map[string]ID{}
					for _, prm := range a.Params {
						af.Args[prm.Name] = b[prm.Name]
					}
				}
				af.With = nearTarget(a.Requires, b)
				out = append(out, af)
				return
			}
			prm := a.Params[i]
			for _, id := range sortedIDs(s.Entities) {
				if id == p || s.Entities[id].Kind != prm.Kind {
					continue
				}
				b[prm.Name] = id
				expand(i+1, b)
				delete(b, prm.Name)
			}
		}
		expand(0, Bind{"self": p})
	}
	out = append(out, w.signAffordances(s, p, self)...)
	out = append(out, w.markAffordances(s, p, self)...)
	slices.SortStableFunc(out, func(x, y Affordance) int { return strings.Compare(string(x.With), string(y.With)) })
	return out
}

// plausible is Holds with three values: leaves the observer cannot tell are
// unknown, and only a known false rules the action out.
func (w *World) plausible(s *State, c Cond, b Bind, p ID) bool {
	v, known := w.tell(s, c, b, p)
	return v || !known
}

func (w *World) tell(s *State, c Cond, b Bind, p ID) (bool, bool) {
	isSelf := func(ref string) bool { return ref == "" || resolve(ref, b) == p }
	switch {
	case c.All != nil:
		known := true
		for _, x := range c.All {
			v, k := w.tell(s, x, b, p)
			if k && !v {
				return false, true
			}
			known = known && k
		}
		return true, known
	case c.Any != nil:
		known := true
		for _, x := range c.Any {
			v, k := w.tell(s, x, b, p)
			if k && v {
				return true, true
			}
			known = known && k
		}
		return false, known
	case c.Not != nil:
		v, k := w.tell(s, *c.Not, b, p)
		return !v, k
	case c.Fact != nil:
		if c.Fact.Private { // the observer's own private facts are visible to them
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.Knows != nil:
		if isSelf(c.Knows.Who) {
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.Num != nil:
		if isSelf(c.Num.E) {
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.Tag != nil:
		if isSelf(c.Tag.E) {
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.Has != nil:
		if isSelf(c.Has.E) {
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.Deeds != nil:
		if isSelf(c.Deeds.E) {
			return w.Holds(s, c, b), true
		}
		return false, false
	case c.In != nil, c.Near != nil, c.Time != nil: // where people are and the hour are visible
		return w.Holds(s, c, b), true
	case c.Rel != nil, c.Chance != nil, c.Beat != nil: // other minds, luck and the story's state are not
		return false, false
	}
	return true, true
}

// nearTarget: the first thing the action must be next to, for client menus.
func nearTarget(c Cond, b Bind) ID {
	if c.Near != nil && resolve(c.Near.A, b) == b["self"] {
		return resolve(c.Near.B, b)
	}
	for _, x := range c.All {
		if t := nearTarget(x, b); t != "" {
			return t
		}
	}
	return ""
}

func actionTitle(a ActionDef) string {
	if a.Title != "" {
		return a.Title
	}
	t := strings.ReplaceAll(a.ID, "-", " ")
	return strings.ToUpper(t[:1]) + t[1:]
}
