package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func setNum(h *harness, ent core.ID, k string, v int64) {
	e := h.s.Entities[ent]
	e.Num[k] = v
	h.s.Entities[ent] = e
}

func helpEvents(s core.State, kind string) int {
	n := 0
	for _, e := range s.Events {
		if e.Kind == kind {
			n++
		}
	}
	return n
}

// Nobody is playing and four named cells still work: each walks its own
// route, the work changes the world, and it does so every time.
func TestSocietyWorksWithoutPlayers(t *testing.T) {
	h := load(t, "hospedeiro")
	seen := map[core.ID]map[core.ID]bool{}
	for i := 0; i < 900; i++ {
		h.tick(1)
		for _, id := range []core.ID{"rubra", "neva", "dendra", "macra"} {
			if seen[id] == nil {
				seen[id] = map[core.ID]bool{}
			}
			seen[id][h.s.Entities[id].Region] = true
		}
	}
	for _, id := range []core.ID{"rubra", "neva", "dendra", "macra"} {
		st := h.s.NPCs[id]
		t.Logf("%s done=%d failed=%d replans=%d phase=%s regions=%d", id, st.Done, st.Failed, st.Replans, st.Phase, len(seen[id]))
		if st.Done < 3 {
			t.Errorf("%s barely worked: %+v", id, st)
		}
	}
	for _, id := range []core.ID{"rubra", "neva", "dendra"} {
		if len(seen[id]) < 2 {
			t.Errorf("%s never left %v", id, seen[id])
		}
	}
	if o := h.s.Entities["rubra"].Num["o2"]; o < 0 || o > 5 {
		t.Errorf("rubra's load out of range: %d", o)
	}
	for id, e := range h.s.Entities {
		for k, v := range e.Num {
			if v < 0 {
				t.Errorf("%s.%s negative: %d", id, k, v)
			}
		}
	}
	// Macra and Neva both did real work against the infection, on the record.
	credit := map[string]int64{}
	for _, c := range h.s.Conflicts {
		for k, v := range c.Credit {
			credit[k] += v
		}
	}
	if credit["macra|limpeza"] == 0 {
		t.Errorf("the macrophage left no record against the infection: %v", credit)
	}
}

// QA-02: Rubra is blocked by a real obstruction, asks for help only after
// waiting, only once, a confirmed deed opens the way, and she remembers who.
func TestRubraBlockedAsksForHelpAndRemembersWhoHelped(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	h.joinAt("p2", "pulmao")
	h.tick(30)
	// A strong, undefended infection chokes the capillaries.
	for _, id := range []string{"neutrofilos_pulmao", "macrofagos_pulmao"} {
		st := h.s.Pops[id]
		st.Count = 0
		h.s.Pops[id] = st
	}
	setNum(h, "medula", "reserva", 0)
	setNum(h, "sangue", "oxigenio", 40)
	setNum(h, "pulmao", "oxigenio", 90)
	setNum(h, "pulmao", "carga", 40)
	h.s.Facts["|foco|pulmao|"] = core.Fact{P: "foco", S: "pulmao", Cause: "test"}
	asked := false
	for i := 0; i < 120 && !asked; i++ {
		h.tick(1)
		setNum(h, "pulmao", "carga", max(h.s.Entities["pulmao"].Num["carga"], 26)) // keep it clogged
		setNum(h, "sangue", "oxigenio", min(h.s.Entities["sangue"].Num["oxigenio"], 60))
		setNum(h, "pulmao", "oxigenio", max(h.s.Entities["pulmao"].Num["oxigenio"], 80))
		asked = h.s.NPCs["rubra"].Phase == core.NPCSeekHelp
	}
	if !asked {
		t.Fatalf("rubra never asked for help: %+v", h.s.NPCs["rubra"])
	}
	req := h.s.Helps[h.s.NPCs["rubra"].Help]
	if req.Status != "open" || req.Need != "capilares-obstruidos" || !strings.Contains(req.Text, "Rubra") {
		t.Fatalf("request must carry the real cause: %+v", req)
	}
	if waited := req.Open - h.s.NPCs["rubra"].Blocked; waited < 4 {
		t.Fatalf("she must wait before asking, waited %d", waited)
	}
	h.tick(10)
	if helpEvents(h.s, "help-requested") != 1 || len(h.s.Helps) != 1 {
		t.Fatalf("one need, one request: %d events, %d requests", helpEvents(h.s, "help-requested"), len(h.s.Helps))
	}
	v2, _ := h.w.View(&h.s, "p2", 10)
	var seen bool
	for _, n := range v2.Society {
		seen = seen || n.ID == "rubra" && n.Help != nil && n.Help.Status == "open"
	}
	if !seen {
		t.Fatal("anyone present must be able to see who is asking, what and where")
	}
	// A client cannot answer for the world.
	if err := h.act("player", "p1", "conter-infeccao-pulmonar", nil); err == nil {
		t.Fatal("a client must not confirm the deed")
	}
	// p1's confirmed deeds clear the infection; nothing else does.
	for i := 0; i < 12 && h.s.Entities["pulmao"].Num["carga"] >= 8; i++ {
		h.do(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: "conter-infeccao-pulmonar", RequestID: "ev-" + strings.Repeat("x", i+1)})
	}
	h.tick(2)
	if helpEvents(h.s, "help-resolved") != 1 {
		t.Fatalf("resolved exactly once, got %d", helpEvents(h.s, "help-resolved"))
	}
	if r := h.s.Helps[req.ID]; r.Status != "resolved" || r.By != "p1" {
		t.Fatalf("p1 answered: %+v", r)
	}
	if h.s.Relations["rubra|p1"] != 3 || h.s.Relations["rubra|p2"] != 0 {
		t.Fatalf("only the one who helped is trusted: %v", h.s.Relations)
	}
	mem := h.s.TopMemories("rubra", "p1", 3)
	if len(mem) != 1 || mem[0].Kind != "ajuda-recebida" || mem[0].Seq == 0 {
		t.Fatalf("rubra must remember p1 with the event that proves it: %+v", mem)
	}
	v1, _ := h.w.View(&h.s, "p1", 10)
	v2, _ = h.w.View(&h.s, "p2", 10)
	mine, other := 0, 0
	for _, n := range v1.Society {
		if n.ID == "rubra" {
			mine = len(n.Memories)
		}
	}
	for _, n := range v2.Society {
		if n.ID == "rubra" {
			other = len(n.Memories)
		}
	}
	if mine != 1 || other != 0 {
		t.Fatalf("a memory is told only to the one it is about: %d/%d", mine, other)
	}
	// And she is on her way again, no longer asking.
	h.tick(10)
	if h.s.NPCs["rubra"].Phase == core.NPCSeekHelp || h.s.NPCs["rubra"].Help != "" {
		t.Fatalf("rubra must be working again: %+v", h.s.NPCs["rubra"])
	}
}

// Without help the request expires; no one is thanked and nobody is blamed.
func TestRubraGivesUpWhenNobodyComes(t *testing.T) {
	h := load(t, "hospedeiro")
	h.tick(30)
	for _, id := range []string{"neutrofilos_pulmao", "macrofagos_pulmao"} {
		st := h.s.Pops[id]
		st.Count = 0
		h.s.Pops[id] = st
	}
	setNum(h, "medula", "reserva", 0)
	setNum(h, "sangue", "oxigenio", 40)
	setNum(h, "pulmao", "oxigenio", 90)
	failed := int64(0)
	for i := 0; i < 400 && failed == 0; i++ {
		h.tick(1)
		setNum(h, "pulmao", "carga", max(h.s.Entities["pulmao"].Num["carga"], 30))
		setNum(h, "sangue", "oxigenio", min(h.s.Entities["sangue"].Num["oxigenio"], 60))
		setNum(h, "pulmao", "oxigenio", max(h.s.Entities["pulmao"].Num["oxigenio"], 80))
		failed = h.s.NPCs["rubra"].Failed
	}
	if failed == 0 {
		t.Fatalf("she must give up: %+v", h.s.NPCs["rubra"])
	}
	var expired int
	for _, r := range h.s.Helps {
		if r.Status == "expired" && r.By == "" {
			expired++
		}
	}
	if expired == 0 || helpEvents(h.s, "help-resolved") != 0 {
		t.Fatalf("expired=%d resolved events=%d", expired, helpEvents(h.s, "help-resolved"))
	}
	if m := h.s.TopMemories("rubra", "", 5); len(m) == 0 || m[0].Kind != "rota-interrompida" {
		t.Fatalf("she remembers the interrupted route: %+v", m)
	}
	for k, v := range h.s.Relations {
		if strings.HasPrefix(k, "rubra|") && v != 0 {
			t.Fatalf("no one helped, no relation moves: %s=%d", k, v)
		}
	}
}

// News travels only through someone who saw it, and only when they meet. A
// belief that was true can be corrected by looking again.
func TestSocietyNewsTravelsByMeetingAndFalseBeliefIsCorrected(t *testing.T) {
	h := load(t, "hospedeiro")
	for _, who := range []core.ID{"neva", "dendra"} {
		if _, ok := h.s.Beliefs[who]["|foco|pulmao|"]; ok {
			t.Fatalf("%s knows of the lung focus before anyone saw it", who)
		}
	}
	h.s.Facts["|foco|pulmao|"] = core.Fact{P: "foco", S: "pulmao", Cause: "test"}
	setNum(h, "pulmao", "carga", 30)
	sources := map[string]bool{}
	for i := 0; i < 60; i++ {
		h.tick(1)
		for _, who := range []core.ID{"neva", "dendra"} {
			if b, ok := h.s.Beliefs[who]["|foco|pulmao|"]; ok && b.Holds {
				sources[string(who)+":"+b.Source] = true
			}
		}
		setNum(h, "pulmao", "carga", max(h.s.Entities["pulmao"].Num["carga"], 30))
	}
	if !sources["dendra:observation"] {
		t.Fatalf("dendra saw it herself: %v", sources)
	}
	if !sources["neva:communication"] && !sources["neva:observation"] {
		t.Fatalf("neva learns by being told or by looking: %v", sources)
	}
	// The cause goes away. A cell that believed in it is corrected only by
	// looking again, never by the world's fact changing on its own.
	delete(h.s.Facts, "|foco|pulmao|")
	setNum(h, "pulmao", "carga", 0)
	corrected := false
	for i := 0; i < 80 && !corrected; i++ {
		h.tick(1)
		b, ok := h.s.Beliefs["neva"]["|foco|pulmao|"]
		corrected = ok && !b.Holds
	}
	if !corrected {
		t.Fatal("neva must update her belief after going to look")
	}
}

// A second NPC is told no when the key is taken: it replans, it does not pile
// on, and it still gets its turn.
func TestTasksReserveReplanAndDetour(t *testing.T) {
	step := func(r core.ID, n core.Tick, do ...core.Effect) core.StepDef {
		return core.StepDef{Region: r, Ticks: n, Doing: "indo", Do: do}
	}
	work := core.Effect{Op: "adjust", E: "a", K: "feito", D: 1}
	u := miniUniverse(nil,
		core.EntitySeed{ID: "n1", Kind: "bicho", Region: "a"},
		core.EntitySeed{ID: "n2", Kind: "bicho", Region: "a"},
		core.EntitySeed{ID: "c", Kind: "lugar"},
		core.EntitySeed{ID: "d", Kind: "lugar"})
	u.Tasks = []core.TaskDef{
		{ID: "t1", NPC: "n1", Title: "T1", Priority: 1, Reserve: "posto", Route: []core.StepDef{step("b", 3, work), step("a", 3)}},
		{ID: "t2", NPC: "n2", Title: "T2", Priority: 1, Reserve: "posto", Route: []core.StepDef{step("b", 3, work), step("a", 3)}},
		// n1's second task passes through d; when d is shut it goes straight to c.
		{ID: "t3", NPC: "n1", Title: "T3", Priority: 0, Cooldown: 50, When: num("sem-uso", "<", 1), Route: []core.StepDef{step("d", 2), step("c", 2, work)},
			Block: &core.BlockDef{Via: "d", When: num("fechado", ">=", 1), HelpAfter: 3, GiveUpAfter: 8, Need: "via", Say: "{self} não passa",
				Detour: []core.StepDef{step("c", 3, work)}}},
	}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	s := core.NewState(w)
	holders := 0
	for i := 0; i < 80; i++ {
		s = tickAll(t, w, s, 1)
		n := 0
		for _, st := range s.NPCs {
			if st.Task == "t1" || st.Task == "t2" {
				n++
			}
		}
		holders = max(holders, n)
	}
	if holders != 1 {
		t.Fatalf("the reserved post must never have %d holders", holders)
	}
	if s.NPCs["n1"].Done == 0 || s.NPCs["n2"].Done == 0 {
		t.Fatalf("both must get a turn (no starvation): n1=%+v n2=%+v", s.NPCs["n1"], s.NPCs["n2"])
	}
	if s.NPCs["n1"].Replans+s.NPCs["n2"].Replans == 0 {
		t.Fatal("the one who found the post taken must have replanned")
	}
	// Detour: shut the way and the NPC goes round, without any help request.
	w2, _ := core.Compile(u)
	s2 := core.NewState(w2)
	s2.Entities["a"].Num["fechado"] = 1
	s2 = tickAll(t, w2, s2, 30)
	if len(s2.Helps) != 0 {
		t.Fatalf("a way round exists, nobody should be asked: %v", s2.Helps)
	}
	if s2.NPCs["n1"].Done < 2 {
		t.Fatalf("n1 must have worked through the detour: %+v", s2.NPCs["n1"])
	}
}

func TestTasksRejectBadDefinitions(t *testing.T) {
	base := func() core.Universe {
		u := miniUniverse(nil, core.EntitySeed{ID: "n1", Kind: "bicho", Region: "a"})
		u.Tasks = []core.TaskDef{{ID: "t", NPC: "n1", Title: "T", Route: []core.StepDef{{Region: "b", Ticks: 1}}}}
		return u
	}
	if _, err := core.Compile(base()); err != nil {
		t.Fatalf("base must be valid: %v", err)
	}
	for name, mut := range map[string]func(*core.Universe){
		"no route":      func(u *core.Universe) { u.Tasks[0].Route = nil },
		"unknown npc":   func(u *core.Universe) { u.Tasks[0].NPC = "nada" },
		"player as npc": func(u *core.Universe) { u.Tasks[0].NPC = "p0" },
		"bad region":    func(u *core.Universe) { u.Tasks[0].Route[0].Region = "nada" },
		"negative leg":  func(u *core.Universe) { u.Tasks[0].Route[0].Ticks = -1 },
		"duplicate":     func(u *core.Universe) { u.Tasks = append(u.Tasks, u.Tasks[0]) },
		"block giveup<=help": func(u *core.Universe) {
			u.Tasks[0].Block = &core.BlockDef{Via: "b", HelpAfter: 5, GiveUpAfter: 5, Need: "x", Say: "y"}
		},
		"transfer without key": func(u *core.Universe) {
			u.Tasks[0].Route[0].Do = []core.Effect{{Op: "transfer", E: "a", To: "b", D: 1}}
		},
	} {
		u := base()
		mut(&u)
		if _, err := core.Compile(u); err == nil {
			t.Errorf("%s must be rejected", name)
		}
	}
}

// The whole society replays to the same digest from the command log.
func TestSocietyReplayDigest(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	h.tick(250)
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

// The view tells a client where each NPC is heading and how far along the leg
// is, so a client can draw real progress instead of a cosmetic timer.
func TestSocietyViewCarriesLegProgress(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	sawLeg := false
	for i := 0; i < 400; i++ {
		h.tick(1)
		v, ok := h.w.View(&h.s, "p1", 10)
		if !ok {
			t.Fatal("no view")
		}
		for _, n := range v.Society {
			if n.Phase == core.NPCTravel {
				if n.Dest == "" || n.Steps < 1 || n.Step >= n.Steps || n.Arrive < n.Since || n.Task == "" {
					t.Fatalf("a travelling NPC must expose its leg: %+v", n)
				}
				sawLeg = true
			}
			if n.Phase == core.NPCIdle && (n.Task != "" || n.Arrive != 0) {
				t.Fatalf("an idle NPC has no leg: %+v", n)
			}
		}
	}
	if !sawLeg {
		t.Fatal("nobody travelled in 400 ticks")
	}
}
