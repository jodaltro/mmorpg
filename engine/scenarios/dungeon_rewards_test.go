package scenarios

import (
	"reflect"
	"slices"
	"strconv"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) expedition(p core.ID) core.ExpeditionPreview {
	return *h.dungeonView(p).Available[0].Preview
}

func TestExpeditionDraftIsStableAcrossTimeAndAbandonment(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	h.matureInBlood("p1")
	preview := h.expedition("p1")
	if len(preview.Choices) != 3 {
		t.Fatalf("want three understandable prizes, got %+v", preview)
	}
	h.tick(12)
	if got := h.expedition("p1"); !reflect.DeepEqual(got, preview) {
		t.Fatal("waiting rerolled prizes")
	}
	h.mustAct("player", "p1", "entrar-masmorra", map[string]core.ID{"dungeon": "granuloma", "briefing": "yes", "preview": core.ID(preview.Token)})
	h.tick(6)
	run := h.dungeonView("p1").Run
	if run.State != "ready" || !reflect.DeepEqual(run.Preview.Choices, preview.Choices) {
		t.Fatal("briefing did not preserve the entrance draft")
	}
	if h.act("adapter", "p1", "sala-limpa", nil) == nil {
		t.Fatal("a room cleared before the player started")
	}
	if h.act("adapter", "p1", "iniciar-masmorra", nil) == nil {
		t.Fatal("only the player starts combat")
	}
	if h.act("player", "p1", "expressar", map[string]core.ID{"gene": "invented"}) == nil {
		t.Fatal("briefing allowed reconfiguration")
	}
	h.mustAct("player", "p1", "abandonar-masmorra", nil)
	if got := h.expedition("p1"); !reflect.DeepEqual(got.Choices, preview.Choices) || got.Token != preview.Token {
		t.Fatal("abandoning rerolled prizes")
	}
}

func TestExpeditionVictoryPaysExactlyOneChosenGeneAndReplays(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	h.matureInBlood("p1")
	preview := h.expedition("p1")
	args := map[string]core.ID{"dungeon": "granuloma", "briefing": "yes", "preview": core.ID(preview.Token)}
	h.mustAct("player", "p1", "entrar-masmorra", args)
	h.tick(6)
	if h.act("player", "p1", "resgatar-masmorra", map[string]core.ID{"gene": core.ID(preview.Choices[0].ID)}) == nil {
		t.Fatal("reward before victory")
	}
	if h.act("player", "p1", "iniciar-masmorra", map[string]core.ID{"preview": "tampered"}) == nil {
		t.Fatal("stale start accepted")
	}
	h.mustAct("player", "p1", "iniciar-masmorra", map[string]core.ID{"preview": core.ID(preview.Token)})
	run := h.dungeonView("p1").Run
	for range run.Rooms {
		h.mustAct("adapter", "p1", "sala-limpa", nil)
	}
	if len(h.s.Genomes["p1"].Library) != 0 {
		t.Fatal("a gene was chosen automatically")
	}
	h.tick(7)
	if h.act("player", "p1", "entrar-masmorra", granuloma) == nil {
		t.Fatal("new run discarded an unclaimed prize")
	}
	if h.act("player", "p1", "resgatar-masmorra", map[string]core.ID{"gene": "not-offered"}) == nil {
		t.Fatal("arbitrary reward accepted")
	}
	chosen := preview.Choices[1].ID
	h.mustAct("player", "p1", "resgatar-masmorra", map[string]core.ID{"gene": core.ID(chosen)})
	if !slices.Equal(h.s.Genomes["p1"].Library, []string{chosen}) {
		t.Fatal("not exactly the chosen permanent reward")
	}
	if h.act("player", "p1", "resgatar-masmorra", map[string]core.ID{"gene": core.ID(chosen)}) == nil {
		t.Fatal("double claim")
	}
	if got := h.expedition("p1"); got.Token == preview.Token {
		t.Fatal("victory did not advance the expedition")
	}
	b := load(t, legacyDungeons)
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatal(err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("procedural rewards broke replay")
	}
}

func TestLegacyDungeonEntryDeliversRewardWithoutClaimUI(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	h.matureInBlood("p1")
	preview := h.expedition("p1")
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
	h.tick(6)
	run := h.dungeonView("p1").Run
	for range run.Rooms {
		h.mustAct("adapter", "p1", "sala-limpa", nil)
	}
	claimed := h.dungeonView("p1").Run.RewardClaimed
	if claimed != preview.Choices[0].ID || !slices.Contains(h.s.Genomes["p1"].Library, claimed) {
		t.Fatal("legacy entry left its reward pending")
	}
	h.tick(7)
	h.mustAct("player", "p1", "entrar-masmorra", granuloma)
}

func TestDraftsVaryAndNeverOfferOwnedOrIneligibleGenes(t *testing.T) {
	h := load(t, legacyDungeons)
	seen := map[string]bool{}
	for i := 0; i < 12; i++ {
		p := core.ID("p" + strconv.Itoa(i))
		h.join(p)
		draft := h.expedition(p)
		key := ""
		for _, reward := range draft.Choices {
			key += reward.ID + "|"
			if reward.Owned || reward.Name == "" || reward.Desc == "" {
				t.Fatal("unusable preview")
			}
		}
		seen[key] = true
	}
	if len(seen) < 3 {
		t.Fatalf("drafts lack variety: %d", len(seen))
	}
	h.becomeClass("p0", "mieloide", "macrofago")
	draft := h.expedition("p0")
	if draft.Choices[0].ID != "fagossomo-profundo" {
		t.Fatalf("specialty slot does not match the class: %+v", draft)
	}
	h.s.Genomes["p0"] = core.Genome{Library: []string{draft.Choices[0].ID}}
	for _, reward := range h.expedition("p0").Choices {
		if reward.ID == draft.Choices[0].ID {
			t.Fatal("owned gene offered")
		}
	}
}

func TestRewardViewsDescribeQuestEffectsWithoutChangingState(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	before := h.s.Digest()
	v, _ := h.w.View(&h.s, "p1", 0)
	found := false
	for _, view := range v.Quests {
		if view.Key == q.Key {
			for _, r := range view.RewardDetails {
				found = found || r.Kind == "gene" && r.ID == "nucleo-reativo" && r.Desc != ""
			}
		}
	}
	if !found || before != h.s.Digest() {
		t.Fatal("reward preview missing or mutated the log state")
	}
	u := h.w.U
	u.Dungeons = slices.Clone(u.Dungeons)
	u.Dungeons[0].RewardPools = []core.RewardPool{{Genes: []string{"invented"}, Take: 1}}
	if _, err := core.Compile(u); err == nil {
		t.Fatal("unknown procedural reward compiled")
	}
}
