package sim

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

// P14: a world that runs for days. Checkpoints are only a verified shortcut
// into the log; every doubt means a full replay, and the result is the same.

func hospedeiro(t *testing.T) *core.World {
	t.Helper()
	w, err := universe.Load("../../universes/hospedeiro/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	return w
}

type files struct{ log, ck string }

func newFiles(t *testing.T) files {
	d := t.TempDir()
	return files{filepath.Join(d, "world.jsonl"), filepath.Join(d, "world.checkpoint.json")}
}

func (f files) open(t *testing.T, w *core.World, every int64) (*Runner, *store.FileLog) {
	t.Helper()
	l, err := store.OpenFile(f.log, w.U.ID, w.Fingerprint())
	if err != nil {
		t.Fatal(err)
	}
	r, err := Open(w, l, Options{CheckpointPath: f.ck, CheckpointEvery: every})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Drain(); l.Close() }) // Windows will not delete an open file
	return r, l
}

// fullReplay is what the world is, ignoring any checkpoint.
func (f files) fullReplay(t *testing.T, w *core.World) core.State {
	t.Helper()
	l, err := store.OpenFile(f.log, w.U.ID, w.Fingerprint())
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	r, err := Open(w, l, Options{})
	if err != nil {
		t.Fatal(err)
	}
	return r.Snapshot()
}

func lived(t *testing.T, r *Runner, n int) {
	t.Helper()
	must(t, r, core.Command{RequestID: "join-p1", Origin: "adapter", Kind: "join", Actor: "p1", Name: "Ana", Region: "medula"})
	ticks(t, r, n)
}

func TestRestartFromCheckpointEqualsFullReplayAndContinuesTheSameWay(t *testing.T) {
	w, f := hospedeiro(t), newFiles(t)
	r, _ := f.open(t, w, 100)
	lived(t, r, 350)
	want := r.Snapshot().Digest()
	r.Drain()
	if err := r.Close(); err != nil {
		t.Fatal(err)
	}

	r2, _ := f.open(t, w, 100)
	m := r2.Metrics()
	if !m.Startup.FromCheckpoint || m.Startup.ReplayedCommands != 0 || m.Startup.CheckpointTick != 350 {
		t.Fatalf("a clean stop must restart from its last checkpoint without replaying: %+v", m.Startup)
	}
	if r2.Snapshot().Digest() != want || f.fullReplay(t, w).Digest() != want {
		t.Fatal("the restored world must be exactly the replayed one")
	}
	ticks(t, r2, 60)
	after := r2.Snapshot().Digest()
	r2.Close()
	if f.fullReplay(t, w).Digest() != after {
		t.Fatal("after more ticks the checkpointed history and the full replay must still agree")
	}
}

func TestCrashLeavesACheckpointAndTheTailIsReplayed(t *testing.T) {
	w, f := hospedeiro(t), newFiles(t)
	r, l := f.open(t, w, 100)
	lived(t, r, 250)
	r.Drain()
	want := r.Snapshot().Digest()
	l.Close() // a crash: no final checkpoint, the cadence's last one is all there is

	r2, _ := f.open(t, w, 100)
	m := r2.Metrics()
	if !m.Startup.FromCheckpoint || m.Startup.ReplayedCommands == 0 || m.Startup.ReplayedCommands >= 150 {
		t.Fatalf("a crash must replay only the tail after the last checkpoint: %+v", m.Startup)
	}
	if r2.Snapshot().Digest() != want {
		t.Fatal("recovery after a crash must give back the same world")
	}
}

func TestADoubtfulCheckpointIsIgnoredAndTheLogDecides(t *testing.T) {
	w := hospedeiro(t)
	damage := map[string]func(f files){
		"garbage":       func(f files) { os.WriteFile(f.ck, []byte("{not json"), 0o600); os.Remove(f.ck + ".prev") },
		"wrong digest":  func(f files) { rewrite(t, f.ck, `"digest":"`, `"digest":"00`); os.Remove(f.ck + ".prev") },
		"other version": func(f files) { rewrite(t, f.ck, `"def":"`, `"def":"x`); os.Remove(f.ck + ".prev") },
		"ahead of log":  func(f files) { cut(t, f.log, 40); os.Remove(f.ck + ".prev") }, // the tail of the log was torn off
	}
	for name, hurt := range damage {
		f := newFiles(t)
		r, _ := f.open(t, w, 100)
		lived(t, r, 220)
		r.Close()
		hurt(f)
		r2, _ := f.open(t, w, 100)
		m := r2.Metrics()
		if m.Startup.FromCheckpoint {
			t.Fatalf("%s: a checkpoint that does not verify must not be used", name)
		}
		if r2.Snapshot().Digest() != f.fullReplay(t, w).Digest() || r2.Snapshot().Tick < 200 {
			t.Fatalf("%s: the world must come back from the log alone (tick %d)", name, r2.Snapshot().Tick)
		}
	}
}

func rewrite(t *testing.T, path, from, to string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), from) {
		t.Fatalf("%s: %q not found", path, from)
	}
	os.WriteFile(path, []byte(strings.Replace(string(b), from, to, 1)), 0o600)
}

func cut(t *testing.T, path string, n int) {
	t.Helper()
	b, _ := os.ReadFile(path)
	os.WriteFile(path, b[:len(b)-n], 0o600)
}

func TestThePreviousCheckpointCoversATornWrite(t *testing.T) {
	w, f := hospedeiro(t), newFiles(t)
	r, l := f.open(t, w, 80)
	lived(t, r, 200)
	r.Drain()
	l.Close()
	os.WriteFile(f.ck, []byte(`{"format":1,"universe":"hospedeiro","tr`), 0o600) // the newest was cut mid-write
	r2, _ := f.open(t, w, 80)
	if !r2.Metrics().Startup.FromCheckpoint {
		t.Fatal("the previous generation must serve when the newest is damaged")
	}
	if r2.Snapshot().Digest() != f.fullReplay(t, w).Digest() {
		t.Fatal("and it must still lead to the same world")
	}
}

func TestTheWorldIsPausedNotCaughtUpWhileTheProcessIsDown(t *testing.T) {
	w, f := hospedeiro(t), newFiles(t)
	r, _ := f.open(t, w, 100)
	lived(t, r, 120)
	last := r.Snapshot().Tick
	r.Close()
	time.Sleep(120 * time.Millisecond) // the "downtime"
	r2, _ := f.open(t, w, 100)
	if r2.Snapshot().Tick != last {
		t.Fatalf("restart must resume at tick %d, not jump ahead: %d", last, r2.Snapshot().Tick)
	}
	d, err := r2.Tick()
	if err != nil || d.Tick != last+1 {
		t.Fatalf("the next tick must be exactly one more: %+v %v", d, err)
	}
}

type brokenLog struct {
	store.Log
	fail atomic.Bool
}

func (b *brokenLog) Append(c core.Command) error {
	if b.fail.Load() {
		return errors.New("disk full")
	}
	return b.Log.Append(c)
}

func TestTickingStopsLoudlyWhenTheLogCannotBeWritten(t *testing.T) {
	w := hospedeiro(t)
	b := &brokenLog{Log: &store.Memory{}}
	r, err := Open(w, b, Options{})
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- r.Run(context.Background(), 5*time.Millisecond) }()
	time.Sleep(60 * time.Millisecond)
	before := r.Snapshot().Tick
	b.fail.Store(true)
	select {
	case err := <-done:
		if !errors.Is(err, errTickFailing) {
			t.Fatalf("Run must say why it stopped: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("a world that cannot persist must stop, not freeze quietly")
	}
	if r.Snapshot().Tick > before+1 {
		t.Fatal("nothing may advance that was not persisted")
	}
	if got := r.Metrics().Status; got != "ok" && got != "starting" && got != "stalled" {
		t.Fatalf("unknown status %q", got)
	}
}

func TestMetricsTellHealthyFromStalled(t *testing.T) {
	w := hospedeiro(t)
	var offset atomic.Int64
	now := func() time.Time { return time.Now().Add(time.Duration(offset.Load())) }
	r, err := Open(w, &store.Memory{}, Options{Now: now})
	if err != nil {
		t.Fatal(err)
	}
	if got := r.Metrics().Status; got != "ok" {
		t.Fatalf("a world ticked by hand has nothing to be late for: %q", got)
	}
	ctx, stop := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- r.Run(ctx, 5*time.Millisecond) }()
	time.Sleep(150 * time.Millisecond)
	m := r.Metrics()
	if m.Status != "ok" || m.TickMS.Samples < 10 || m.TickMS.P99 <= 0 || m.TickMS.P50 > m.TickMS.Max || m.World.NPCs < 10 || m.LogEntries != int(m.Tick) {
		t.Fatalf("a ticking world reports itself: %+v", m)
	}
	stop()
	<-done
	offset.Store(int64(time.Minute))
	if got := r.Metrics().Status; got != "stalled" {
		t.Fatalf("ticks that stopped coming must show as stalled, got %q", got)
	}
}

func TestStateStaysBoundedOverALongRun(t *testing.T) {
	if testing.Short() {
		t.Skip("long")
	}
	w := hospedeiro(t)
	r, err := Open(w, &store.Memory{}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	must(t, r, core.Command{RequestID: "join-p1", Origin: "adapter", Kind: "join", Actor: "p1", Name: "Ana", Region: "medula"})
	size := func() int {
		path := filepath.Join(t.TempDir(), "c.json")
		if err := writeCheckpoint(path, w, 0, r.Snapshot()); err != nil {
			t.Fatal(err)
		}
		st, _ := os.Stat(path)
		return int(st.Size())
	}
	ticks(t, r, 3000)
	early := size()
	ticks(t, r, 5000)
	late := size()
	events := len(r.Snapshot().Events)
	t.Logf("checkpoint %d bytes at tick 3000, %d at tick 8000; %d events kept", early, late, events)
	if late > early*3/2 {
		t.Fatalf("the state must not grow with time: %d -> %d bytes", early, late)
	}
	if events > 1000 {
		t.Fatalf("the event list is capped by the universe (1000): %d", events)
	}
}
