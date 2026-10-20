package core

import (
	"slices"
	"strconv"
	"strings"
)

// --- Player model (after PaSSAGE, Thue et al. 2007) ----------------------
// Deeds and finished quests teach the world what each player enjoys.

func (w *World) learn(s *State, p ID, tags []string, d int64) {
	if len(tags) == 0 || s.Entities[p].Kind != w.U.PlayerKind {
		return
	}
	if s.Styles[p] == nil {
		s.Styles[p] = map[string]int64{}
	}
	for _, t := range tags {
		s.Styles[p][t] = max(0, s.Styles[p][t]+d)
	}
}

func (w *World) styleText(s *State, p ID) string {
	m := s.Styles[p]
	if len(m) == 0 {
		return "unknown yet"
	}
	keys := sortedKeys(m)
	slices.SortStableFunc(keys, func(a, b string) int { return int(m[b] - m[a]) })
	parts := []string{}
	for _, k := range keys {
		parts = append(parts, k+"="+strconv.FormatInt(m[k], 10))
	}
	return strings.Join(parts, ", ")
}

// --- Salience (storylets; Valve dynamic dialog: most specific wins) -------

func leaves(c Cond) int {
	n := 0
	for _, x := range c.All {
		n += leaves(x)
	}
	for _, x := range c.Any {
		n += leaves(x)
	}
	if c.Not != nil {
		n += leaves(*c.Not)
	}
	if c.Fact != nil || c.Knows != nil || c.Num != nil || c.Tag != nil || c.Beat != nil || c.In != nil || c.Near != nil || c.Rel != nil || c.Chance != nil || c.Time != nil {
		n++
	}
	return n
}

// salience scores how fitting a candidate is for this player now: more
// specific preconditions, matching play style, the world story, the bond
// with the giver, minus fatigue from repeating the same kind of quest.
func (w *World) salience(s *State, p ID, c candidate) int64 {
	score := int64(2 * leaves(c.def.Eligible))
	for _, t := range c.def.Tags {
		score += min(s.Styles[p][t], 10)
	}
	if c.def.Arc != "" {
		score += 6
	}
	if c.def.Giver != "" {
		b := Bind{"self": p}
		for k, v := range c.bind {
			b[k] = v
		}
		score += min(max(s.Relations[relKey(resolve(c.def.Giver, b), p)], -6), 6)
	}
	// Crowding: an MMO feels alive when people pursue different things.
	for _, q := range s.Quests {
		if q.Def == c.def.ID && q.Holder != p && (q.State == "offered" || q.State == "active") {
			score -= 3
		}
	}
	for _, d := range s.Decisions {
		if def, _, _ := strings.Cut(d.Default, "|"); d.Kind == "offer" && d.Subject != string(p) && def == c.def.ID {
			score -= 3
		}
	}
	recent := 0
	for i := len(s.Events) - 1; i >= 0 && recent < 3; i-- {
		e := s.Events[i]
		if e.Kind != "quest-done" || e.Holder != p {
			continue
		}
		recent++
		if q, ok := s.Quests[e.Data["quest"]]; ok {
			for _, t := range w.quests[q.Def].Tags {
				if slices.Contains(c.def.Tags, t) {
					score -= 3
				}
			}
		}
	}
	return score
}

// best returns the most salient candidate (ties broken by a stable hash).
func (w *World) best(s *State, p ID, cands []candidate, seed string) candidate {
	top := []candidate{}
	var hi int64
	for i, c := range cands {
		sc := w.salience(s, p, c)
		if i == 0 || sc > hi {
			hi, top = sc, []candidate{c}
		} else if sc == hi {
			top = append(top, c)
		}
	}
	return top[pick(seed, len(top))]
}

// --- Gossip (after Talk of the Town, Ryan et al. 2015) --------------------
// Entities sharing a place exchange their newest beliefs on shareable
// predicates. Stale beliefs travel too, so rumors can be wrong.

func (w *World) gossip(s *State, cause string) {
	g := w.U.Gossip
	if g == nil || s.Tick%g.Every != 0 {
		return
	}
	groups := map[ID][]ID{}
	for _, id := range sortedIDs(s.Entities) {
		e := s.Entities[id]
		if e.Region != "" && slices.Contains(g.Kinds, e.Kind) {
			groups[e.Region] = append(groups[e.Region], id)
		}
	}
	for _, region := range sortedIDs(groups) {
		members := groups[region]
		if len(members) < 2 {
			continue
		}
		newest := map[string]Belief{}
		teller := map[string]ID{}
		for _, m := range members {
			for k, b := range s.Beliefs[m] {
				if !slices.Contains(g.Predicates, b.P) {
					continue
				}
				if cur, ok := newest[k]; !ok || b.At > cur.At || b.At == cur.At && m < teller[k] {
					newest[k], teller[k] = b, m
				}
			}
		}
		for _, k := range sortedKeys(newest) {
			b := newest[k]
			for _, m := range members {
				if m == teller[k] {
					continue
				}
				if old, ok := s.Beliefs[m][k]; ok && old.At >= b.At {
					continue
				}
				heard := Belief{P: b.P, S: b.S, O: b.O, Holds: b.Holds, Source: "rumor", From: teller[k], At: b.At}
				s.believe(m, heard)
				w.count(s, m, "rumor")
				if s.Entities[m].Kind == w.U.PlayerKind && g.Texts[b.P] != "" && b.Holds {
					text := w.render(s, g.Texts[b.P], Bind{"from": teller[k], "s": b.S})
					w.emit(s, Event{Kind: "rumor", Actor: teller[k], Holder: m, Text: text, Cause: cause, Data: map[string]string{"p": b.P}})
				}
			}
		}
	}
}

// --- Pacing (after the Left 4 Dead AI Director and RimWorld storytellers) --

func (w *World) decayTension(s *State) {
	d := w.U.Director
	if d == nil || s.Tension == 0 {
		return
	}
	keep := d.Decay
	if keep == 0 {
		keep = 95
	}
	s.Tension = s.Tension * keep / 100
}

func (w *World) phase(s *State) string {
	d := w.U.Director
	switch {
	case d == nil || d.Peak == 0:
		return "free"
	case s.Tension >= d.Peak:
		return "relax"
	case s.Tension <= d.Calm:
		return "build-up"
	}
	return "sustain"
}
