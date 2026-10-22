package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) marks(p core.ID) []core.MarkView {
	h.t.Helper()
	v, ok := h.w.View(&h.s, p, 5)
	if !ok {
		h.t.Fatalf("no view for %s", p)
	}
	return v.Marks
}

func (h *harness) mark(p core.ID, glyph, spot string) error {
	return h.act("player", p, "marcar", map[string]core.ID{"glyph": core.ID(glyph), "spot": core.ID(spot)})
}

// A mark is left for everyone who comes to that place: the same symbol, the
// same author, and agreeing with it keeps it alive.
func TestTravellerMarksAreSharedAndConfirmed(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2", "p3")
	h.move("p3", "estrada")
	if err := h.mark("p1", "perigo", "banco-estrada"); err == nil {
		t.Fatal("a mark can only be left where you are")
	}
	if err := h.mark("p1", "grafite", "horta"); err == nil {
		t.Fatal("only the glyphs the world knows")
	}
	if err := h.mark("p1", "escondido", "horta"); err != nil {
		t.Fatal(err)
	}
	seen := h.marks("p2")
	if len(seen) != 1 || seen[0].Glyph != "escondido" || seen[0].AuthorName != "P1" || seen[0].Spot != "horta" || seen[0].Mine {
		t.Fatalf("p2 sees p1's mark: %+v", seen)
	}
	if mine := h.marks("p1"); len(mine) != 1 || !mine[0].Mine || mine[0].ID != seen[0].ID {
		t.Fatalf("p1 sees the same mark as theirs: %+v", mine)
	}
	if len(h.marks("p3")) != 0 {
		t.Fatal("p3 is elsewhere: no mark here")
	}
	id := seen[0].ID
	agree := func(p core.ID) error {
		return h.act("player", p, "concordar", map[string]core.ID{"mark": core.ID(id)})
	}
	if err := agree("p1"); err == nil {
		t.Fatal("nobody confirms their own mark")
	}
	if err := agree("p3"); err == nil {
		t.Fatal("p3 is not there")
	}
	if err := agree("p2"); err != nil {
		t.Fatal(err)
	}
	if err := agree("p2"); err == nil {
		t.Fatal("one confirmation each")
	}
	if got := h.marks("p1")[0]; got.Agree != 1 {
		t.Fatalf("p1 sees one confirmation: %+v", got)
	}
	found := false
	for _, a := range h.w.Affordances(&h.s, "p3") {
		found = found || a.Action == "concordar"
	}
	if found {
		t.Fatal("no affordance to confirm marks in another place")
	}
}

// A mark fades, unless others keep confirming it; and nobody keeps more than a few.
func TestMarksFadeAndAreLimitedPerTraveller(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.mustAct("player", "p1", "marcar", map[string]core.ID{"glyph": "perigo", "spot": "horta"})
	h.mustAct("player", "p1", "marcar", map[string]core.ID{"glyph": "atencao", "spot": "poco"})
	h.mustAct("player", "p1", "marcar", map[string]core.ID{"glyph": "descanso", "spot": "praca"})
	h.mustAct("player", "p1", "marcar", map[string]core.ID{"glyph": "desconfie", "spot": "forja"})
	got := h.marks("p2")
	if len(got) != 3 {
		t.Fatalf("at most three per traveller, got %d", len(got))
	}
	for _, m := range got {
		if m.Glyph == "perigo" {
			t.Fatal("the oldest mark makes room for the new one")
		}
	}
	// p2 confirms one of them; after the usual life only that one remains.
	var keep core.MarkView
	for _, m := range got {
		if m.Glyph == "atencao" {
			keep = m
		}
	}
	h.mustAct("player", "p2", "concordar", map[string]core.ID{"mark": core.ID(keep.ID)})
	h.tick(210)
	left := h.marks("p2")
	if len(left) != 1 || left[0].ID != keep.ID {
		t.Fatalf("only the confirmed mark outlives the others: %+v", left)
	}
	h.tick(80)
	if len(h.marks("p2")) != 0 {
		t.Fatal("everything fades in the end")
	}
}

// What one player knows can be passed on to another, who then holds it as
// heard from them; it cannot be passed to someone elsewhere.
func TestSecretsPassBetweenPlayers(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2", "p3")
	h.tickUntilFact("poisoned", "poco")
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "agua-turva"})
	h.move("p3", "estrada")
	tell := func(to core.ID) error {
		return h.act("player", "p1", "contar", map[string]core.ID{"npc": to, "p": "poisoned", "s": "poco"})
	}
	offered := func(to core.ID) bool {
		for _, a := range h.w.Affordances(&h.s, "p1") {
			if a.Action == "contar" && a.With == to {
				return true
			}
		}
		return false
	}
	if !offered("p2") {
		t.Fatal("p2 does not know it: p1 can tell them")
	}
	if err := tell("p3"); err == nil {
		t.Fatal("p3 is elsewhere")
	}
	if err := tell("p1"); err == nil {
		t.Fatal("telling yourself is not telling")
	}
	if err := tell("p2"); err != nil {
		t.Fatal(err)
	}
	if b := h.s.Beliefs["p2"]["|poisoned|poco|"]; !b.Holds || b.Source != "communication" || b.From != "p1" {
		t.Fatalf("p2 holds it as heard from p1: %+v", b)
	}
	v, _ := h.w.View(&h.s, "p2", 5)
	told := false
	for _, e := range v.Events {
		told = told || e.Kind == "told" && strings.Contains(e.Text, "P1")
	}
	if !told {
		t.Fatal("p2 is told, in words, who spoke")
	}
	if offered("p2") {
		t.Fatal("nothing left to tell p2 about this")
	}
}

// Two players in the same village see different worlds (they know different
// things), and the same shared things: the mark and the monument of a claimed chapter.
func TestTwoPlayersSeeDifferentBeliefsAndTheSameMarksAndMonument(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "cenouras-roidas"})
	h.mustAct("player", "p1", "marcar", map[string]core.ID{"glyph": "escondido", "spot": "horta"})
	v1, _ := h.w.View(&h.s, "p1", 5)
	v2, _ := h.w.View(&h.s, "p2", 5)
	clue := func(v core.View) bool {
		for _, f := range v.Facts {
			if f.P == "den-trail" {
				return true
			}
		}
		return false
	}
	if !clue(v1) || clue(v2) {
		t.Fatal("only p1 reached the clue about the den")
	}
	if len(v1.Marks) != 1 || len(v2.Marks) != 1 || v1.Marks[0].ID != v2.Marks[0].ID {
		t.Fatalf("both see the same mark: %+v / %+v", v1.Marks, v2.Marks)
	}
	// p1 follows the trail at the seal: the first chapter is theirs, for everyone to see.
	h.tickUntilFact("seal-broken", "selo")
	h.move("p1", "floresta")
	h.mustAct("adapter", "p1", "seguir-rastro", nil)
	h.tick(2)
	chapter := func(p core.ID) []string {
		v, _ := h.w.View(&h.s, p, 5)
		for _, st := range v.Story {
			for _, ch := range st.Chronicle {
				if ch.Beat == "origem" {
					return ch.By
				}
			}
		}
		return nil
	}
	a, b := chapter("p1"), chapter("p2")
	if len(a) != 1 || a[0] != "P1" || len(b) != 1 || b[0] != "P1" {
		t.Fatalf("the claimed chapter is public: %v / %v", a, b)
	}
	// And the title shows on the person.
	v2, _ = h.w.View(&h.s, "p2", 5)
	for _, o := range v2.Others {
		if o.ID == "p1" && o.Title != "Descobridor do Selo" {
			t.Fatalf("p2 sees p1's public title: %q", o.Title)
		}
	}
}

// Fame changes how people speak to you.
func TestPublicTitlesChangeHowPeopleGreetYou(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.s.Entities["p1"].Tag["title"] = "Descobridor do Selo"
	var lines []string
	d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "conversar", Args: map[string]core.ID{"npc": "orin"}})
	for _, e := range d.Events {
		if e.Kind == "talked" {
			lines = append(lines, e.Text)
		}
	}
	joined := strings.Join(lines, " | ")
	if !strings.Contains(joined, "Descobridor do Selo") {
		t.Fatalf("the guard knows who you are: %q", joined)
	}
}
