package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// The world lives with nobody online: the seal breaks, the village sickens,
// the guard notices, investigates, warns the healer, and she cures the well.
func TestWorldLivesWithoutPlayers(t *testing.T) {
	h := load(t, "valdoria")
	h.tick(80)
	if len(h.events("outbreak")) != 1 {
		t.Fatalf("expected one public outbreak, got %v", h.events("outbreak"))
	}
	purified := h.events("purified")
	if len(purified) == 0 || purified[0].Actor != "mira" {
		t.Fatalf("Mira should purify the well on her own: %+v", purified)
	}
	if got, _ := h.believes("orin", "poisoned", "poco"); got && !h.fact("", "poisoned", "poco", "") {
		t.Fatal("after the public purification Orin should believe the well is clean")
	}
	if h.s.Arcs["maldicao"].Beats["origem"].State != "open" {
		t.Fatalf("the unique scenario should be open and unclaimed: %+v", h.s.Arcs["maldicao"])
	}
}

// Mira acts on what she believes, not on the truth. The well is poisoned
// from tick 5, but she does nothing until someone tells her.
func TestAgentActsOnBeliefNotTruth(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tick(18)
	if !h.fact("", "poisoned", "poco", "") {
		t.Fatal("well should be poisoned by now")
	}
	if m := h.s.Entities["mira"]; m.Num["herbs"] != 0 || len(h.events("brewing")) != 0 {
		t.Fatalf("Mira acted without knowing: %+v", m.Num)
	}
	h.mustAct("player", "p1", "examinar-poco", nil)
	if err := h.act("player", "p1", "purificar-poco", nil); !isRejected(err) {
		t.Fatalf("player without antidote must be rejected, got %v", err)
	}
	h.mustAct("player", "p1", "contar-veneno", map[string]core.ID{"npc": "mira"})
	if holds, ok := h.believes("mira", "poisoned", "poco"); !ok || !holds {
		t.Fatal("Mira should believe the well is poisoned")
	}
	if b := h.s.Beliefs["mira"]["|poisoned|poco|"]; b.Source != "communication" || b.From != "p1" {
		t.Fatalf("belief must carry provenance: %+v", b)
	}
	h.tick(4)
	if h.fact("", "poisoned", "poco", "") {
		t.Fatal("Mira should cure the well within a few ticks of learning")
	}
	if h.s.Tick >= 24 {
		t.Fatal("the player should have changed the outcome before the outbreak")
	}
	if len(h.events("outbreak")) != 0 {
		t.Fatal("thanks to p1 the outbreak never happened")
	}
}

// Same world, different knowledge, different views.
func TestPrivateKnowledgeAndViews(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.tick(6)
	h.mustAct("player", "p1", "examinar-poco", nil)
	v1, _ := h.w.View(&h.s, "p1", 0)
	v2, _ := h.w.View(&h.s, "p2", 0)
	if len(v1.Beliefs) != 1 || !v1.Beliefs[0].Holds {
		t.Fatalf("p1 should know: %+v", v1.Beliefs)
	}
	if len(v2.Beliefs) != 0 {
		t.Fatalf("p2 must not see p1 knowledge: %+v", v2.Beliefs)
	}
	for _, e := range v2.Events {
		if e.Holder == "p1" {
			t.Fatalf("p2 sees a private event of p1: %+v", e)
		}
	}
	for _, f := range v2.Facts {
		if f.Holder != "p2" {
			t.Fatalf("p2 sees foreign fact %+v", f)
		}
	}
}

// Curing a symptom does not end the story: while the seal is broken the
// corruption returns, so the unique scenario stays reachable for everyone.
func TestStoryNeverStallsOnTransientState(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tick(6)
	h.mustAct("player", "p1", "examinar-poco", nil)
	h.mustAct("player", "p1", "contar-veneno", map[string]core.ID{"npc": "mira"})
	h.tick(5)
	if h.fact("", "poisoned", "poco", "") {
		t.Fatal("Mira should have cured the well")
	}
	h.tick(25)
	if !h.fact("", "poisoned", "poco", "") || len(h.events("omen")) < 2 {
		t.Fatal("the corruption must come back while the seal is broken")
	}
	if h.s.Arcs["maldicao"].Beats["origem"].State != "open" {
		t.Fatal("the unique scenario must remain open")
	}
}
