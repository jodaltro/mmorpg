package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// P13: the Hospedeiro has no dungeon runs any more. What they paid (pressure
// towards a gene, maturity, the seal of the organ) is paid by the crisis of
// the same organ, once, to the players who really took part in it.
var dungeonSuccessors = []struct{ crisis, seal, action string }{
	{"infeccao-pulmonar", "selo-do-granuloma", "conter-infeccao-pulmonar"},
	{"sobrecarga-hepatica", "selo-do-figado", "filtrar-toxina"},
	{"congestao-esplenica", "selo-do-baco", "reciclar-hemacia"},
	{"disbiose-intestinal", "selo-do-intestino", "nutrir-microbiota"},
	{"sobrecarga-renal", "selo-do-rim", "filtrar-ureia"},
}

func TestHospedeiroHasNoDungeonEntryAndTheCrisesPayInstead(t *testing.T) {
	h := load(t, "hospedeiro")
	if len(h.w.U.Dungeons) != 0 {
		t.Fatalf("the Hospedeiro must not offer dungeon runs, it has %d", len(h.w.U.Dungeons))
	}
	for _, d := range dungeonSuccessors {
		found := false
		for _, c := range h.w.U.Conflicts {
			if c.ID != d.crisis {
				continue
			}
			found = true
			sealed := false
			for _, e := range c.Rewards {
				sealed = sealed || (e.Op == "grant" && e.V == d.seal)
			}
			if !sealed {
				t.Fatalf("%s must grant %s to those who take part", d.crisis, d.seal)
			}
		}
		if !found {
			t.Fatalf("crisis %s is missing", d.crisis)
		}
	}
	h.join("p1")
	if _, err := h.try(core.Command{Kind: "decide", Origin: "player", Actor: "p1", Choice: "dungeon"}); err == nil {
		t.Fatal("a new character must not find an entry to a dungeon")
	}
}

func TestResolvedCrisisPaysOnlyThoseWhoTookPartAndOnlyOnce(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "figado")
	h.joinAt("p2", "figado")
	setNum(h, "figado", "toxina", 100)
	runUntil(h, 50, func() bool { return openedOf(h, "sobrecarga-hepatica") })
	if !openedOf(h, "sobrecarga-hepatica") {
		t.Fatal("the liver crisis must open")
	}
	before := h.s.Entities["p1"].Num["pressao"]
	for i := 0; i < 3; i++ {
		h.mustAct("adapter", "p1", "filtrar-toxina", nil)
	}
	if _, ok := h.s.Skills["p1"]["selo-do-figado"]; ok {
		t.Fatal("nothing is paid while the crisis is still open")
	}
	runUntil(h, 8000, func() bool { return resolvedOf(h, "sobrecarga-hepatica") }) // the liver heals slowly on its own since 28/10/2026
	if !resolvedOf(h, "sobrecarga-hepatica") {
		t.Fatal("the liver crisis must resolve by itself")
	}
	if _, ok := h.s.Skills["p1"]["selo-do-figado"]; !ok {
		t.Fatal("the player who filtered toxins must receive the seal")
	}
	if h.s.Entities["p1"].Num["pressao"] < before+10 {
		t.Fatalf("pressure must rise by the reward: %d -> %d", before, h.s.Entities["p1"].Num["pressao"])
	}
	if _, ok := h.s.Skills["p2"]["selo-do-figado"]; ok {
		t.Fatal("a player who only watched must not be paid")
	}
	paid := len(h.events("conflict-reward"))
	if paid != 1 {
		t.Fatalf("exactly one player is paid, got %d reward events", paid)
	}
	for _, e := range h.events("conflict-reward") {
		if e.Holder != "p1" || e.Public {
			t.Fatalf("the reward is private to the player: %+v", e)
		}
	}
	h.tick(200)
	if got := len(h.events("conflict-reward")); got != paid {
		t.Fatalf("a resolved crisis never pays twice: %d -> %d", paid, got)
	}
}
