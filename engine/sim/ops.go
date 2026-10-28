package sim

// Operation of a world that runs for days: checkpoints so a restart does not
// replay every tick ever made, and the numbers an operator needs to tell a
// healthy world from a stalled one. None of this is a source of truth. The
// command log is; a checkpoint is a verified shortcut to a point in it, and
// anything doubtful about it means a full replay.

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"slices"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
)

const checkpointFormat = 1

// tickRing is how many recent tick durations the metrics keep.
const tickRing = 512

// maxTickFailures is how many ticks in a row may fail to be applied before Run
// gives up, so a supervisor sees a dead process instead of a frozen world.
const maxTickFailures = 5

type checkpointFile struct {
	Format   int        `json:"format"`
	Universe string     `json:"universe"`
	Def      string     `json:"def"`
	Entries  int        `json:"entries"` // commands of the log this state includes
	Tick     core.Tick  `json:"tick"`
	Digest   string     `json:"digest"`
	SavedAt  string     `json:"savedAt"`
	State    core.State `json:"state"`
}

// loadCheckpoint returns the newest valid checkpoint (the file, else its
// previous generation). Valid means: same universe version, no more entries
// than the log has, and a digest that matches the state it carries.
func loadCheckpoint(path string, w *core.World, logEntries int) (core.State, int, bool) {
	for _, p := range []string{path, path + ".prev"} {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		var c checkpointFile
		if json.Unmarshal(b, &c) != nil || c.Format != checkpointFormat || c.Universe != w.U.ID || c.Def != w.Fingerprint() {
			continue
		}
		if c.Entries < 0 || c.Entries > logEntries || c.State.Digest() != c.Digest {
			continue
		}
		w.Revive(&c.State)
		if c.State.Digest() != c.Digest { // reviving must change nothing that counts
			continue
		}
		return c.State, c.Entries, true
	}
	return core.State{}, 0, false
}

// writeCheckpoint stores a state atomically and keeps the previous
// generation, so a crash while writing never leaves the world without one.
func writeCheckpoint(path string, w *core.World, entries int, s core.State) error {
	b, err := json.Marshal(checkpointFile{Format: checkpointFormat, Universe: w.U.ID, Def: w.Fingerprint(), Entries: entries, Tick: s.Tick, Digest: s.Digest(), SavedAt: time.Now().UTC().Format(time.RFC3339), State: s})
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	if _, err = f.Write(b); err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmp)
		return err
	}
	if _, err := os.Stat(path); err == nil {
		if err := os.Rename(path, path+".prev"); err != nil {
			return err
		}
	}
	return os.Rename(tmp, path)
}

func removeCheckpoints(path string) {
	for _, p := range []string{path, path + ".prev", path + ".tmp"} {
		os.Remove(p)
	}
}

// maybeCheckpoint starts a background write when the tick is on the cadence.
// Callers hold r.mu; the state it captures is never mutated afterwards.
func (r *Runner) maybeCheckpoint() {
	if r.opt.CheckpointPath == "" || r.opt.CheckpointEvery <= 0 || r.s.Tick == 0 || int64(r.s.Tick)%r.opt.CheckpointEvery != 0 {
		return
	}
	entries, s, gen := r.entries, r.s, r.gen
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		r.saveCheckpoint(entries, s, gen)
	}()
}

func (r *Runner) saveCheckpoint(entries int, s core.State, gen int) {
	r.ckMu.Lock()
	defer r.ckMu.Unlock()
	r.mu.Lock()
	stale := gen != r.gen || entries <= r.ck.entries && r.ck.written
	r.mu.Unlock()
	if stale {
		return
	}
	err := writeCheckpoint(r.opt.CheckpointPath, r.w, entries, s)
	r.mu.Lock()
	defer r.mu.Unlock()
	if gen != r.gen {
		return
	}
	if err != nil {
		r.ck.failures++
		r.ck.lastError = err.Error()
		return
	}
	r.ck.written, r.ck.entries, r.ck.tick, r.ck.at, r.ck.writes = true, entries, s.Tick, r.now(), r.ck.writes+1
}

type ckStats struct {
	written   bool
	entries   int
	tick      core.Tick
	at        time.Time
	writes    int64
	failures  int64
	lastError string
}

// recordTick keeps how long applying a tick took (Step plus the fsynced
// append), and when the last one landed. Callers hold r.mu.
func (r *Runner) recordTick(d time.Duration) {
	if len(r.tickTimes) < tickRing {
		r.tickTimes = append(r.tickTimes, d)
	} else {
		r.tickTimes[r.tickAt%tickRing] = d
	}
	r.tickAt++
	r.lastTickAt = r.now()
}

// Metrics is the operator's view of a running world. Counts only: no player
// names, no positions, nothing a client sent.
type Metrics struct {
	Universe      string  `json:"universe"`
	Tick          int64   `json:"tick"`
	Revision      int64   `json:"revision"`
	Status        string  `json:"status"` // ok | stalled | starting
	UptimeSeconds float64 `json:"uptimeSeconds"`
	// LastTickAgeSeconds is -1 until the first tick of this process.
	LastTickAgeSeconds float64 `json:"lastTickAgeSeconds"`
	TickIntervalMS     int64   `json:"tickIntervalMs"`
	LogEntries         int     `json:"logEntries"`
	TickMS             TickMS  `json:"tickMs"`
	Startup            Startup `json:"startup"`
	Checkpoint         CkView  `json:"checkpoint"`
	World              Census  `json:"world"`
	Advisor            Stats   `json:"advisor"`
	Subscribers        int     `json:"subscribers"`
	PendingDecisions   int     `json:"pendingDecisions"`
	QueuedQuestions    int     `json:"queuedQuestions"`
}

// TickMS are the percentiles of the last tick durations, in milliseconds.
type TickMS struct {
	Samples int     `json:"samples"`
	Mean    float64 `json:"mean"`
	P50     float64 `json:"p50"`
	P95     float64 `json:"p95"`
	P99     float64 `json:"p99"`
	Max     float64 `json:"max"`
}

// Startup says how this process got its state.
type Startup struct {
	FromCheckpoint   bool    `json:"fromCheckpoint"`
	CheckpointTick   int64   `json:"checkpointTick,omitempty"`
	ReplayedCommands int     `json:"replayedCommands"`
	OpenMS           float64 `json:"openMs"`
}

type CkView struct {
	Enabled    bool    `json:"enabled"`
	EveryTicks int64   `json:"everyTicks,omitempty"`
	Tick       int64   `json:"tick"`
	Entries    int     `json:"entries"`
	AgeSeconds float64 `json:"ageSeconds"` // -1 when none was written by this process
	Writes     int64   `json:"writes"`
	Failures   int64   `json:"failures"`
	LastError  string  `json:"lastError,omitempty"`
}

// Census counts what the world holds, so growth is visible before it hurts.
type Census struct {
	Entities         int `json:"entities"`
	NPCs             int `json:"npcs"`
	NPCsWorking      int `json:"npcsWorking"`
	LiveConflicts    int `json:"liveConflicts"`
	Events           int `json:"events"`
	OpenHelpRequests int `json:"openHelpRequests"`
}

// Metrics reads the counters under the lock for a moment and does the rest outside it.
func (r *Runner) Metrics() Metrics {
	r.mu.Lock()
	s := r.s
	times := slices.Clone(r.tickTimes)
	last := r.lastTickAt
	every := r.every
	started := r.started
	ck := r.ck
	startup := r.startup
	entries := r.entries
	st := r.stats
	pending := len(s.Decisions)
	queued := len(r.queue)
	now := r.now()
	r.mu.Unlock()
	r.subMu.Lock()
	subs := len(r.subs)
	r.subMu.Unlock()
	m := Metrics{Universe: s.Universe, Tick: int64(s.Tick), Revision: s.Revision, UptimeSeconds: now.Sub(started).Seconds(), LastTickAgeSeconds: -1,
		TickIntervalMS: every.Milliseconds(), LogEntries: entries, Startup: startup, Advisor: st, Subscribers: subs, PendingDecisions: pending, QueuedQuestions: queued}
	if !last.IsZero() {
		m.LastTickAgeSeconds = now.Sub(last).Seconds()
	}
	m.Status = "ok"
	switch {
	case every <= 0:
		m.Status = "ok" // ticked by hand (tests, tools): nothing to be late for
	case last.IsZero():
		if now.Sub(started) > 5*every+5*time.Second {
			m.Status = "stalled"
		} else {
			m.Status = "starting"
		}
	case now.Sub(last) > 5*every+2*time.Second:
		m.Status = "stalled"
	}
	m.TickMS = percentiles(times)
	m.Checkpoint = CkView{Enabled: r.opt.CheckpointPath != "", EveryTicks: r.opt.CheckpointEvery, Tick: int64(ck.tick), Entries: ck.entries, AgeSeconds: -1, Writes: ck.writes, Failures: ck.failures, LastError: ck.lastError}
	if ck.written {
		m.Checkpoint.AgeSeconds = now.Sub(ck.at).Seconds()
	}
	m.World = Census{Entities: len(s.Entities), NPCs: len(s.NPCs), Events: len(s.Events)}
	for _, n := range s.NPCs {
		if n.Task != "" {
			m.World.NPCsWorking++
		}
		if n.Help != "" {
			m.World.OpenHelpRequests++
		}
	}
	for _, c := range s.Conflicts {
		if c.Phase != core.PhaseResolved {
			m.World.LiveConflicts++
		}
	}
	return m
}

func percentiles(times []time.Duration) TickMS {
	if len(times) == 0 {
		return TickMS{}
	}
	xs := slices.Clone(times)
	slices.Sort(xs)
	ms := func(d time.Duration) float64 { return float64(d.Microseconds()) / 1000 }
	at := func(p float64) float64 { return ms(xs[min(len(xs)-1, int(p*float64(len(xs))))]) }
	var sum time.Duration
	for _, d := range xs {
		sum += d
	}
	return TickMS{Samples: len(xs), Mean: ms(sum) / float64(len(xs)), P50: at(0.50), P95: at(0.95), P99: at(0.99), Max: ms(xs[len(xs)-1])}
}

var errTickFailing = errors.New("ticks keep failing")

func tickFailure(n int, err error) error {
	return fmt.Errorf("%w (%d in a row): %v", errTickFailing, n, err)
}
