package scenarios

import (
	"slices"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// 28/10/2026: a class is what the crisis needs from you where you stand. The offer
// comes from the crisis's needs and from who already covers what, so the answer is not
// always the same class; the player chooses among a few options.

func callingOf(h *harness, p core.ID) *core.CallingView {
	v, _ := h.w.View(&h.s, p, 5)
	return v.Calling
}

func openSkinCrisis(t *testing.T) *harness {
	h := loadWithoutPops(t, "hospedeiro")
	setNum(h, "pele", "ferida", 80)
	h.tick(3)
	if _, live := byDef(h.s, "ferida-na-pele"); len(live) == 0 {
		t.Fatal("the skin crisis did not open")
	}
	return h
}

func TestTheOfferFollowsWhatTheCrisisNeedsAndWhoIsAlreadyThere(t *testing.T) {
	h := openSkinCrisis(t)
	h.joinAt("p1", "pele")
	h.joinAt("p2", "pele")
	h.joinAt("p3", "pele")
	h.joinAt("p4", "pele")
	h.joinAt("far", "medula")
	if v := callingOf(h, "far"); v == nil || !strings.HasPrefix(v.Conflict, "organ:") || len(v.Offer) == 0 {
		t.Fatalf("away from the crisis the organ's own routine offers the calling: %+v", v)
	}
	if err := h.act("player", "far", "assumir", map[string]core.ID{"calling": "neutrofilo"}); !isRejected(err) {
		t.Fatalf("a calling the organ does not offer must be rejected: %v", err)
	}
	v := callingOf(h, "p1")
	if len(v.Offer) < 2 || len(v.Offer) > 3 {
		t.Fatalf("a few options, not one and not a wall: %+v", v.Offer)
	}
	roles := map[string]bool{}
	for _, o := range v.Offer {
		if roles[o.Role] {
			t.Fatalf("two options for one role: %+v", v.Offer)
		}
		roles[o.Role] = true
	}
	if v.Offer[0].Role != "cura" || v.Offer[0].Missing != 3 {
		t.Fatalf("the skin needs healers first: %+v", v.Offer[0])
	}
	if err := h.act("player", "p1", "assumir", map[string]core.ID{"calling": "t-regulador"}); !isRejected(err) {
		t.Fatalf("a calling the crisis did not offer must be rejected: %v", err)
	}
	if err := h.act("adapter", "p1", "assumir", map[string]core.ID{"calling": core.ID(v.Offer[0].ID)}); !isRejected(err) {
		t.Fatalf("only the player chooses their calling: %v", err)
	}
	h.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(v.Offer[0].ID)})
	if e := h.s.Entities["p1"]; e.Tag["role"] != "cura" || e.Tag["form"] == "" {
		t.Fatalf("the calling is a tag on the player: %v", e.Tag)
	}
	for _, p := range []core.ID{"p2", "p3"} {
		o := callingOf(h, p).Offer
		h.mustAct("player", p, "assumir", map[string]core.ID{"calling": core.ID(o[0].ID)})
	}
	// three healers are there: the fourth is asked for something else
	o := callingOf(h, "p4").Offer
	if o[0].Role == "cura" {
		t.Fatalf("the healers are covered: the next one must be offered another role: %+v", o)
	}
	if !o[0].Gap {
		t.Fatalf("the first option fills a missing role: %+v", o[0])
	}
	// inside one role the calling fewer hold comes first: the three healers split between two callings
	held := map[string]int{}
	for _, p := range []core.ID{"p1", "p2", "p3"} {
		held[h.s.Entities[p].Tag["calling"]]++
	}
	if len(held) < 2 {
		t.Fatalf("the offer should spread the callings of a role: %v", held)
	}
}

func TestACallingEndsWhenThePlayerLeavesOrTheCrisisEnds(t *testing.T) {
	h := openSkinCrisis(t)
	h.joinAt("p1", "pele")
	o := callingOf(h, "p1").Offer
	h.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(o[0].ID)})
	if len(h.s.Roles) != 1 {
		t.Fatal("the calling was not recorded")
	}
	h.move("p1", "sangue")
	h.tick(1)
	if len(h.s.Roles) != 0 || h.s.Entities["p1"].Tag["calling"] != "" {
		t.Fatalf("leaving the crisis returns the player to the base form: %v %v", h.s.Roles, h.s.Entities["p1"].Tag)
	}
	if len(h.events("calling-released")) != 1 {
		t.Fatal("the release is announced once")
	}
	h.move("p1", "pele")
	o = callingOf(h, "p1").Offer
	h.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(o[0].ID)})
	setNum(h, "pele", "ferida", 0)
	for i := 0; i < 3000 && strings.HasPrefix(h.s.Roles["p1"].Conflict, "conflict:"); i++ {
		h.tick(1)
	}
	if r, ok := h.s.Roles["p1"]; !ok || r.Conflict != "organ:pele" {
		t.Fatalf("a resolved crisis leaves the calling with the organ's routine: %+v", h.s.Roles)
	}
	h.move("p1", "sangue")
	h.tick(1)
	if r, ok := h.s.Roles["p1"]; ok && r.Conflict == "organ:pele" {
		t.Fatal("leaving the organ releases the calling")
	}
}

func TestEveryCrisisOffersAtLeastTwoDifferentRolesAndTheOfferIsDeterministic(t *testing.T) {
	h := load(t, "hospedeiro")
	for _, c := range h.w.U.Conflicts {
		if len(c.Needs) < 2 {
			t.Errorf("%s needs a single role: nobody would have a choice", c.ID)
		}
		for _, n := range c.Needs {
			if !slices.ContainsFunc(h.w.U.Callings, func(cd core.CallingDef) bool { return cd.Role == n.Role }) {
				t.Errorf("%s needs %s and no calling answers it", c.ID, n.Role)
			}
		}
	}
	run := func() string {
		g := openSkinCrisis(t)
		g.joinAt("p1", "pele")
		g.joinAt("p2", "pele")
		g.mustAct("player", "p1", "assumir", map[string]core.ID{"calling": core.ID(callingOf(g, "p1").Offer[0].ID)})
		g.mustAct("player", "p2", "assumir", map[string]core.ID{"calling": core.ID(callingOf(g, "p2").Offer[0].ID)})
		g.tick(20)
		return g.s.Digest()
	}
	if run() != run() {
		t.Fatal("callings must replay to the same digest")
	}
}
