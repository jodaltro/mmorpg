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

func codexUnlocked(h *harness, p core.ID, id string) bool {
	v, _ := h.w.View(&h.s, p, 50)
	for _, c := range v.Codex {
		if c.ID == id {
			return c.Unlocked
		}
	}
	return false
}

func nicheListed(h *harness, p core.ID, id string) bool {
	v, _ := h.w.View(&h.s, p, 50)
	for _, n := range v.Explore.Niches {
		if n.ID == id {
			return true
		}
	}
	return false
}

// The codex fills in as the cell sees and does things; locked entries say nothing.
func TestHospedeiroCodexUnlocksWithWhatTheCellDoes(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.tick(1)
	if !codexUnlocked(h, "p1", "cx-medula") || codexUnlocked(h, "p1", "cx-endocardio") || codexUnlocked(h, "p1", "cx-nutrientes") {
		t.Fatal("only the marrow is in the codex at the start")
	}
	v, _ := h.w.View(&h.s, "p1", 50)
	for _, c := range v.Codex {
		if !c.Unlocked && (c.Text != "" || c.Title != "???") {
			t.Fatalf("a locked entry leaks: %+v", c)
		}
	}
	h.move("p1", "sangue")
	h.move("p1", "coracao")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.tick(1)
	if !codexUnlocked(h, "p1", "cx-endocardio") || !codexUnlocked(h, "p1", "cx-nutrientes") {
		t.Fatal("going to the heart and eating unlock their entries")
	}
	if len(h.events("codice")) < 4 {
		t.Fatalf("each unlock is told once, got %d events", len(h.events("codice")))
	}
	n := len(h.events("codice"))
	h.tick(5)
	if len(h.events("codice")) != n {
		t.Fatal("an entry unlocks only once")
	}
}

// Secrets show only while the body is in their state: the marrow's chamber opens only in sleep, the hot alveolus only in fever.
func TestHospedeiroSecretNichesFollowTheStateOfTheBody(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	sleepNow := func() bool { return h.fact("", "sono", "medula", "") }
	for i := 0; i < 900 && !sleepNow(); i++ {
		h.tick(1)
	}
	if !sleepNow() {
		t.Fatal("the body should fall asleep at some point")
	}
	if !nicheListed(h, "p1", "sonho-da-medula") {
		t.Fatal("while the body sleeps the chamber exists")
	}
	findNiche(h, "p1", "sonho-da-medula")
	if !hasGene(h, "p1", "memoria-de-longa-vida") {
		t.Fatal("the sleeping chamber pays its gene")
	}
	if !codexUnlocked(h, "p1", "cx-segredo-sonho") {
		t.Fatal("and the codex records it")
	}
	h2 := load(t, "hospedeiro")
	h2.join("p2")
	if nicheListed(h2, "p2", "sonho-da-medula") {
		t.Fatal("awake, the chamber is not even listed")
	}
	if _, err := h2.try(core.Command{Kind: "act", Origin: "adapter", Actor: "p2", Action: "achar-nicho", Args: map[string]core.ID{"niche": "sonho-da-medula"}}); !isRejected(err) {
		t.Fatalf("a secret cannot be found out of its state, got %v", err)
	}
}

// Living somewhere long enough adapts the body to it, and the world remembers.
func TestHospedeiroLivingInAPlaceAdaptsTheCell(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.tick(25)
	if v, _ := h.w.View(&h.s, "p1", 50); len(v.Explore.Adapted) != 0 {
		t.Fatalf("too soon to adapt: %v", v.Explore.Adapted)
	}
	h.tick(10)
	v, _ := h.w.View(&h.s, "p1", 50)
	if len(v.Explore.Adapted) != 1 || v.Explore.Adapted[0] != "medula" || len(h.events("adaptou")) != 1 {
		t.Fatalf("the cell adapts to the marrow once: %v", v.Explore.Adapted)
	}
}

// The advisor points a player to the next place worth finding; the choice is revalidated and the default is the nearest.
func TestHospedeiroRotaPointsToAPlaceAndIsRevalidated(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.move("p1", "sangue") // the marrow's and the venule's niches are now both whispered
	var d core.Decision
	for i := 0; i < 30 && d.ID == ""; i++ {
		h.tick(1)
		for _, x := range h.s.Decisions {
			if x.Kind == "rota" {
				d = x
			}
		}
	}
	if d.ID == "" || len(d.Options) < 2 {
		t.Fatal("with several places worth finding the advisor is asked")
	}
	if d.Default != "bolsa-da-venula" {
		t.Fatalf("the default is the nearest place (where the cell is), got %s", d.Default)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "gruta-alveolar"}); !isRejected(err) {
		t.Fatalf("a place behind a closed passage cannot be chosen, got %v", err)
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "nicho-estroma", Provider: "test"})
	v, _ := h.w.View(&h.s, "p1", 50)
	if v.Explore.Route != "nicho-estroma" {
		t.Fatalf("the route is the advisor's pick, got %q", v.Explore.Route)
	}
	findNiche(h, "p1", "bolsa-da-venula") // the cell finds the other one on its own; the route stays where it was pointed
	if v, _ = h.w.View(&h.s, "p1", 50); v.Explore.Route != "nicho-estroma" {
		t.Fatal("finding another niche does not move the route")
	}
}

// Without anybody answering, the deadline decides: every player still ends up with a route, and replaying the log gives the same world.
func TestHospedeiroRotaDefaultsAtDeadlineAndReplays(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.move("p1", "sangue")
	h.tick(30)
	v, _ := h.w.View(&h.s, "p1", 50)
	if v.Explore.Route == "" {
		t.Fatal("the default should have set a route")
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replay digest differs")
	}
}

// E2 part 3: diapedesis is a key of its own. The aorta's wall is crossed by the macrophage and the neutrophil because of what they are,
// or by any cell with the elastic cytoskeleton; an undifferentiated cell without the gene stays out.
func TestHospedeiroDiapedesisOpensTheAorta(t *testing.T) {
	toHeart := func(h *harness, p core.ID) {
		h.move(p, "sangue")
		h.move(p, "coracao")
	}
	h := load(t, "hospedeiro")
	h.join("p0")
	toHeart(h, "p0")
	if _, err := h.try(core.Command{Kind: "move", Origin: "adapter", Actor: "p0", Region: "aorta"}); !isRejected(err) {
		t.Fatalf("a plain cell cannot cross the aorta's wall, got %v", err)
	}
	for class, progenitor := range map[string]string{"macrofago": "mieloide", "neutrofilo": "mieloide", "dendritica": "mieloide"} {
		h := load(t, "hospedeiro")
		h.join("p1")
		h.becomeClass("p1", progenitor, class)
		toHeart(h, "p1")
		_, err := h.try(core.Command{Kind: "move", Origin: "adapter", Actor: "p1", Region: "aorta"})
		if open := err == nil; open != (class != "dendritica") {
			t.Fatalf("%s: aorta open = %v, err %v", class, open, err)
		}
	}
	h.move("p0", "sangue")
	findNiche(h, "p0", "bolsa-da-venula")
	toHeart(h, "p0")
	h.move("p0", "aorta")
	if h.s.Entities["p0"].Region != "aorta" {
		t.Fatal("the elastic cytoskeleton also opens the aorta")
	}
}

// E2 part 3: the route turns into a quest. While the advisor points the player to a niche, the first mentor offers the trail; finding
// the niche completes it and pays pressure.
func TestHospedeiroRouteQuestCompletesWhenTheNicheIsFound(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil) // the first deed unlocks offers
	h.move("p1", "sangue")
	var d core.Decision
	for i := 0; i < 30 && d.ID == ""; i++ {
		h.tick(1)
		for _, x := range h.s.Decisions {
			if x.Kind == "rota" {
				d = x
			}
		}
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "bolsa-da-venula", Provider: "test"})
	q := h.steer("p1", "rastro-bolsa-da-venula")
	if q.Giver != "estroma" {
		t.Fatalf("Osteia offers the trail, got %q", q.Giver)
	}
	h.accept("p1", q)
	before := h.s.Entities["p1"].Num["pressao"]
	findNiche(h, "p1", "bolsa-da-venula")
	h.tick(2)
	if got, _ := h.quest("p1", "rastro-bolsa-da-venula"); got.State != "done" {
		t.Fatalf("finding the niche should complete the trail, state %q", got.State)
	}
	if h.s.Entities["p1"].Num["pressao"] <= before {
		t.Fatal("the trail should pay evolutionary pressure")
	}
}
