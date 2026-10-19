package sim

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

func offers(s core.State) int {
	n := 0
	for _, d := range s.Decisions {
		if d.Kind == "offer" {
			n++
		}
	}
	return n
}

func world(t *testing.T) *core.World {
	w, err := universe.Load("../../universes/valdoria/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func must(t *testing.T, r *Runner, c core.Command) {
	t.Helper()
	c.Version = 1
	if _, err := r.Submit(c); err != nil {
		t.Fatalf("%+v: %v", c, err)
	}
}

func ticks(t *testing.T, r *Runner, n int) {
	t.Helper()
	for i := 0; i < n; i++ {
		if _, err := r.Tick(); err != nil {
			t.Fatal(err)
		}
	}
}

func script(t *testing.T, r *Runner, from, to int) {
	for r.Snapshot().Tick < core.Tick(to) {
		tick := int(r.Snapshot().Tick)
		if tick == 1 && from <= 1 {
			must(t, r, core.Command{RequestID: "join-p1", Origin: "adapter", Kind: "join", Actor: "p1", Name: "Ana"})
		}
		if tick == 7 && from <= 7 {
			must(t, r, core.Command{RequestID: "look-p1", Origin: "player", Kind: "act", Actor: "p1", Action: "examinar-poco"})
		}
		ticks(t, r, 1)
	}
}

// The world survives a process restart: 40 ticks, stop, reopen, 60 more
// ticks equals 100 uninterrupted ticks, byte for byte.
func TestRestartContinuesTheSameWorld(t *testing.T) {
	w := world(t)
	path := filepath.Join(t.TempDir(), "world.jsonl")
	open := func() *Runner {
		l, err := store.OpenFile(path, w.U.ID, w.Fingerprint())
		if err != nil {
			t.Fatal(err)
		}
		r, err := Open(w, l, Options{})
		if err != nil {
			t.Fatal(err)
		}
		return r
	}
	a := open()
	script(t, a, 0, 40)
	a.Close()
	b := open()
	if b.Snapshot().Tick != 40 {
		t.Fatalf("restored at tick %d", b.Snapshot().Tick)
	}
	script(t, b, 40, 100)
	got := b.Snapshot().Digest()
	b.Close()

	c, _ := Open(w, &store.Memory{}, Options{})
	script(t, c, 0, 100)
	if want := c.Snapshot().Digest(); got != want {
		t.Fatal("restarted world diverged from continuous world")
	}
	other, _ := universe.Load("../../universes/orbital/universe.json")
	if _, err := store.OpenFile(path, other.U.ID, other.Fingerprint()); err != store.ErrMismatch {
		t.Fatalf("a log must not be replayed on another universe: %v", err)
	}
}

func TestTornLastLineIsDiscarded(t *testing.T) {
	w := world(t)
	path := filepath.Join(t.TempDir(), "world.jsonl")
	l, _ := store.OpenFile(path, w.U.ID, w.Fingerprint())
	r, _ := Open(w, l, Options{})
	ticks(t, r, 5)
	r.Close()
	f, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o600)
	f.WriteString(`{"version":1,"requestId":"tick:6","ori`)
	f.Close()
	l2, err := store.OpenFile(path, w.U.ID, w.Fingerprint())
	if err != nil {
		t.Fatal(err)
	}
	r2, err := Open(w, l2, Options{})
	if err != nil || r2.Snapshot().Tick != 5 {
		t.Fatalf("tick %d err %v", r2.Snapshot().Tick, err)
	}
	ticks(t, r2, 1)
	r2.Close()
}

type slowAdvisor struct{ release chan struct{} }

func (s slowAdvisor) Decide(ctx context.Context, _ string, d core.Decision) (advisor.Answer, error) {
	select {
	case <-s.release:
		return advisor.Answer{Choice: d.Options[len(d.Options)-1].ID, Provider: "slow"}, nil
	case <-ctx.Done():
		return advisor.Answer{}, ctx.Err()
	}
}

// A slow advisor never blocks game commands; the default applies at the
// deadline and the late answer is rejected by the engine.
func TestSlowAdvisorNeverBlocksTheWorld(t *testing.T) {
	w := world(t)
	release := make(chan struct{})
	r, _ := Open(w, &store.Memory{}, Options{Advisor: slowAdvisor{release}, AdvisorTimeout: 5 * time.Second})
	must(t, r, core.Command{RequestID: "j", Origin: "adapter", Kind: "join", Actor: "p1"})
	ticks(t, r, 6)
	must(t, r, core.Command{RequestID: "look", Origin: "player", Kind: "act", Actor: "p1", Action: "examinar-poco"})
	ticks(t, r, 1)
	if offers(r.Snapshot()) == 0 {
		t.Fatal("expected a pending offer decision")
	}
	start := time.Now()
	for i := 0; i < 200; i++ {
		must(t, r, core.Command{RequestID: "spam" + string(rune(0x41+i%26)) + time.Now().Format("150405.000000000"), Origin: "player", Kind: "act", Actor: "p1", Action: "examinar-poco"})
	}
	ticks(t, r, int(w.U.Limits.DecisionTimeout))
	if el := time.Since(start); el > time.Second {
		t.Fatalf("game commands waited for the advisor: %v", el)
	}
	if offers(r.Snapshot()) != 0 {
		t.Fatalf("default should have applied: %+v", r.Snapshot().Decisions)
	}
	close(release)
	r.Drain()
	r.Close()
}

type fixedAdvisor struct{ pick func(core.Decision) string }

func (f fixedAdvisor) Decide(_ context.Context, _ string, d core.Decision) (advisor.Answer, error) {
	return advisor.Answer{Choice: f.pick(d), Provider: "fixed"}, nil
}

func TestAdvisorAnswerAppliedOrRejected(t *testing.T) {
	w := world(t)
	last := func(d core.Decision) string { return d.Options[len(d.Options)-1].ID }
	r, _ := Open(w, &store.Memory{}, Options{Advisor: fixedAdvisor{last}})
	must(t, r, core.Command{RequestID: "j", Origin: "adapter", Kind: "join", Actor: "p1"})
	ticks(t, r, 6)
	must(t, r, core.Command{RequestID: "look", Origin: "player", Kind: "act", Actor: "p1", Action: "examinar-poco"})
	ticks(t, r, 1)
	r.Drain()
	s := r.Snapshot()
	if offers(s) != 0 {
		t.Fatal("advisor answer should resolve the decision immediately")
	}
	applied := false
	for _, e := range s.Events {
		if e.Kind == "decision" && e.Data["provider"] == "fixed" {
			applied = true
		}
	}
	if !applied {
		t.Fatal("advisor decision not recorded")
	}
	r.Close()

	bad, _ := Open(w, &store.Memory{}, Options{Advisor: fixedAdvisor{func(core.Decision) string { return "hacked" }}})
	must(t, bad, core.Command{RequestID: "j", Origin: "adapter", Kind: "join", Actor: "p1"})
	ticks(t, bad, 6)
	must(t, bad, core.Command{RequestID: "look", Origin: "player", Kind: "act", Actor: "p1", Action: "examinar-poco"})
	ticks(t, bad, 1)
	bad.Drain()
	if offers(bad.Snapshot()) != 1 {
		t.Fatal("an invalid answer must leave the decision pending for the default")
	}
	ticks(t, bad, int(w.U.Limits.DecisionTimeout))
	if offers(bad.Snapshot()) != 0 {
		t.Fatal("default must apply after an invalid answer")
	}
	bad.Close()
}
