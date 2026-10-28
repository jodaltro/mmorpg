package scenarios

import (
	"fmt"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func num(k string, op string, v int64) core.Cond {
	return core.Cond{Num: &core.NumCmp{E: "a", K: k, Op: op, V: v}}
}

// miniConflict builds a world whose only crisis is measured by a.sev.
func miniConflict(t *testing.T) (*core.World, core.State) {
	t.Helper()
	u := miniUniverse(nil)
	u.Entities[0].Num = map[string]int64{"sev": 0}
	u.Conflicts = []core.ConflictDef{{
		ID: "crise", Title: "Crise", Region: "a",
		Trigger:  num("sev", ">=", 10),
		Severity: core.ConflictMetric{ID: "sev", Label: "Gravidade", E: "a", K: "sev"},
		Critical: 60, CriticalExit: 45,
		Contain: num("sev", "<=", 20),
		Resolve: core.Cond{All: []core.Cond{num("sev", "<=", 5), num("ok", ">=", 1)}},
		Sustain: 6, Recovery: 8, Cooldown: 30,
		Metrics:         []core.ConflictMetric{{ID: "ok", Label: "Estável", E: "a", K: "ok"}},
		Fronts:          []core.ConflictFront{{ID: "b", Region: "b", When: num("spread", ">=", 1)}},
		WhileRecovering: []core.Effect{{Op: "adjust", E: "a", K: "repair", D: 1}},
	}}
	u.Actions = []core.ActionDef{{ID: "ajudar", By: []string{"adapter"}, Effects: []core.Effect{{Op: "contribute", Rule: "crise", K: "reparo", D: 99}}}}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	return w, core.NewState(w)
}

func set(s core.State, k string, v int64) core.State {
	s.Entities["a"].Num[k] = v
	return s
}

func count(s core.State, kind string) int {
	n := 0
	for _, e := range s.Events {
		if e.Kind == kind {
			n++
		}
	}
	return n
}

func only(t *testing.T, s core.State) core.ConflictState {
	t.Helper()
	if len(s.Conflicts) != 1 {
		t.Fatalf("want one conflict, got %d", len(s.Conflicts))
	}
	for _, c := range s.Conflicts {
		return c
	}
	return core.ConflictState{}
}

func TestConflictOpensOnceFromMaterialCause(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, s, 20)
	if len(s.Conflicts) != 0 {
		t.Fatal("a conflict opened without its cause")
	}
	s = tickAll(t, w, set(s, "sev", 30), 80)
	c := only(t, s)
	if c.Phase != core.PhaseActive || count(s, "conflict-started") != 1 || c.Revision != 1 {
		t.Fatalf("one cause, one instance, one announcement: %+v starts=%d", c, count(s, "conflict-started"))
	}
	if !strings.HasPrefix(c.ID, "conflict:crise:a:") {
		t.Fatalf("id %q", c.ID)
	}
}

func TestConflictNeverExpiresByTime(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, set(s, "sev", 40), 1500)
	if c := only(t, s); c.Phase != core.PhaseActive || c.Revision != 1 {
		t.Fatalf("persistent cause must keep the conflict: %+v", c)
	}
}

func TestConflictCriticalHysteresis(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, set(s, "sev", 30), 2)
	s = tickAll(t, w, set(s, "sev", 70), 3)
	if only(t, s).Phase != core.PhaseCritical || count(s, "conflict-escalated") != 1 {
		t.Fatal("must escalate once")
	}
	s = tickAll(t, w, set(s, "sev", 50), 10) // between exit and critical: stays critical, no spam
	if only(t, s).Phase != core.PhaseCritical || count(s, "conflict-escalated") != 1 {
		t.Fatal("hysteresis broken")
	}
	s = tickAll(t, w, set(s, "sev", 40), 2)
	if only(t, s).Phase != core.PhaseActive {
		t.Fatal("must ease below the exit threshold")
	}
}

func TestConflictContainmentNeedsSustainAndCanReopen(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, set(s, "sev", 30), 2)
	id := only(t, s).ID
	s = tickAll(t, w, set(s, "sev", 15), 3) // 3 < sustain 6
	s = tickAll(t, w, set(s, "sev", 30), 1) // flicker resets the counter
	s = tickAll(t, w, set(s, "sev", 15), 5)
	if only(t, s).Phase != core.PhaseActive {
		t.Fatal("contained too early")
	}
	s = tickAll(t, w, s, 3)
	if c := only(t, s); c.Phase != core.PhaseContained {
		t.Fatalf("must be contained after a sustained window: %+v", c)
	}
	s = tickAll(t, w, set(s, "sev", 35), 1)
	c := only(t, s)
	if c.Phase != core.PhaseActive || c.ID != id || c.Reopened != 1 || count(s, "conflict-reopened") != 1 {
		t.Fatalf("recurrence keeps the instance: %+v", c)
	}
}

func TestConflictRecoveryDoesRealWorkThenResolves(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, set(s, "sev", 30), 2)
	s = set(set(s, "sev", 3), "ok", 1)
	s = tickAll(t, w, s, 7) // contained
	if only(t, s).Phase != core.PhaseContained {
		t.Fatal("not contained")
	}
	s = tickAll(t, w, s, 7)
	if only(t, s).Phase != core.PhaseRecovering {
		t.Fatalf("must be recovering: %+v", only(t, s))
	}
	s = tickAll(t, w, s, 3)
	if s.Entities["a"].Num["repair"] == 0 {
		t.Fatal("recovery must produce real work")
	}
	s = tickAll(t, w, set(s, "ok", 0), 1) // stability lost while recovering
	if only(t, s).Phase != core.PhaseActive {
		t.Fatal("a failed recovery reopens the conflict")
	}
	s = tickAll(t, w, set(s, "ok", 1), 40)
	c := only(t, s)
	if c.Phase != core.PhaseResolved || count(s, "conflict-resolved") != 1 {
		t.Fatalf("must resolve exactly once: %+v", c)
	}
	// Cooldown: the same cause does not reopen at once, but does later.
	s = tickAll(t, w, set(s, "sev", 30), 5)
	if len(s.Conflicts) != 1 {
		t.Fatal("reopened inside the cooldown")
	}
	s = tickAll(t, w, s, 40)
	if len(s.Conflicts) != 2 {
		t.Fatal("a new cause after the cooldown must open a new instance")
	}
}

func TestConflictFrontOpensOnceWithoutCopyingTheConflict(t *testing.T) {
	w, s := miniConflict(t)
	s = tickAll(t, w, set(s, "sev", 30), 2)
	s = tickAll(t, w, set(s, "spread", 1), 30)
	c := only(t, s)
	if len(c.Fronts) != 1 || count(s, "conflict-front-opened") != 1 {
		t.Fatalf("one front, announced once: %+v", c)
	}
}

func TestConflictContributionIsCappedDedupedAndOnlyWhileAlive(t *testing.T) {
	w, s := miniConflict(t)
	act := func(rid string) error {
		var err error
		s, _, err = w.Step(s, core.Command{Version: 1, RequestID: rid, Origin: "adapter", Kind: "act", Actor: "p0", Action: "ajudar"})
		return err
	}
	if err := act("ev1"); err == nil {
		// p0 does not exist in the mini world until it joins; both outcomes are fine,
		// what matters is that no conflict exists to credit.
		if len(s.Conflicts) != 0 {
			t.Fatal("no conflict, nothing to credit")
		}
	}
	s, _, _ = w.Step(s, core.Command{Version: 1, RequestID: "j0", Origin: "system", Kind: "join", Actor: "p0", Name: "p0"})
	s = tickAll(t, w, set(s, "sev", 30), 2)
	if err := act("ev2"); err != nil {
		t.Fatal(err)
	}
	if err := act("ev2"); err != nil { // the same evidence again: a duplicate, not an error
		t.Fatal(err)
	}
	if got := only(t, s).Credit["p0|reparo"]; got != 10 {
		t.Fatalf("credit must be capped at 10 and counted once, got %d", got)
	}
	if err := act("ev3"); err != nil {
		t.Fatal(err)
	}
	if got := only(t, s).Credit["p0|reparo"]; got != 20 {
		t.Fatalf("second evidence adds, got %d", got)
	}
	// A client may not send it.
	if _, _, err := w.Step(s, core.Command{Version: 1, RequestID: "x", Origin: "player", Kind: "act", Actor: "p0", Action: "ajudar"}); err == nil {
		t.Fatal("a player must not confirm a deed")
	}
}

func TestConflictViewIsTheSameForEveryone(t *testing.T) {
	w, s := miniConflict(t)
	for _, n := range []string{"p1", "p2"} {
		var err error
		s, _, err = w.Step(s, core.Command{Version: 1, RequestID: "j" + n, Origin: "system", Kind: "join", Actor: core.ID(n), Name: n})
		if err != nil {
			t.Fatal(err)
		}
	}
	s = tickAll(t, w, set(s, "sev", 30), 2)
	s, _, _ = w.Step(s, core.Command{Version: 1, RequestID: "d1", Origin: "adapter", Kind: "act", Actor: "p1", Action: "ajudar"})
	v1, _ := w.View(&s, "p1", 10)
	v2, _ := w.View(&s, "p2", 10)
	a, b := v1.Conflicts, v2.Conflicts
	if a == nil || len(a.Active) != 1 || b == nil || a.Focus != b.Focus || a.Active[0].ID != b.Active[0].ID || a.Active[0].Severity != b.Active[0].Severity {
		t.Fatalf("both must see the same crisis: %+v %+v", a, b)
	}
	if a.Active[0].Mine["reparo"] == 0 || len(b.Active[0].Mine) != 0 {
		t.Fatal("each sees only their own credit")
	}
}

func TestConflictReplayIsDeterministic(t *testing.T) {
	run := func() string {
		w, s := miniConflict(t)
		for i := 0; i < 200; i++ {
			switch i {
			case 3:
				s = set(s, "sev", 70)
			case 60:
				s = set(set(s, "sev", 3), "ok", 1)
			}
			s = tickAll(t, w, s, 1)
		}
		return fmt.Sprint(s.Digest(), only(t, s).Phase)
	}
	if run() != run() {
		t.Fatal("digest differs")
	}
}

func TestConflictRejectsBadDefinitions(t *testing.T) {
	base := func() core.Universe {
		u := miniUniverse(nil)
		u.Conflicts = []core.ConflictDef{{ID: "c", Title: "C", Region: "a", Trigger: num("x", ">", 0),
			Severity: core.ConflictMetric{ID: "s", Label: "S", E: "a", K: "s"}, Critical: 10, CriticalExit: 5, Sustain: 1, Recovery: 1}}
		return u
	}
	if _, err := core.Compile(base()); err != nil {
		t.Fatalf("the base must be valid: %v", err)
	}
	for name, mut := range map[string]func(*core.Universe){
		"exit>=critical": func(u *core.Universe) { u.Conflicts[0].CriticalExit = 10 },
		"no sustain":     func(u *core.Universe) { u.Conflicts[0].Sustain = 0 },
		"bad region":     func(u *core.Universe) { u.Conflicts[0].Region = "nada" },
		"bad entity":     func(u *core.Universe) { u.Conflicts[0].Severity.E = "nada" },
		"duplicate":      func(u *core.Universe) { u.Conflicts = append(u.Conflicts, u.Conflicts[0]) },
		"unknown contribute": func(u *core.Universe) {
			u.Actions = []core.ActionDef{{ID: "x", By: []string{"adapter"}, Effects: []core.Effect{{Op: "contribute", Rule: "nada", K: "k", D: 1}}}}
		},
	} {
		u := base()
		mut(&u)
		if _, err := core.Compile(u); err == nil {
			t.Errorf("%s must be rejected", name)
		}
	}
}
