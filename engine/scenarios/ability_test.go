package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// becomeClass takes p through both tiers of differentiation into the given class
// (macrofago, neutrofilo or dendritica are myeloid; the others lymphoid).
func (h *harness) becomeClass(p core.ID, progenitor, class string) {
	h.t.Helper()
	h.fight(p, 7)
	h.waitLineageOffer(p)
	h.mustAct("player", p, "diferenciar", map[string]core.ID{"lineage": core.ID(progenitor)})
	h.fight(p, 14)
	h.waitLineageOffer(p)
	h.mustAct("player", p, "diferenciar", map[string]core.ID{"lineage": core.ID(class)})
}

func (h *harness) skillIDs(p core.ID) []string {
	v, _ := h.w.View(&h.s, p, 1)
	out := []string{}
	for _, k := range v.Skills {
		out = append(out, k.ID)
	}
	return out
}

// Every class is born with one ability, and only its own.
func TestEachClassIsBornWithItsStarterAbility(t *testing.T) {
	cases := map[string][3]string{
		"macrofago":    {"mieloide", "engolir", "rede-de-dna"},
		"neutrofilo":   {"mieloide", "rede-de-dna", "engolir"},
		"linfocito-b":  {"linfoide", "anticorpo-y", "perforina"},
		"t-citotoxico": {"linfoide", "perforina", "anticorpo-y"},
		"mastocito":    {"mieloide", "granulos-latentes", "adesao"},
		"eosinofilo":   {"mieloide", "adesao", "granulos-latentes"},
		"celula-nk":    {"linfoide", "passo-sem-identidade", "anergia"},
		"t-regulador":  {"linfoide", "anergia", "passo-sem-identidade"},
	}
	for class, c := range cases {
		h := load(t, "hospedeiro")
		h.join("p1")
		if got := h.skillIDs("p1"); len(got) != 0 {
			t.Fatalf("a newborn ball knows no ability, got %v", got)
		}
		h.becomeClass("p1", c[0], class)
		got := h.skillIDs("p1")
		if !slices.Contains(got, c[1]) {
			t.Fatalf("%s should be born with %s, got %v", class, c[1], got)
		}
		if slices.Contains(got, c[2]) {
			t.Fatalf("%s must not know %s", class, c[2])
		}
	}
}

// A class quest grants the second ability as its reward.
func TestClassQuestGrantsAnAbility(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.move("p1", "sangue")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.tick(8)
	h.becomeClass("p1", "mieloide", "macrofago")
	q := h.steer("p1", "prova-macrofago")
	if q.Giver != "neva" {
		t.Fatalf("Neva sets the macrophage's trial, got %q", q.Giver)
	}
	h.accept("p1", q)
	h.repeat("adapter", "p1", "absorver-nutriente", 40)
	h.tick(2)
	if got, _ := h.quest("p1", "prova-macrofago"); got.State != "done" {
		t.Fatalf("eating enough completes the trial, state %q", got.State)
	}
	if !slices.Contains(h.skillIDs("p1"), "onda-de-pseudopodes") {
		t.Fatalf("the quest reward teaches an ability, got %v", h.skillIDs("p1"))
	}
}

// Deeds discover an ability by themselves, but only for the class it belongs to.
func TestDeedsDiscoverAnAbilityOfTheClass(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.becomeClass("p1", "mieloide", "macrofago")
	h.repeat("adapter", "p1", "estilo-chicote", 30)
	h.tick(1)
	if !slices.Contains(h.skillIDs("p1"), "contragolpe") {
		t.Fatalf("lashing 30 times teaches the counter, got %v", h.skillIDs("p1"))
	}
	g := load(t, "hospedeiro")
	g.join("p2")
	g.becomeClass("p2", "linfoide", "linfocito-b")
	g.repeat("adapter", "p2", "estilo-chicote", 30)
	g.tick(1)
	if slices.Contains(g.skillIDs("p2"), "contragolpe") {
		t.Fatal("a B cell must not discover a macrophage's ability")
	}
}

// The body awakens an ability by itself: the advisor decides which one, and it is revalidated.
func TestTheAdvisorAwakensAnAbilityOfTheClass(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.becomeClass("p1", "mieloide", "neutrofilo")
	h.repeat("adapter", "p1", "estilo-impulso", 14)
	d := core.Decision{}
	for i := 0; i < 90 && d.ID == ""; i++ {
		for _, x := range h.s.Decisions {
			if x.Kind == "ability" && x.Subject == "p1" {
				d = x
			}
		}
		if d.ID == "" {
			h.tick(1)
		}
	}
	if d.ID == "" {
		t.Fatal("expected an ability decision once the class has played enough")
	}
	if len(d.Options) != 3 {
		t.Fatalf("the quest, discovery and awakening abilities all compete, got %+v", d.Options)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "engolir", Provider: "test"}); err == nil {
		t.Fatal("an ability outside the options (another class's) is refused")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "surto-oxidativo", Provider: "test"})
	if !slices.Contains(h.skillIDs("p1"), "surto-oxidativo") {
		t.Fatalf("the advisor's pick awakens, got %v", h.skillIDs("p1"))
	}
}

// The four newer classes each have a proof quest that closes on its own deed and grants its second ability.
func TestTheNewClassesHaveTheirProofQuests(t *testing.T) {
	cases := []struct {
		progenitor, class, action, grant string
		n                                int
	}{
		{"mieloide", "mastocito", "absorver-nutriente", "histamina-instavel", 30},
		{"mieloide", "eosinofilo", "derrotar-virus", "cristal-de-charcot", 120},
		{"linfoide", "celula-nk", "esquivar", "predar", 10},
		{"linfoide", "t-regulador", "absorver-nutriente", "sinapse-imunologica", 25},
	}
	for _, c := range cases {
		h := load(t, "hospedeiro")
		h.join("p1")
		h.mustAct("adapter", "p1", "absorver-nutriente", nil)
		h.move("p1", "sangue")
		h.mustAct("adapter", "p1", "absorver-nutriente", nil)
		h.tick(8)
		h.becomeClass("p1", c.progenitor, c.class)
		q := h.steer("p1", "prova-"+c.class)
		h.accept("p1", q)
		for i := 0; i < c.n+2; i++ {
			h.mustAct("adapter", "p1", c.action, nil)
		}
		h.tick(2)
		if got, _ := h.quest("p1", "prova-"+c.class); got.State != "done" {
			t.Fatalf("%s: the proof quest should close, state %q", c.class, got.State)
		}
		if !slices.Contains(h.skillIDs("p1"), c.grant) {
			t.Fatalf("%s: the proof should grant %s, got %v", c.class, c.grant, h.skillIDs("p1"))
		}
	}
}
