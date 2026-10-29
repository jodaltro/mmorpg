package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func organOf(h *harness, observer core.ID, id string) *core.OrganView {
	v, _ := h.w.View(&h.s, observer, 10)
	for i := range v.Organs {
		if string(v.Organs[i].ID) == id {
			return &v.Organs[i]
		}
	}
	return nil
}

// 29/10/2026: every part of the body always has work to do, crisis or not. Entering any organ offers a calling for what the organ
// needs, the organ has a health that wears with time and mends with work, and what the player did there is shown back to them.
func TestEveryOrganHasHealthRoutineWorkAndOffersACalling(t *testing.T) {
	h := load(t, "hospedeiro")
	if len(h.w.U.Organs) != 12 {
		t.Fatalf("the twelve regions are organs, got %d", len(h.w.U.Organs))
	}
	for _, o := range h.w.U.Organs {
		g := load(t, "hospedeiro")
		g.joinAt("p1", core.ID(o.ID))
		v := callingOf(g, "p1")
		if v == nil || !strings.HasPrefix(v.Conflict, "organ:") && v.Conflict == "" || len(v.Offer) == 0 {
			t.Errorf("%s: entering it offers no calling: %+v", o.ID, v)
			continue
		}
		roles := map[string]bool{}
		for _, opt := range v.Offer {
			roles[opt.Role] = true
		}
		if len(v.Offer) > 1 && len(roles) != len(v.Offer) {
			t.Errorf("%s: the options must be of different roles: %+v", o.ID, v.Offer)
		}
		ov := organOf(g, "p1", o.ID)
		if ov == nil || ov.Health < 0 || ov.Health > 100 || len(ov.Metrics) == 0 {
			t.Errorf("%s: no health in the view: %+v", o.ID, ov)
		}
		// routine work exists for every verb the needs ask for and mends the wear
		opt := v.Offer[0]
		g.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(opt.ID)})
		var did int
		for _, a := range g.w.U.Actions {
			if !strings.HasPrefix(a.ID, "terreno-") || !strings.HasSuffix(a.ID, "-organ-"+o.ID) {
				continue
			}
			setNum(g, core.ID(o.ID), "desgaste", 50)
			if err := g.act("adapter", "p1", a.ID, nil); err != nil {
				continue
			}
			did++
			if g.s.Entities[core.ID(o.ID)].Num["desgaste"] >= 50 {
				t.Errorf("%s: routine work must mend the wear", a.ID)
			}
			g.tick(1)
		}
		if did == 0 {
			t.Errorf("%s: a %s cannot do any routine work here", o.ID, opt.Role)
		}
	}
}

func TestOrganWearGrowsAndWorkIsShownBackToThePlayer(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "figado")
	before := organOf(h, "p1", "figado").Health
	h.tick(160) // 20 wear steps
	if h.s.Entities["figado"].Num["desgaste"] < 15 {
		t.Fatalf("the tissue wears with time: %d", h.s.Entities["figado"].Num["desgaste"])
	}
	worn := organOf(h, "p1", "figado").Health
	if worn >= before {
		t.Fatalf("a worn organ is less healthy: %d -> %d", before, worn)
	}
	opts := callingOf(h, "p1").Offer
	for _, o := range opts {
		if o.Role == "limpeza" {
			h.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(o.ID)})
		}
	}
	h.mustAct("adapter", "p1", "terreno-limpar-organ-figado", nil)
	ov := organOf(h, "p1", "figado")
	if ov.Health <= worn || ov.Mine != 1 || len(ov.Deeds) != 1 || ov.Deeds[0].Action != "terreno-limpar-organ-figado" {
		t.Fatalf("the work mends the organ and is counted for the player: %+v", ov)
	}
	h.joinAt("p2", "figado")
	if other := organOf(h, "p2", "figado"); other == nil || other.Mine != 0 {
		t.Fatalf("another player did nothing there: %+v", other)
	}
}

func TestACallingStaysWhenACrisisOpensInTheOrganAndLeavesWithTheOrgan(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pele")
	h.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(callingOf(h, "p1").Offer[0].ID)})
	if r := h.s.Roles["p1"]; !strings.HasPrefix(r.Conflict, "organ:") {
		t.Fatalf("held in the organ routine: %+v", r)
	}
	setNum(h, "pele", "ferida", 60)
	for i := 0; i < 400 && strings.HasPrefix(h.s.Roles["p1"].Conflict, "organ:"); i++ {
		h.tick(1)
	}
	r, ok := h.s.Roles["p1"]
	if !ok || strings.HasPrefix(r.Conflict, "organ:") {
		t.Fatalf("when the crisis opens the calling follows it and stays: %+v", h.s.Roles)
	}
	h.move("p1", "sangue")
	h.tick(1)
	if _, ok := h.s.Roles["p1"]; ok && h.s.Roles["p1"].Region == "pele" {
		t.Fatal("leaving the organ releases the calling")
	}
}
