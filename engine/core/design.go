package core

import (
	"slices"
	"strconv"
	"strings"
)

// Design: the procedural signature of a player's cell, authored by the advisor (Jev). The universe lists traits (the shape of the
// nucleus, the texture of the membrane, which organelles dominate, the glow, the flavour of every ability's effect) and, for each,
// the options the client knows how to draw. Jev chooses an option per trait for this particular player, reading how they live, the
// genes they express, their class and where they have made their home; the engine only validates the choice (it must be one of the
// options) and keeps it in the player's Look. A deterministic default (the option whose affinities match the body axes) applies at
// the deadline, so the game is fine with the advisor off.

// TraitDef is one thing the advisor designs.
type TraitDef struct {
	ID       string        `json:"id"`
	Name     string        `json:"name"`
	Question string        `json:"question"` // what is being decided, in words, for the advisor
	Options  []TraitOption `json:"options"`
}

// TraitOption is one way a trait can be. Affinity weighs the body axes that favour it (used only for the default).
type TraitOption struct {
	ID       string           `json:"id"`
	Name     string           `json:"name"`
	Desc     string           `json:"desc"`
	Affinity map[string]int64 `json:"affinity,omitempty"`
}

func (w *World) trait(id string) (TraitDef, bool) {
	if w.U.Appearance == nil {
		return TraitDef{}, false
	}
	i := slices.IndexFunc(w.U.Appearance.Traits, func(t TraitDef) bool { return t.ID == id })
	if i < 0 {
		return TraitDef{}, false
	}
	return w.U.Appearance.Traits[i], true
}

func (w *World) compileDesign() error {
	a := w.U.Appearance
	if a == nil {
		return nil
	}
	axes := map[string]bool{}
	for _, x := range a.Axes {
		axes[x.ID] = true
	}
	seen := map[string]bool{}
	for _, t := range a.Traits {
		if !validID(t.ID) || seen[t.ID] || t.Name == "" || len(t.Options) < 2 {
			return invalid("design trait %q", t.ID)
		}
		seen[t.ID] = true
		opts := map[string]bool{}
		for _, o := range t.Options {
			if !validID(o.ID) || opts[o.ID] || o.Name == "" {
				return invalid("design trait %s: option %q", t.ID, o.ID)
			}
			opts[o.ID] = true
			for k := range o.Affinity {
				if !axes[k] {
					return invalid("design trait %s option %s: unknown axis %q", t.ID, o.ID, k)
				}
			}
		}
	}
	return nil
}

// designDefault is the option whose affinities match the body best (ties: the first).
func (w *World) designDefault(s *State, p ID, t TraitDef) string {
	base := w.baseline(s, p)
	best, bestScore := t.Options[0].ID, int64(-1<<62)
	for _, o := range t.Options {
		score := int64(0)
		for _, x := range w.U.Appearance.Axes {
			score += o.Affinity[x.ID] * (base[x.ID] - x.Base)
		}
		if score > bestScore {
			best, bestScore = o.ID, score
		}
	}
	return best
}

func (w *World) pendingDesign(s *State, p ID) bool {
	return slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
		return s.Decisions[k].Kind == "design" && s.Decisions[k].Subject == string(p)
	})
}

// designTick asks for a fresh design when a player has lived enough since the last one. Every trait is its own decision, all
// created together so the advisor answers them in parallel.
func (w *World) designTick(s *State, cause string) {
	a := w.U.Appearance
	if a == nil || len(a.Traits) == 0 || s.Tick%a.Every != 0 {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind != w.U.PlayerKind || w.pendingDesign(s, p) {
			continue
		}
		key := "design|" + string(p)
		total := w.totalDeeds(s, p)
		if total < max(a.MinDeeds, 1) || total-s.Receipts[key] < a.MinDeeds {
			continue
		}
		base := w.profile(s, p)
		base = append(base, w.genomeText(s, p), w.behaviourText(s, p))
		if now := s.Looks[p]; len(now.Traits) > 0 {
			keys := sortedKeys(now.Traits)
			cur := make([]string, 0, len(keys))
			for _, k := range keys {
				cur = append(cur, k+"="+now.Traits[k])
			}
			base = append(base, "current design (change it only if their life changed): "+strings.Join(cur, ", "))
		}
		for _, t := range a.Traits {
			opts := make([]Option, 0, len(t.Options))
			for _, o := range t.Options {
				opts = append(opts, Option{ID: o.ID, Title: o.Name, Desc: o.Desc})
			}
			id := "design:" + t.ID + ":" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
			ctx := append([]string{"trait being designed: " + t.Name + " - " + t.Question}, base...)
			s.Decisions[id] = Decision{ID: id, Kind: "design", Subject: string(p), Options: opts, Default: w.designDefault(s, p, t),
				Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
		}
		s.Receipts[key] = total
	}
}

// decideDesign keeps the advisor's option for one trait after revalidating it.
func (w *World) decideDesign(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	parts := strings.Split(d.ID, ":")
	if w.U.Appearance == nil || len(parts) < 4 || s.Entities[p].Kind != w.U.PlayerKind {
		return reject("design")
	}
	t, ok := w.trait(parts[1])
	if !ok || !slices.ContainsFunc(t.Options, func(o TraitOption) bool { return o.ID == choice }) {
		return reject("choice")
	}
	delete(s.Decisions, d.ID)
	if s.Looks == nil {
		s.Looks = map[ID]Look{}
	}
	l := s.Looks[p]
	traits := map[string]string{}
	for k, v := range l.Traits {
		traits[k] = v
	}
	traits[t.ID] = choice
	l.Traits, l.At = traits, s.Tick
	s.Looks[p] = l
	w.emit(s, Event{Kind: "design", Holder: p, Text: t.Name, Cause: cause, Data: map[string]string{"trait": t.ID, "choice": choice}})
	return nil
}
