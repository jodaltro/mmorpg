package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// The game server says where a newcomer arrives; the place must exist.
func TestJoinAtTheArrivalRegion(t *testing.T) {
	h := load(t, "valdoria")
	h.do(core.Command{Kind: "join", Origin: "adapter", Actor: "p1", Name: "P1", Region: "estrada"})
	if got := h.s.Entities["p1"].Region; got != "estrada" {
		t.Fatalf("arrived in %q", got)
	}
	if !found(h, "p1", "estrada") || found(h, "p1", "vila") {
		t.Fatal("only the place of arrival is on the map")
	}
	if _, err := h.try(core.Command{Kind: "join", Origin: "adapter", Actor: "p2", Name: "P2", Region: "poco"}); err == nil {
		t.Fatal("a landmark is not a region to arrive in")
	}
}

// A newcomer is a stranger to the system too: no window until they do
// something. The same timeline without the rule does produce offers, so the
// silence comes from the rule and not from an empty world.
func TestNewcomerGetsNoOfferBeforeTheFirstDeed(t *testing.T) {
	run := func(gate bool) (before bool, after bool) {
		h := load(t, "valdoria")
		u := h.w.U
		u.Limits.FirstDeedFirst = gate
		w, err := core.Compile(u)
		if err != nil {
			t.Fatal(err)
		}
		h.w, h.s = w, core.NewState(w)
		h.do(core.Command{Kind: "join", Origin: "adapter", Actor: "p1", Name: "P1", Region: "estrada"})
		h.tick(120)
		h.move("p1", "vila")
		h.tick(60)
		for _, q := range h.s.Quests {
			before = before || q.Holder == "p1"
		}
		h.mustAct("player", "p1", "ler-quadro", nil)
		h.tick(30)
		for _, q := range h.s.Quests {
			after = after || q.Holder == "p1"
		}
		return
	}
	if before, after := run(true); before || !after {
		t.Fatalf("with the rule: before the deed %v (want false), after %v (want true)", before, after)
	}
	if before, _ := run(false); !before {
		t.Fatal("without the rule this timeline offers quests to an idle newcomer")
	}
}

// What a person says depends on whether they know you.
func TestGreetingsDependOnAcquaintance(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	talk := func() string {
		d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "conversar", Args: map[string]core.ID{"npc": "orin"}})
		for _, e := range d.Events {
			if e.Kind == "talked" {
				return e.Text
			}
		}
		t.Fatal("no greeting")
		return ""
	}
	first, second := talk(), talk()
	if !strings.Contains(first, "Nome?") || strings.Contains(second, "Nome?") || first == second {
		t.Fatalf("a stranger is asked their name and a known face is not:\n1: %s\n2: %s", first, second)
	}
}

// The view says who knows the observer, and only for them: the villagers who
// saw a deed, not the ones elsewhere, and never for other players' secrets.
func TestViewShowsWhoKnowsYou(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	knows := func(observer, who core.ID) bool {
		v, _ := h.w.View(&h.s, observer, 5)
		for _, o := range v.Others {
			if o.ID == who {
				return o.KnowsYou
			}
		}
		t.Fatalf("%s not in the view", who)
		return false
	}
	if knows("p1", "mira") {
		t.Fatal("a newcomer is a stranger to everyone")
	}
	h.mustAct("player", "p1", "examinar-poco", nil)
	if !knows("p1", "mira") || !knows("p1", "brom") {
		t.Fatal("those who saw the deed know p1 now")
	}
	if knows("p1", "tomas") {
		t.Fatal("Tomas was elsewhere")
	}
	if knows("p2", "mira") {
		t.Fatal("what Mira knows about p1 says nothing about p2")
	}
}
