package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func pending(s core.State, kind string) []core.Decision {
	var out []core.Decision
	for _, id := range sortedDecisionIDs(s) {
		if d := s.Decisions[id]; d.Kind == kind {
			out = append(out, d)
		}
	}
	return out
}

func sortedDecisionIDs(s core.State) []string {
	ids := make([]string, 0, len(s.Decisions))
	for id := range s.Decisions {
		ids = append(ids, id)
	}
	for i := range ids {
		for j := i + 1; j < len(ids); j++ {
			if ids[j] < ids[i] {
				ids[i], ids[j] = ids[j], ids[i]
			}
		}
	}
	return ids
}

// runUntil ticks until a decision of kind is pending (or gives up).
func (h *harness) runUntil(kind string, max int) []core.Decision {
	for i := 0; i < max; i++ {
		if ds := pending(h.s, kind); len(ds) > 0 {
			return ds
		}
		h.tick(1)
	}
	return nil
}

func (h *harness) resolve(d core.Decision, choice string) error {
	_, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: choice, Provider: "test",
		Probabilities: map[string]float64{choice: 0.9}})
	return err
}

// Only a real choice becomes a question: Rubra has a single task and never asks;
// Neva, Dendra and Macra weigh two, and the budget and the quiet time bound how often.
func TestDeliberationOnlyRealChoicesAreAsked(t *testing.T) {
	h := load(t, "hospedeiro")
	asked := map[string]int{}
	maxOpen := 0
	for i := 0; i < 1200; i++ {
		h.tick(1)
		ds := pending(h.s, core.DecisionNPC)
		maxOpen = max(maxOpen, len(ds))
		for _, d := range ds {
			asked[d.Subject]++
			if d.Default == "" || len(d.Options) < 3 || d.Due <= d.Created {
				t.Fatalf("malformed decision %+v", d)
			}
		}
	}
	t.Logf("npc decisions seen by subject: %v (max open %d)", asked, maxOpen)
	if asked["rubra"] != 0 {
		t.Error("rubra has one task and no choice to make but was asked")
	}
	for _, who := range []string{"neva", "dendra", "macra"} {
		if asked[who] == 0 {
			t.Errorf("%s has two tasks to weigh and must be asked at least once", who)
		}
	}
	if maxOpen > h.w.U.Deliberation.MaxOpen {
		t.Errorf("the AI budget was exceeded: %d", maxOpen)
	}
}

// The advisor can change what an NPC does, and only within the options the
// engine built. The default, with no advisor, never blocks anyone.
func TestDeliberationAnswerChangesBehaviourAndStaleAnswersAreRefused(t *testing.T) {
	h := load(t, "hospedeiro")
	ds := h.runUntil(core.DecisionNPC, 800)
	if len(ds) == 0 {
		t.Fatal("no NPC decision ever opened")
	}
	d := ds[0]
	if st := h.s.NPCs[core.ID(d.Subject)]; st.Phase != core.NPCDeciding || st.Decision != d.ID {
		t.Fatalf("the NPC must wait for the answer: %+v", st)
	}
	if err := h.resolve(d, "task-que-nao-existe"); err == nil {
		t.Fatal("an option the engine never offered must be refused")
	}
	if err := h.resolve(d, core.WaitChoice); err != nil {
		t.Fatal(err)
	}
	st := h.s.NPCs[core.ID(d.Subject)]
	if st.Phase != core.NPCIdle || len(pending(h.s, core.DecisionNPC)) != 0 && pending(h.s, core.DecisionNPC)[0].ID == d.ID {
		t.Fatalf("waiting keeps the NPC idle and closes the question: %+v", st)
	}
	var ev *core.Event
	for i := range h.s.Events {
		if h.s.Events[i].Kind == "decision" && h.s.Events[i].Data["decision"] == d.ID {
			ev = &h.s.Events[i]
		}
	}
	if ev == nil || ev.Data["choice"] != core.WaitChoice || ev.Data["default"] == core.WaitChoice || ev.Data["probs"] == "" {
		t.Fatalf("the audit must show choice, default and distribution: %+v", ev)
	}
	// A second answer to the same question is stale.
	if err := h.resolve(d, d.Default); err == nil {
		t.Fatal("an answer to a closed question must be refused")
	}
}

// With nobody answering, the default applies and the NPC works as before.
func TestDeliberationDefaultKeepsTheWorldMoving(t *testing.T) {
	h := load(t, "hospedeiro")
	h.tick(900)
	if st := h.s.NPCs["neva"]; st.Done < 5 {
		t.Fatalf("neva must keep working on defaults: %+v", st)
	}
	for _, id := range sortedDecisionIDs(h.s) {
		if d := h.s.Decisions[id]; d.Kind == core.DecisionNPC && h.s.Tick-d.Created > 20 {
			t.Fatalf("a decision outlived its deadline: %+v", d)
		}
	}
}

// A conflict that starts asks the body how to answer; the chosen response is a
// validated effect that spends the real reserve, once, and a stale revision
// cannot be answered.
func TestConflictResponseMusterSpendsReserveOnce(t *testing.T) {
	h := load(t, "hospedeiro")
	ds := h.runUntil(core.DecisionConflict, 900)
	if len(ds) == 0 {
		t.Fatal("the infection never asked how to respond")
	}
	d := ds[0]
	if len(d.Options) != 3 || d.Default != "manter-defesa" {
		t.Fatalf("%+v", d)
	}
	setNum(h, "medula", "reserva", 50)
	before := h.s.Pops["neutrofilos_pulmao"].Count
	reserve := h.s.Entities["medula"].Num["reserva"]
	if err := h.resolve(d, "mobilizar-defesa"); err != nil {
		t.Fatal(err)
	}
	after := h.s.Pops["neutrofilos_pulmao"].Count
	if after-before != 20 || h.s.Entities["medula"].Num["reserva"] >= reserve {
		t.Fatalf("neutrophils %d -> %d, reserve %d -> %d", before, after, reserve, h.s.Entities["medula"].Num["reserva"])
	}
	if err := h.resolve(d, "mobilizar-defesa"); err == nil {
		t.Fatal("the same question cannot be answered twice")
	}
	if h.s.Pops["neutrofilos_pulmao"].Count-before > 20 {
		t.Fatal("mustered twice")
	}
	// Empty reserve: nothing appears from nowhere.
	ds = nil
	for i := 0; i < 1200 && len(ds) == 0; i++ {
		h.tick(1)
		ds = pending(h.s, core.DecisionConflict)
	}
	if len(ds) > 0 {
		setNum(h, "medula", "reserva", 0)
		c0 := h.s.Pops["macrofagos_pulmao"].Count
		if err := h.resolve(ds[0], "mobilizar-defesa"); err != nil {
			t.Fatal(err)
		}
		if h.s.Pops["macrofagos_pulmao"].Count > c0 || h.s.Entities["medula"].Num["reserva"] != 0 {
			t.Fatal("an empty reserve cannot muster")
		}
	}
}

// Answers are commands in the log: replaying them (no network) gives the same
// digest, including the audited distribution.
func TestDeliberationReplayWithAnswersKeepsDigest(t *testing.T) {
	h := load(t, "hospedeiro")
	for i := 0; i < 1500; i++ {
		h.tick(1)
		for _, k := range []string{core.DecisionNPC, core.DecisionConflict} {
			for _, d := range pending(h.s, k) {
				choice := d.Options[len(d.Options)-1].ID // never the default for NPCs
				_ = h.resolve(d, choice)
			}
		}
	}
	resolved := 0
	for _, c := range h.log {
		if c.Kind == "resolve" {
			resolved++
		}
	}
	if resolved < 3 {
		t.Fatalf("expected several answered decisions, got %d", resolved)
	}
	s := core.NewState(h.w)
	for _, c := range h.log {
		var err error
		if s, _, err = h.w.Step(s, c); err != nil {
			t.Fatal(err)
		}
	}
	if s.Digest() != h.s.Digest() {
		t.Fatal("replay digest mismatch with advisor answers")
	}
	t.Logf("%d answered decisions replayed to the same digest", resolved)
}
