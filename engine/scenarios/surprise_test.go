package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// What happens in the world can be seen where it happens, and some of it from
// afar, and it goes away when it ends.
func TestWorldEventsLeaveVisibleTraces(t *testing.T) {
	for _, c := range []struct {
		happening, sign string
		region          core.ID
		afterEnd        int
	}{
		{"caravana", "caravana-no-mercado", "vila", 26},
		{"tempestade", "tempestade-sobre-a-vila", "vila", 21},
		{"feira-magos", "feira-dos-magos", "vila", 31},
		{"peregrinos", "peregrinos-na-capela", "vila", 26},
		{"desabamento", "poeira-da-mina", "mina", 41},
	} {
		h := load(t, "valdoria")
		h.join("p1")
		h.move("p1", c.region)
		if _, there := h.signs("p1")[c.sign]; there {
			t.Fatalf("%s: seen before it happens", c.sign)
		}
		h.happen(c.happening)
		if _, there := h.signs("p1")[c.sign]; !there {
			t.Fatalf("%s: not seen while %s lasts", c.sign, c.happening)
		}
		h.tick(c.afterEnd)
		if _, there := h.signs("p1")[c.sign]; there {
			t.Fatalf("%s: still there after it ended", c.sign)
		}
	}
	// The festival is a fact like any other: ribbons and lanterns while it holds.
	hf := load(t, "valdoria")
	hf.join("p1")
	if _, there := hf.signs("p1")["festival-de-lanternas"]; there {
		t.Fatal("ribbons before the festival")
	}
	hf.s.Facts["|festival|vila|"] = core.Fact{P: "festival", S: "vila"}
	if _, there := hf.signs("p1")["festival-de-lanternas"]; !there {
		t.Fatal("ribbons and lanterns during the festival")
	}
	// A collapse is a landmark: a cloud of dust seen from the village too.
	h := load(t, "valdoria")
	h.join("p1")
	h.happen("desabamento")
	if sg, there := h.signs("p1")["poeira-da-mina"]; !there || !sg.Far {
		t.Fatalf("the dust cloud is seen from the village: %+v", sg)
	}
}

// The seal marks whoever touches it: others see the mark, people react to it,
// the night whispers, and a prayer can wash it off.
func TestSealMarkIsSeenReactedToAndCanBePurified(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.tickUntilFact("seal-broken", "selo")
	h.move("p1", "floresta")
	h.tickToHour(23)
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "selo-brilha"})
	if _, ok := h.s.Facts["p1|seal-touched|p1|selo"]; !ok {
		t.Fatal("touching the stones leaves the mark")
	}
	marks := func(observer, who core.ID) []string {
		v, _ := h.w.View(&h.s, observer, 5)
		for _, o := range v.Others {
			if o.ID == who {
				return o.Marks
			}
		}
		return nil
	}
	if got := marks("p2", "p1"); len(got) != 1 || got[0] != "seal-touched" {
		t.Fatalf("p2 sees p1's mark: %v", got)
	}
	if got := marks("p1", "p2"); len(got) != 0 {
		t.Fatalf("p2 carries nothing: %v", got)
	}
	h.move("p1", "vila")
	if _, there := h.signs("p1")["sussurros-na-noite"]; !there {
		t.Fatal("the marked hear whispers at night")
	}
	if _, there := h.signs("p2")["sussurros-na-noite"]; there {
		t.Fatal("others hear nothing")
	}
	talk := func(npc core.ID) string {
		d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "conversar", Args: map[string]core.ID{"npc": npc}})
		for _, e := range d.Events {
			if e.Kind == "talked" {
				return e.Text
			}
		}
		return ""
	}
	if got := talk("orin"); !strings.Contains(got, "marca") {
		t.Fatalf("the guard reacts to the mark: %q", got)
	}
	if got := talk("elena"); !strings.Contains(got, "purifica") {
		t.Fatalf("Elena offers to purify: %q", got)
	}
	h.mustAct("player", "p1", "purificar-marca", nil)
	if got := marks("p2", "p1"); len(got) != 0 {
		t.Fatalf("the mark is gone: %v", got)
	}
	if got := talk("orin"); strings.Contains(got, "marca") {
		t.Fatalf("the guard sees nothing now: %q", got)
	}
}

// A shooting star is rare, only at night, and brief.
func TestShootingStarIsRareAndOnlyAtNight(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	nights, stars := 0, 0
	for i := 0; i < 480; i++ { // ten days
		hr := h.w.Hour(&h.s)
		night := hr >= 21 || hr < 6
		if night {
			nights++
		}
		if _, there := h.signs("p1")["estrela-cadente"]; there {
			stars++
			if !night {
				t.Fatalf("a shooting star at %dh", hr)
			}
		}
		h.tick(1)
	}
	if stars == 0 {
		t.Fatal("ten nights without a single shooting star")
	}
	if stars*4 > nights {
		t.Fatalf("not rare: %d of %d night ticks", stars, nights)
	}
}

// The world keeps changing: in each of three stretches of play in a row,
// something the observer could not see when the stretch began appears on its
// own (events, stars, whispers, dust on the horizon).
func TestEachStretchOfPlayBringsSomethingNew(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	snapshot := func() map[string]bool {
		out := map[string]bool{}
		for _, r := range []core.ID{"vila", "estrada", "floresta", "mina", "ruinas", "toca"} {
			h.move("p1", r)
			for id := range h.signs("p1") {
				out[id] = true
			}
		}
		return out
	}
	for w := 0; w < 3; w++ {
		start := snapshot()
		var fresh []string
		for i := 0; i < 100; i++ {
			h.tick(1)
			for id := range snapshot() {
				if !start[id] && !slicesHas(fresh, id) {
					fresh = append(fresh, id)
				}
			}
		}
		if len(fresh) == 0 {
			t.Fatalf("stretch %d: nothing new appeared (it began with %d signs)", w+1, len(start))
		}
	}
}

func slicesHas(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
