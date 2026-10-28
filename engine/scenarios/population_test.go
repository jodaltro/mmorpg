package scenarios

import (
	"fmt"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// miniUniverse is the smallest world that can host cohorts: two places, one
// player kind. Used to audit conservation with exact arithmetic.
func miniUniverse(pops []core.PopulationDef, ents ...core.EntitySeed) core.Universe {
	return core.Universe{
		Version: 1, ID: "mini", Name: "mini", Kinds: []string{"lugar", "gente", "bicho"}, RegionKinds: []string{"lugar"}, PlayerKind: "gente",
		Perceivers: []string{"gente"}, Predicates: []string{"p"},
		Player:      core.EntitySeed{ID: "p0", Kind: "gente", Region: "a"},
		Entities:    append([]core.EntitySeed{{ID: "a", Kind: "lugar"}, {ID: "b", Kind: "lugar"}}, ents...),
		Populations: pops,
		Limits:      core.Limits{MaxActiveQuests: 1, DecisionTimeout: 3, OfferExpiry: 10, MaxEvents: 64},
	}
}

func tickAll(t *testing.T, w *core.World, s core.State, n int) core.State {
	t.Helper()
	for i := 0; i < n; i++ {
		var err error
		s, _, err = w.Step(s, core.Command{Version: 1, Origin: "system", Kind: "tick", RequestID: fmt.Sprintf("tick:%d", s.Tick+1)})
		if err != nil {
			t.Fatal(err)
		}
	}
	return s
}

// A cohort moves a quantity with loss and a ceiling: what leaves the source is
// exactly what arrives plus what the ledger records as sink.
func TestPopulationConservesQuantities(t *testing.T) {
	ceiling := int64(60)
	u := miniUniverse([]core.PopulationDef{{ID: "carregadores", Role: "transporte", Region: "a", Count: 7, Work: []core.WorkDef{
		{ID: "levar", K: "o2", From: "a", To: "b", Rate: 900, Loss: 100, ToMax: &ceiling},
	}}})
	u.Entities[0].Num = map[string]int64{"o2": 100}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	s := core.NewState(w)
	for i := 0; i < 120; i++ {
		s = tickAll(t, w, s, 1)
		total := s.Entities["a"].Num["o2"] + s.Entities["b"].Num["o2"] + s.Ledger["sink:o2"] - s.Ledger["source:o2"]
		if total != 100 {
			t.Fatalf("tick %d: o2 not conserved: a=%d b=%d sink=%d", s.Tick, s.Entities["a"].Num["o2"], s.Entities["b"].Num["o2"], s.Ledger["sink:o2"])
		}
		if s.Entities["a"].Num["o2"] < 0 || s.Entities["b"].Num["o2"] > ceiling {
			t.Fatalf("tick %d: limits broken a=%d b=%d", s.Tick, s.Entities["a"].Num["o2"], s.Entities["b"].Num["o2"])
		}
	}
	if s.Entities["b"].Num["o2"] == 0 {
		t.Fatal("the cohort never delivered anything")
	}
}

// Fractions of work are kept: 3 members at 100 milli-units do one unit every
// 3.33 ticks, not zero forever.
func TestPopulationKeepsFractionalWork(t *testing.T) {
	u := miniUniverse([]core.PopulationDef{{ID: "lentos", Role: "x", Region: "a", Count: 3, Work: []core.WorkDef{{ID: "w", K: "k", From: "a", To: "b", Rate: 100}}}})
	u.Entities[0].Num = map[string]int64{"k": 50}
	w, _ := core.Compile(u)
	s := tickAll(t, w, core.NewState(w), 100)
	if got := s.Entities["b"].Num["k"]; got != 30 {
		t.Fatalf("100 ticks of 0.3/tick must deliver 30, got %d", got)
	}
}

// A cohort that dies off is replaced only by spending its reserve; with the
// reserve empty it shrinks and never goes below zero.
func TestPopulationRecruitSpendsReserve(t *testing.T) {
	u := miniUniverse([]core.PopulationDef{{ID: "c", Role: "x", Region: "a", Count: 100, Max: 100, Mortality: 100, MortalityEvery: 1,
		Recruit: &core.RecruitDef{From: "a", K: "reserva", Cost: 2, PerCycle: 50}}})
	u.Entities[0].Num = map[string]int64{"reserva": 40}
	w, _ := core.Compile(u)
	s := core.NewState(w)
	for i := 0; i < 80; i++ {
		s = tickAll(t, w, s, 1)
		if s.Pops["c"].Count < 0 || s.Pops["c"].Count > 100 || s.Entities["a"].Num["reserva"] < 0 {
			t.Fatalf("tick %d: count=%d reserva=%d", s.Tick, s.Pops["c"].Count, s.Entities["a"].Num["reserva"])
		}
	}
	if s.Entities["a"].Num["reserva"] != 0 {
		t.Fatalf("reserve must be spent, left %d", s.Entities["a"].Num["reserva"])
	}
	if s.Ledger["born:c"] != 20 {
		t.Fatalf("40 reserve at cost 2 = 20 births, got %d", s.Ledger["born:c"])
	}
	if s.Pops["c"].Count >= 100 {
		t.Fatal("without reserve the cohort must shrink")
	}
}

func TestPopulationRejectsBadDefinitions(t *testing.T) {
	bad := []core.PopulationDef{
		{ID: "x", Role: "r", Region: "nenhum", Count: 1},
		{ID: "x", Role: "r", Region: "a", Count: 5, Max: 2},
		{ID: "x", Role: "r", Region: "a", Count: 1, Work: []core.WorkDef{{ID: "w", K: "k", Rate: 0}}},
		{ID: "x", Role: "r", Region: "a", Count: 1, Work: []core.WorkDef{{ID: "w", K: "k", From: "fantasma", Rate: 1}}},
		{ID: "x", Role: "r", Region: "a", Count: 1, Mortality: 2000},
	}
	for i, p := range bad {
		if _, err := core.Compile(miniUniverse([]core.PopulationDef{p})); err == nil {
			t.Errorf("case %d must be rejected", i)
		}
	}
}

// The real Hospedeiro body, with nobody in it and no advisor: cohorts work,
// nothing goes negative, the reserve is the only thing replacing the dead and
// the whole run replays to the same digest.
func TestHospedeiroBodyWorksWithoutPlayers(t *testing.T) {
	run := func() core.State {
		h := load(t, "hospedeiro")
		h.tick(600)
		return h.s
	}
	s := run()
	t.Logf("tick %d pops=%v ledger=%v oxigenio sangue=%d pulmao=%d reserva=%d", s.Tick, s.Pops, s.Ledger, s.Entities["sangue"].Num["oxigenio"], s.Entities["pulmao"].Num["oxigenio"], s.Entities["medula"].Num["reserva"])
	for _, id := range []string{"hemacias_sangue", "suporte_sangue", "neutrofilos_pulmao", "macrofagos_pulmao"} {
		if c := s.Pops[id].Count; c <= 0 {
			t.Errorf("cohort %s died out: %d", id, c)
		}
	}
	for id, e := range s.Entities {
		for k, v := range e.Num {
			if v < 0 {
				t.Errorf("%s.%s is negative: %d", id, k, v)
			}
		}
	}
	if s.Entities["sangue"].Num["oxigenio"] <= 0 {
		t.Error("red cells never carried oxygen into the blood")
	}
	if s.Ledger["sink:oxigenio"] <= 0 {
		t.Error("tissue support never used oxygen")
	}
	if s.Ledger["born:hemacias_sangue"] == 0 && s.Ledger["died:hemacias_sangue"] > 0 {
		t.Error("dead red cells were never replaced")
	}
	if again := run(); again.Digest() != s.Digest() {
		t.Fatal("digest differs between two identical runs")
	}
}

// Replaying the command log from tick 0 reproduces the digest.
func TestHospedeiroPopulationReplay(t *testing.T) {
	h := load(t, "hospedeiro")
	h.tick(200)
	s := core.NewState(h.w)
	for _, c := range h.log {
		var err error
		if s, _, err = h.w.Step(s, c); err != nil {
			t.Fatal(err)
		}
	}
	if s.Digest() != h.s.Digest() {
		t.Fatal("replay digest mismatch")
	}
}
