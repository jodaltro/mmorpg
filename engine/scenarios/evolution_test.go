package scenarios

import (
	"slices"
	"sort"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) evolutionDecision(p core.ID) (core.Decision, bool) {
	for _, d := range h.s.Decisions {
		if d.Kind == "evolution" && d.Subject == string(p) {
			return d, true
		}
	}
	return core.Decision{}, false
}

// fight confirms n virions destroyed by p (3 pressure and a combat deed each).
func (h *harness) fight(p core.ID, n int) {
	h.t.Helper()
	for i := 0; i < n; i++ {
		h.mustAct("adapter", p, "derrotar-virus", nil)
	}
}

// waitOffer ticks until p holds a mutation offer (the default applies at the deadline).
func (h *harness) waitOffer(p core.ID) core.Genome {
	h.t.Helper()
	for i := 0; i < 20; i++ { // a composed offer takes a slot decision per open slot
		if g := h.s.Genomes[p]; len(g.Offer) > 0 {
			return g
		}
		h.tick(1)
	}
	h.t.Fatalf("%s never got a mutation offer: %+v", p, h.s.Genomes[p])
	return core.Genome{}
}

func hasTag(h *harness, gene, tag string) bool {
	for _, m := range h.w.U.Mutations {
		if m.ID == gene {
			return slices.Contains(m.Tags, tag)
		}
	}
	return false
}

func TestEvolutionWaitsForPressure(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 3) // 9 pressure, threshold 10
	h.tick(5)
	if _, ok := h.evolutionDecision("p1"); ok || len(h.s.Genomes["p1"].Offer) > 0 {
		t.Fatal("no evolution before the pressure overflows")
	}
}

// Without an advisor, the default follows the path the player has been living.
func TestEvolutionDefaultFollowsTheWayThePlayerLives(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	h.tick(1)
	d, ok := h.evolutionDecision("p1")
	if !ok || len(d.Options) <= 3 {
		t.Fatalf("expected an evolution decision with more candidates than fit an offer, got %+v", d)
	}
	g := h.waitOffer("p1")
	if len(g.Offer) != 3 || g.Featured != g.Offer[0] {
		t.Fatalf("offer of 3 with the featured first, got %+v", g)
	}
	for _, id := range g.Offer {
		if !hasTag(h, id, "combat") {
			t.Fatalf("a fighter is offered %s, outside the combat path: %v", id, g.Offer)
		}
	}
	if got := h.s.Entities["p1"].Num["pressao"]; got != 2 {
		t.Fatalf("the offer spends the threshold: pressure %d, want 2", got)
	}
}

// The advisor (Jev) picks where the body leans; its answer is revalidated.
func TestAdvisorPicksWhereTheBodyLeans(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	h.tick(1)
	d, _ := h.evolutionDecision("p1")
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "nao-existe", Provider: "test"}); err == nil {
		t.Fatal("a choice outside the options is refused")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "membrana-espessa", Provider: "test"})
	g := h.waitOffer("p1") // the other slots fall back to fit at the deadline
	if g.Featured != "membrana-espessa" || g.Offer[0] != "membrana-espessa" || len(g.Offer) != 3 {
		t.Fatalf("the advisor's pick leads the offer: %+v", g)
	}
}

func slotDecisions(h *harness, p core.ID) []core.Decision {
	out := []core.Decision{}
	for _, d := range h.s.Decisions {
		if d.Kind == "evolution-slot" && d.Subject == string(p) {
			out = append(out, d)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// The advisor composes the whole offer: after the featured mutation the other slots are asked one after the other (each knowing what
// the earlier ones became), every answer is validated, a duplicate collapses, and the player sees nothing until the offer is whole.
func TestAdvisorComposesTheWholeOffer(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	h.tick(1)
	d, _ := h.evolutionDecision("p1")
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "membrana-espessa", Provider: "test"})
	if len(h.s.Genomes["p1"].Offer) != 0 {
		t.Fatal("the offer is not shown while slots are being composed")
	}
	first := slotDecisions(h, "p1")
	if len(first) != 1 {
		t.Fatalf("the slots are asked one at a time, got %d", len(first))
	}
	if hasOption(first[0].Options, "membrana-espessa") {
		t.Fatal("a slot never offers the featured mutation again")
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: first[0].ID, Choice: "membrana-espessa", Provider: "test"}); !isRejected(err) {
		t.Fatalf("the featured mutation is not a valid slot answer, got %v", err)
	}
	pick := first[0].Options[len(first[0].Options)-1].ID // the last candidate: not what fit would pick
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: first[0].ID, Choice: pick, Provider: "test"})
	if len(h.s.Genomes["p1"].Offer) != 0 {
		t.Fatal("one slot is still waiting")
	}
	second := slotDecisions(h, "p1")
	if len(second) != 1 || hasOption(second[0].Options, pick) {
		t.Fatalf("the next slot is asked without what was just chosen, got %+v", second)
	}
	pick2 := second[0].Options[len(second[0].Options)-1].ID
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: second[0].ID, Choice: pick2, Provider: "test"})
	g := h.s.Genomes["p1"]
	if len(g.Offer) != 3 || g.Offer[0] != "membrana-espessa" || g.Offer[1] != pick || g.Offer[2] != pick2 {
		t.Fatalf("the composed offer keeps the advisor's picks in order: %+v", g)
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying a composed offer gives another world")
	}
}

// With nobody answering the slots, the deadline completes the offer by fit.
func TestComposedOfferCompletesByFitAtTheDeadline(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	h.tick(1)
	d, _ := h.evolutionDecision("p1")
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "membrana-espessa", Provider: "test"})
	g := h.waitOffer("p1")
	if len(g.Offer) != 3 || len(g.Building) != 0 || len(slotDecisions(h, "p1")) != 0 {
		t.Fatalf("the offer completes on its own: %+v", g)
	}
}

// Choosing expresses the gene and reinforces the path it belongs to.
func TestChoosingAGeneDeepensThePath(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	g := h.waitOffer("p1")
	before := h.s.Styles["p1"]["combat"]
	if h.act("player", "p1", "evoluir", map[string]core.ID{"gene": "mitocondria-avida"}) == nil && !slices.Contains(g.Offer, "mitocondria-avida") {
		t.Fatal("only a gene of the pending offer can be expressed")
	}
	h.mustAct("player", "p1", "evoluir", map[string]core.ID{"gene": core.ID(g.Featured)})
	after := h.s.Genomes["p1"]
	if !slices.Contains(after.Genes, g.Featured) || len(after.Offer) != 0 {
		t.Fatalf("gene expressed and offer closed: %+v", after)
	}
	if h.s.Styles["p1"]["combat"] != before+1 {
		t.Fatalf("choosing a combat gene deepens the combat path: %d -> %d", before, h.s.Styles["p1"]["combat"])
	}
	v, _ := h.w.View(&h.s, "p1", 10)
	if v.Evolution == nil || len(v.Evolution.Genes) != 1 || v.Evolution.Genes[0].ID != g.Featured {
		t.Fatalf("the view shows the genome: %+v", v.Evolution)
	}
}

func TestDeclinedMutationsAreNotOfferedRightAway(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.fight("p1", 4)
	first := h.waitOffer("p1").Offer
	h.mustAct("player", "p1", "recusar-evolucao", nil)
	h.fight("p1", 3)
	second := h.waitOffer("p1").Offer
	for _, id := range second {
		if slices.Contains(first, id) {
			t.Fatalf("declined %v came back right away in %v", first, second)
		}
	}
}

func TestSlotsReabsorbTheOldestGene(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	chosen := []string{}
	slots := h.w.U.Evolution.Slots
	for i := 0; i < slots+1; i++ {
		h.fight("p1", 4)
		g := h.waitOffer("p1")
		h.mustAct("player", "p1", "evoluir", map[string]core.ID{"gene": core.ID(g.Featured)})
		chosen = append(chosen, g.Featured)
	}
	genes := h.s.Genomes["p1"].Genes
	if len(genes) != slots || slices.Contains(genes, chosen[0]) || !slices.Equal(genes, chosen[1:]) {
		t.Fatalf("%d slots, oldest reabsorbed: chosen %v, expressed %v", slots, chosen, genes)
	}
}
