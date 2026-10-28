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
	// MaxQuestionsPerMinute and MaxCostPerHour (USD, as reported by the
	// provider) bound what the advisor may be asked. Over the cap a question is
	// not sent and its deadline default applies; zero means no cap. Higher
	// priority questions (attention, then conflict, then NPC) are sent first.
	MaxQuestionsPerMinute int
	MaxCostPerHour        float64
	// Now is the clock for the caps; nil means time.Now.
	Now func() time.Time
	// CheckpointPath, when set, keeps a verified snapshot of the state next to
	// the log, written every CheckpointEvery ticks (0: only on Close), so a
	// restart replays the tail of the log instead of the whole of it.
	CheckpointPath  string
	CheckpointEvery int64
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
	spent    []spend
	flushing bool
	gen      int // bumped by Reset; advisor answers of an older world are dropped

	// Operation (see ops.go).
	entries    int // commands in the log this state includes
	ckMu       sync.Mutex
	ck         ckStats
	tickTimes  []time.Duration
	tickAt     int
	lastTickAt time.Time
	every      time.Duration
	started    time.Time
	startup    Startup
}

// Open rebuilds the world by replaying the log, then dispatches decisions
// that were still pending when the process stopped.
func Open(w *core.World, log store.Log, opt Options) (*Runner, error) {
	if opt.AdvisorTimeout <= 0 {
		opt.AdvisorTimeout = 8 * time.Second
	}
	r := &Runner{w: w, s: core.NewState(w), log: log, opt: opt, inflight: map[string]bool{}, subs: map[int]chan core.Delta{}}
	r.started = r.now()
	cmds, err := log.Load()
	if err != nil {
		return nil, err
	}
	from := 0
	if opt.CheckpointPath != "" {
		// A checkpoint is only a shortcut: if it is missing, old or does not
		// verify, the whole log is replayed and nothing is lost.
		if st, n, ok := loadCheckpoint(opt.CheckpointPath, w, len(cmds)); ok {
			r.s, from = st, n
			r.startup.FromCheckpoint, r.startup.CheckpointTick = true, int64(st.Tick)
			r.ck = ckStats{written: true, entries: n, tick: st.Tick, at: r.now()}
		}
	}
	for i := from; i < len(cmds); i++ {
		s, _, err := w.Step(r.s, cmds[i])
		if err != nil {
			return nil, errors.New("replay failed at entry " + strconv.Itoa(i+1) + ": " + err.Error())
		}
		r.s = s
	}
	r.entries = len(cmds)
	r.startup.ReplayedCommands = len(cmds) - from
	r.startup.OpenMS = float64(r.now().Sub(r.started).Microseconds()) / 1000
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
	began := time.Now()
	next, d, err := r.w.Step(r.s, c)
	if err == nil && !d.Duplicate {
		if err = r.log.Append(c); err == nil {
			r.s = next
			r.entries++
			if c.Kind == "tick" {
				r.recordTick(time.Since(began))
				r.maybeCheckpoint()
			}
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
//
// Time is faithful to ticks, not to the clock: while the process is down the
// world is paused and resumes at the tick where it stopped, with no catch-up
// burst. A tick that fails to be applied (a full disk, a log that cannot be
// written) is retried on the next beat; after a few in a row Run returns the
// error, so a supervisor restarts the process instead of leaving a frozen
// world that still answers requests.
func (r *Runner) Run(ctx context.Context, every time.Duration) error {
	r.mu.Lock()
	r.every = every
	r.mu.Unlock()
	t := time.NewTicker(every)
	defer t.Stop()
	failed := 0
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			if _, err := r.Tick(); err != nil {
				if failed++; failed >= maxTickFailures {
					return tickFailure(failed, err)
				}
				continue
			}
			failed = 0
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
	Skipped   int64   // questions the caps kept from being sent
	LatencyMS int64   // sum over calls
	Cost      float64 // sum of reported cost
	// ByKind splits the same counters by decision kind (npc, conflict, world...).
	ByKind map[string]KindStats
}

// KindStats are the per-kind counters.
type KindStats struct{ Created, Asked, Failed, Applied, Rejected, Changed, Skipped int64 }

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
func batchable(kind string) bool {
	return kind == core.DecisionNPC || kind == core.DecisionConflict || kind == core.DecisionAttention
}

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

type spend struct {
	at   time.Time
	n    int
	cost float64
}

func (r *Runner) now() time.Time {
	if r.opt.Now != nil {
		return r.opt.Now()
	}
	return time.Now()
}

// admit says how many of n questions may be sent now under the caps, and
// records them. Callers do not hold r.mu.
func (r *Runner) admit(n int) int {
	if r.opt.MaxQuestionsPerMinute <= 0 && r.opt.MaxCostPerHour <= 0 {
		return n
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	now := r.now()
	keep := r.spent[:0]
	var perMinute int
	var perHour float64
	for _, x := range r.spent {
		if now.Sub(x.at) < time.Hour {
			keep = append(keep, x)
			perHour += x.cost
			if now.Sub(x.at) < time.Minute {
				perMinute += x.n
			}
		}
	}
	r.spent = keep
	allowed := n
	if r.opt.MaxQuestionsPerMinute > 0 {
		allowed = min(allowed, max(r.opt.MaxQuestionsPerMinute-perMinute, 0))
	}
	if r.opt.MaxCostPerHour > 0 && perHour >= r.opt.MaxCostPerHour {
		allowed = 0
	}
	if allowed > 0 {
		r.spent = append(r.spent, spend{at: now, n: allowed})
	}
	return allowed
}

// charge adds the real cost of a finished call to the newest matching window entry.
func (r *Runner) charge(cost float64) {
	if r.opt.MaxCostPerHour <= 0 || cost <= 0 {
		return
	}
	r.mu.Lock()
	r.spent = append(r.spent, spend{at: r.now(), cost: cost})
	r.mu.Unlock()
}

// skip counts a question the caps kept from being sent.
func (r *Runner) skip(q queued) {
	r.release(q.d, q.gen)
	r.mu.Lock()
	r.stats.Skipped++
	r.kind(q.d.Kind, func(k *KindStats) { k.Skipped++ })
	r.mu.Unlock()
	r.wg.Done()
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
		r.mu.Lock()
		r.kind(d.Kind, func(k *KindStats) { k.Created++ })
		r.mu.Unlock()
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
		if r.admit(1) == 0 {
			r.skip(queued{d, gen})
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
					defer r.charge(*a.Cost)
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
	for _, kind := range []string{core.DecisionAttention, core.DecisionConflict, core.DecisionNPC} {
		var same []queued
		for _, x := range q {
			if x.d.Kind == kind {
				same = append(same, x)
			}
		}
		for len(same) > 0 {
			n := min(len(same), advisor.MaxBatch)
			ok := r.admit(n)
			for _, q := range same[ok:n] {
				r.skip(q)
			}
			if ok > 0 {
				r.sendBatch(b, kind, same[:ok])
			}
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
				defer r.charge(*x.Answer.Cost)
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
	r.entries = 0
	r.ck = ckStats{}
	r.startup = Startup{}
	if r.opt.CheckpointPath != "" {
		removeCheckpoints(r.opt.CheckpointPath)
	}
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
	entries, s, gen := r.entries, r.s, r.gen
	r.mu.Unlock()
	r.wg.Wait()
	if r.opt.CheckpointPath != "" && s.Tick > 0 {
		r.saveCheckpoint(entries, s, gen) // a clean stop leaves the shortest possible restart
	}
	return r.log.Close()
}
