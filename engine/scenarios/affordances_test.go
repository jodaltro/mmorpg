package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func affordances(h *harness, p core.ID) map[string]core.Affordance {
	out := map[string]core.Affordance{}
	for _, a := range h.w.Affordances(&h.s, p) {
		out[a.Action+"@"+string(a.With)] = a
	}
	return out
}

// What a player can try follows where they are and what they can tell.
func TestAffordancesFollowThePlayer(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	a := affordances(h, "p1")
	for _, want := range []string{"conversar@mira", "conversar@brom", "examinar-poco@poco"} {
		if _, ok := a[want]; !ok {
			t.Fatalf("in the village p1 should be able to try %s: %v", want, a)
		}
	}
	if a["conversar@mira"].Args["npc"] != "mira" || a["conversar@mira"].Title != "Conversar com Mira, a curandeira" {
		t.Fatalf("talking to Mira binds her and names her: %+v", a["conversar@mira"])
	}
	for _, not := range []string{"minerar@", "forjar@brom", "purificar-poco@poco", "conversar@garrick"} {
		if _, ok := a[not]; ok {
			t.Fatalf("%s is ruled out by what p1 can tell (place, own numbers)", not)
		}
	}
	h.move("p1", "mina")
	a = affordances(h, "p1")
	if m, ok := a["minerar@"]; !ok || m.Origin != "adapter" {
		t.Fatalf("at the mine, mining is an occurrence the game server confirms: %+v", a)
	}
	if _, ok := a["conversar@garrick"]; !ok {
		t.Fatal("Garrick is at the mine")
	}
}

// Listing an affordance reveals nothing hidden: looking for Nino shows up in
// the forest whether or not he is really lost; the engine decides.
func TestAffordancesDoNotRevealHiddenFacts(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	if h.fact("", "child-lost", "floresta", "") {
		t.Fatal("precondition: Nino is not lost at the start")
	}
	if _, ok := affordances(h, "p1")["achar-crianca@"]; !ok {
		t.Fatal("the option must not depend on the hidden truth")
	}
	if err := h.act("adapter", "p1", "achar-crianca", nil); !isRejected(err) {
		t.Fatal("the authority still validates against the truth")
	}
}
