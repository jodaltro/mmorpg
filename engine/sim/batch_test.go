package sim

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

// fakeBatch answers batchable decisions together, picks the last option (never
// the default), and can fail some questions or the whole call.
type fakeBatch struct {
	mu       sync.Mutex
	batches  [][]string
	singles  int
	failOdd  bool
	failCall bool
	delay    time.Duration
	cost     float64
}

func (f *fakeBatch) Decide(_ context.Context, _ string, d core.Decision) (advisor.Answer, error) {
	f.mu.Lock()
	f.singles++
	f.mu.Unlock()
	return advisor.Answer{Choice: d.Default, Provider: "fake", Model: "fake"}, nil
}

func (f *fakeBatch) DecideBatch(_ context.Context, _ string, _ string, ds []core.Decision) []advisor.BatchResult {
	time.Sleep(f.delay)
	ids := []string{}
	out := make([]advisor.BatchResult, len(ds))
	for i, d := range ds {
		ids = append(ids, d.ID)
		out[i] = advisor.BatchResult{Decision: d.ID, Answer: advisor.Answer{Choice: d.Options[len(d.Options)-1].ID, Provider: "fake", Model: "fake", LatencyMS: 5, Cost: costPtr(f.cost),
			Probabilities: map[string]float64{d.Options[len(d.Options)-1].ID: 0.9}}}
		if f.failCall || f.failOdd && i%2 == 1 {
			out[i].Err = errors.New("fail")
		}
	}
	f.mu.Lock()
	f.batches = append(f.batches, ids)
	f.mu.Unlock()
	return out
}

func hospedeiroRunner(t *testing.T, adv advisor.Advisor, window ...time.Duration) *Runner {
	t.Helper()
	w, err := universe.Load("../../universes/hospedeiro/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	r, err := Open(w, &store.Memory{}, Options{Advisor: adv, AdvisorTimeout: 2 * time.Second, BatchWindow: append(window, 0)[0]})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}

func run(t *testing.T, r *Runner, n int) {
	for i := 0; i < n; i++ {
		ticks(t, r, 1)
		time.Sleep(time.Millisecond) // let answers land between ticks
	}
	r.Drain()
}

// Decisions of the cognitive scheduler travel together: fewer calls than
// questions whenever several are open at once, and every answer is validated.
func TestRunnerSendsCognitiveDecisionsInBatches(t *testing.T) {
	f := &fakeBatch{}
	r := hospedeiroRunner(t, f)
	run(t, r, 900)
	st := r.Stats()
	if st.Questions == 0 || st.Applied == 0 {
		t.Fatalf("nothing was asked or applied: %+v", st)
	}
	if st.Failed != 0 || st.Applied+st.Rejected != st.Questions {
		t.Fatalf("every question must end applied or refused: %+v", st)
	}
	if st.Changed == 0 {
		t.Fatalf("an advisor that never differs from the default changes nothing: %+v", st)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.singles != 0 && len(f.batches) == 0 {
		t.Fatal("npc/conflict questions must use the batch path")
	}
	t.Logf("stats %+v batches=%d", st, len(f.batches))
}

// A failed question falls to the default; a failed call too; the world never waits.
func TestRunnerFallsBackPerQuestionAndPerCall(t *testing.T) {
	for name, f := range map[string]*fakeBatch{"odd questions fail": {failOdd: true}, "whole call fails": {failCall: true}} {
		r := hospedeiroRunner(t, f)
		run(t, r, 700)
		st := r.Stats()
		f.mu.Lock()
		asked := 0
		for _, b := range f.batches {
			asked += len(b)
		}
		f.mu.Unlock()
		if name == "whole call fails" && (asked == 0 || st.Failed < int64(asked)) {
			t.Errorf("%s: asked %d, %+v", name, asked, st)
		}
		if r.Snapshot().NPCs["neva"].Done == 0 {
			t.Errorf("%s: neva must keep working on the defaults", name)
		}
		for _, d := range r.Snapshot().Decisions {
			if (d.Kind == core.DecisionNPC || d.Kind == core.DecisionConflict) && r.Snapshot().Tick-d.Created > 20 {
				t.Errorf("%s: stuck decision %s", name, d.ID)
			}
		}
	}
}

// An advisor slower than the deadline is simply ignored: the answer arrives
// after the default applied, the engine refuses it and the world is intact.
func TestRunnerLateBatchAnswerIsRefused(t *testing.T) {
	f := &fakeBatch{delay: 600 * time.Millisecond}
	r := hospedeiroRunner(t, f)
	started := time.Now()
	ticks(t, r, 400)
	if time.Since(started) > 5*time.Second {
		t.Fatal("ticks must not wait for the advisor")
	}
	r.Drain()
	if st := r.Stats(); st.Questions > 0 && st.Applied+st.Rejected == 0 {
		t.Fatalf("late answers must be counted and refused, not lost: %+v", st)
	}
}

// With a window, questions created in nearby ticks share a request.
func TestRunnerBatchWindowCoalescesQuestions(t *testing.T) {
	f := &fakeBatch{}
	r := hospedeiroRunner(t, f, 40*time.Millisecond)
	for i := 0; i < 700; i++ {
		ticks(t, r, 1)
		if i%25 == 0 {
			time.Sleep(60 * time.Millisecond)
		}
	}
	r.Drain()
	time.Sleep(100 * time.Millisecond)
	f.mu.Lock()
	defer f.mu.Unlock()
	most, total := 0, 0
	for _, b := range f.batches {
		most = max(most, len(b))
		total += len(b)
	}
	if total == 0 || most < 2 || len(f.batches) >= total {
		t.Fatalf("a window must coalesce: %d batches carrying %d questions (largest %d)", len(f.batches), total, most)
	}
}

func costPtr(c float64) *float64 {
	if c == 0 {
		return nil
	}
	return &c
}

func runnerWith(t *testing.T, adv advisor.Advisor, mod func(*Options)) *Runner {
	t.Helper()
	w := uncapped(t)
	opt := Options{Advisor: adv, AdvisorTimeout: 2 * time.Second}
	mod(&opt)
	r, err := Open(w, &store.Memory{}, opt)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}

func asked(f *fakeBatch) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, b := range f.batches {
		n += len(b)
	}
	return n
}

// The question cap holds inside its minute: the rest are skipped, counted, and
// the defaults carry the world. A minute later the advisor is asked again.
func TestRunnerQuestionCapSkipsAndRecovers(t *testing.T) {
	f := &fakeBatch{}
	clock := time.Unix(1_000_000, 0)
	r := runnerWith(t, f, func(o *Options) {
		o.MaxQuestionsPerMinute = 4
		o.Now = func() time.Time { return clock }
	})
	run(t, r, 700)
	st := r.Stats()
	if st.Questions != 4 {
		t.Fatalf("the cap is 4 questions per minute (of any kind) and the clock did not move: asked %d", st.Questions)
	}
	if st.Skipped == 0 {
		t.Fatalf("over-cap questions must be counted as skipped: %+v", st)
	}
	if r.Snapshot().NPCs["neva"].Done == 0 {
		t.Fatal("the defaults must carry the world while the advisor is capped")
	}
	clock = clock.Add(61 * time.Second)
	run(t, r, 300)
	if got := r.Stats().Questions; got <= 4 || got > 8 {
		t.Fatalf("a new minute allows 4 more, asked %d in total", got)
	}
}

// The cost cap closes the tap once the provider-reported spend reaches it.
func TestRunnerCostCapStopsAsking(t *testing.T) {
	f := &fakeBatch{cost: 0.01}
	clock := time.Unix(2_000_000, 0)
	r := runnerWith(t, f, func(o *Options) {
		o.MaxCostPerHour = 0.05
		o.Now = func() time.Time { return clock }
	})
	run(t, r, 1200)
	got := asked(f)
	if got < 5 {
		t.Fatalf("the cap should allow about five paid answers before closing, asked %d", got)
	}
	if got > 5+8 { // answers in flight when the cap closes may still land
		t.Fatalf("the cost cap did not close: asked %d at 0.01 each against 0.05", got)
	}
	if r.Stats().Skipped == 0 {
		t.Fatal("after the cap the questions must be skipped")
	}
}

// Several crises make the macro question exist, and it travels in a batch kind
// of its own before the conflict and NPC questions.
func TestRunnerSendsAttentionQuestions(t *testing.T) {
	f := &fakeBatch{}
	r := runnerWith(t, f, func(o *Options) { o.BatchWindow = 20 * time.Millisecond })
	run(t, r, 2500)
	st := r.Stats()
	if st.ByKind[core.DecisionAttention].Asked == 0 {
		t.Fatalf("with five crises cycling the body must have asked where to concentrate: %+v", st.ByKind)
	}
	if st.ByKind[core.DecisionAttention].Applied == 0 {
		t.Fatalf("attention answers must be applied: %+v", st.ByKind[core.DecisionAttention])
	}
	t.Logf("by kind: %+v batches=%d", st.ByKind, st.Batches)
}

// uncapped is the Hospedeiro with several crises free to be alive at once: the
// advisor's macro question (where to concentrate) only exists then.
func uncapped(t *testing.T) *core.World {
	t.Helper()
	data, err := os.ReadFile("../../universes/hospedeiro/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	var u core.Universe
	if err := json.NewDecoder(bytes.NewReader(bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf}))).Decode(&u); err != nil {
		t.Fatal(err)
	}
	u.Limits.MaxLiveConflicts, u.Limits.LiveConflictPatience = 0, 0
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	return w
}
