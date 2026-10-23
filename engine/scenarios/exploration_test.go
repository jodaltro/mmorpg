package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func hasGene(h *harness, p core.ID, gene string) bool {
	return slices.Contains(h.s.Genomes[p].Genes, gene)
}

func findNiche(h *harness, p core.ID, niche string) {
	h.t.Helper()
	h.mustAct("adapter", p, "achar-nicho", map[string]core.ID{"niche": core.ID(niche)})
}

// E2: a gene is a key. The lung is closed to a cell that cannot squeeze into its capillaries; a niche in the
// venule gives the gene that opens it, and the log replays the whole trip to the same state.
func TestHospedeiroNicheGeneOpensTheLung(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.move("p1", "sangue")
	h.move("p1", "coracao")
	if _, err := h.try(core.Command{Kind: "move", Origin: "adapter", Actor: "p1", Region: "pulmao"}); !isRejected(err) {
		t.Fatalf("the lung should be closed without the key, got %v", err)
	}
	h.move("p1", "sangue")
	findNiche(h, "p1", "bolsa-da-venula")
	if !hasGene(h, "p1", "citoesqueleto-elastico") {
		t.Fatal("the niche should hand over its gene")
	}
	if got := h.events("nicho"); len(got) != 1 {
		t.Fatalf("one niche event, got %d", len(got))
	}
	findNiche(h, "p1", "bolsa-da-venula") // finding it again changes nothing
	if n := slices.Index(h.s.Genomes["p1"].Genes, "citoesqueleto-elastico"); n != len(h.s.Genomes["p1"].Genes)-1 || len(h.events("nicho")) != 1 {
		t.Fatal("a niche pays once")
	}
	h.move("p1", "coracao")
	h.move("p1", "pulmao")
	if h.s.Entities["p1"].Region != "pulmao" {
		t.Fatal("with the key the lung opens")
	}
	v, _ := h.w.View(&h.s, "p1", 50)
	for _, p := range v.Explore.Passages {
		if p.ID == "arteria_pulmonar" && !p.Open {
			t.Fatal("the view should show the passage open")
		}
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying the exploration log gives another world")
	}
}

// Unique niches belong to the first finder; the second player finds it already taken. Only the adapter confirms a find, and only
// where the cell really is.
func TestHospedeiroUniqueNicheBelongsToTheFirstFinder(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1", "p2")
	for _, p := range []core.ID{"p1", "p2"} {
		h.move(p, "sangue")
		h.move(p, "coracao")
	}
	if _, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "achar-nicho", Args: map[string]core.ID{"niche": "recesso-do-atrio"}}); !isRejected(err) {
		t.Fatalf("a player cannot declare a find, got %v", err)
	}
	if _, err := h.try(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: "achar-nicho", Args: map[string]core.ID{"niche": "bolsa-da-venula"}}); !isRejected(err) {
		t.Fatalf("a niche cannot be found from another region, got %v", err)
	}
	findNiche(h, "p1", "recesso-do-atrio")
	findNiche(h, "p2", "recesso-do-atrio")
	if !hasGene(h, "p1", "receptor-de-mapa") || hasGene(h, "p2", "receptor-de-mapa") {
		t.Fatal("only the first finder gets the gene")
	}
	if len(h.events("nicho-vazio")) != 1 || len(h.events("nicho-reivindicado")) != 1 {
		t.Fatal("the second finder is told it was taken and the world hears of the first")
	}
	v2, _ := h.w.View(&h.s, "p2", 50)
	taken := false
	for _, n := range v2.Explore.Niches {
		if n.ID == "recesso-do-atrio" && n.Claimed == false && n.Found {
			taken = true
		}
	}
	if !taken {
		t.Fatal("the second player has found it (and was told it was empty)")
	}
}

// What a cell has visited is remembered by the world and shown as facts; niche hints appear in the places it knows and the ones next door.
func TestHospedeiroDiscoveryAndHints(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	hint := func(id string) string {
		v, _ := h.w.View(&h.s, "p1", 50)
		for _, n := range v.Explore.Niches {
			if n.ID == id {
				return n.Hint
			}
		}
		return "?"
	}
	if hint("nicho-estroma") == "" {
		t.Fatal("the marrow is known from the start: its niche whispers")
	}
	if hint("recesso-do-atrio") != "" {
		t.Fatal("nothing is said of a region the cell has not visited")
	}
	h.move("p1", "sangue")
	h.move("p1", "coracao")
	if hint("recesso-do-atrio") == "" || !h.fact("p1", "visitou", "p1", "coracao") {
		t.Fatal("visiting the heart reveals it and its niche")
	}
}
