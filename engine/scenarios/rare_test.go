package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// Luck is deterministic: same state, same roll; across ticks it matches the
// configured rate.
func TestChanceIsDeterministicAndCalibrated(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	c := core.Cond{Chance: &core.ChanceCmp{Seed: "test", Permille: 100}}
	hits := 0
	for i := 0; i < 4000; i++ {
		h.s.Tick = core.Tick(i)
		a := h.w.Holds(&h.s, c, core.Bind{"self": "p1"})
		if a != h.w.Holds(&h.s, c, core.Bind{"self": "p1"}) {
			t.Fatal("the same state must roll the same")
		}
		if a {
			hits++
		}
	}
	if hits < 320 || hits > 480 {
		t.Fatalf("10%% chance hit %d of 4000", hits)
	}
}

// A hidden quest with very specific and lucky requirements: hunting at
// night after three trophies may reveal the White Boar.
func TestHiddenWhiteBoarQuest(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	night := func() {
		for h.w.Hour(&h.s) < 20 && h.w.Hour(&h.s) >= 4 {
			h.tick(1)
		}
	}
	found := false
	for i := 0; i < 600 && !found; i++ {
		night()
		h.mustAct("adapter", "p1", "cacar-javali", nil)
		found = h.fact("p1", "white-boar-sign", "p1", "floresta")
		h.tick(1)
	}
	if !found {
		t.Fatal("the lucky sign should appear eventually")
	}
	if h.s.Entities["p1"].Num["trophies"] < 3 {
		t.Fatal("the sign only appears to proven hunters")
	}
	q := h.steer("p1", "javali-branco")
	if q.Giver != "" || q.Rank != "A" {
		t.Fatalf("a hidden quest announced by the system: %+v", q)
	}
	h.accept("p1", q)
	for h.w.Hour(&h.s) >= 4 && h.w.Hour(&h.s) < 20 {
		h.tick(1)
		if err := h.act("adapter", "p1", "cacar-javali-branco", nil); err == nil {
			t.Fatal("the White Boar only appears at night")
		}
	}
	night()
	h.mustAct("adapter", "p1", "cacar-javali-branco", nil)
	if h.s.Entities["p1"].Tag["title"] != "Cacador do Javali Branco" {
		t.Fatalf("rare title missing: %+v", h.s.Entities["p1"].Tag)
	}
}
