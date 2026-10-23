package scenarios

import (
	"slices"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// matureInBlood brings a player to the blood with enough maturity to enter the granuloma.
func (h *harness) matureInBlood(p core.ID) {
	h.t.Helper()
	h.mustAct("adapter", p, "absorver-nutriente", nil)
	h.move(p, "sangue")
	h.fight(p, 7)
}

func (h *harness) dungeonView(p core.ID) core.DungeonView {
	v, _ := h.w.View(&h.s, p, 1)
	if v.Dungeon == nil {
		h.t.Fatal("no dungeon view")
	}
	return *v.Dungeon
}

func (h *harness) pendingDungeonDecision(p core.ID) (core.Decision, bool) {
	for _, x := range h.s.Decisions {
		if x.Kind == "dungeon" && x.Subject == string(p) {
			return x, true
		}
	}
	return core.Decision{}, false
}

var granuloma = map[string]core.ID{"dungeon": "granuloma"}

// The granuloma is for people who are ready and are standing in the blood where it is.
func TestGranulomaNeedsMaturityAndTheRightPlace(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	if err := h.act("player", "p1", "entrar-masmorra", granuloma); err == nil {
		t.Fatal("a newborn in the marrow cannot enter the granuloma")
	}
	h.matureInBlood("p1")
	view := h.dungeonView("p1")
	if len(view.Available) != 2 || view.Available[0].ID != "granuloma" || view.Available[0].Rooms != 6 {
		t.Fatalf("the granuloma lists its longest run (opening + 4 + boss) and is listed, got %+v", view.Available)
	}
	if !view.Available[0].Eligible {
		t.Fatal("a mature cell in the blood may enter")
	}
	h.move("p1", "medula")
	if h.dungeonView("p1").Available[0].Eligible {
		t.Fatal("the entrance is in the blood, not in the marrow")
	}
}

// The advisor chooses the modifier of the run among the valid ones, it is revalidated, and the seed comes from the engine.
func TestTheAdvisorPicksTheModifierAndTheRunStarts(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.matureInBlood("p1")
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
	if run := h.dungeonView("p1").Run; run == nil || run.State != "preparing" {
		t.Fatalf("the run prepares while the advisor chooses, got %+v", run)
	}
	d, ok := h.pendingDungeonDecision("p1")
	if !ok || len(d.Options) != 5 {
		t.Fatalf("every modifier competes, got %+v", d.Options)
	}
	if d.Default != "em-febre" {
		t.Fatalf("the default is the first valid modifier, got %s", d.Default)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "inventado", Provider: "test"}); err == nil {
		t.Fatal("a modifier outside the options is refused")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "ar-rarefeito", Provider: "test"})
	run := h.dungeonView("p1").Run
	if run == nil || run.State != "active" || run.Modifier == nil || run.Modifier.ID != "ar-rarefeito" || run.Seed == 0 || len(run.Rooms) < 5 || len(run.Rooms) > 6 {
		t.Fatalf("the run is active with the chosen modifier and a seed (5 or 6 rooms), got %+v", run)
	}
	if started := h.events("dungeon-started"); len(started) != 1 || started[0].Data["modifier"] != "ar-rarefeito" {
		t.Fatalf("the start is announced, got %+v", started)
	}
}

// Without an answer the deterministic default applies at the deadline, so the dungeon never waits for the advisor.
func TestTheDefaultModifierAppliesAtTheDeadline(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.matureInBlood("p1")
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
	h.tick(6)
	run := h.dungeonView("p1").Run
	if run == nil || run.State != "active" || run.Modifier == nil || run.Modifier.ID != "em-febre" {
		t.Fatalf("the default starts the run, got %+v", run)
	}
}

// Rooms are confirmed by the game server (adapter) in order; the last one completes the run, rewards and the unique first clear.
func TestClearingTheRoomsRewardsAndTheFirstClearIsUnique(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1", "p2")
	for _, p := range []core.ID{"p1", "p2"} {
		h.matureInBlood(p)
	}
	enter := func(p core.ID) {
		h.mustAct("player", p, "entrar-masmorra", granuloma)
		h.tick(6)
	}
	enter("p1")
	if err := h.act("player", "p1", "sala-limpa", nil); err == nil {
		t.Fatal("a client cannot declare that it cleared a room")
	}
	before := h.s.Entities["p1"].Num["maturidade"]
	h.clearRun("p1")
	if run := h.dungeonView("p1").Run; run.State != "cleared" {
		t.Fatalf("clearing every room of the run clears the dungeon, got %+v", run)
	}
	if after := h.s.Entities["p1"].Num["maturidade"]; after-before != 8 {
		t.Fatalf("the reward adds maturity, got %d -> %d", before, after)
	}
	if got := h.skillIDs("p1"); !slices.Contains(got, "selo-do-granuloma") || !slices.Contains(got, "primeiro-selador") {
		t.Fatalf("the first clear is unique and also gives the seal, got %v", got)
	}
	if first := h.events("dungeon-first"); len(first) != 1 || !first[0].Public {
		t.Fatalf("the first clear enters the public chronicle, got %+v", first)
	}
	if err := h.act("adapter", "p1", "sala-limpa", nil); err == nil {
		t.Fatal("a finished run accepts no more rooms")
	}
	h.tick(7)
	enter("p2")
	h.clearRun("p2")
	got := h.skillIDs("p2")
	if !slices.Contains(got, "selo-do-granuloma") || slices.Contains(got, "primeiro-selador") {
		t.Fatalf("the second clear gets the seal but not the unique title, got %v", got)
	}
}

// Falling ends the run, and the same cell must wait before going in again.
func TestAFailedRunEndsAndHasACooldown(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.matureInBlood("p1")
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
	h.tick(6)
	h.mustAct("adapter", "p1", "sala-limpa", nil)
	h.mustAct("adapter", "p1", "falhar-masmorra", nil)
	if run := h.dungeonView("p1").Run; run.State != "failed" || run.Room != 1 {
		t.Fatalf("the run failed in the second room, got %+v", run)
	}
	if err := h.act("player", "p1", "entrar-masmorra", granuloma); err == nil {
		t.Fatal("the cell has to wait before it tries again")
	}
	h.tick(7)
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
	if err := h.act("player", "p1", "abandonar-masmorra", nil); err != nil {
		t.Fatalf("a player can give up a run: %v", err)
	}
	if run := h.dungeonView("p1").Run; run.State != "failed" {
		t.Fatalf("giving up ends the run, got %+v", run)
	}
}

// clearRun confirms every room of p's current run (the length is drawn per run).
func (h *harness) clearRun(p core.ID) {
	h.t.Helper()
	run := h.dungeonView(p).Run
	if run == nil {
		h.t.Fatal("no run to clear")
	}
	for i := 0; i < len(run.Rooms); i++ {
		h.mustAct("adapter", p, "sala-limpa", nil)
	}
}

// Procedural dungeons: the opening and the boss are fixed, the rooms between them are drawn from the pool by the seed of the run, so
// different runs differ in length, rooms and order, never repeat a room, and the same run replays the same.
func TestDungeonsAreProceduralPerRun(t *testing.T) {
	for _, tc := range []struct {
		dungeon, first, last string
		mature               func(*harness, core.ID)
	}{
		{"granuloma", "guarda-de-linfocitos", "bacilo", func(h *harness, p core.ID) { h.matureInBlood(p) }},
		{"cordoes-hepaticos", "sinusoides-vigiados", "nodulo", func(h *harness, p core.ID) { h.matureInLiver(p) }},
	} {
		h := load(t, "hospedeiro")
		seen := map[string]bool{}
		lengths := map[int]bool{}
		for i := 0; i < 10; i++ {
			p := core.ID("p" + string(rune('a'+i)))
			h.join(p)
			tc.mature(h, p)
			h.mustAct("player", p, "entrar-masmorra", map[string]core.ID{"dungeon": core.ID(tc.dungeon)})
			h.tick(6)
			run := h.dungeonView(p).Run
			ids := []string{}
			kinds := map[string]bool{}
			for _, r := range run.Rooms {
				if kinds[r.ID] {
					t.Fatalf("%s: a room repeats in %v", tc.dungeon, ids)
				}
				kinds[r.ID] = true
				ids = append(ids, r.ID)
			}
			if ids[0] != tc.first || ids[len(ids)-1] != tc.last || len(ids) < 5 || len(ids) > 6 {
				t.Fatalf("%s: a run opens with %s, closes with %s and has 5 or 6 rooms, got %v", tc.dungeon, tc.first, tc.last, ids)
			}
			seen[strings.Join(ids, ",")] = true
			lengths[len(ids)] = true
		}
		if len(seen) < 6 || len(lengths) < 2 {
			t.Fatalf("%s: ten runs should differ (%d distinct sequences, lengths %v)", tc.dungeon, len(seen), lengths)
		}
	}
}
