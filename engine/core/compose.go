package core

import (
	"slices"
	"strconv"
	"strings"
)

// Composing the offer: the mutation offer a player sees is authored by the advisor, not only its first slot. When the player's
// pressure overflows, the advisor picks the featured mutation (kind "evolution"); the remaining slots are then asked one after
// the other (kind "evolution-slot"), each knowing what the earlier slots became, so each can have its own reason: a deepening of
// the path, a surprise, a hedge. A stale answer is rejected, a slot nobody answers is filled by fit at its deadline, and the
// offer reaches the player only when it is whole.

const kindSlot = "evolution-slot"

// startOffer begins the offer around the featured mutation. With nothing to choose among, the offer is whole at once.
func (w *World) startOffer(s *State, p ID, featured, cause string) {
	if w.offerSize() <= 1 || len(w.slotCandidates(s, p, []string{featured})) == 0 {
		w.offerMutations(s, p, featured, cause)
		return
	}
	g := s.Genomes[p]
	g.Building = []string{featured}
	s.Genomes[p] = g
	w.askSlot(s, p)
}

// slotCandidates are the mutations still free for the next slot (everything valid that is not already in the offer).
func (w *World) slotCandidates(s *State, p ID, taken []string) []MutationDef {
	out := []MutationDef{}
	for _, m := range w.mutationCandidates(s, p) {
		if !slices.Contains(taken, m.ID) {
			out = append(out, m)
		}
	}
	return out
}

// askSlot asks for the next slot, one at a time, so the advisor sees what the earlier slots became and gives each its own reason.
func (w *World) askSlot(s *State, p ID) {
	g := s.Genomes[p]
	rest := w.slotCandidates(s, p, g.Building)
	if len(rest) == 0 {
		return
	}
	ranked := w.byFit(s, p, rest)
	opts := make([]Option, 0, len(rest))
	for _, m := range rest {
		desc := m.Desc + " (" + m.Rarity + ")"
		if len(m.Tags) > 0 {
			desc += " [path: " + strings.Join(m.Tags, ", ") + "]"
		}
		opts = append(opts, Option{ID: m.ID, Title: m.Name, Desc: desc})
	}
	already := make([]string, 0, len(g.Building))
	for _, id := range g.Building {
		m, _ := w.mutation(id)
		already = append(already, m.Name+" ["+strings.Join(m.Tags, ", ")+"]")
	}
	id := kindSlot + ":" + string(p) + ":" + strconv.Itoa(len(g.Building)+1) + ":" + strconv.FormatInt(int64(s.Tick), 10)
	ctx := w.profile(s, p)
	ctx = append(ctx, w.genomeText(s, p), "composing slot "+strconv.Itoa(len(g.Building)+1)+" of "+strconv.Itoa(w.offerSize())+" of the player's mutation offer; already in the offer: "+strings.Join(already, "; ")+". Give this slot its own reason: deepen the path, a surprise, or a hedge; do not repeat what is already offered")
	s.Decisions[id] = Decision{ID: id, Kind: kindSlot, Subject: string(p), Options: opts, Default: ranked[0].ID,
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
}

func (w *World) slotsPending(s *State, p ID) bool {
	return slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
		return s.Decisions[k].Kind == kindSlot && s.Decisions[k].Subject == string(p)
	})
}

// decideSlot keeps the advisor's mutation for one slot after revalidating it.
func (w *World) decideSlot(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	g := s.Genomes[p]
	if len(g.Building) == 0 || !slices.ContainsFunc(w.mutationCandidates(s, p), func(m MutationDef) bool { return m.ID == choice }) {
		return reject("choice no longer valid")
	}
	delete(s.Decisions, d.ID)
	if !slices.Contains(g.Building, choice) {
		g.Building = append(slices.Clone(g.Building), choice)
		s.Genomes[p] = g
	}
	if len(g.Building) < w.offerSize() {
		w.askSlot(s, p)
	}
	w.finishOffer(s, p, cause)
	return nil
}

// finishOffer shows the offer once no slot is waiting for an answer; whatever is missing is filled by fit.
func (w *World) finishOffer(s *State, p ID, cause string) {
	g := s.Genomes[p]
	if len(g.Building) == 0 || w.slotsPending(s, p) {
		return
	}
	chosen := g.Building
	g.Building = nil
	s.Genomes[p] = g
	w.offerFrom(s, p, chosen, cause)
}

// composeTick completes any offer whose slot decisions vanished without an answer.
func (w *World) composeTick(s *State, cause string) {
	for _, p := range sortedIDs(s.Entities) {
		if g := s.Genomes[p]; len(g.Building) > 0 && len(g.Building) < w.offerSize() && !w.slotsPending(s, p) {
			w.askSlot(s, p) // the previous slot lapsed: ask again (or, with nothing left, finish below)
		}
		w.finishOffer(s, p, cause)
	}
}
