package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func TestDeliveredQuestWaitsForResponseAndSurvivesTravel(t *testing.T) {
	h := load(t, legacyQuests)
	h.join("p1", "p2")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	args := map[string]core.ID{"quest": core.ID(q.Key)}
	before := h.s.Digest()
	if h.act("player", "p2", "acknowledge-quest", args) == nil || h.s.Digest() != before {
		t.Fatal("another player acknowledged the offer")
	}
	if h.act("adapter", "p1", "acknowledge-quest", args) == nil {
		t.Fatal("receipt is a player intention")
	}
	h.mustAct("player", "p1", "acknowledge-quest", args)
	h.tick(60)
	if got := h.s.Quests[q.Key]; got.State != "offered" || !got.Acknowledged {
		t.Fatal("a delivered offer expired")
	}
	h.move("p1", "sangue")
	h.tick(3)
	for _, other := range h.s.Quests {
		if other.Holder == "p1" && other.State == "offered" && other.Key != q.Key {
			t.Fatal("a new offer replaced an unanswered quest")
		}
	}
	if h.s.Quests[q.Key].State != "offered" {
		t.Fatal("travel or achieving the objective withdrew the delivered offer")
	}
	h.accept("p1", q)
	if h.s.Quests[q.Key].State != "done" {
		t.Fatal("accepting after reaching the objective did not complete the quest")
	}
	b := load(t, legacyQuests)
	for _, command := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, command); err != nil {
			t.Fatal(err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("quest receipt broke replay")
	}
}

func TestDeliveredActiveQuestKeepsItsObjectiveWhenEligibilityChanges(t *testing.T) {
	h := load(t, legacyQuests)
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	h.accept("p1", q)
	h.mustAct("player", "p1", "acknowledge-quest", map[string]core.ID{"quest": core.ID(q.Key)})
	// Eligibility is only for initial selection. A short trip elsewhere must not end an accepted journey.
	h.move("p1", "figado")
	h.tick(30)
	if h.s.Quests[q.Key].State != "active" {
		t.Fatal("accepted quest silently became obsolete")
	}
	h.move("p1", "sangue")
	h.tick(1)
	if h.s.Quests[q.Key].State != "done" {
		t.Fatal("preserved objective no longer completes")
	}
}
