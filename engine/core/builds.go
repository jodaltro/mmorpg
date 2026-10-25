package core

import (
	"slices"
	"strconv"
)

// Builds: the genes a body has met are not lost when the slots are full. A gene that leaves the slots is silenced and kept in the
// library, and the player may express it again, swapping it with an expressed one, or silence one to free a slot. A build is a
// saved set of genes (a few numbered slots) that can be applied in one gesture. Every change of expression is the player's
// intent, validated here: only a player, only genes the body has, never during a dungeon run, and not again before the body has
// rested (the universe says for how many ticks), so a build is chosen between fights and not inside them.

const (
	actExpress    = "expressar"     // args: gene, swap (optional: the expressed gene that gives its slot)
	actSilence    = "silenciar"     // args: gene
	actSaveBuild  = "salvar-build"  // args: slot
	actApplyBuild = "aplicar-build" // args: slot
)

// BuildView is a saved build as the player sees it.
type BuildView struct {
	Slot  string     `json:"slot"`
	Genes []GeneView `json:"genes"`
}

// buildSlots is how many builds a player may save (0 = the feature is off).
func (w *World) buildSlots() int {
	if w.U.Evolution == nil {
		return 0
	}
	return w.U.Evolution.Builds
}

func (w *World) compileBuilds() error {
	ev := w.U.Evolution
	if ev == nil {
		return nil
	}
	if ev.Builds < 0 || ev.Builds > 9 || ev.Rest < 0 {
		return invalid("evolution builds")
	}
	for _, reserved := range []string{actExpress, actSilence, actSaveBuild, actApplyBuild} {
		if _, taken := w.actions[reserved]; taken {
			return invalid("action id %q is reserved by the engine", reserved)
		}
	}
	return nil
}

// reconfigurable says whether p may change the expression now (the reason when not).
func (w *World) reconfigurable(s *State, origin string, p ID) error {
	if origin != "player" || w.U.Evolution == nil || s.Entities[p].Kind != w.U.PlayerKind {
		return reject("build")
	}
	if run, has := s.Delves[p]; has && (run.State == "preparing" || run.State == "ready" || run.State == "active") {
		return reject("build: not inside a dungeon run")
	}
	if s.Tick < s.Genomes[p].RestUntil {
		return reject("build: the body is still settling")
	}
	return nil
}

// settle starts the rest after a change of expression.
func (w *World) settle(s *State, p ID) {
	g := s.Genomes[p]
	g.RestUntil = s.Tick + w.U.Evolution.Rest
	s.Genomes[p] = g
}

// silenceGene moves an expressed gene to the library.
func silenceGene(g *Genome, gene string) {
	g.Genes = slices.DeleteFunc(slices.Clone(g.Genes), func(id string) bool { return id == gene })
	if !slices.Contains(g.Library, gene) {
		g.Library = append(slices.Clone(g.Library), gene)
	}
}

// expressGene expresses a gene the body has: it leaves the library and, with every slot taken, the oldest expressed gene is
// silenced. It returns the silenced gene (or "").
func (w *World) expressGene(g *Genome, gene string) string {
	g.Library = slices.DeleteFunc(slices.Clone(g.Library), func(id string) bool { return id == gene })
	if slices.Contains(g.Genes, gene) {
		return ""
	}
	g.Genes = append(slices.Clone(g.Genes), gene)
	if len(g.Genes) <= w.geneSlots() {
		return ""
	}
	oldest := g.Genes[0]
	silenceGene(g, oldest)
	return oldest
}

func (w *World) expressChoice(s *State, origin string, p ID, args map[string]ID, cause string) error {
	if err := w.reconfigurable(s, origin, p); err != nil {
		return err
	}
	g := s.Genomes[p]
	gene, swap := string(args["gene"]), string(args["swap"])
	if !slices.Contains(g.Library, gene) {
		return reject("build: that gene is not in the library")
	}
	data := map[string]string{"gene": gene}
	if len(g.Genes) >= w.geneSlots() {
		if !slices.Contains(g.Genes, swap) {
			return reject("build: every slot is taken: say which expressed gene gives its place")
		}
		silenceGene(&g, swap)
		data["silenced"] = swap
	}
	w.expressGene(&g, gene)
	s.Genomes[p] = g
	w.settle(s, p)
	m, _ := w.mutation(gene)
	w.emit(s, Event{Kind: "reconfigured", Actor: p, Holder: p, Text: m.Name + " passa a se expressar", Cause: cause, Data: data})
	return nil
}

func (w *World) silenceChoice(s *State, origin string, p ID, args map[string]ID, cause string) error {
	if err := w.reconfigurable(s, origin, p); err != nil {
		return err
	}
	g := s.Genomes[p]
	gene := string(args["gene"])
	if !slices.Contains(g.Genes, gene) {
		return reject("build: that gene is not expressed")
	}
	silenceGene(&g, gene)
	s.Genomes[p] = g
	w.settle(s, p)
	m, _ := w.mutation(gene)
	w.emit(s, Event{Kind: "reconfigured", Actor: p, Holder: p, Text: m.Name + " foi silenciado", Cause: cause, Data: map[string]string{"silenced": gene}})
	return nil
}

func (w *World) buildSlot(args map[string]ID) (string, error) {
	n, err := strconv.Atoi(string(args["slot"]))
	if err != nil || n < 1 || n > w.buildSlots() {
		return "", reject("build: no such slot")
	}
	return strconv.Itoa(n), nil
}

// saveBuild remembers the genes expressed now in a numbered slot. Saving is free of rest: it changes nothing in the body.
func (w *World) saveBuild(s *State, origin string, p ID, args map[string]ID, cause string) error {
	if origin != "player" || w.buildSlots() == 0 || s.Entities[p].Kind != w.U.PlayerKind {
		return reject("build")
	}
	slot, err := w.buildSlot(args)
	if err != nil {
		return err
	}
	g := s.Genomes[p]
	if len(g.Genes) == 0 {
		return reject("build: nothing is expressed")
	}
	next := make(map[string][]string, len(g.Builds)+1)
	for k, v := range g.Builds {
		next[k] = v
	}
	next[slot] = slices.Clone(g.Genes)
	g.Builds = next
	s.Genomes[p] = g
	w.emit(s, Event{Kind: "build-saved", Actor: p, Holder: p, Text: "Build " + slot + " guardada", Cause: cause, Data: map[string]string{"slot": slot}})
	return nil
}

// applyBuild expresses the genes of a saved build (those the body still has), silencing the rest.
func (w *World) applyBuild(s *State, origin string, p ID, args map[string]ID, cause string) error {
	if err := w.reconfigurable(s, origin, p); err != nil {
		return err
	}
	if w.buildSlots() == 0 {
		return reject("build")
	}
	slot, err := w.buildSlot(args)
	if err != nil {
		return err
	}
	g := s.Genomes[p]
	saved, has := g.Builds[slot]
	if !has {
		return reject("build: that slot is empty")
	}
	target := []string{}
	for _, gene := range saved {
		if (slices.Contains(g.Genes, gene) || slices.Contains(g.Library, gene)) && len(target) < w.geneSlots() {
			target = append(target, gene)
		}
	}
	if len(target) == 0 || slices.Equal(slices.Sorted(slices.Values(target)), slices.Sorted(slices.Values(g.Genes))) {
		return reject("build: nothing would change")
	}
	for _, gene := range slices.Clone(g.Genes) {
		if !slices.Contains(target, gene) {
			silenceGene(&g, gene)
		}
	}
	g.Library = slices.DeleteFunc(slices.Clone(g.Library), func(id string) bool { return slices.Contains(target, id) })
	g.Genes = target
	s.Genomes[p] = g
	w.settle(s, p)
	w.emit(s, Event{Kind: "reconfigured", Actor: p, Holder: p, Text: "Build " + slot + " aplicada", Cause: cause, Data: map[string]string{"slot": slot}})
	return nil
}

func (w *World) buildViews(g Genome) []BuildView {
	out := []BuildView{}
	for i := 1; i <= w.buildSlots(); i++ {
		slot := strconv.Itoa(i)
		out = append(out, BuildView{Slot: slot, Genes: w.geneViews(g.Builds[slot])})
	}
	return out
}
