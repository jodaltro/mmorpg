package scenarios

import (
	"slices"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) waitLineageOffer(p core.ID) core.LineageView {
	h.t.Helper()
	for i := 0; i < 12; i++ {
		if v, _ := h.w.View(&h.s, p, 1); v.Lineage != nil && len(v.Lineage.Offer) > 0 {
			return *v.Lineage
		}
		h.tick(1)
	}
	h.t.Fatalf("%s never got a lineage offer", p)
	return core.LineageView{}
}

func (h *harness) lineageView(p core.ID) core.LineageView {
	v, _ := h.w.View(&h.s, p, 1)
	return *v.Lineage
}

// Everyone is born undifferentiated, and growing into a lineage needs maturity.
func TestBornUndifferentiatedAndMaturityOpensTheFirstTier(t *testing.T) {
	h := load(t, legacyGrowth)
	h.join("p1")
	if v := h.lineageView("p1"); v.Current != "" || v.Tier != 0 || v.Next != 14*pace {
		t.Fatalf("a newborn is undifferentiated with the first tier at 14 maturity: %+v", v)
	}
	h.fight("p1", 6) // 12 maturity
	h.tick(6)
	if v := h.lineageView("p1"); len(v.Offer) > 0 {
		t.Fatalf("no offer before the maturity is reached: %+v", v)
	}
	h.fight("p1", 1)
	offer := h.waitLineageOffer("p1")
	ids := []string{}
	for _, o := range offer.Offer {
		ids = append(ids, o.ID)
	}
	if offer.Featured != "mieloide" || !slices.Equal(ids, []string{"mieloide", "linfoide"}) {
		t.Fatalf("a fighter leans myeloid, featured first: %v featured %s", ids, offer.Featured)
	}
}

func TestAdvisorPicksTheLineageAndPlayerBecomesIt(t *testing.T) {
	h := load(t, legacyGrowth)
	h.join("p1")
	h.fight("p1", 7)
	h.tick(1)
	d := core.Decision{}
	for _, x := range h.s.Decisions {
		if x.Kind == "lineage" {
			d = x
		}
	}
	if d.ID == "" || len(d.Options) != 2 {
		t.Fatalf("expected a lineage decision with both progenitors, got %+v", d)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "macrofago", Provider: "test"}); err == nil {
		t.Fatal("a lineage that is not in the options is refused")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "linfoide", Provider: "test"})
	v := h.lineageView("p1")
	if v.Featured != "linfoide" || v.Offer[0].ID != "linfoide" {
		t.Fatalf("the advisor's pick leads the offer: %+v", v)
	}
	if h.act("player", "p1", "diferenciar", map[string]core.ID{"lineage": "macrofago"}) == nil {
		t.Fatal("only a lineage of the pending offer can be chosen")
	}
	h.mustAct("player", "p1", "diferenciar", map[string]core.ID{"lineage": "linfoide"})
	v = h.lineageView("p1")
	if v.Current != "linfoide" || v.Tier != 1 || len(v.Offer) != 0 || v.Next != 40*pace {
		t.Fatalf("now a lymphoid cell heading for tier 2 at 40: %+v", v)
	}
	if h.s.Styles["p1"]["knowledge"] < 2 {
		t.Fatal("differentiating deepens the path it belongs to")
	}
}

// The second tier offers only the classes that descend from the chosen progenitor.
func TestSecondTierOffersTheClassesOfTheProgenitor(t *testing.T) {
	h := load(t, legacyGrowth)
	h.join("p1")
	h.fight("p1", 7)
	first := h.waitLineageOffer("p1")
	h.mustAct("player", "p1", "diferenciar", map[string]core.ID{"lineage": core.ID(first.Featured)})
	h.fight("p1", 14) // up to 40 maturity
	second := h.waitLineageOffer("p1")
	got := []string{}
	for _, o := range second.Offer {
		got = append(got, o.ID)
	}
	slices.Sort(got)
	if want := []string{"dendritica", "eosinofilo", "macrofago", "mastocito", "neutrofilo"}; !slices.Equal(got, want) {
		t.Fatalf("a myeloid cell becomes a macrophage, neutrophil, dendritic cell, mast cell or eosinophil, got %v", got)
	}
	h.mustAct("player", "p1", "diferenciar", map[string]core.ID{"lineage": "macrofago"})
	if v := h.lineageView("p1"); v.Current != "macrofago" || v.Tier != 2 || v.Next != 0 {
		t.Fatalf("a macrophage is final: %+v", v)
	}
	e := h.s.Entities["p1"]
	if e.Tag["lineage"] != "macrofago" {
		t.Fatalf("the lineage is a tag the client and conditions can read, got %v", e.Tag)
	}
}

// Class mutations (the ones that change the form drastically) only appear for that class.
func TestClassMutationsAppearOnlyForTheirClass(t *testing.T) {
	h := load(t, legacyGrowth)
	h.join("p1", "p2")
	for _, p := range []core.ID{"p1", "p2"} {
		h.fight(p, 7)
		first := h.waitLineageOffer(p)
		h.mustAct("player", p, "diferenciar", map[string]core.ID{"lineage": core.ID(first.Featured)})
		h.fight(p, 14)
		h.waitLineageOffer(p)
	}
	h.mustAct("player", "p1", "diferenciar", map[string]core.ID{"lineage": "macrofago"})
	h.mustAct("player", "p2", "diferenciar", map[string]core.ID{"lineage": "neutrofilo"})
	var ids = func(p core.ID) []string {
		out := []string{}
		for i := 0; i < 8; i++ {
			h.fight(p, 5)
			h.tick(3)
			if g := h.s.Genomes[p]; len(g.Offer) > 0 {
				out = append(out, g.Offer...)
				h.mustAct("player", p, "recusar-evolucao", nil)
			}
		}
		return out
	}
	a, b := ids("p1"), ids("p2")
	for _, id := range a {
		if id == "rede-de-dna" || id == "nucleo-multilobulado" {
			t.Fatalf("a macrophage must not be offered the neutrophil's %s", id)
		}
	}
	for _, id := range b {
		if id == "pseudopodes-gigantes" || id == "lisossomos-acidos" {
			t.Fatalf("a neutrophil must not be offered the macrophage's %s", id)
		}
	}
	if !slices.Contains(a, "pseudopodes-gigantes") && !slices.Contains(a, "lisossomos-acidos") {
		t.Fatalf("a macrophage should meet its own class mutations, got %v", a)
	}
}

// A wide pool: generic mutations for everyone, and six of each class's own, each one reshaping one of that
// class's abilities (the card says which).
func TestEveryClassHasSixOwnMutationsThatNameTheirAbility(t *testing.T) {
	h := load(t, legacyGrowth)
	own := map[string]int{}
	generic := 0
	skillNames := map[string][]string{}
	for _, k := range h.w.U.Skills {
		if k.Class != "" {
			skillNames[k.Class] = append(skillNames[k.Class], k.Name)
		}
	}
	for _, m := range h.w.U.Mutations {
		if m.Eligible == nil || m.Eligible.Tag == nil || m.Eligible.Tag.K != "lineage" {
			generic++
			continue
		}
		class := m.Eligible.Tag.V
		own[class]++
		named := false
		for _, n := range skillNames[class] {
			if strings.Contains(m.Desc, n+":") {
				named = true
			}
		}
		if !named {
			t.Errorf("%s (%s) should say which %s ability it reshapes: %q", m.ID, class, class, m.Desc)
		}
	}
	if generic < 12 {
		t.Fatalf("want at least 12 generic mutations, got %d", generic)
	}
	for _, class := range []string{"macrofago", "neutrofilo", "dendritica", "linfocito-b", "t-citotoxico", "t-auxiliar", "mastocito", "eosinofilo", "celula-nk", "t-regulador"} {
		if own[class] != 6 {
			t.Fatalf("%s should have 6 own mutations, got %d", class, own[class])
		}
	}
}
