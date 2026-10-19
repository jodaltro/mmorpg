package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// Two players pursue the same unique scenario in parallel. Only the first
// claims it; the other is not erased: they witnessed something and get a
// different personal continuation. The world story then branches.
func TestUniqueScenarioOnlyOneAdvancesTheStory(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.tick(6)
	for _, p := range []core.ID{"p1", "p2"} {
		h.mustAct("player", p, "examinar-poco", nil)
	}
	h.tick(1)
	q1 := h.steer("p1", "cenario-origem")
	q2 := h.steer("p2", "cenario-origem")
	h.accept("p1", q1)
	h.accept("p2", q2)

	h.mustAct("adapter", "p1", "seguir-rastro", nil)
	if q, _ := h.quest("p1", "cenario-origem"); q.State != "done" {
		t.Fatalf("p1 should have claimed: %+v", q)
	}
	if q, _ := h.quest("p2", "cenario-origem"); q.State != "superseded" {
		t.Fatalf("p2 should be superseded: %+v", q)
	}
	arc := h.s.Arcs["maldicao"]
	if b := arc.Beats["origem"]; b.State != "claimed" || len(b.By) != 1 || b.By[0] != "p1" {
		t.Fatalf("beat must be claimed by p1 only: %+v", b)
	}
	if !h.fact("p2", "witnessed", "p2", "selo") {
		t.Fatal("the rival must receive an alternative continuation")
	}
	if h.s.Entities["p1"].Tag["title"] != "Descobridor do Selo" {
		t.Fatal("claimant title missing")
	}
	// p2 still reaches the seal in the game, but the chapter is already history.
	h.mustAct("adapter", "p2", "seguir-rastro", nil)
	if b := h.s.Arcs["maldicao"].Beats["origem"]; len(b.By) != 1 {
		t.Fatalf("a unique beat can never be claimed twice: %+v", b)
	}
	// The story must branch: restore or pact. Nobody waits for the advisor.
	if !arc.Choosing {
		t.Fatalf("arc should be choosing its next chapter: %+v", arc)
	}
	story := h.s.Decisions["story:maldicao:origem"]
	if len(story.Options) != 2 {
		t.Fatalf("story options: %+v", story)
	}
	h.tick(int(h.w.U.Limits.DecisionTimeout))
	arc = h.s.Arcs["maldicao"]
	if arc.Choosing || arc.Current == "origem" {
		t.Fatalf("default must apply at the deadline: %+v", arc)
	}
	// p2 can reach the witness quest that only rivals get: declining other
	// offers makes room for it.
	found := false
	for i := 0; i < 8 && !found; i++ {
		h.tick(1 + int(h.w.U.Limits.DecisionTimeout))
		for _, q := range h.s.Quests {
			if q.Holder != "p2" || q.State != "offered" {
				continue
			}
			if q.Def == "testemunha" {
				found = true
			} else {
				h.do(core.Command{Kind: "decline", Origin: "player", Actor: "p2", Quest: q.Key})
			}
		}
	}
	if !found {
		t.Fatalf("p2 should be offered the witness continuation: %+v", h.s.Quests)
	}
	if _, ok := h.quest("p1", "testemunha"); ok {
		t.Fatal("the claimant must not get the rival continuation")
	}
}

// The advisor (Jev) chooses the branch; the choice is revalidated.
func TestAdvisorChoosesStoryBranchAndIsRevalidated(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tick(6)
	h.mustAct("player", "p1", "examinar-poco", nil)
	h.tick(1)
	q := h.steer("p1", "cenario-origem")
	h.accept("p1", q)
	h.mustAct("adapter", "p1", "seguir-rastro", nil)
	id := "story:maldicao:origem"
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: id, Choice: "invented-ending"}); !isRejected(err) {
		t.Fatalf("an option outside the list must be rejected, got %v", err)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "player", Decision: id, Choice: "pacto"}); !isRejected(err) {
		t.Fatal("players cannot resolve advisor decisions")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: id, Choice: "pacto", Provider: "TypeSafe", Model: "typesafe/jev-1.13"})
	if a := h.s.Arcs["maldicao"]; a.Current != "pacto" || a.Choosing {
		t.Fatalf("advisor choice not applied: %+v", a)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: id, Choice: "restaurar"}); !isRejected(err) {
		t.Fatal("a late answer must not change the story again")
	}
	// The dark branch: the pact is a unique scenario too.
	h.tick(1)
	h.mustAct("player", "p1", "examinar-poco", nil)
	if a := h.s.Arcs["maldicao"]; a.Beats["pacto"].State != "open" {
		t.Fatalf("pact should open: %+v", a)
	}
}

// Different players get different quests from the same templates.
func TestQuestsDifferPerPlayer(t *testing.T) {
	h := load(t, "valdoria")
	ps := []core.ID{"a1", "a2", "a3", "a4", "a5", "a6"}
	h.join(ps...)
	h.tick(6)
	for _, p := range ps {
		h.mustAct("player", p, "examinar-poco", nil)
	}
	h.tick(1 + int(h.w.U.Limits.DecisionTimeout))
	seen := map[string]bool{}
	for _, p := range ps {
		for _, q := range h.s.Quests {
			if q.Holder == p && q.State == "offered" {
				seen[q.Title] = true
			}
		}
	}
	if len(seen) < 2 {
		t.Fatalf("expected varied offers, got %v", seen)
	}
}
