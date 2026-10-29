package scenarios

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// 28/10/2026: the Hospedeiro lives one crisis at a time, and has no missions.
// A crisis whose cause holds while another is alive waits its turn; the physiology
// goes on meanwhile, so what waited comes in worse, not forgotten.

var allCrises = []string{"ferida-na-pele", "infeccao-pulmonar", "sobrecarga-hepatica", "congestao-esplenica", "disbiose-intestinal", "medula-esgotada",
	"sobrecarga-renal", "reacao-exagerada", "sofrimento-cerebral", "tumor-intestinal"}

// liveCrises are the ones asking for attention. A contained or recovering crisis
// is calm and runs beside the next; only active and critical ones take the place.
func liveCrises(h *harness) []string {
	var out []string
	for _, d := range allCrises {
		if _, l := byDef(h.s, d); len(l) > 0 && (l[0].Phase == core.PhaseActive || l[0].Phase == core.PhaseCritical) {
			out = append(out, d)
		}
	}
	return out
}

// patienceRan: two may be demanding at once only when the older has already
// kept its place for the whole patience of the universe.
func patienceRan(h *harness, live []string) bool {
	oldest := core.Tick(0)
	for _, d := range live {
		if _, l := byDef(h.s, d); h.s.Tick-l[0].Onset > oldest {
			oldest = h.s.Tick - l[0].Onset
		}
	}
	return oldest >= h.w.U.Limits.LiveConflictPatience
}

func TestTheBodyLivesOneCrisisAtATimeAndEveryOneGetsItsTurn(t *testing.T) {
	run := func() (*harness, []string) {
		h := load(t, "hospedeiro")
		forceBody(h) // nine causes hold at once
		var opened []string
		seen := map[string]bool{}
		for i := 0; i < 6000; i++ {
			h.tick(1)
			live := liveCrises(h)
			if len(live) > 1 && !patienceRan(h, live) {
				t.Fatalf("tick %d: %d crises asking for attention at once: %v", h.s.Tick, len(live), live)
			}
			for _, d := range live {
				if !seen[d] {
					seen[d] = true
					opened = append(opened, d)
				}
			}
		}
		return h, opened
	}
	a, opened := run()
	b, _ := run()
	if a.s.Digest() != b.s.Digest() {
		t.Fatal("the queue of crises must be deterministic")
	}
	// A cause that waited may well have healed on its own meanwhile (the kidney
	// is filtered by Nefra whether or not its crisis is open). What must not happen
	// is a cause that still holds and was never given its turn.
	for _, c := range a.w.U.Conflicts {
		if !slices.Contains(opened, c.ID) && a.w.Holds(&a.s, c.Trigger, core.Bind{}) {
			t.Fatalf("%s: its cause still holds after 6000 ticks and it never had a turn (opened: %v)", c.ID, opened)
		}
	}
	if len(opened) < 5 {
		t.Fatalf("taken one at a time the body must still get through several: %v", opened)
	}
	resolved := 0
	for _, d := range allCrises {
		if resolvedOf(a, d) {
			resolved++
		}
	}
	if resolved < 4 {
		t.Fatalf("only %d resolved", resolved)
	}
	t.Logf("opened in order: %v; %d resolved", opened, resolved)
}

func TestACrisisWaitsForTheLivePlaceAndTheLongestWaitingGoesFirst(t *testing.T) {
	h := load(t, "hospedeiro")
	setNum(h, "pele", "ferida", 80)
	h.tick(3)
	if !openedOf(h, "ferida-na-pele") {
		t.Fatal("the wound opens first: it is the only cause")
	}
	setNum(h, "figado", "toxina", 100)
	setNum(h, "rim", "ureia", 95)
	h.tick(5)
	if openedOf(h, "sobrecarga-hepatica") || openedOf(h, "sobrecarga-renal") {
		t.Fatal("while the wound is alive nothing else may open")
	}
	var wound core.ConflictState
	if _, live := byDef(h.s, "ferida-na-pele"); len(live) == 1 {
		wound = live[0]
	}
	runUntil(h, 3000, func() bool { return resolvedOf(h, "ferida-na-pele") })
	if !resolvedOf(h, "ferida-na-pele") {
		t.Fatal("the wound must close by itself")
	}
	h.tick(3)
	// Only the crises that take the place count: one that has kept it past the universe's patience lets the next open beside it.
	var next []string
	for _, d := range liveCrises(h) {
		if _, l := byDef(h.s, d); h.s.Tick-l[0].Onset < h.w.U.Limits.LiveConflictPatience {
			next = append(next, d)
		}
	}
	if len(next) != 1 || next[0] == "ferida-na-pele" {
		t.Fatalf("a place is free: the next waiting cause must open, and not the wound again: %v", next)
	}
	if _, live := byDef(h.s, next[0]); live[0].Onset <= wound.Since {
		t.Fatalf("%s must open after the wound, not before", next[0])
	}
}

// 28/10/2026: nobody grows any more. There are no missions, and doing things teaches no ability: a class
// and its kit come only with a calling, while the player stands in a crisis.
func TestNoMissionsAndNothingIsLearnedByDoing(t *testing.T) {
	h := load(t, "hospedeiro")
	if len(h.w.U.Quests) != 0 || len(h.w.U.Arcs) != 0 {
		t.Fatalf("the Hospedeiro has no missions: %d quests, %d arcs", len(h.w.U.Quests), len(h.w.U.Arcs))
	}
	if h.w.U.Evolution != nil || h.w.U.Differentiation != nil || len(h.w.U.Mutations) > 0 || len(h.w.U.Niches) > 0 || h.w.U.Appearance != nil || h.w.U.Abilities != nil {
		t.Fatal("the Hospedeiro has no growth: no evolution, mutations, differentiation, niches, body shaped by play or abilities found by doing")
	}
	for _, sk := range h.w.U.Skills {
		if sk.Learn != nil || sk.Starter {
			t.Fatalf("%s is learned by doing or on growing: nothing is", sk.ID)
		}
	}
	h.join("p1")
	h.repeat("adapter", "p1", "absorver-nutriente", 80)
	h.tick(50)
	for _, id := range h.skillIDs("p1") {
		if i := slices.IndexFunc(h.w.U.Skills, func(sk core.SkillDef) bool { return sk.ID == id }); i >= 0 && h.w.U.Skills[i].Class != "" {
			t.Fatalf("p1 learned the class ability %s by eating", id)
		}
	}
	if v, _ := h.w.View(&h.s, "p1", 5); v.Evolution != nil || v.Lineage != nil {
		t.Fatalf("no pressure, no maturity: %+v %+v", v.Evolution, v.Lineage)
	}
}

func TestEveryCrisisHasADeedThePlayerCanDoInItsOrgan(t *testing.T) {
	h := load(t, "hospedeiro")
	for _, c := range h.w.U.Conflicts {
		found := false
		for _, a := range h.w.U.Actions {
			if !slices.Contains(a.By, "adapter") || a.Title == "" {
				continue
			}
			raw, _ := json.Marshal(a)
			if strings.Contains(string(raw), `"rule":"`+c.ID+`"`) && strings.Contains(string(raw), `"region":"`+string(c.Region)+`"`) {
				found = true
			}
		}
		if !found {
			t.Errorf("%s (%s): no deed of a player in that organ counts for it", c.ID, c.Region)
		}
	}
}

func TestAPlayerInTheBrainHelpsItsCrisisAndIsPaidWhenItEnds(t *testing.T) {
	h := loadUncapped(t, "hospedeiro")
	h.joinAt("p1", "cerebro")
	setNum(h, "cerebro", "energia", 15)
	setNum(h, "cerebro", "residuos", 70)
	runUntil(h, 60, func() bool { return openedOf(h, "sofrimento-cerebral") })
	if !openedOf(h, "sofrimento-cerebral") {
		t.Fatal("the brain crisis must open")
	}
	for i := 0; i < 4; i++ {
		h.mustAct("adapter", "p1", "amparar-neuronios-cerebro", nil)
	}
	if !creditedBy(h, "sofrimento-cerebral", "p1") {
		t.Fatal("the player's deed must count for the crisis")
	}
	runUntil(h, 2500, func() bool { return resolvedOf(h, "sofrimento-cerebral") })
	if !resolvedOf(h, "sofrimento-cerebral") {
		t.Fatal("the crisis must end")
	}
}

// A crisis can be anywhere, so every organ is open to every cell from the start:
// no passage asks for a gene or a lineage.
func TestNoPassageOfTheBodyAsksForAGeneOrALineage(t *testing.T) {
	h := load(t, "hospedeiro")
	if len(h.w.U.Passages) == 0 {
		t.Fatal("the body has vessels")
	}
	for _, p := range h.w.U.Passages {
		if p.Gene != "" || len(p.Lineages) > 0 {
			t.Errorf("passage %s still asks for %q %v", p.ID, p.Gene, p.Lineages)
		}
	}
}
