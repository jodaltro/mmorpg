// Package sim runs a world over time: it owns the authoritative state,
// persists every accepted command, advances ticks on a clock, and sends
// decisions to an advisor in the background.
//
// The lock is held only while core.Step runs (microseconds). Advisor calls
// happen outside it, so a game server submitting combat occurrences never
// waits for Jev.
package sim

import (
	"context"
	"errors"
	"maps"
	"strconv"
	"sync"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/store"
)

type Options struct {
	Advisor        advisor.Advisor
	AdvisorTimeout time.Duration
	// BatchWindow holds cognitive decisions (NPC choices, conflict responses)
	// for this long so those created in nearby ticks travel in one request.
	// Zero sends at once. The deadline of each decision does not move, so a
	// window longer than the decision timeout only wastes the question.
	BatchWindow time.Duration
}

type Runner struct {
	mu       sync.Mutex
	w        *core.World
	s        core.State
	log      store.Log
	opt      Options
	inflight map[string]bool
	wg       sync.WaitGroup
	subMu    sync.Mutex
	subs     map[int]chan core.Delta
	nextSub  int
	closed   bool
	stats    Stats
	queue    []queued
	flushing bool
	gen      int // bumped by Reset; advisor answers of an older world are dropped
}

// Open rebuilds the world by replaying the log, then dispatches decisions
// that were still pending when the process stopped.
func Open(w *core.World, log store.Log, opt Options) (*Runner, error) {
	if opt.AdvisorTimeout <= 0 {
		opt.AdvisorTimeout = 8 * time.Second
	}
	r := &Runner{w: w, s: core.NewState(w), log: log, opt: opt, inflight: map[string]bool{}, subs: map[int]chan core.Delta{}}
	cmds, err := log.Load()
	if err != nil {
		return nil, err
	}
	for i, c := range cmds {
		s, _, err := w.Step(r.s, c)
		if err != nil {
			return nil, errors.New("replay failed at entry " + strconv.Itoa(i+1) + ": " + err.Error())
		}
		r.s = s
	}
	pending := []core.Decision{}
	for _, d := range r.s.Decisions {
		pending = append(pending, d)
	}
	r.dispatch(pending)
	return r, nil
}

func (r *Runner) World() *core.World { return r.w }

// Snapshot returns the current state. States are never mutated after being
// published (Step copies), so callers may read it without locking.
func (r *Runner) Snapshot() core.State {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.s
}

// Submit applies a command: validate, persist, publish. Nothing is
// published unless it was durably appended to the log first.
func (r *Runner) Submit(c core.Command) (core.Delta, error) { return r.submit(c, -1) }

var errStale = errors.New("stale_world")

// submit applies c; gen >= 0 means "only if the world was not reset since".
func (r *Runner) submit(c core.Command, gen int) (core.Delta, error) {
	r.mu.Lock()
	if r.closed {
		r.mu.Unlock()
		return core.Delta{}, errors.New("runner_closed")
	}
	if gen >= 0 && gen != r.gen {
		r.mu.Unlock()
		return core.Delta{}, errStale
	}
	next, d, err := r.w.Step(r.s, c)
	if err == nil && !d.Duplicate {
		if err = r.log.Append(c); err == nil {
			r.s = next
		}
	}
	r.mu.Unlock()
	if err != nil {
		return core.Delta{}, err
	}
	if !d.Duplicate {
		r.publish(d)
		r.dispatch(d.Decisions)
	}
	return d, nil
}

// Tick advances world time by one tick.
func (r *Runner) Tick() (core.Delta, error) {
	r.mu.Lock()
	next := int64(r.s.Tick) + 1
	r.mu.Unlock()
	return r.Submit(core.Command{Version: 1, RequestID: "tick:" + strconv.FormatInt(next, 10), Origin: "system", Kind: "tick"})
}

// Run ticks on a wall clock until ctx ends. The world lives whether or not
// anyone is connected.
func (r *Runner) Run(ctx context.Context, every time.Duration) error {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			if _, err := r.Tick(); err != nil {
				return err
			}
		}
	}
}

// Stats counts what the advisor did, so the value of asking can be measured:
// an answer that equals the default changed nothing.
type Stats struct {
	Questions int64   // decisions sent
	Batches   int64   // requests carrying more than one question
	Calls     int64   // provider requests of any size
	Failed    int64   // questions that got no usable answer (the default applies)
	Applied   int64   // answers the engine accepted
	Rejected  int64   // answers the engine refused (stale or invalid)
	Changed   int64   // accepted answers that differ from the default
	LatencyMS int64   // sum over calls
	Cost      float64 // sum of reported cost
	// ByKind splits the same counters by decision kind (npc, conflict, world...).
	ByKind map[string]KindStats
}

// KindStats are the per-kind counters.
type KindStats struct{ Asked, Failed, Applied, Rejected, Changed int64 }

// kind updates one kind's counters; callers hold r.mu.
func (r *Runner) kind(k string, f func(*KindStats)) {
	if r.stats.ByKind == nil {
		r.stats.ByKind = map[string]KindStats{}
	}
	x := r.stats.ByKind[k]
	f(&x)
	r.stats.ByKind[k] = x
}

// Stats returns a copy of the counters.
func (r *Runner) Stats() Stats {
	r.mu.Lock()
	defer r.mu.Unlock()
	c := r.stats
	c.ByKind = maps.Clone(r.stats.ByKind)
	return c
}

// batchable kinds are the cognitive scheduler's: NPC choices and conflict
// responses. They are grouped by kind and sent together in one request.
func batchable(kind string) bool { return kind == core.DecisionNPC || kind == core.DecisionConflict }

func (r *Runner) claim(d core.Decision) (gen int, ok bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.inflight[d.ID] || r.closed {
		return 0, false
	}
	r.inflight[d.ID] = true
	r.wg.Add(1)
	return r.gen, true
}

func (r *Runner) release(d core.Decision, gen int) {
	r.mu.Lock()
	if gen == r.gen {
		delete(r.inflight, d.ID)
	}
	r.mu.Unlock()
}

// apply submits one answer. A late or stale one is rejected by the engine.
func (r *Runner) apply(d core.Decision, a advisor.Answer, gen int) {
	_, err := r.submit(core.Command{Version: 1, RequestID: "resolve:" + d.ID, Origin: "advisor", Kind: "resolve",
		Decision: d.ID, Choice: a.Choice, Provider: a.Provider, Model: a.Model, Call: a.Call,
		Confidence: a.Confidence, LatencyMS: a.LatencyMS, Cost: a.Cost, Probabilities: a.Probabilities}, gen)
	r.mu.Lock()
	if err != nil {
		r.stats.Rejected++
		r.kind(d.Kind, func(k *KindStats) { k.Rejected++ })
	} else {
		r.stats.Applied++
		changed := a.Choice != d.Default
		if changed {
			r.stats.Changed++
		}
		r.kind(d.Kind, func(k *KindStats) {
			k.Applied++
			if changed {
				k.Changed++
			}
		})
	}
	r.mu.Unlock()
}

type queued struct {
	d   core.Decision
	gen int
}

func (r *Runner) dispatch(ds []core.Decision) {
	if r.opt.Advisor == nil {
		return
	}
	_, canBatch := r.opt.Advisor.(advisor.BatchAdvisor)
	for _, d := range ds {
		gen, ok := r.claim(d)
		if !ok {
			continue
		}
		if canBatch && batchable(d.Kind) {
			r.mu.Lock()
			r.queue = append(r.queue, queued{d, gen})
			arm := !r.flushing
			r.flushing = true
			r.mu.Unlock()
			if arm {
				if r.opt.BatchWindow > 0 {
					time.AfterFunc(r.opt.BatchWindow, r.flush)
				} else {
					r.flush()
				}
			}
			continue
		}
		go func(d core.Decision) {
			defer r.wg.Done()
			ctx, cancel := context.WithTimeout(context.Background(), r.opt.AdvisorTimeout)
			a, err := r.opt.Advisor.Decide(ctx, r.w.U.ID, d)
			cancel()
			r.release(d, gen)
			r.mu.Lock()
			r.stats.Questions++
			r.stats.Calls++
			r.kind(d.Kind, func(k *KindStats) { k.Asked++ })
			if err != nil {
				r.stats.Failed++
				r.kind(d.Kind, func(k *KindStats) { k.Failed++ })
			} else {
				r.stats.LatencyMS += a.LatencyMS
				if a.Cost != nil {
					r.stats.Cost += *a.Cost
				}
			}
			r.mu.Unlock()
			if err != nil {
				return // the deterministic default applies at the deadline
			}
			r.apply(d, a, gen)
		}(d)
	}
}

// flush sends what the window collected: one request per kind and per
// MaxBatch questions.
func (r *Runner) flush() {
	r.mu.Lock()
	q := r.queue
	r.queue, r.flushing = nil, false
	r.mu.Unlock()
	b, _ := r.opt.Advisor.(advisor.BatchAdvisor)
	for _, kind := range []string{core.DecisionConflict, core.DecisionNPC} {
		var same []queued
		for _, x := range q {
			if x.d.Kind == kind {
				same = append(same, x)
			}
		}
		for len(same) > 0 {
			n := min(len(same), advisor.MaxBatch)
			r.sendBatch(b, kind, same[:n])
			same = same[n:]
		}
	}
}

func (r *Runner) sendBatch(b advisor.BatchAdvisor, kind string, mine []queued) {
	go func() {
		list := make([]core.Decision, len(mine))
		for i, c := range mine {
			list[i] = c.d
		}
		ctx, cancel := context.WithTimeout(context.Background(), r.opt.AdvisorTimeout)
		res := b.DecideBatch(ctx, r.w.U.ID, kind, list)
		cancel()
		r.mu.Lock()
		r.stats.Calls++
		if len(list) > 1 {
			r.stats.Batches++
		}
		r.stats.Questions += int64(len(list))
		for _, c := range mine {
			r.kind(c.d.Kind, func(k *KindStats) { k.Asked++ })
		}
		if len(res) > 0 && res[0].Err == nil {
			r.stats.LatencyMS += res[0].Answer.LatencyMS
		}
		for i, x := range res {
			if x.Err != nil {
				r.stats.Failed++
				if i < len(mine) {
					r.kind(mine[i].d.Kind, func(k *KindStats) { k.Failed++ })
				}
			} else if x.Answer.Cost != nil {
				r.stats.Cost += *x.Answer.Cost
			}
		}
		r.mu.Unlock()
		for i, c := range mine {
			r.release(c.d, c.gen)
			if i < len(res) && res[i].Err == nil && res[i].Decision == c.d.ID {
				r.apply(c.d, res[i].Answer, c.gen)
			} else if i >= len(res) || res[i].Err == nil {
				r.mu.Lock()
				r.stats.Failed++ // no result for this question
				r.kind(c.d.Kind, func(k *KindStats) { k.Failed++ })
				r.mu.Unlock()
			}
			r.wg.Done()
		}
	}()
}

// Subscribe receives every applied delta. Slow subscribers drop deltas
// rather than slowing the world; clients resync from a View.
func (r *Runner) Subscribe() (<-chan core.Delta, func()) {
	r.subMu.Lock()
	defer r.subMu.Unlock()
	id := r.nextSub
	r.nextSub++
	ch := make(chan core.Delta, 64)
	r.subs[id] = ch
	return ch, func() {
		r.subMu.Lock()
		defer r.subMu.Unlock()
		if c, ok := r.subs[id]; ok {
			delete(r.subs, id)
			close(c)
		}
	}
}

func (r *Runner) publish(d core.Delta) {
	r.subMu.Lock()
	defer r.subMu.Unlock()
	for _, ch := range r.subs {
		select {
		case ch <- d:
		default:
		}
	}
}

// Reset starts a new world from the universe: the log keeps the old one
// aside (see store.Log.Reset) and pending advisor answers are dropped.
// Decision ids repeat across worlds (they carry the tick), hence the generation.
func (r *Runner) Reset() (string, error) {
	r.mu.Lock()
	if r.closed {
		r.mu.Unlock()
		return "", errors.New("runner_closed")
	}
	archived, err := r.log.Reset()
	if err != nil {
		r.mu.Unlock()
		return "", err
	}
	r.s = core.NewState(r.w)
	r.gen++
	r.inflight = map[string]bool{}
	s := r.s
	r.mu.Unlock()
	r.publish(core.Delta{Revision: s.Revision, Tick: s.Tick})
	return archived, nil
}

// Drain waits for in-flight advisor calls (tests, shutdown).
func (r *Runner) Drain() { r.wg.Wait() }

func (r *Runner) Close() error {
	r.mu.Lock()
	r.closed = true
	r.mu.Unlock()
	r.wg.Wait()
	return r.log.Close()
}
