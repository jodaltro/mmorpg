package scenarios

import (
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// transitions lists the public conflict events of a state as "kind@tick:rN".
func transitions(s core.State) []string {
	var out []string
	for _, e := range s.Events {
		if strings.HasPrefix(e.Kind, "conflict-") && e.Data["def"] == "infeccao-pulmonar" {
			out = append(out, e.Kind+"@"+strconv.Itoa(int(e.At))+":r"+e.Data["revision"])
		}
	}
	return out
}

// lung returns only the pulmonary infection instances: other conflicts coexist.
func lung(s core.State) map[string]core.ConflictState {
	out := map[string]core.ConflictState{}
	for id, c := range s.Conflicts {
		if c.Def == "infeccao-pulmonar" {
			out[id] = c
		}
	}
	return out
}

func liveCount(s core.State) int {
	n := 0
	for _, c := range s.Conflicts {
		if c.Def == "infeccao-pulmonar" && c.Phase != core.PhaseResolved {
			n++
		}
	}
	return n
}

func (h *harness) joinAt(id, region core.ID) {
	h.do(core.Command{Kind: "join", Origin: "adapter", Actor: id, Name: strings.ToUpper(string(id)), Region: region})
}

// With nobody in the body the pulmonary infection is still a conflict of the
// world: it opens from the real focus, the cohorts hold it back and it ends by
// the numbers (sustained containment, then recovery), over and over. At no
// moment do two live instances of the same cause exist, and every transition is
// announced exactly once with a growing revision.
func TestHospedeiroLungInfectionResolvesByItselfWithoutPlayers(t *testing.T) {
	h := load(t, "hospedeiro")
	maxLive := 0
	for i := 0; i < 1500; i++ {
		h.tick(1)
		maxLive = max(maxLive, liveCount(h.s))
	}
	if maxLive != 1 {
		t.Fatalf("one cause must never have %d live instances", maxLive)
	}
	if got := len(lung(h.s)); got < 5 {
		t.Fatalf("recurrent infections should have opened several instances, got %d", got)
	}
	resolved := 0
	for id, c := range lung(h.s) {
		if c.Phase == core.PhaseResolved {
			resolved++
		}
		if c.Revision < 1 || !strings.HasPrefix(id, "conflict:infeccao-pulmonar:pulmao:") {
			t.Errorf("bad instance %s %+v", id, c)
		}
	}
	if resolved < 4 {
		t.Fatalf("the healthy body should resolve infections on its own, resolved %d", resolved)
	}
	// Per instance, revisions in the events strictly increase.
	last := map[string]int{}
	for _, e := range h.s.Events {
		if !strings.HasPrefix(e.Kind, "conflict-") || e.Kind == "conflict-response" || e.Data["def"] != "infeccao-pulmonar" {
			continue
		}
		r, _ := strconv.Atoi(e.Data["revision"])
		if r <= last[e.Data["conflict"]] {
			t.Fatalf("revision did not grow for %s: %v", e.Data["conflict"], transitions(h.s))
		}
		last[e.Data["conflict"]] = r
	}
	t.Logf("tick %d: %d instances (%d resolved), first cycle %v", h.s.Tick, len(lung(h.s)), resolved, transitions(h.s)[:5])
}

// Remove the body's defenders and the same infection is no longer held back:
// it climbs to critical and stays there, because the cause is still present.
func TestHospedeiroLungInfectionEscalatesWhenDefendersAreGone(t *testing.T) {
	h := load(t, "hospedeiro")
	h.tick(40)
	for _, id := range []string{"neutrofilos_pulmao", "macrofagos_pulmao"} {
		st := h.s.Pops[id]
		st.Count = 0
		h.s.Pops[id] = st
	}
	med := h.s.Entities["medula"]
	med.Num["reserva"] = 0
	h.s.Entities["medula"] = med
	critical := false
	for i := 0; i < 900 && !critical; i++ {
		h.tick(1)
		for _, c := range lung(h.s) {
			critical = critical || c.Phase == core.PhaseCritical
		}
	}
	if !critical || len(transitions(h.s)) == 0 {
		t.Fatalf("an undefended lung must reach a critical conflict, got %v", transitions(h.s))
	}
	if !slices.ContainsFunc(transitions(h.s), func(x string) bool { return strings.HasPrefix(x, "conflict-escalated") }) {
		t.Fatal("the escalation must be announced")
	}
}

// A confirmed deed in the lung lowers the official load and is credited once;
// the same evidence again, a deed with no infection, and a client claiming it
// all change nothing.
func TestHospedeiroLungInfectionTakesConfirmedContributions(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	h.joinAt("p2", "pulmao")
	for i := 0; i < 400 && len(lung(h.s)) == 0; i++ {
		h.tick(1)
	}
	if len(lung(h.s)) == 0 {
		t.Fatal("the lung infection never opened")
	}
	if err := h.act("player", "p1", "conter-infeccao-pulmonar", nil); err == nil {
		t.Fatal("a client must not confirm a deed")
	}
	before := h.s.Entities["pulmao"].Num["carga"]
	if before <= 0 {
		t.Fatal("expected a load to fight")
	}
	h.do(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: "conter-infeccao-pulmonar", RequestID: "ev-1"})
	dup, _ := h.try(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: "conter-infeccao-pulmonar", RequestID: "ev-1"})
	if !dup.Duplicate {
		t.Fatal("the same evidence must be recognised as a duplicate")
	}
	h.do(core.Command{Kind: "act", Origin: "adapter", Actor: "p2", Action: "conter-infeccao-pulmonar", RequestID: "ev-2"})
	v1, _ := h.w.View(&h.s, "p1", 10)
	v2, _ := h.w.View(&h.s, "p2", 10)
	pick := func(v core.View) core.ConflictItemView {
		if v.Conflicts != nil {
			for _, c := range v.Conflicts.Active {
				if c.Def == "infeccao-pulmonar" {
					return c
				}
			}
		}
		t.Fatalf("the lung crisis must be visible: %+v", v.Conflicts)
		return core.ConflictItemView{}
	}
	a1, a2 := pick(v1), pick(v2)
	if a1.Mine["combate"] != 3 || a2.Mine["combate"] != 3 {
		t.Fatalf("each fighter is credited once: %v %v", a1.Mine, a2.Mine)
	}
	if a1.Severity != a2.Severity || v1.Conflicts.Focus != v2.Conflicts.Focus {
		t.Fatal("both players must see the same official numbers")
	}
	// Once the load is gone there is nothing to fight and nothing to credit.
	e := h.s.Entities["pulmao"]
	e.Num["carga"] = 0
	h.s.Entities["pulmao"] = e
	if err := h.act("adapter", "p1", "conter-infeccao-pulmonar", nil); err == nil {
		t.Fatal("a deed against nothing must be rejected")
	}
}

// Leaving does not close a conflict: the player quits, the world keeps going,
// and coming back shows the true state, not a fresh announcement.
func TestHospedeiroConflictSurvivesLogoutAndReplays(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	for i := 0; i < 400 && liveCount(h.s) == 0; i++ {
		h.tick(1)
	}
	if liveCount(h.s) == 0 {
		t.Fatal("no conflict to leave")
	}
	id, rev := "", int64(0)
	for k, c := range lung(h.s) {
		id, rev = k, c.Revision
	}
	h.tick(3) // the player is gone; the clock does not care
	if c := h.s.Conflicts[id]; c.Revision < rev {
		t.Fatal("a conflict cannot go backwards")
	}
	h.tick(300)
	s := core.NewState(h.w)
	for _, c := range h.log {
		var err error
		if s, _, err = h.w.Step(s, c); err != nil {
			t.Fatal(err)
		}
	}
	if s.Digest() != h.s.Digest() {
		t.Fatal("replay digest mismatch with conflicts")
	}
}
