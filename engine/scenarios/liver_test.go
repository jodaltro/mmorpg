package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// intoLiver walks p to the liver along the vessels. In the frozen fixture the venule's niche gives the key to the aorta;
// in the live Hospedeiro every passage is open to every cell.
func (h *harness) intoLiver(p core.ID) {
	h.t.Helper()
	h.move(p, "sangue")
	if len(h.w.U.Niches) > 0 {
		findNiche(h, p, "bolsa-da-venula")
	}
	h.move(p, "coracao")
	h.move(p, "aorta")
	h.move(p, "figado")
}

// E3: the liver's two verbs only work inside it, and each one moves the liver's numbers.
func TestHospedeiroLiverVerbsNeedTheLiver(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	if err := h.act("adapter", "p1", "guardar-glicogenio", nil); !isRejected(err) {
		t.Fatalf("storing glycogen outside the liver should be refused, got %v", err)
	}
	h.intoLiver("p1")
	g, tox := h.s.Entities["figado"].Num["glicogenio"], h.s.Entities["figado"].Num["toxina"]
	h.mustAct("adapter", "p1", "guardar-glicogenio", nil)
	h.mustAct("adapter", "p1", "filtrar-toxina", nil)
	if h.s.Entities["figado"].Num["glicogenio"] != g+4 || h.s.Entities["figado"].Num["toxina"] != tox-4 {
		t.Fatalf("glycogen %d->%d toxin %d->%d", g, h.s.Entities["figado"].Num["glicogenio"], tox, h.s.Entities["figado"].Num["toxina"])
	}
	if err := h.act("player", "p1", "guardar-glicogenio", nil); !isRejected(err) {
		t.Fatalf("only the game server confirms it, got %v", err)
	}
}

// E3: organs talk to each other. A blood sugar that runs low is topped up from the liver's glycogen; toxins that nobody filters pile up
// until the body inflames. All of it without a single player acting, and the log replays it.
func TestHospedeiroLiverKeepsSugarAndPilesToxins(t *testing.T) {
	h := loadWithoutPops(t, "hospedeiro", "hepatocitos_figado") // nobody filters the toxins
	h.join("p1")
	h.tick(60)
	if len(h.events("figado-libera")) == 0 {
		t.Fatal("when the sugar runs low the liver should release glycogen")
	}
	if h.s.Entities["sangue"].Num["glicose"] == 0 {
		t.Fatal("the liver should be keeping the sugar above zero")
	}
	h.tick(300)
	if len(h.events("figado-sobrecarregado")) == 0 {
		t.Fatal("unfiltered toxins should overload the liver and inflame the body")
	}
	b := loadWithoutPops(t, "hospedeiro", "hepatocitos_figado")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying the liver's log gives another world")
	}
}

// E3: the crypt of Kupffer is unique and hands over the peroxisomes; the liver quests close on the deeds.
func TestHospedeiroKupfferCryptAndLiverQuest(t *testing.T) {
	h := load(t, legacyQuests)
	h.join("p1", "p2")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil) // the first deed unlocks offers
	h.mustAct("adapter", "p2", "absorver-nutriente", nil)
	h.intoLiver("p1")
	findNiche(h, "p1", "cripta-de-kupffer")
	if !hasGene(h, "p1", "peroxissomos") {
		t.Fatal("the crypt should hand over the peroxisomes")
	}
	h.intoLiver("p2")
	findNiche(h, "p2", "cripta-de-kupffer")
	if hasGene(h, "p2", "peroxissomos") {
		t.Fatal("a unique niche belongs to its first finder")
	}
	q := h.steer("p1", "figado-limpo")
	h.accept("p1", q)
	for i := 0; i < 8; i++ {
		h.mustAct("adapter", "p1", "filtrar-toxina", nil)
	}
	h.tick(2)
	if got, _ := h.quest("p1", "figado-limpo"); got.State != "done" {
		t.Fatalf("eight filtered toxins should close the quest, state %q", got.State)
	}
}
