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
func (r *Runner) Submit(c core.Command) (core.Delta, error) {
	r.mu.Lock()
	if r.closed {
		r.mu.Unlock()
		return core.Delta{}, errors.New("runner_closed")
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

func (r *Runner) dispatch(ds []core.Decision) {
	if r.opt.Advisor == nil {
		return
	}
	for _, d := range ds {
		r.mu.Lock()
		if r.inflight[d.ID] || r.closed {
			r.mu.Unlock()
			continue
		}
		r.inflight[d.ID] = true
		r.wg.Add(1)
		r.mu.Unlock()
		go func(d core.Decision) {
			defer r.wg.Done()
			ctx, cancel := context.WithTimeout(context.Background(), r.opt.AdvisorTimeout)
			a, err := r.opt.Advisor.Decide(ctx, r.w.U.ID, d)
			cancel()
			r.mu.Lock()
			delete(r.inflight, d.ID)
			r.mu.Unlock()
			if err != nil {
				return // the deterministic default applies at the deadline
			}
			// A late or stale answer is rejected by the engine; that is fine.
			_, _ = r.Submit(core.Command{Version: 1, RequestID: "resolve:" + d.ID, Origin: "advisor", Kind: "resolve",
				Decision: d.ID, Choice: a.Choice, Provider: a.Provider, Model: a.Model, Call: a.Call,
				Confidence: a.Confidence, LatencyMS: a.LatencyMS, Cost: a.Cost})
		}(d)
	}
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

// Drain waits for in-flight advisor calls (tests, shutdown).
func (r *Runner) Drain() { r.wg.Wait() }

func (r *Runner) Close() error {
	r.mu.Lock()
	r.closed = true
	r.mu.Unlock()
	r.wg.Wait()
	return r.log.Close()
}
