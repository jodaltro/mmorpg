package core

import (
	"slices"
	"strconv"
	"strings"
)

// Differentiation: players are born as the simplest, undifferentiated form
// and grow into a lineage in steps (tiers). Maturity, a number built by
// deeds, opens each step; the engine then offers the lineages of the next tier
// that descend from the player's current one. The advisor (Jev) picks the one
// the body leans towards, judging from how the player has been living; the
// player still chooses. Differentiating is permanent and shapes the body, the
// stats and the mutations that may appear. The current lineage is a tag on the
// player ("lineage", "tier"), so conditions and the client can read it.

const actDifferentiate = "diferenciar" // args: lineage

// DifferentiationDef sets the maturity each tier needs (ascending).
type DifferentiationDef struct {
	Maturity string  `json:"maturity"` // player number built by deeds
	Tiers    []int64 `json:"tiers"`    // maturity needed to open tier 1, 2, ...
}

// LineageDef is one lineage. From is the parent lineage ("" for tier 1).
type LineageDef struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Desc     string   `json:"desc"`
	Tier     int      `json:"tier"`
	From     string   `json:"from,omitempty"`
	Tags     []string `json:"tags,omitempty"` // the path it belongs to, in the vocabulary of styles
	Eligible *Cond    `json:"eligible,omitempty"`
}

// Differ is a player's pending lineage offer.
type Differ struct {
	Offer    []string `json:"offer,omitempty"` // featured first
	Featured string   `json:"featured,omitempty"`
}

// LineageOption is a lineage as the player sees it in an offer.
type LineageOption struct {
	ID   string   `json:"id"`
	Name string   `json:"name"`
	Desc string   `json:"desc"`
	Tier int      `json:"tier"`
	Tags []string `json:"tags,omitempty"`
}

// LineageView is the observer's own lineage, offer and progress.
type LineageView struct {
	Current  string          `json:"current"` // "" while undifferentiated
	Name     string          `json:"name"`
	Tier     int             `json:"tier"`
	Offer    []LineageOption `json:"offer"`
	Featured string          `json:"featured,omitempty"`
	Maturity int64           `json:"maturity"`
	Next     int64           `json:"next"` // maturity that opens the next tier, 0 when final
}

func (w *World) lineageDef(id string) (LineageDef, bool) {
	i := slices.IndexFunc(w.U.Lineages, func(l LineageDef) bool { return l.ID == id })
	if i < 0 {
		return LineageDef{}, false
	}
	return w.U.Lineages[i], true
}

// lineageOf is the player's current lineage id ("" when undifferentiated) and tier.
func (w *World) lineageOf(s *State, p ID) (string, int) {
	e := s.Entities[p]
	tier, _ := strconv.Atoi(e.Tag["tier"])
	return e.Tag["lineage"], tier
}

func (w *World) compileDifferentiation() error {
	d := w.U.Differentiation
	if d == nil {
		if len(w.U.Lineages) > 0 {
			return invalid("lineages need a differentiation block")
		}
		return nil
	}
	if d.Maturity == "" || len(d.Tiers) == 0 || len(w.U.Lineages) == 0 || !slices.IsSorted(d.Tiers) || d.Tiers[0] < 1 {
		return invalid("differentiation")
	}
	seen := map[string]LineageDef{}
	for _, l := range w.U.Lineages {
		if !validID(l.ID) || l.Name == "" || l.Tier < 1 || l.Tier > len(d.Tiers) {
			return invalid("lineage %q", l.ID)
		}
		if _, dup := seen[l.ID]; dup {
			return invalid("duplicate lineage %q", l.ID)
		}
		seen[l.ID] = l
	}
	for _, l := range w.U.Lineages {
		if l.Tier == 1 && l.From != "" {
			return invalid("lineage %s: a tier 1 lineage has no parent", l.ID)
		}
		if l.Tier > 1 {
			if parent, ok := seen[l.From]; !ok || parent.Tier != l.Tier-1 {
				return invalid("lineage %s: parent %q is not a tier %d lineage", l.ID, l.From, l.Tier-1)
			}
		}
	}
	for t := 1; t <= len(d.Tiers); t++ {
		if !slices.ContainsFunc(w.U.Lineages, func(l LineageDef) bool { return l.Tier == t }) {
			return invalid("differentiation: no lineage for tier %d", t)
		}
	}
	if _, taken := w.actions[actDifferentiate]; taken {
		return invalid("action id %q is reserved by the engine", actDifferentiate)
	}
	return nil
}

// lineageCandidates are the lineages of the player's next tier that descend from the current one.
func (w *World) lineageCandidates(s *State, p ID) []LineageDef {
	cur, tier := w.lineageOf(s, p)
	out := []LineageDef{}
	for _, l := range w.U.Lineages {
		if l.Tier != tier+1 || l.From != cur {
			continue
		}
		if l.Eligible != nil && !w.Holds(s, *l.Eligible, Bind{"self": p}) {
			continue
		}
		out = append(out, l)
	}
	return out
}

func (w *World) lineageFit(s *State, p ID, l LineageDef) int64 {
	score := int64(0)
	for _, t := range l.Tags {
		score += min(s.Styles[p][t], 10)
	}
	return score
}

func (w *World) lineageTick(s *State, cause string) {
	d := w.U.Differentiation
	if d == nil {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind != w.U.PlayerKind || len(s.Lineages[p].Offer) > 0 {
			continue
		}
		_, tier := w.lineageOf(s, p)
		if tier >= len(d.Tiers) || s.Entities[p].Num[d.Maturity] < d.Tiers[tier] {
			continue
		}
		if slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == "lineage" && s.Decisions[k].Subject == string(p)
		}) {
			continue
		}
		cands := w.lineageCandidates(s, p)
		if len(cands) == 0 {
			continue
		}
		best := cands[0]
		for _, c := range cands {
			if w.lineageFit(s, p, c) > w.lineageFit(s, p, best) {
				best = c
			}
		}
		if len(cands) == 1 {
			w.offerLineages(s, p, best.ID, cause)
			continue
		}
		opts := make([]Option, 0, len(cands))
		for _, c := range cands {
			desc := c.Desc
			if len(c.Tags) > 0 {
				desc += " [path: " + strings.Join(c.Tags, ", ") + "]"
			}
			opts = append(opts, Option{ID: c.ID, Title: c.Name, Desc: desc + " [fit " + strconv.FormatInt(w.lineageFit(s, p, c), 10) + "]"})
		}
		id := "lineage:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
		ctx := w.profile(s, p)
		ctx = append(ctx, w.genomeText(s, p))
		if w.U.Appearance != nil {
			ctx = append(ctx, w.behaviourText(s, p))
		}
		s.Decisions[id] = Decision{ID: id, Kind: "lineage", Subject: string(p), Options: opts, Default: best.ID,
			Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
	}
}

// decideLineage applies the advisor's pick after revalidating it.
func (w *World) decideLineage(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	if w.U.Differentiation == nil || len(s.Lineages[p].Offer) > 0 {
		return reject("lineage no longer pending")
	}
	if !slices.ContainsFunc(w.lineageCandidates(s, p), func(l LineageDef) bool { return l.ID == choice }) {
		return reject("choice no longer valid")
	}
	delete(s.Decisions, d.ID)
	w.offerLineages(s, p, choice, cause)
	return nil
}

func (w *World) offerLineages(s *State, p ID, featured, cause string) {
	offer := []string{featured}
	for _, l := range w.lineageCandidates(s, p) {
		if l.ID != featured {
			offer = append(offer, l.ID)
		}
	}
	if s.Lineages == nil {
		s.Lineages = map[ID]Differ{}
	}
	s.Lineages[p] = Differ{Offer: offer, Featured: featured}
	l, _ := w.lineageDef(featured)
	w.emit(s, Event{Kind: "lineage-offered", Holder: p, Text: l.Name, Cause: cause,
		Data: map[string]string{"featured": featured, "offer": strings.Join(offer, ",")}})
}

// differentiate is the player's choice: grow into one lineage of the pending offer.
func (w *World) differentiate(s *State, origin string, p ID, args map[string]ID, cause string) error {
	d := s.Lineages[p]
	id := string(args["lineage"])
	if origin != "player" || w.U.Differentiation == nil || s.Entities[p].Kind != w.U.PlayerKind || !slices.Contains(d.Offer, id) {
		return reject("lineage")
	}
	l, _ := w.lineageDef(id)
	e := s.Entities[p]
	if e.Tag == nil {
		e.Tag = map[string]string{}
	}
	e.Tag["lineage"], e.Tag["tier"] = l.ID, strconv.Itoa(l.Tier)
	s.Entities[p] = e
	s.Lineages[p] = Differ{}
	w.learn(s, p, l.Tags, 2)
	w.count(s, p, actDifferentiate)
	w.emit(s, Event{Kind: "differentiated", Actor: p, Holder: p, Public: true, Text: s.Entities[p].Name + " se diferencia em " + l.Name + ".", Cause: cause,
		Data: map[string]string{"lineage": l.ID, "tier": strconv.Itoa(l.Tier)}})
	w.grantStarters(s, p, l.ID, cause)
	w.discover(s, p, cause)
	return nil
}

func (w *World) lineageViewOf(s *State, p ID) *LineageView {
	d := w.U.Differentiation
	if d == nil || s.Entities[p].Kind != w.U.PlayerKind {
		return nil
	}
	cur, tier := w.lineageOf(s, p)
	v := &LineageView{Current: cur, Tier: tier, Offer: []LineageOption{}, Featured: s.Lineages[p].Featured, Maturity: s.Entities[p].Num[d.Maturity]}
	if l, ok := w.lineageDef(cur); ok {
		v.Name = l.Name
	}
	if tier < len(d.Tiers) {
		v.Next = d.Tiers[tier]
	}
	for _, id := range s.Lineages[p].Offer {
		if l, ok := w.lineageDef(id); ok {
			v.Offer = append(v.Offer, LineageOption{ID: l.ID, Name: l.Name, Desc: l.Desc, Tier: l.Tier, Tags: l.Tags})
		}
	}
	return v
}
