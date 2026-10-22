package core

import (
	"slices"
	"strconv"
	"strings"
)

// Evolution: every player's rooted goal is to evolve. Confirmed deeds build a
// pressure number (declared by the universe); when it overflows, the engine
// gathers the mutations that make sense for that player and, if there are
// more than fit in one offer, asks the advisor (Jev) which one the body leans
// towards, judging from how the player has been living. The player still
// chooses among the offer. Choosing reinforces the style the mutation
// expresses, so each path deepens. No levels: the genome is the progression.

const (
	actEvolve  = "evoluir"          // args: gene
	actRefuseE = "recusar-evolucao" // no args
)

// EvolutionDef configures how mutations are offered.
type EvolutionDef struct {
	Pressure  string `json:"pressure"`        // player number that builds up with deeds
	Threshold int64  `json:"threshold"`       // pressure spent per offer
	Offer     int    `json:"offer,omitempty"` // candidates per offer (default 3)
	Slots     int    `json:"slots,omitempty"` // genes expressed at once (default 3); the oldest is reabsorbed
}

// MutationDef is a gene the body may express. Tags are the evolutionary path
// it belongs to, in the same vocabulary as action and quest tags.
type MutationDef struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Desc     string   `json:"desc"`
	Rarity   string   `json:"rarity"`
	Tags     []string `json:"tags,omitempty"`
	Eligible *Cond    `json:"eligible,omitempty"` // $self is the player
}

// Genome is a player's expressed genes and pending mutation offer.
type Genome struct {
	Genes    []string `json:"genes,omitempty"`    // expressed, oldest first
	Offer    []string `json:"offer,omitempty"`    // pending offer, featured first
	Featured string   `json:"featured,omitempty"` // where the body leans (the advisor's pick or the default)
	Declined []string `json:"declined,omitempty"` // last declined offer, not repeated right away
}

// GeneView is a mutation as the player sees it.
type GeneView struct {
	ID     string   `json:"id"`
	Name   string   `json:"name"`
	Desc   string   `json:"desc"`
	Rarity string   `json:"rarity"`
	Tags   []string `json:"tags,omitempty"`
}

// EvolutionView is the observer's own genome, offer and pressure.
type EvolutionView struct {
	Genes     []GeneView `json:"genes"`
	Offer     []GeneView `json:"offer"`
	Featured  string     `json:"featured,omitempty"`
	Pressure  int64      `json:"pressure"`
	Threshold int64      `json:"threshold"`
	Slots     int        `json:"slots"`
}

func (w *World) offerSize() int {
	if w.U.Evolution.Offer > 0 {
		return w.U.Evolution.Offer
	}
	return 3
}

func (w *World) geneSlots() int {
	if w.U.Evolution.Slots > 0 {
		return w.U.Evolution.Slots
	}
	return 3
}

func (w *World) mutation(id string) (MutationDef, bool) {
	i := slices.IndexFunc(w.U.Mutations, func(m MutationDef) bool { return m.ID == id })
	if i < 0 {
		return MutationDef{}, false
	}
	return w.U.Mutations[i], true
}

func (w *World) compileEvolution(v *validator) error {
	ev := w.U.Evolution
	if ev == nil {
		if len(w.U.Mutations) > 0 {
			return invalid("mutations need an evolution block")
		}
		return nil
	}
	if ev.Pressure == "" || ev.Threshold < 1 || ev.Offer < 0 || ev.Offer > 6 || ev.Slots < 0 || ev.Slots > 10 || len(w.U.Mutations) == 0 {
		return invalid("evolution")
	}
	seen := map[string]bool{}
	for _, m := range w.U.Mutations {
		if !validID(m.ID) || seen[m.ID] || m.Name == "" || !slices.Contains(rarities, m.Rarity) {
			return invalid("mutation %q", m.ID)
		}
		seen[m.ID] = true
		if m.Eligible != nil {
			if e := v.cond(*m.Eligible, map[string]bool{"self": true}, "mutation "+m.ID); e != nil {
				return e
			}
		}
	}
	for _, reserved := range []string{actEvolve, actRefuseE} {
		if _, taken := w.actions[reserved]; taken {
			return invalid("action id %q is reserved by the engine", reserved)
		}
	}
	return nil
}

// fit is how well a mutation follows the path the player has been living.
func (w *World) fit(s *State, p ID, m MutationDef) int64 {
	score := int64(0)
	for _, t := range m.Tags {
		score += min(s.Styles[p][t], 10)
	}
	return score
}

// mutationCandidates are the mutations p does not express and that make sense
// now. A just-declined offer is left out unless that leaves too few.
func (w *World) mutationCandidates(s *State, p ID) []MutationDef {
	g := s.Genomes[p]
	all := []MutationDef{}
	for _, m := range w.U.Mutations {
		if slices.Contains(g.Genes, m.ID) {
			continue
		}
		if m.Eligible != nil && !w.Holds(s, *m.Eligible, Bind{"self": p}) {
			continue
		}
		all = append(all, m)
	}
	fresh := slices.DeleteFunc(slices.Clone(all), func(m MutationDef) bool { return slices.Contains(g.Declined, m.ID) })
	if len(fresh) >= w.offerSize() || len(fresh) == len(all) {
		return fresh
	}
	return all
}

// byFit orders candidates by fit, keeping universe order between equals.
func (w *World) byFit(s *State, p ID, cands []MutationDef) []MutationDef {
	out := slices.Clone(cands)
	slices.SortStableFunc(out, func(a, b MutationDef) int { return int(w.fit(s, p, b) - w.fit(s, p, a)) })
	return out
}

// mutationTick creates an evolution decision (or an offer directly, when
// there is nothing to choose) for each player whose pressure overflowed.
func (w *World) mutationTick(s *State, cause string) {
	ev := w.U.Evolution
	if ev == nil {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		e := s.Entities[p]
		if e.Kind != w.U.PlayerKind || e.Num[ev.Pressure] < ev.Threshold || len(s.Genomes[p].Offer) > 0 {
			continue
		}
		if slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == "evolution" && s.Decisions[k].Subject == string(p)
		}) {
			continue
		}
		cands := w.mutationCandidates(s, p)
		if len(cands) == 0 {
			continue
		}
		ranked := w.byFit(s, p, cands)
		if len(cands) <= w.offerSize() {
			w.offerMutations(s, p, ranked[0].ID, cause)
			continue
		}
		opts := make([]Option, 0, len(cands))
		for _, m := range cands {
			desc := m.Desc + " (" + m.Rarity + ")"
			if len(m.Tags) > 0 {
				desc += " [path: " + strings.Join(m.Tags, ", ") + "]"
			}
			desc += " [fit " + strconv.FormatInt(w.fit(s, p, m), 10) + "]"
			opts = append(opts, Option{ID: m.ID, Title: m.Name, Desc: desc})
		}
		id := "evolution:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
		ctx := w.profile(s, p)
		ctx = append(ctx, w.genomeText(s, p))
		ctx = append(ctx, w.storySoFar(s)...)
		ctx = append(ctx, w.recentPublic(s, 4)...)
		s.Decisions[id] = Decision{ID: id, Kind: "evolution", Subject: string(p), Options: opts,
			Default: ranked[0].ID, Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
	}
}

func (w *World) genomeText(s *State, p ID) string {
	g := s.Genomes[p]
	if len(g.Genes) == 0 {
		return "expressed genes: none yet (a newborn stem cell)"
	}
	parts := []string{}
	for _, id := range g.Genes {
		m, _ := w.mutation(id)
		parts = append(parts, m.Name+" ["+strings.Join(m.Tags, ", ")+"]")
	}
	return "expressed genes (oldest first): " + strings.Join(parts, "; ")
}

// decideMutation applies the advisor's pick after revalidating it.
func (w *World) decideMutation(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	ev := w.U.Evolution
	if ev == nil || s.Entities[p].Num[ev.Pressure] < ev.Threshold || len(s.Genomes[p].Offer) > 0 {
		return reject("evolution no longer pending")
	}
	if !slices.ContainsFunc(w.mutationCandidates(s, p), func(m MutationDef) bool { return m.ID == choice }) {
		return reject("choice no longer valid")
	}
	delete(s.Decisions, d.ID)
	w.offerMutations(s, p, choice, cause)
	return nil
}

// offerMutations shows p the featured mutation plus the best-fitting others.
func (w *World) offerMutations(s *State, p ID, featured, cause string) {
	offer := []string{featured}
	for _, m := range w.byFit(s, p, w.mutationCandidates(s, p)) {
		if len(offer) >= w.offerSize() {
			break
		}
		if m.ID != featured {
			offer = append(offer, m.ID)
		}
	}
	g := s.Genomes[p]
	g.Offer, g.Featured = offer, featured
	s.Genomes[p] = g
	e := s.Entities[p]
	if e.Num == nil {
		e.Num = map[string]int64{}
	}
	e.Num[w.U.Evolution.Pressure] = max(0, e.Num[w.U.Evolution.Pressure]-w.U.Evolution.Threshold)
	s.Entities[p] = e
	m, _ := w.mutation(featured)
	w.emit(s, Event{Kind: "evolution-offered", Holder: p, Text: m.Name, Cause: cause,
		Data: map[string]string{"featured": featured, "offer": strings.Join(offer, ",")}})
}

// chooseMutation is the player's choice: express one gene of the pending offer.
func (w *World) chooseMutation(s *State, origin string, p ID, args map[string]ID, cause string) error {
	g := s.Genomes[p]
	gene := string(args["gene"])
	if origin != "player" || w.U.Evolution == nil || s.Entities[p].Kind != w.U.PlayerKind || !slices.Contains(g.Offer, gene) {
		return reject("evolution")
	}
	m, _ := w.mutation(gene)
	g.Genes = append(slices.Clone(g.Genes), gene)
	replaced := ""
	if len(g.Genes) > w.geneSlots() {
		replaced, g.Genes = g.Genes[0], g.Genes[1:]
	}
	g.Offer, g.Featured, g.Declined = nil, "", nil
	s.Genomes[p] = g
	w.learn(s, p, m.Tags, 1)
	w.count(s, p, actEvolve)
	data := map[string]string{"gene": gene, "rarity": m.Rarity}
	if replaced != "" {
		data["replaced"] = replaced
	}
	w.emit(s, Event{Kind: "mutated", Actor: p, Holder: p, Text: m.Name, Cause: cause, Data: data})
	w.discover(s, p, cause)
	return nil
}

func (w *World) refuseMutation(s *State, origin string, p ID, cause string) error {
	g := s.Genomes[p]
	if origin != "player" || len(g.Offer) == 0 {
		return reject("evolution")
	}
	g.Declined, g.Offer, g.Featured = g.Offer, nil, ""
	s.Genomes[p] = g
	w.count(s, p, actRefuseE)
	w.emit(s, Event{Kind: "evolution-declined", Holder: p, Cause: cause})
	return nil
}

func (w *World) geneViews(ids []string) []GeneView {
	out := []GeneView{}
	for _, id := range ids {
		if m, ok := w.mutation(id); ok {
			out = append(out, GeneView{ID: m.ID, Name: m.Name, Desc: m.Desc, Rarity: m.Rarity, Tags: m.Tags})
		}
	}
	return out
}

func (w *World) evolutionView(s *State, p ID) *EvolutionView {
	if w.U.Evolution == nil || s.Entities[p].Kind != w.U.PlayerKind {
		return nil
	}
	g := s.Genomes[p]
	return &EvolutionView{Genes: w.geneViews(g.Genes), Offer: w.geneViews(g.Offer), Featured: g.Featured,
		Pressure: s.Entities[p].Num[w.U.Evolution.Pressure], Threshold: w.U.Evolution.Threshold, Slots: w.geneSlots()}
}
