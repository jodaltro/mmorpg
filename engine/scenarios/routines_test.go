package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func whereIs(h *harness, id core.ID) (core.ID, string, string) {
	e := h.s.Entities[id]
	return e.Region, e.Tag["spot"], e.Tag["doing"]
}

func tickToHour(h *harness, hour int64) {
	for h.w.Hour(&h.s) != hour {
		h.tick(1)
	}
}

// The village has a day: people are somewhere in particular at each hour.
func TestRoutinesPutNpcsWhereTheirDayIs(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	tickToHour(h, 8)
	if r, sp, _ := whereIs(h, "mira"); r != "vila" || sp != "horta" {
		t.Fatalf("mira at 8h: %s/%s", r, sp)
	}
	if _, sp, _ := whereIs(h, "brom"); sp != "forja" {
		t.Fatalf("brom at 8h: %s", sp)
	}
	tickToHour(h, 13)
	if _, sp, _ := whereIs(h, "mira"); sp != "poco" {
		t.Fatalf("mira at 13h: %s", sp)
	}
	tickToHour(h, 18)
	if _, sp, _ := whereIs(h, "brom"); sp != "taverna" {
		t.Fatalf("brom at 18h: %s", sp)
	}
	if r, sp, _ := whereIs(h, "tomas"); r != "vila" || sp != "taverna" {
		t.Fatalf("tomas should come in to the tavern at 18h: %s/%s", r, sp)
	}
	tickToHour(h, 2)
	// Asleep, or hidden at home if he heard about wolves: either way, home.
	if _, sp, _ := whereIs(h, "nino"); sp != "casa-nino" {
		t.Fatalf("nino at 2h: %s", sp)
	}
	// The view shows where and what, never why.
	v, _ := h.w.View(&h.s, "p1", 5)
	for _, o := range v.Others {
		if o.ID == "nino" && (o.Spot != "casa-nino" || o.Doing == "") {
			t.Fatalf("view of nino: %+v", o)
		}
	}
}

// Overheard talk happens where the speakers are and follows their beliefs.
func TestChatterFollowsWhoIsThereAndWhatTheyKnow(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	tickToHour(h, 8)
	h.tick(6)
	var spots, ids = map[string]bool{}, map[string]bool{}
	for _, e := range h.s.Events {
		if e.Kind == "chatter" {
			spots[e.Data["spot"]], ids[e.Data["chatter"]] = true, true
			if !e.Public || e.Data["region"] == "" {
				t.Fatalf("chatter must be public with its region: %+v", e)
			}
		}
	}
	if !ids["horta-cenouras"] || !ids["portao-rotina"] {
		t.Fatalf("expected the garden and gate talk in the morning, got %v", ids)
	}
	if ids["poco-doentes"] || ids["poco-veneno"] || ids["taverna-lobos"] {
		t.Fatalf("talk about what nobody believes yet: %v", ids)
	}
	if spots["forja"] != true {
		t.Fatalf("brom talks at the forge in the morning: %v", spots)
	}
}
