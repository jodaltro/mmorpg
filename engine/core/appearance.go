package core

import (
	"slices"
	"strconv"
	"strings"
)

// Appearance: what a player's body looks like is procedural and personal.
// The universe declares numeric axes (ferocity, agility...) and, for each,
// which behaviour signals push it (what the player does, which attacks they
// use, how they move, who they talk to, which genes they express). From those
// signals the engine computes a baseline body; candidate variants lean the
// baseline different ways, and the advisor (Jev) picks the variant that best
// reflects how this person actually plays. Every few ticks the choice is
// reconsidered, so the body follows the player's life. Clients only draw.

// AppearanceDef configures the body axes and the variants offered to the advisor.
type AppearanceDef struct {
	Every    Tick         `json:"every"`    // ticks between reconsiderations
	MinDeeds int64        `json:"minDeeds"` // new deeds needed since the last decision
	Axes     []AxisDef    `json:"axes"`
	Variants []VariantDef `json:"variants"`
}

// AxisDef is one body parameter. Signals map a behaviour key to its weight:
// "deed:<action>", "style:<tag>", "rel:<entity>", "gene:<mutation>" or a number
// of the player. Raw = sum(weight*signal); the value saturates towards Min or
// Max around Scale, so no behaviour can push it out of range.
type AxisDef struct {
	ID      string           `json:"id"`
	Min     int64            `json:"min"`
	Max     int64            `json:"max"`
	Base    int64            `json:"base"`
	Scale   int64            `json:"scale"`
	Signals map[string]int64 `json:"signals"`
}

// VariantDef is a way the body may lean; Bias is added to the baseline per axis.
type VariantDef struct {
	ID   string           `json:"id"`
	Name string           `json:"name"`
	Desc string           `json:"desc"`
	Bias map[string]int64 `json:"bias"`
}

// Look is a player's current body: the variant and the value of every axis.
type Look struct {
	Variant string           `json:"variant"`
	Name    string           `json:"name"`
	Axes    map[string]int64 `json:"axes"`
	At      Tick             `json:"at"`
}

func (w *World) compileAppearance() error {
	a := w.U.Appearance
	if a == nil {
		return nil
	}
	if a.Every < 1 || a.MinDeeds < 0 || len(a.Axes) == 0 || len(a.Variants) < 2 {
		return invalid("appearance")
	}
	axes := map[string]bool{}
	for _, x := range a.Axes {
		if !validID(x.ID) || axes[x.ID] || x.Min >= x.Max || x.Base < x.Min || x.Base > x.Max || x.Scale < 1 || len(x.Signals) == 0 {
			return invalid("appearance axis %q", x.ID)
		}
		axes[x.ID] = true
		for key := range x.Signals {
			kind, ref, _ := strings.Cut(key, ":")
			switch kind {
			case "rel":
				if !slices.ContainsFunc(w.U.Entities, func(e EntitySeed) bool { return string(e.ID) == ref }) {
					return invalid("appearance axis %s: unknown entity %q", x.ID, ref)
				}
			case "gene":
				if _, ok := w.mutation(ref); !ok {
					return invalid("appearance axis %s: unknown mutation %q", x.ID, ref)
				}
			}
		}
	}
	seen := map[string]bool{}
	for _, v := range a.Variants {
		if !validID(v.ID) || seen[v.ID] || v.Name == "" {
			return invalid("appearance variant %q", v.ID)
		}
		seen[v.ID] = true
		for k := range v.Bias {
			if !axes[k] {
				return invalid("appearance variant %s: unknown axis %q", v.ID, k)
			}
		}
	}
	return nil
}

// signal reads one behaviour signal of player p.
func (w *World) signal(s *State, p ID, key string) int64 {
	kind, ref, found := strings.Cut(key, ":")
	if !found {
		return s.Entities[p].Num[key]
	}
	switch kind {
	case "deed":
		return s.Deeds[p][ref]
	case "style":
		return s.Styles[p][ref]
	case "rel":
		return s.Relations[relKey(ID(ref), p)]
	case "gene":
		if slices.Contains(s.Genomes[p].Genes, ref) {
			return 1
		}
	}
	return 0
}

// baseline is the body the player's behaviour alone would give.
func (w *World) baseline(s *State, p ID) map[string]int64 {
	out := map[string]int64{}
	for _, x := range w.U.Appearance.Axes {
		raw := int64(0)
		for key, weight := range x.Signals {
			raw += weight * w.signal(s, p, key)
		}
		v := x.Base
		switch {
		case raw > 0:
			v = x.Base + (x.Max-x.Base)*raw/(raw+x.Scale)
		case raw < 0:
			v = x.Base - (x.Base-x.Min)*(-raw)/(-raw+x.Scale)
		}
		out[x.ID] = v
	}
	return out
}

func (w *World) clampAxis(id string, v int64) int64 {
	for _, x := range w.U.Appearance.Axes {
		if x.ID == id {
			return min(max(v, x.Min), x.Max)
		}
	}
	return v
}

func (w *World) leaned(s *State, p ID, v VariantDef) map[string]int64 {
	out := w.baseline(s, p)
	for k, b := range v.Bias {
		out[k] = w.clampAxis(k, out[k]+b)
	}
	return out
}

// variantFit scores how well a variant matches what the behaviour pushes: it
// rewards leaning where the baseline already departs from neutral.
func (w *World) variantFit(s *State, p ID, v VariantDef) int64 {
	base := w.baseline(s, p)
	score := int64(0)
	for _, x := range w.U.Appearance.Axes {
		score += v.Bias[x.ID] * (base[x.ID] - x.Base)
	}
	return score
}

func (w *World) totalDeeds(s *State, p ID) int64 {
	n := int64(0)
	for _, c := range s.Deeds[p] {
		n += c
	}
	return n
}

func (w *World) appearanceTick(s *State, cause string) {
	a := w.U.Appearance
	if a == nil || s.Tick%a.Every != 0 {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind != w.U.PlayerKind {
			continue
		}
		key := "appearance|" + string(p)
		total := w.totalDeeds(s, p)
		if total < max(a.MinDeeds, 1) || total-s.Receipts[key] < a.MinDeeds {
			continue
		}
		if slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == "appearance" && s.Decisions[k].Subject == string(p)
		}) {
			continue
		}
		opts := make([]Option, 0, len(a.Variants))
		best, bestFit := a.Variants[0].ID, int64(-1<<62)
		for _, v := range a.Variants {
			fit := w.variantFit(s, p, v)
			if fit > bestFit {
				best, bestFit = v.ID, fit
			}
			opts = append(opts, Option{ID: v.ID, Title: v.Name, Desc: v.Desc + " [fit " + strconv.FormatInt(fit, 10) + "]"})
		}
		id := "appearance:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
		ctx := w.profile(s, p)
		ctx = append(ctx, w.genomeText(s, p), w.behaviourText(s, p))
		s.Decisions[id] = Decision{ID: id, Kind: "appearance", Subject: string(p), Options: opts, Default: best,
			Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
	}
}

// behaviourText is what the advisor reads about how this player moves, fights and relates.
func (w *World) behaviourText(s *State, p ID) string {
	base := w.baseline(s, p)
	parts := []string{}
	for _, x := range w.U.Appearance.Axes {
		parts = append(parts, x.ID+"="+strconv.FormatInt(base[x.ID], 10))
	}
	deeds := []string{}
	for _, k := range sortedKeys(s.Deeds[p]) {
		deeds = append(deeds, k+"="+strconv.FormatInt(s.Deeds[p][k], 10))
	}
	return "body axes from behaviour: " + strings.Join(parts, ", ") + "; deeds: " + strings.Join(deeds, ", ")
}

// decideAppearance applies the advisor's pick after revalidating it.
func (w *World) decideAppearance(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	if w.U.Appearance == nil || s.Entities[p].Kind != w.U.PlayerKind {
		return reject("appearance")
	}
	i := slices.IndexFunc(w.U.Appearance.Variants, func(v VariantDef) bool { return v.ID == choice })
	if i < 0 {
		return reject("choice")
	}
	v := w.U.Appearance.Variants[i]
	delete(s.Decisions, d.ID)
	if s.Looks == nil {
		s.Looks = map[ID]Look{}
	}
	s.Looks[p] = Look{Variant: v.ID, Name: v.Name, Axes: w.leaned(s, p, v), At: s.Tick}
	s.Receipts["appearance|"+string(p)] = w.totalDeeds(s, p)
	w.emit(s, Event{Kind: "appearance", Holder: p, Text: v.Name, Cause: cause, Data: map[string]string{"variant": v.ID}})
	return nil
}

// LookView is a body as anyone who can see the player sees it.
type LookView struct {
	Variant string           `json:"variant"`
	Name    string           `json:"name"`
	Axes    map[string]int64 `json:"axes"`
}

func (w *World) lookOf(s *State, p ID) *LookView {
	l, ok := s.Looks[p]
	if !ok {
		return nil
	}
	return &LookView{Variant: l.Variant, Name: l.Name, Axes: l.Axes}
}
