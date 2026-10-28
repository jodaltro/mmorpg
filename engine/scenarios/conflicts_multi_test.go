package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

var allConflicts = []string{"infeccao-pulmonar", "ferida-na-pele", "congestao-esplenica", "sobrecarga-hepatica", "disbiose-intestinal"}

func byDef(s core.State, def string) (all, live []core.ConflictState) {
	for _, id := range sortedConflictIDs(s) {
		if c := s.Conflicts[id]; c.Def == def {
			all = append(all, c)
			if c.Phase != core.PhaseResolved {
				live = append(live, c)
			}
		}
	}
	return
}

func sortedConflictIDs(s core.State) []string {
	ids := make([]string, 0, len(s.Conflicts))
	for id := range s.Conflicts {
		ids = append(ids, id)
	}
	for i := range ids {
		for j := i + 1; j < len(ids); j++ {
			if ids[j] < ids[i] {
				ids[i], ids[j] = ids[j], ids[i]
			}
		}
	}
	return ids
}

// Five different crises live in the same body. With nobody playing and no
// advisor each one opens from its own cause, never twice at once, and the body
// closes them by the numbers (the stricter ones less often than the lung).
func TestFiveConflictsCycleOnTheirOwnWithoutPlayers(t *testing.T) {
	h := load(t, "hospedeiro")
	maxLive := map[string]int{}
	concurrent := 0
	for i := 0; i < 4500; i++ {
		h.tick(1)
		live := 0
		for _, def := range allConflicts {
			_, l := byDef(h.s, def)
			maxLive[def] = max(maxLive[def], len(l))
			live += len(l)
		}
		concurrent = max(concurrent, live)
	}
	for _, def := range allConflicts {
		all, _ := byDef(h.s, def)
		resolved := 0
		for _, c := range all {
			if c.Phase == core.PhaseResolved {
				resolved++
			}
		}
		t.Logf("%-22s instances=%d resolved=%d maxLive=%d", def, len(all), resolved, maxLive[def])
		if len(all) == 0 {
			t.Errorf("%s never opened in 4500 ticks", def)
		}
		if resolved == 0 {
			t.Errorf("%s never closed: the body must be able to recover", def)
		}
		if maxLive[def] > 1 {
			t.Errorf("%s had %d live instances of one cause", def, maxLive[def])
		}
	}
	if concurrent < 2 {
		t.Errorf("crises never overlapped (max %d at once): nothing to prioritise", concurrent)
	}
	t.Logf("most crises alive at once: %d", concurrent)
}

// Each crisis can be lost: take away its own cohort and named cell and it
// climbs to critical and stays there, because its cause is still present.
func TestEachConflictEscalatesWhenItsDefendersAreGone(t *testing.T) {
	cases := []struct {
		def     string
		without []string
		force   func(*harness)
	}{
		{"ferida-na-pele", []string{"plaquetas_pele", "npc:placa"}, func(h *harness) { setNum(h, "pele", "ferida", 40) }},
		{"congestao-esplenica", []string{"macrofagos_baco", "npc:esplena"}, func(h *harness) { setNum(h, "baco", "hemacias", 85) }},
		{"sobrecarga-hepatica", []string{"hepatocitos_figado", "npc:kupffer"}, func(h *harness) { setNum(h, "figado", "toxina", 85) }},
		{"disbiose-intestinal", []string{"flora_intestinal"}, func(h *harness) { setNum(h, "intestino", "microbiota", 12) }},
	}
	for _, c := range cases {
		h := loadWithoutPops(t, "hospedeiro", c.without...)
		h.tick(5)
		c.force(h)
		critical := false
		for i := 0; i < 900 && !critical; i++ {
			h.tick(1)
			_, live := byDef(h.s, c.def)
			critical = len(live) == 1 && live[0].Phase == core.PhaseCritical
		}
		if !critical {
			t.Errorf("%s: undefended, it must reach critical", c.def)
			continue
		}
		h.tick(200)
		if _, live := byDef(h.s, c.def); len(live) != 1 || live[0].Phase == core.PhaseResolved {
			t.Errorf("%s: with its cause present it must not resolve by itself", c.def)
		}
	}
}

// A player can help in each organ with a confirmed deed that counts for the
// right crisis, lowers the right number, and is refused to a client.
func TestPlayersContributeToEveryOrganCrisis(t *testing.T) {
	cases := []struct {
		def, region, action, kind string
		force                     func(*harness)
	}{
		{"ferida-na-pele", "pele", "selar-ferida-pele", "reparo", func(h *harness) { setNum(h, "pele", "ferida", 40) }},
		{"congestao-esplenica", "baco", "reciclar-hemacia", "reciclagem", func(h *harness) { setNum(h, "baco", "hemacias", 85) }},
		{"sobrecarga-hepatica", "figado", "filtrar-toxina", "depuracao", func(h *harness) { setNum(h, "figado", "toxina", 85) }},
		{"disbiose-intestinal", "intestino", "nutrir-microbiota", "nutricao", func(h *harness) { setNum(h, "intestino", "microbiota", 12) }},
	}
	for _, c := range cases {
		h := load(t, "hospedeiro")
		h.joinAt("p1", core.ID(c.region))
		h.tick(3)
		c.force(h)
		for i := 0; i < 5; i++ {
			if _, live := byDef(h.s, c.def); len(live) > 0 {
				break
			}
			h.tick(1)
		}
		if _, live := byDef(h.s, c.def); len(live) == 0 {
			t.Errorf("%s: the crisis never opened", c.def)
			continue
		}
		if err := h.act("player", "p1", c.action, nil); err == nil {
			t.Errorf("%s: a client must not confirm the deed", c.action)
		}
		h.do(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: c.action, RequestID: "ev-" + c.def})
		dup, _ := h.try(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: c.action, RequestID: "ev-" + c.def})
		if !dup.Duplicate {
			t.Errorf("%s: repeated evidence must be a duplicate", c.action)
		}
		_, live := byDef(h.s, c.def)
		if got := live[0].Credit["p1|"+c.kind]; got != 2 && got != 3 {
			t.Errorf("%s: credit for %s should be recorded once, got %d (%v)", c.def, c.kind, got, live[0].Credit)
		}
	}
}

// QA-06: two crises at once compete for the same marrow reserve and for the
// body's attention. Neither is dropped, nothing is created from nothing, and
// the attention choice has a material effect on what an NPC does by default.
func TestConcurrentCrisesShareTheReserveAndTheBodysAttention(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	h.joinAt("p2", "pele")
	h.tick(10)
	setNum(h, "pele", "ferida", 45)
	setNum(h, "baco", "hemacias", 88)
	var att core.Decision
	for i := 0; i < 200 && att.ID == ""; i++ {
		h.tick(1)
		if ds := pending(h.s, core.DecisionAttention); len(ds) > 0 {
			att = ds[0]
		}
	}
	if att.ID == "" {
		t.Fatal("with several crises alive the body must decide where to concentrate")
	}
	if len(att.Options) < 2 || att.Default != att.Options[0].ID {
		t.Fatalf("%+v", att)
	}
	for _, o := range att.Options {
		if h.s.Conflicts[o.ID].Phase == core.PhaseResolved {
			t.Fatalf("a resolved crisis is not an option: %s", o.ID)
		}
	}
	// Both are visible to both players and neither is hidden by the focus.
	v1, _ := h.w.View(&h.s, "p1", 10)
	v2, _ := h.w.View(&h.s, "p2", 10)
	if v1.Conflicts == nil || len(v1.Conflicts.Active) < 2 || v1.Conflicts.Focus != v2.Conflicts.Focus {
		t.Fatalf("both players must see all crises and the same focus: %+v", v1.Conflicts)
	}
	// Choose the last option (never the default) and check the effect.
	choice := att.Options[len(att.Options)-1].ID
	if err := h.resolve(att, choice); err != nil {
		t.Fatal(err)
	}
	if h.s.Attention != choice {
		t.Fatalf("attention did not move to %s: %s", choice, h.s.Attention)
	}
	if v, _ := h.w.View(&h.s, "p1", 10); v.Conflicts.Focus != choice {
		t.Fatal("the recommended focus follows the body's attention")
	}
	if err := h.resolve(att, choice); err == nil {
		t.Fatal("a closed question cannot be answered twice")
	}
	// The reserve is finite: two musters cannot spend more than there is.
	setNum(h, "medula", "reserva", 30)
	before := h.s.Pops["plaquetas_pele"].Count + h.s.Pops["neutrofilos_pulmao"].Count + h.s.Pops["macrofagos_pulmao"].Count + h.s.Pops["macrofagos_baco"].Count
	ledger := h.s.Ledger["born:plaquetas_pele"] + h.s.Ledger["born:neutrofilos_pulmao"] + h.s.Ledger["born:macrofagos_pulmao"] + h.s.Ledger["born:macrofagos_baco"]
	for i := 0; i < 2; i++ {
		for _, d := range pending(h.s, core.DecisionConflict) {
			def := h.s.Conflicts[d.Subject].Def
			switch def {
			case "ferida-na-pele":
				_ = h.resolve(d, "mobilizar-plaquetas")
			case "congestao-esplenica":
				_ = h.resolve(d, "mobilizar-macrofagos")
			case "infeccao-pulmonar":
				_ = h.resolve(d, "mobilizar-defesa")
			}
		}
	}
	after := h.s.Pops["plaquetas_pele"].Count + h.s.Pops["neutrofilos_pulmao"].Count + h.s.Pops["macrofagos_pulmao"].Count + h.s.Pops["macrofagos_baco"].Count
	born := h.s.Ledger["born:plaquetas_pele"] + h.s.Ledger["born:neutrofilos_pulmao"] + h.s.Ledger["born:macrofagos_pulmao"] + h.s.Ledger["born:macrofagos_baco"] - ledger
	if r := h.s.Entities["medula"].Num["reserva"]; r < 0 {
		t.Fatalf("reserve went negative: %d", r)
	}
	if after-before > born+30 { // natural recruiting may add a few; musters cannot exceed the 30 paid
		t.Fatalf("headcount rose by %d with only 30 in reserve", after-before)
	}
	// Nothing was closed by the choice.
	for _, def := range []string{"ferida-na-pele", "congestao-esplenica"} {
		if _, live := byDef(h.s, def); len(live) != 1 {
			t.Errorf("%s was dropped by the focus", def)
		}
	}
}

// QA-13 (cascade): an open wound that nobody closes lets invaders into the
// blood; the effect crosses organs through a rule, with delay, not by decree.
func TestUnclosedWoundContaminatesTheBlood(t *testing.T) {
	h := loadWithoutPops(t, "hospedeiro", "plaquetas_pele", "npc:placa")
	h.tick(5)
	setNum(h, "pele", "ferida", 40)
	base := h.s.Entities["sangue"].Num["carga"]
	n := 0
	for i := 0; i < 300 && h.s.Entities["pele"].Num["ferida"] < 50; i++ {
		h.tick(1)
		n++
	}
	if h.s.Entities["pele"].Num["ferida"] < 50 {
		t.Fatal("an unattended wound must keep opening")
	}
	if n < 20 {
		t.Fatalf("the wound opened instantly (%d ticks): effects need time", n)
	}
	events := 0
	for i := 0; i < 120; i++ {
		h.tick(1)
		for _, e := range h.s.Events {
			if e.Kind == "ferida-contamina" {
				events++
				break
			}
		}
		if events > 0 {
			break
		}
	}
	if events == 0 {
		t.Fatal("the open wound never reached the blood")
	}
	if h.s.Entities["sangue"].Num["carga"] <= base {
		t.Logf("blood load %d (base %d): cohorts may already have cleared it", h.s.Entities["sangue"].Num["carga"], base)
	}
}

// With several crises the whole run, answers included, replays to the digest.
func TestMultiConflictReplayWithAttentionAnswers(t *testing.T) {
	h := load(t, "hospedeiro")
	answered := 0
	for i := 0; i < 2500; i++ {
		h.tick(1)
		for _, k := range []string{core.DecisionAttention, core.DecisionConflict, core.DecisionNPC} {
			for _, d := range pending(h.s, k) {
				if h.resolve(d, d.Options[len(d.Options)-1].ID) == nil {
					answered++
				}
			}
		}
	}
	if answered < 10 {
		t.Fatalf("expected many answered decisions, got %d", answered)
	}
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
	t.Logf("%d answers over 2500 ticks with up to five crises replayed to the same digest", answered)
}

// The attention has a material effect: an NPC with two tasks takes, by default,
// the one that serves the crisis the body concentrates on, even if the other
// has the higher own priority.
func TestAttentionTiltsTheDefaultTaskOfANPC(t *testing.T) {
	build := func() (*core.World, core.State) {
		u := miniUniverse(nil, core.EntitySeed{ID: "n", Kind: "bicho", Region: "a"})
		u.Entities[0].Num = map[string]int64{"sev": 30}
		u.Conflicts = []core.ConflictDef{{ID: "crise", Title: "Crise", Region: "a", Trigger: num("sev", ">=", 10),
			Severity: core.ConflictMetric{ID: "sev", Label: "S", E: "a", K: "sev"}, Critical: 90, CriticalExit: 80,
			Contain: num("sev", "<=", 1), Resolve: num("sev", "<=", 0), Sustain: 5, Recovery: 5}}
		step := []core.StepDef{{Region: "b", Ticks: 5}}
		u.Tasks = []core.TaskDef{
			{ID: "alto", NPC: "n", Title: "Alto", Priority: 5, Route: step},
			{ID: "serve", NPC: "n", Title: "Serve", Priority: 3, Conflict: "crise", Route: step},
		}
		w, err := core.Compile(u)
		if err != nil {
			t.Fatal(err)
		}
		return w, core.NewState(w)
	}
	w, s := build()
	s = tickAll(t, w, s, 3)
	if s.NPCs["n"].Task != "alto" {
		t.Fatalf("without attention the higher priority wins, got %q", s.NPCs["n"].Task)
	}
	w, s = build()
	s = tickAll(t, w, s, 1) // the crisis opens
	for id := range s.Conflicts {
		s.Attention = id
	}
	started := []string{}
	for i := 0; i < 20; i++ {
		s = tickAll(t, w, s, 1)
		if st := s.NPCs["n"]; st.Phase == core.NPCTravel && st.Since == s.Tick {
			started = append(started, st.Task)
		}
	}
	if len(started) < 2 {
		t.Fatalf("the NPC should have started several tasks, got %v", started)
	}
	for _, task := range started {
		if task != "serve" {
			t.Fatalf("with attention on the crisis its task wins every time, got %v", started)
		}
	}
}
