package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// grow gives p n genes, taking the featured one of each offer.
func (h *harness) grow(p core.ID, n int) {
	h.t.Helper()
	for i := 0; i < n; i++ {
		h.fight(p, 4)
		g := h.waitOffer(p)
		h.mustAct("player", p, "evoluir", map[string]core.ID{"gene": core.ID(g.Featured)})
	}
}

func (h *harness) evolution(p core.ID) *core.EvolutionView {
	v, _ := h.w.View(&h.s, p, 1)
	return v.Evolution
}

func (h *harness) rest(p core.ID) {
	h.t.Helper()
	h.tick(int(h.w.U.Evolution.Rest))
}

// A gene that leaves the slots is silenced, not lost: it waits in the library and is never offered again.
func TestSilencedGenesWaitInTheLibrary(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	slots := h.w.U.Evolution.Slots
	h.grow("p1", slots+1)
	g := h.s.Genomes["p1"]
	if len(g.Genes) != slots || len(g.Library) != 1 {
		t.Fatalf("%d slots: %d expressed, library %v", slots, len(g.Genes), g.Library)
	}
	if v := h.evolution("p1"); len(v.Library) != 1 || len(v.Builds) != h.w.U.Evolution.Builds {
		t.Fatalf("the view shows the library and the build slots: %+v", v)
	}
	h.fight("p1", 4)
	for _, id := range h.waitOffer("p1").Offer {
		if slices.Contains(g.Library, id) || slices.Contains(g.Genes, id) {
			t.Fatalf("a gene the body already has is offered again: %s", id)
		}
	}
}

// Swapping an expressed gene with a library one: validated, one at a time, and the body must rest between changes.
func TestExpressingAGeneSwapsAndTheBodyRests(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	slots := h.w.U.Evolution.Slots
	h.grow("p1", slots+1)
	g := h.s.Genomes["p1"]
	silenced, expressed := g.Library[0], g.Genes[0]
	express := func(gene, swap string) error {
		args := map[string]core.ID{"gene": core.ID(gene)}
		if swap != "" {
			args["swap"] = core.ID(swap)
		}
		return h.act("player", "p1", "expressar", args)
	}
	if err := express(silenced, ""); err == nil {
		t.Fatal("with every slot taken the gene that gives its place must be named")
	}
	if err := express(silenced, "nao-existe"); err == nil {
		t.Fatal("the gene that gives its place must be expressed")
	}
	if err := express(expressed, ""); err == nil {
		t.Fatal("only a gene of the library is expressed")
	}
	if err := h.act("adapter", "p1", "expressar", map[string]core.ID{"gene": core.ID(silenced), "swap": core.ID(expressed)}); err == nil {
		t.Fatal("only the player changes their own genes")
	}
	if err := express(silenced, expressed); err != nil {
		t.Fatalf("the swap: %v", err)
	}
	after := h.s.Genomes["p1"]
	if !slices.Contains(after.Genes, silenced) || slices.Contains(after.Genes, expressed) || !slices.Contains(after.Library, expressed) || slices.Contains(after.Library, silenced) {
		t.Fatalf("the swap moved the genes: %+v", after)
	}
	if err := express(expressed, after.Genes[0]); err == nil {
		t.Fatal("the body is still settling")
	}
	if v := h.evolution("p1"); v.RestLeft <= 0 {
		t.Fatalf("the view says how long to rest: %d", v.RestLeft)
	}
	h.rest("p1")
	if err := h.act("player", "p1", "silenciar", map[string]core.ID{"gene": core.ID(after.Genes[0])}); err != nil {
		t.Fatalf("silencing frees a slot after the rest: %v", err)
	}
	h.rest("p1")
	if err := express(expressed, ""); err != nil {
		t.Fatalf("a free slot needs no swap: %v", err)
	}
}

// Builds: a saved set of genes, applied in one gesture, and a replay of the log gives the same world.
func TestBuildsAreSavedAndApplied(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	slots := h.w.U.Evolution.Slots
	h.grow("p1", slots)
	first := slices.Clone(h.s.Genomes["p1"].Genes)
	if err := h.act("player", "p1", "salvar-build", map[string]core.ID{"slot": "9"}); err == nil {
		t.Fatal("no such slot")
	}
	h.mustAct("player", "p1", "salvar-build", map[string]core.ID{"slot": "1"})
	if err := h.act("player", "p1", "aplicar-build", map[string]core.ID{"slot": "1"}); err == nil {
		t.Fatal("applying what is already expressed changes nothing")
	}
	if err := h.act("player", "p1", "aplicar-build", map[string]core.ID{"slot": "2"}); err == nil {
		t.Fatal("an empty slot cannot be applied")
	}
	h.grow("p1", 2)
	if g := h.s.Genomes["p1"]; slices.Equal(g.Genes, first) || len(g.Library) != 2 {
		t.Fatalf("two more genes pushed two out: %+v", g)
	}
	h.rest("p1")
	h.mustAct("player", "p1", "aplicar-build", map[string]core.ID{"slot": "1"})
	g := h.s.Genomes["p1"]
	if !slices.Equal(slices.Sorted(slices.Values(g.Genes)), slices.Sorted(slices.Values(first))) {
		t.Fatalf("the saved build is expressed again: want %v, got %v", first, g.Genes)
	}
	if len(g.Library) != 2 {
		t.Fatalf("the genes that left are kept: %v", g.Library)
	}
	if err := h.act("player", "p1", "aplicar-build", map[string]core.ID{"slot": "1"}); err == nil {
		t.Fatal("the body must rest before it changes again")
	}
	if v := h.evolution("p1"); len(v.Builds[0].Genes) != slots || len(v.Builds[1].Genes) != 0 {
		t.Fatalf("the view shows the saved builds: %+v", v.Builds)
	}
	if len(h.events("reconfigured")) == 0 || len(h.events("build-saved")) == 0 {
		t.Fatal("the changes are told")
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("the replay of the log gives the same world")
	}
}
