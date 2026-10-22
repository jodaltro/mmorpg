package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func worldDecision(h *harness) (core.Decision, bool) {
	for _, d := range h.s.Decisions {
		if d.Kind == "world" {
			return d, true
		}
	}
	return core.Decision{}, false
}

// The director keeps the world moving: it proposes eligible happenings,
// the advisor picks one (or none), and the choice is revalidated.
func TestDirectorProposesHappeningsAndAdvisorPicks(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.meet("p1", "orin")
	h.tick(10)
	d, ok := worldDecision(h)
	if !ok {
		t.Fatal("director should create a world decision at tick 10")
	}
	ids := map[string]bool{}
	for _, o := range d.Options {
		ids[o.ID] = true
	}
	if !ids["none"] || !ids["lobos"] || !ids["caravana"] {
		t.Fatalf("options %+v", d.Options)
	}
	if d.Default == "none" {
		t.Fatal("the default keeps the world lively")
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "dragon-attack"}); !isRejected(err) {
		t.Fatal("invented happenings must be rejected")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "lobos", Provider: "test"})
	if !h.fact("", "wolves", "vila", "") || len(h.events("wolves")) != 1 {
		t.Fatal("chosen happening must occur")
	}
	if holds, _ := h.believes("p1", "wolves", "vila"); !holds {
		t.Fatal("public happening must be revealed to players")
	}
	// It creates a new personal opportunity: hunting the wolves.
	if q := h.steer("p1", "cacar"); q.Giver != "orin" {
		t.Fatalf("the hunt is offered by Orin: %+v", q)
	}
	// Cooldown: wolves cannot be proposed again right away.
	h.tick(10)
	if d, ok := worldDecision(h); ok {
		for _, o := range d.Options {
			if o.ID == "lobos" {
				t.Fatal("happening on cooldown was proposed again")
			}
		}
	}
}

// Without an advisor the world still lives: the default happening occurs.
func TestDirectorDefaultsWithoutAdvisor(t *testing.T) {
	h := load(t, "valdoria")
	h.tick(60)
	n := 0
	for _, e := range h.events("decision") {
		if e.Data["kind"] == "world" && e.Data["provider"] == "default" {
			n++
		}
	}
	if n < 3 {
		t.Fatalf("expected several director defaults, got %d", n)
	}
}

// An accepted quest that the world made pointless is closed and frees the
// single active slot instead of trapping the player forever.
func TestObsoleteQuestFreesTheSlot(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.happen("caravana")
	q := h.steer("p1", "escoltar")
	h.accept("p1", q)
	// The caravan leaves before p1 escorts it: the quest no longer makes sense.
	for i := 0; i < 40; i++ {
		h.tick(1)
		if q, _ := h.quest("p1", "escoltar"); q.State != "active" {
			break
		}
	}
	if q, _ := h.quest("p1", "escoltar"); q.State != "obsolete" {
		t.Fatalf("quest should be obsolete once the caravan left: %+v", q)
	}
}

// Offers are not gated by distance: once Mira knows the player she calls
// them even while they are in the forest. Coherence comes from the situation
// and from who knows whom, not from proximity.
func TestOfferReachesPlayerAnywhereWithGiver(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.meet("p1", "mira")
	h.move("p1", "floresta")
	h.tick(6)
	q := h.steer("p1", "investigar-poco")
	if q.State != "offered" || q.Giver != "mira" || q.Region != "floresta" || q.Rank != "E" || q.Objective == "" {
		t.Fatalf("Mira should reach the player in the forest: %+v", q)
	}
	var ev core.Event
	for _, e := range h.events("quest-offered") {
		ev = e
	}
	if ev.Actor != "mira" || ev.Data["giver"] != "mira" || ev.Data["region"] != "floresta" {
		t.Fatalf("the offer event must tell the client who calls and where the player is: %+v", ev)
	}
	// Coherence: once the player already knows the cause, the offer is withdrawn.
	h.move("p1", "vila")
	h.mustAct("player", "p1", "examinar-poco", nil)
	h.tick(1)
	if q, _ := h.quest("p1", "investigar-poco"); q.State != "withdrawn" {
		t.Fatalf("an offer that no longer makes sense must be withdrawn: %+v", q)
	}
}

// One quest at a time, and in this world it must be finished.
func TestAcceptedQuestMustBeFinished(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.meet("p1", "mira")
	h.tick(6)
	q := h.steer("p1", "investigar-poco")
	h.accept("p1", q)
	if _, err := h.try(core.Command{Kind: "abandon", Origin: "player", Actor: "p1", Quest: q.Key}); !isRejected(err) {
		t.Fatal("valdoria does not allow abandoning an accepted quest")
	}
	h.tick(5)
	for _, x := range h.s.Quests {
		if x.Holder == "p1" && x.State == "offered" {
			t.Fatalf("no new proposal while a quest is active: %+v", x)
		}
	}
	h.mustAct("player", "p1", "examinar-poco", nil)
	if q, _ := h.quest("p1", "investigar-poco"); q.State != "done" {
		t.Fatalf("quest should complete: %+v", q)
	}
	h.tick(int(h.w.U.Limits.QuestGap) - 1)
	for _, x := range h.s.Quests {
		if x.Holder == "p1" && x.State == "offered" {
			t.Fatalf("the next quest waits the quiet gap: %+v", x)
		}
	}
	for _, d := range h.s.Decisions {
		if d.Subject == "p1" {
			t.Fatalf("no decision during the gap: %+v", d)
		}
	}
	h.tick(2 + int(h.w.U.Limits.DecisionTimeout))
	got := false
	for _, x := range h.s.Quests {
		got = got || x.Holder == "p1" && x.State == "offered"
	}
	if !got {
		t.Fatal("after the gap the world offers the next quest")
	}
}
