package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

var cords = map[string]core.ID{"dungeon": "cordoes-hepaticos"}

// matureInLiver brings p to the liver with enough maturity for the cords (16).
func (h *harness) matureInLiver(p core.ID) {
	h.t.Helper()
	h.mustAct("adapter", p, "absorver-nutriente", nil)
	h.move(p, "sangue")
	h.fight(p, 9)
	findNiche(h, p, "bolsa-da-venula")
	h.move(p, "coracao")
	h.move(p, "aorta")
	h.move(p, "figado")
}

func (h *harness) setLiver(key string, v int64) {
	e := h.s.Entities["figado"]
	e.Num[key] = v
	h.s.Entities["figado"] = e
}

func modifierOptions(d core.Decision) []string {
	out := []string{}
	for _, o := range d.Options {
		out = append(out, o.ID)
	}
	slices.Sort(out)
	return out
}

// E3: the cords are entered from inside the liver, by the mature, and both dungeons are listed side by side.
func TestCordsNeedMaturityAndTheLiver(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	if err := h.act("player", "p1", "entrar-masmorra", cords); err == nil {
		t.Fatal("a newborn cannot enter the cords")
	}
	h.matureInLiver("p1")
	listed := map[string]bool{}
	for _, o := range h.dungeonView("p1").Available {
		listed[o.ID] = o.Eligible
	}
	if !listed["cordoes-hepaticos"] || listed["granuloma"] {
		t.Fatalf("in the liver only the cords are open, got %+v", listed)
	}
	h.move("p1", "aorta")
	if h.dungeonView("p1").Available[1].Eligible {
		t.Fatal("the entrance is in the liver, not in the aorta")
	}
}

// E3: the modifiers the cords offer depend on the state of the liver itself: the body decides what is possible.
func TestCordsModifiersFollowTheLiversState(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1")
	h.matureInLiver("p1")
	h.setLiver("toxina", 10)
	h.setLiver("glicogenio", 10)
	h.mustAct("player", "p1", "entrar-masmorra", cords)
	d, _ := h.pendingDungeonDecision("p1")
	if got := modifierOptions(d); !slices.Equal(got, []string{"bile-acida", "fibrose-ativa", "kupffer-aliadas"}) {
		t.Fatalf("a clean, poor liver offers these, got %v", got)
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "kupffer-aliadas", Provider: "test"})
	h.mustAct("player", "p1", "abandonar-masmorra", nil)
	h.tick(7)
	h.setLiver("toxina", 80)
	h.setLiver("glicogenio", 80)
	h.mustAct("player", "p1", "entrar-masmorra", cords)
	d, _ = h.pendingDungeonDecision("p1")
	if got := modifierOptions(d); !slices.Equal(got, []string{"bile-acida", "fibrose-ativa", "glicogenio-cheio", "toxinas-altas"}) {
		t.Fatalf("a loaded, rich liver offers these, got %v", got)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "kupffer-aliadas", Provider: "test"}); err == nil {
		t.Fatal("a modifier that does not apply now is refused")
	}
}

// E3: clearing the cords cleans the liver, the first clear is unique, and the run replays from the log.
func TestCordsClearCleansTheLiverAndFirstClearIsUnique(t *testing.T) {
	h := load(t, legacyDungeons)
	h.join("p1", "p2")
	h.matureInLiver("p1")
	h.matureInLiver("p2")
	h.mustAct("player", "p1", "entrar-masmorra", cords)
	h.tick(6)
	before := h.s.Entities["figado"].Num["toxina"]
	if run := h.dungeonView("p1").Run; run == nil || run.Dungeon != "cordoes-hepaticos" || run.State != "active" || len(run.Rooms) < 5 || len(run.Rooms) > 6 {
		t.Fatalf("the cords run is active with 5 or 6 rooms, got %+v", run)
	}
	h.clearRun("p1")
	if got := h.s.Entities["figado"].Num["toxina"]; got >= before {
		t.Fatalf("clearing the cords should clean the liver of toxin, %d -> %d", before, got)
	}
	if got := h.skillIDs("p1"); !slices.Contains(got, "selo-do-figado") || !slices.Contains(got, "primeiro-filtro") {
		t.Fatalf("the first clear gives the seal and the unique title, got %v", got)
	}
	h.tick(7)
	h.mustAct("player", "p2", "entrar-masmorra", cords)
	h.tick(6)
	h.clearRun("p2")
	if got := h.skillIDs("p2"); !slices.Contains(got, "selo-do-figado") || slices.Contains(got, "primeiro-filtro") {
		t.Fatalf("the second clear gets the seal only, got %v", got)
	}
	b := load(t, legacyDungeons)
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying the cords gives another world")
	}
}
