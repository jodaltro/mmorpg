package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) moveTo(p, region core.ID, spot string) {
	h.t.Helper()
	h.do(core.Command{Kind: "move", Origin: "adapter", Actor: p, Region: region, Spot: spot})
}

// A deed is noticed by the people close to it, not by the whole village.
func TestOnlyThoseNearTheDeedNoticeIt(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(8) // Brom at the forge, Mira in the garden, Orin at the gate
	h.moveTo("p1", "vila", "forja")
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "marca-bigorna"})
	if !h.knowsOf("brom", "p1") {
		t.Fatal("Brom, at the forge, saw it")
	}
	if h.knowsOf("mira", "p1") || h.knowsOf("orin", "p1") {
		t.Fatal("Mira in the garden and Orin at the gate did not see anything")
	}
	h.moveTo("p1", "vila", "praca")
	h.mustAct("player", "p1", "ler-quadro", nil)
	if !h.knowsOf("nino", "p1") {
		t.Fatal("Nino plays in the plaza and saw it")
	}
	if h.knowsOf("mira", "p1") {
		t.Fatal("Mira is still elsewhere")
	}
}

// People who are asleep notice nothing; people spoken to always know who speaks.
func TestSleepersSeeNothingAndTheAddressedAlwaysKnow(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(2) // Mira sleeps at home
	h.moveTo("p1", "vila", "casa-mira")
	h.mustAct("player", "p1", "ler-quadro", nil)
	if h.knowsOf("mira", "p1") {
		t.Fatal("Mira is asleep")
	}
	h.tickToHour(8)
	h.moveTo("p1", "vila", "forja")
	h.mustAct("player", "p1", "conversar", map[string]core.ID{"npc": "orin"}) // Orin is at the gate, far from here
	if !h.knowsOf("orin", "p1") {
		t.Fatal("whoever is spoken to knows who speaks")
	}
	if h.knowsOf("mira", "p1") {
		t.Fatal("but the others did not hear it")
	}
}

// Without a known spot the old rule holds (everyone awake in the region), so
// other game servers that do not report spots keep working.
func TestWithoutASpotEveryoneAwakeNotices(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(8)
	h.mustAct("player", "p1", "ler-quadro", nil)
	if !h.knowsOf("brom", "p1") || !h.knowsOf("mira", "p1") || !h.knowsOf("orin", "p1") {
		t.Fatal("without a spot, the awake villagers notice")
	}
}

// A spot belongs to one region; the actor's spot is forgotten on leaving.
func TestSpotsBelongToTheirRegion(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	if _, err := h.try(core.Command{Kind: "move", Origin: "adapter", Actor: "p1", Region: "vila", Spot: "banco-estrada"}); err == nil {
		t.Fatal("the road bench is not in the village")
	}
	h.moveTo("p1", "vila", "forja")
	if h.s.Entities["p1"].Tag["spot"] != "forja" {
		t.Fatal("the spot is remembered")
	}
	h.moveTo("p1", "estrada", "")
	if _, has := h.s.Entities["p1"].Tag["spot"]; has {
		t.Fatal("leaving the region forgets the spot")
	}
}

// NPCs have lives of their own: news about a stranger travels only when two of
// them actually meet. Brom saw the deed at the forge; in the evening he drinks at
// the tavern with Tomas, so Tomas hears; the people in the garden, at the gate and
// in the plaza never cross his path, so they do not.
func TestNewsOfAStrangerTravelsOnlyWhenPeopleMeet(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(8)
	h.moveTo("p1", "vila", "forja")
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "marca-bigorna"})
	if !h.knowsOf("brom", "p1") {
		t.Fatal("Brom saw it")
	}
	h.tick(6) // still in the morning: nobody has met Brom
	for _, id := range []core.ID{"mira", "orin", "elena", "nino", "tomas"} {
		if h.knowsOf(id, "p1") {
			t.Fatalf("%s cannot have heard yet", id)
		}
	}
	for i := 0; i < 400 && !h.knowsOf("tomas", "p1"); i++ {
		h.tick(1)
	}
	if !h.knowsOf("tomas", "p1") {
		t.Fatal("Tomas meets Brom at the tavern in the evening and hears of p1")
	}
	h.tick(150)
	for _, id := range []core.ID{"mira", "orin", "elena", "nino"} {
		if h.knowsOf(id, "p1") {
			t.Fatalf("%s never met Brom or Tomas that day", id)
		}
	}
}

// Standing in the open, away from every named spot, nobody notices what you do.
func TestNobodyNoticesYouOnOpenGround(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(8)
	h.moveTo("p1", "vila", core.OpenGround)
	h.mustAct("player", "p1", "ler-quadro", nil)
	for _, id := range []core.ID{"brom", "mira", "orin", "nino", "elena"} {
		if h.knowsOf(id, "p1") {
			t.Fatalf("%s saw something on open ground", id)
		}
	}
}
