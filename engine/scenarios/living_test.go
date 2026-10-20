package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// happen waits for the director to propose a happening and picks it, as
// the advisor (Jev) would.
func (h *harness) happen(id string) {
	h.t.Helper()
	for i := 0; i < 80; i++ {
		if d, ok := worldDecision(h); ok {
			for _, o := range d.Options {
				if o.ID == id {
					h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: id, Provider: "test"})
					return
				}
			}
		}
		h.tick(1)
	}
	h.t.Fatalf("happening %s never proposed", id)
}

func (h *harness) events2(kind string, holder core.ID) []core.Event {
	out := []core.Event{}
	for _, e := range h.s.Events {
		if e.Kind == kind && e.Holder == holder {
			out = append(out, e)
		}
	}
	return out
}

// The quest window changes mid-quest: the bandits stole the cargo, so
// "Bandidos na estrada" (C) becomes "A carga de Lia" (B) with a new goal.
func TestQuestEvolvesWithTheWorld(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.happen("bandidos")
	q := h.steer("p1", "estrada-segura")
	if q.Rank != "C" || q.Objective == "" || q.Reward == "" {
		t.Fatalf("the system window must show rank, objective and reward: %+v", q)
	}
	h.accept("p1", q)
	q, _ = h.quest("p1", "estrada-segura")
	if q.Stage != "carga-roubada" || q.Rank != "B" || q.Title != "A carga de Lia" {
		t.Fatalf("quest should evolve to the robbed-cargo stage: %+v", q)
	}
	up := h.events2("quest-updated", "p1")
	if len(up) == 0 || up[0].Data["rankFrom"] != "C" || up[0].Data["rank"] != "B" {
		t.Fatalf("the client must be told the quest changed rank: %+v", up)
	}
	h.move("p1", "estrada")
	h.mustAct("adapter", "p1", "enfrentar-bandidos", nil)
	if q, _ := h.quest("p1", "estrada-segura"); q.State != "active" {
		t.Fatalf("beating bandits is no longer enough after the robbery: %+v", q)
	}
	h.mustAct("adapter", "p1", "recuperar-mercadorias", nil)
	if q, _ := h.quest("p1", "estrada-segura"); q.State != "done" {
		t.Fatalf("returning the goods completes the evolved quest: %+v", q)
	}
}

// Two players search for Nino; the one who finds him first succeeds and
// the other fails, because the world changed.
func TestQuestFailsWhenSomeoneElseSolvesIt(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.happen("crianca-perdida")
	for _, p := range []core.ID{"p1", "p2"} {
		h.accept(p, h.steer(p, "nino-perdido"))
		h.move(p, "floresta")
	}
	h.mustAct("adapter", "p2", "achar-crianca", nil)
	h.tick(1)
	if q, _ := h.quest("p2", "nino-perdido"); q.State != "done" {
		t.Fatalf("p2 found Nino: %+v", q)
	}
	if q, _ := h.quest("p1", "nino-perdido"); q.State != "failed" {
		t.Fatalf("p1 arrived too late and must fail: %+v", q)
	}
}

// A rescue has a time limit; when it runs out the quest fails with consequences.
func TestQuestTimeLimit(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.happen("desabamento")
	q := h.steer("p1", "resgate-mina")
	h.accept("p1", q)
	q, _ = h.quest("p1", "resgate-mina")
	if q.Deadline == 0 {
		t.Fatal("accepted timed quest must carry a deadline")
	}
	before := h.s.Entities["vila"].Num["health"]
	for h.s.Tick < q.Deadline {
		h.tick(1)
	}
	if q, _ := h.quest("p1", "resgate-mina"); q.State != "failed" {
		t.Fatalf("the rescue must fail at the deadline: %+v", q)
	}
	if h.s.Entities["vila"].Num["health"] >= before+20 {
		t.Fatal("failure effects should apply")
	}
}

// Refusing has consequences; a deed reveals a quest at once.
func TestRefusalAndImmediateOffer(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	q := h.steer("p1", "javali")
	respect := h.s.Entities["kael"].Num["respect"]
	h.do(core.Command{Kind: "decline", Origin: "player", Actor: "p1", Quest: q.Key})
	if h.s.Entities["kael"].Num["respect"] != respect-1 && respect > 0 {
		t.Fatal("declining Kael lowers his respect")
	}
	// A deed reveals a quest in the same step: mining gives ore, and Brom
	// immediately asks for the first forging.
	h2 := load(t, "valdoria")
	h2.join("p1")
	h2.move("p1", "mina")
	h2.tick(int(h2.w.U.Limits.DecisionTimeout) + 1)
	for _, x := range h2.s.Quests {
		if x.State == "offered" {
			h2.do(core.Command{Kind: "decline", Origin: "player", Actor: "p1", Quest: x.Key})
		}
	}
	d := h2.do(core.Command{Kind: "act", Origin: "adapter", Actor: "p1", Action: "minerar"})
	offered := false
	for _, e := range d.Events {
		offered = offered || e.Kind == "quest-offered"
	}
	for _, x := range d.Decisions {
		offered = offered || x.Kind == "offer"
	}
	if !offered {
		t.Fatalf("the deed should reveal a quest in the same step: %+v", d.Events)
	}
}

// Overgeared-style hidden class: only one player inherits the legendary
// smith; the other becomes an apprentice with their own path.
func TestLegendaryClassIsUnique(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.happen("mercador-misterioso")
	h.tick(1) // the hidden scenario opens with the world
	for _, p := range []core.ID{"p1", "p2"} {
		h.move(p, "mina")
		for i := 0; i < 3; i++ {
			h.mustAct("adapter", p, "minerar", nil)
		}
		h.move(p, "vila")
		for i := 0; i < 3; i++ {
			h.mustAct("player", p, "forjar", nil)
		}
	}
	h.move("p2", "ruinas")
	h.mustAct("adapter", "p2", "explorar-ruinas", nil)
	if h.s.Entities["p2"].Tag["class"] != "Ferreiro Lendario" {
		t.Fatalf("p2 should inherit the legacy: %+v", h.s.Entities["p2"].Tag)
	}
	h.move("p1", "ruinas")
	h.mustAct("adapter", "p1", "explorar-ruinas", nil)
	if h.s.Entities["p1"].Tag["class"] != "" {
		t.Fatal("the legendary class is unique")
	}
	if !h.fact("p1", "apprentice", "p1", "brom") {
		t.Fatal("the late player becomes an apprentice")
	}
	if q := h.steer("p1", "aprendiz"); q.Rank != "B" {
		t.Fatalf("apprentice continuation: %+v", q)
	}
}
