package scenarios

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// benchWorld loads the Hospedeiro universe and adds n synthetic named NPCs,
// each with one cheap goal, to measure how the tick scales with agents. The
// universe on disk is not changed.
func benchWorld(tb testing.TB, n int) (*core.World, core.State) {
	tb.Helper()
	data, err := os.ReadFile("../../universes/hospedeiro/universe.json")
	if err != nil {
		tb.Fatal(err)
	}
	dec := json.NewDecoder(bytes.NewReader(bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf})))
	dec.DisallowUnknownFields()
	var u core.Universe
	if err := dec.Decode(&u); err != nil {
		tb.Fatal(err)
	}
	for i := 0; i < n; i++ {
		id := core.ID(fmt.Sprintf("npc:bench:sangue:%d", i))
		u.Entities = append(u.Entities, core.EntitySeed{ID: id, Kind: "celula", Name: string(id), Region: "sangue"})
		u.Agents = append(u.Agents, core.AgentDef{Entity: id, Think: 1, Goals: []core.GoalDef{{
			ID: "nutrir", Priority: 1, Action: "nutrir-nicho", Cooldown: 6,
			When: core.Cond{Num: &core.NumCmp{E: "medula", K: "reserva", Op: "<", V: 80}},
		}}})
	}
	w, err := core.Compile(u)
	if err != nil {
		tb.Fatal(err)
	}
	return w, core.NewState(w)
}

func benchTick(w *core.World, s core.State) core.State {
	s, _, err := w.Step(s, core.Command{Version: 1, Origin: "system", Kind: "tick", RequestID: fmt.Sprintf("tick:%d", s.Tick+1)})
	if err != nil {
		panic(err)
	}
	return s
}

// BenchmarkTickNPCs measures one world tick with 0/10/100/1000 synthetic NPCs.
// Step clones the state, so the numbers include that copy (the real cost).
func BenchmarkTickNPCs(b *testing.B) {
	for _, n := range []int{0, 10, 100, 1000} {
		b.Run(fmt.Sprintf("npcs=%d", n), func(b *testing.B) {
			w, s := benchWorld(b, n)
			for i := 0; i < 20; i++ {
				s = benchTick(w, s)
			}
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				s = benchTick(w, s)
			}
		})
	}
}

// TestBenchWorldReplays keeps the benchmark honest: the synthetic world must
// replay to the same digest.
func TestBenchWorldReplays(t *testing.T) {
	w, s := benchWorld(t, 50)
	for i := 0; i < 100; i++ {
		s = benchTick(w, s)
	}
	w2, s2 := benchWorld(t, 50)
	for i := 0; i < 100; i++ {
		s2 = benchTick(w2, s2)
	}
	if s.Digest() != s2.Digest() {
		t.Fatal("digest differs between identical runs")
	}
}
