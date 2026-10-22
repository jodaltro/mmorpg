package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) signs(p core.ID) map[string]core.SignView {
	h.t.Helper()
	v, ok := h.w.View(&h.s, p, 5)
	if !ok {
		h.t.Fatalf("no view for %s", p)
	}
	out := map[string]core.SignView{}
	for _, sg := range v.Signs {
		out[sg.ID] = sg
	}
	return out
}

func (h *harness) tickToHour(hour int64) {
	for h.w.Hour(&h.s) != hour {
		h.tick(1)
	}
}

func (h *harness) tickUntilFact(p, s string) {
	h.t.Helper()
	for i := 0; i < 200; i++ {
		for _, f := range h.s.Facts {
			if f.P == p && string(f.S) == s {
				return
			}
		}
		h.tick(1)
	}
	h.t.Fatalf("fact %s %s never came to be", p, s)
}

// A sign is the effect of a hidden truth: it exists only while the truth
// holds, and showing it never names the cause.
func TestSignShowsTheEffectNeverTheCause(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	if _, there := h.signs("p1")["agua-turva"]; there {
		t.Fatal("clear water before the poisoning")
	}
	h.tickUntilFact("poisoned", "poco")
	sg, there := h.signs("p1")["agua-turva"]
	if !there {
		t.Fatal("murky water once the well is poisoned")
	}
	v, _ := h.w.View(&h.s, "p1", 5)
	b, _ := json.Marshal(v.Signs)
	if strings.Contains(string(b), "poisoned") || strings.Contains(sg.Look, "veneno") {
		t.Fatalf("a sign must not name its cause: %s", b)
	}
	for _, f := range v.Facts {
		if f.P == "poisoned" {
			t.Fatal("seeing the sign is not knowing the fact")
		}
	}
	if _, here := h.signs("p1")["veios-brilham"]; here {
		t.Fatal("signs belong to a place: the mine's are not in the village")
	}
}

// Examining a sign is how the world teaches: the observer ends up believing,
// by observation, what the sign points to.
func TestExaminingASignFormsAnObservedBelief(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	if err := h.act("player", "p1", "examinar", map[string]core.ID{"sign": "veios-brilham"}); err == nil {
		t.Fatal("cannot examine what is in another place")
	}
	d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "examinar", Args: map[string]core.ID{"sign": "agua-turva"}})
	if len(d.Events) == 0 || d.Events[0].Kind != "examined" || d.Events[0].Public {
		t.Fatalf("a private account of what was seen: %+v", d.Events)
	}
	b, ok := h.s.Beliefs["p1"]["|poisoned|poco|"]
	if !ok || !b.Holds || b.Source != "observation" {
		t.Fatalf("belief after examining: %+v", b)
	}
}

// Seeing takes more than being there: a night sign needs the night, and the
// white boar's track needs someone who knows how to look.
func TestSignsAskForTheHourAndForSkill(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	h.tickToHour(12)
	if _, there := h.signs("p1")["pegada-branca"]; there {
		t.Fatal("not by day")
	}
	h.tickToHour(23)
	if _, there := h.signs("p1")["pegada-branca"]; there {
		t.Fatal("not at night for someone who never hunted")
	}
	h.s.Entities["p1"].Num["hunts"] = 1
	if _, there := h.signs("p1")["pegada-branca"]; !there {
		t.Fatal("a hunter sees the track at night")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "pegada-branca"})
	if _, ok := h.s.Facts["p1|white-boar-sign|p1|floresta"]; !ok {
		t.Fatalf("the track becomes a private clue; facts: %v", h.s.Facts)
	}
}

// You can only tell what you believe; people answer by what they already know,
// and by whether it is still true.
func TestTellingBeliefsAndHowPeopleReact(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	tell := func(npc core.ID) (string, error) {
		d, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "contar",
			Args: map[string]core.ID{"npc": npc, "p": "poisoned", "s": "poco"}})
		for _, e := range d.Events {
			if e.Kind == "told" {
				return e.Text, err
			}
		}
		return "", err
	}
	if _, err := tell("mira"); err == nil {
		t.Fatal("nobody can tell what they do not believe")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "agua-turva"})
	if _, err := tell("kael"); err == nil {
		t.Fatal("Kael is in the forest: the listener must be here")
	}
	first, err := tell("mira")
	if err != nil || !strings.Contains(first, "antidoto") {
		t.Fatalf("Mira takes the news: %q %v", first, err)
	}
	if b := h.s.Beliefs["mira"]["|poisoned|poco|"]; !b.Holds || b.Source != "communication" || b.From != "p1" {
		t.Fatalf("Mira's belief: %+v", b)
	}
	if second, _ := tell("mira"); !strings.Contains(second, "Eu sei") {
		t.Fatalf("she already knows: %q", second)
	}
	// The world moves on: the well is clean, and what p1 believes is stale.
	delete(h.s.Facts, "|poisoned|poco|")
	if stale, _ := tell("brom"); !strings.Contains(stale, "limpo") {
		t.Fatalf("out of date: %q", stale)
	}
	if b, ok := h.s.Beliefs["brom"]["|poisoned|poco|"]; ok && b.Holds {
		t.Fatal("Brom must not take in something no longer true")
	}
}

// What can be tried follows what is seen and believed.
func TestAffordancesIncludeExamineAndTell(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	find := func(action string, with core.ID) bool {
		for _, a := range h.w.Affordances(&h.s, "p1") {
			if a.Action == action && (with == "" || a.With == with) {
				return true
			}
		}
		return false
	}
	if !find("examinar", "") {
		t.Fatal("the murky water can be examined")
	}
	if find("contar", "mira") {
		t.Fatal("nothing to tell before believing something")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "agua-turva"})
	if !find("contar", "mira") {
		t.Fatal("now Mira can be told")
	}
}

// Tomas draws a sketch: two places appear on the map without going there.
func TestSketchRevealsPlacesOnTheMap(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", h.s.Entities["tomas"].Region)
	h.mustAct("player", "p1", "pedir-esboco", nil)
	if !found(h, "p1", "floresta") || !found(h, "p1", "mina") || found(h, "p1", "toca") {
		t.Fatal("the sketch shows the forest and the mine, not the den")
	}
	if err := h.act("player", "p1", "pedir-esboco", nil); err == nil {
		t.Fatal("one sketch is enough")
	}
}
