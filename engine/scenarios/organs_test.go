package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// organ describes what the tests need to know about each of the next organs (E3).
type organ struct {
	region, dungeon, niche, gene string
	verbs                        map[string]string // verb -> the number it moves and the direction (in the organ's entity)
	maturity                     int64
	seal, title                  string
}

var organs = []organ{
	{"baco", "centro-germinativo", "centro-germinativo-oculto", "nucleo-reativo", map[string]string{"reciclar-hemacia": "hemacias", "capturar-antigeno": "antigenos"}, 18 * pace, "selo-do-baco", "primeira-selecao"},
	{"intestino", "criptas-profundas", "cripta-de-lieberkuhn", "enzima-voraz", map[string]string{"nutrir-microbiota": "microbiota", "repelir-invasor": "microbiota"}, 20 * pace, "selo-do-intestino", "primeira-muralha"},
	{"rim", "nefrons", "glomerulo-oculto", "membrana-espessa", map[string]string{"filtrar-ureia": "ureia", "equilibrar-sal": "sodio"}, 22 * pace, "selo-do-rim", "primeiro-calculo"},
}

// intoOrgan walks p to the organ the way the world asks for: the venule's niche gives the key to the aorta, and every organ opens from it.
func (h *harness) intoOrgan(p core.ID, region string) {
	h.t.Helper()
	h.move(p, "sangue")
	if !hasGene(h, p, "citoesqueleto-elastico") {
		findNiche(h, p, "bolsa-da-venula")
	}
	h.move(p, "coracao")
	h.move(p, "aorta")
	h.move(p, core.ID(region))
}

// matureIn gives p the maturity the organ's dungeon asks for, and brings them in.
func (h *harness) matureIn(p core.ID, o organ) {
	h.t.Helper()
	h.mustAct("adapter", p, "absorver-nutriente", nil)
	h.move(p, "sangue")
	for i := 0; i < 80 && h.s.Entities[p].Num["maturidade"] < o.maturity; i++ {
		h.fight(p, 1)
	}
	if h.s.Entities[p].Num["maturidade"] < o.maturity {
		h.t.Fatalf("%s never reached maturity %d", p, o.maturity)
	}
	h.intoOrgan(p, o.region)
}

func (h *harness) organNum(region, key string) int64 { return h.s.Entities[core.ID(region)].Num[key] }

// E3: each organ's verbs only work inside it, only the game server confirms them, and they move the organ's numbers.
func TestOrganVerbsNeedTheirOrgan(t *testing.T) {
	for _, o := range organs {
		h := load(t, "hospedeiro")
		h.join("p1")
		for verb := range o.verbs {
			if err := h.act("adapter", "p1", verb, nil); !isRejected(err) {
				t.Fatalf("%s outside the %s should be refused, got %v", verb, o.region, err)
			}
		}
		h.intoOrgan("p1", o.region)
		for verb, key := range o.verbs {
			before := h.organNum(o.region, key)
			h.mustAct("adapter", "p1", verb, nil)
			if h.organNum(o.region, key) == before && before != 100 && before != 0 {
				t.Fatalf("%s did not move %s.%s (%d)", verb, o.region, key, before)
			}
			if err := h.act("player", "p1", verb, nil); !isRejected(err) {
				t.Fatalf("%s: only the game server confirms it, got %v", verb, err)
			}
		}
	}
}

// E3: the organs talk to each other: the spleen's recycled iron feeds the marrow, the gut pours food (and toxins) into the liver, the liver's
// toxins become the kidney's urea, and an overloaded kidney raises the pressure of the artery. Nobody acts for any of it, and the log replays.
func TestOrganChains(t *testing.T) {
	h := loadWithoutPops(t, "hospedeiro", "hepatocitos_figado", "flora_intestinal", "npc:entera", "npc:kupffer", "npc:nefra", "nefrons_rim") // the chain of the bare organs
	h.join("p1")
	h.intoOrgan("p1", "baco")
	for i := 0; i < 6; i++ {
		h.mustAct("adapter", "p1", "reciclar-hemacia", nil)
	}
	if h.organNum("medula", "ferro") < 5 {
		t.Fatalf("recycling hemoglobin gives iron to the marrow, got %d", h.organNum("medula", "ferro"))
	}
	reserve := h.organNum("medula", "reserva")
	liverToxin := h.organNum("figado", "toxina")
	pressure := h.organNum("aorta", "pressao")
	h.tick(150)
	if len(h.events("medula-usa-ferro")) == 0 || h.organNum("medula", "reserva") == reserve {
		t.Fatal("the marrow should use the recycled iron")
	}
	if len(h.events("intestino-despeja")) == 0 {
		t.Fatal("the gut should pour its food into the liver")
	}
	if h.organNum("rim", "ureia") <= 25 && len(h.events("rim-sobrecarregado")) == 0 {
		t.Fatalf("the liver's toxins should become the kidney's urea (urea %d, toxin %d -> %d)", h.organNum("rim", "ureia"), liverToxin, h.organNum("figado", "toxina"))
	}
	h.tick(900)
	if len(h.events("rim-sobrecarregado")) == 0 || h.organNum("aorta", "pressao") <= pressure {
		t.Fatalf("a kidney that cannot keep up should raise the artery's pressure (%d -> %d)", pressure, h.organNum("aorta", "pressao"))
	}
	if len(h.events("baco-congestionado")) == 0 {
		t.Fatal("old red cells nobody recycles should congest the spleen")
	}
	b := loadWithoutPops(t, "hospedeiro", "hepatocitos_figado", "flora_intestinal", "npc:entera", "npc:kupffer", "npc:nefra", "nefrons_rim")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying the organs' log gives another world")
	}
}

// E3: each organ has a unique niche that gives a gene to the first finder only, and a quest that closes on its deeds.
func TestOrganNichesAreUniqueAndQuestsClose(t *testing.T) {
	for _, o := range organs {
		h := load(t, "hospedeiro")
		h.join("p1", "p2")
		h.mustAct("adapter", "p1", "absorver-nutriente", nil)
		h.mustAct("adapter", "p2", "absorver-nutriente", nil)
		h.intoOrgan("p1", o.region)
		findNiche(h, "p1", o.niche)
		if !hasGene(h, "p1", o.gene) {
			t.Fatalf("%s should hand over %s", o.niche, o.gene)
		}
		h.intoOrgan("p2", o.region)
		findNiche(h, "p2", o.niche)
		if hasGene(h, "p2", o.gene) {
			t.Fatalf("%s is unique and belongs to its first finder", o.niche)
		}
		quest := map[string]string{"baco": "polpa-limpa", "intestino": "jardim-do-intestino", "rim": "filtro-do-corpo"}[o.region]
		verb := map[string]string{"baco": "reciclar-hemacia", "intestino": "nutrir-microbiota", "rim": "filtrar-ureia"}[o.region]
		q := h.steer("p1", quest)
		h.accept("p1", q)
		for i := 0; i < 8; i++ {
			h.mustAct("adapter", "p1", verb, nil)
		}
		h.tick(2)
		if got, _ := h.quest("p1", quest); got.State != "done" {
			t.Fatalf("%s: eight deeds should close the quest, state %q", o.region, got.State)
		}
	}
}

// E3: each organ's dungeon is entered from inside the organ by the mature, the run is procedural (its own rooms, opening and boss), it
// rewards and cleans the organ, and the first clear is unique.
func TestOrganDungeons(t *testing.T) {
	for _, o := range organs {
		h := load(t, "hospedeiro")
		h.join("p1", "p2")
		enter := map[string]core.ID{"dungeon": core.ID(o.dungeon)}
		if err := h.act("player", "p1", "entrar-masmorra", enter); err == nil {
			t.Fatalf("a newborn cannot enter %s", o.dungeon)
		}
		h.matureIn("p1", o)
		h.matureIn("p2", o)
		h.mustAct("player", "p1", "entrar-masmorra", enter)
		h.tick(6)
		run := h.dungeonView("p1").Run
		if run == nil || run.Dungeon != o.dungeon || run.State != "active" || len(run.Rooms) < 5 || len(run.Rooms) > 6 {
			t.Fatalf("%s: the run is active with 5 or 6 rooms, got %+v", o.dungeon, run)
		}
		kinds := []string{}
		for _, r := range run.Rooms {
			kinds = append(kinds, r.Kind)
		}
		if kinds[0] != "guard" || kinds[len(kinds)-1] != "boss" || slices.Contains(kinds[1:len(kinds)-1], "boss") {
			t.Fatalf("%s: a run opens on guard and closes on the boss, got %v", o.dungeon, kinds)
		}
		h.clearRun("p1")
		if got := h.skillIDs("p1"); !slices.Contains(got, o.seal) || !slices.Contains(got, o.title) {
			t.Fatalf("%s: the first clear gives the seal and the unique title, got %v", o.dungeon, got)
		}
		h.tick(7)
		h.mustAct("player", "p2", "entrar-masmorra", enter)
		h.tick(6)
		h.clearRun("p2")
		if got := h.skillIDs("p2"); !slices.Contains(got, o.seal) || slices.Contains(got, o.title) {
			t.Fatalf("%s: the second clear gets the seal only, got %v", o.dungeon, got)
		}
	}
}

// E3: the dungeons are procedural for every organ: runs differ, and the modifiers an organ offers follow its own state.
func TestOrganDungeonsDifferAndFollowTheOrgan(t *testing.T) {
	for _, o := range organs {
		h := load(t, "hospedeiro")
		seen := map[string]bool{}
		for i := 0; i < 8; i++ {
			p := core.ID("p" + string(rune('a'+i)))
			h.join(p)
			h.matureIn(p, o)
			h.mustAct("player", p, "entrar-masmorra", map[string]core.ID{"dungeon": core.ID(o.dungeon)})
			h.tick(6)
			ids := ""
			for _, r := range h.dungeonView(p).Run.Rooms {
				ids += r.ID + ","
			}
			seen[ids] = true
		}
		if len(seen) < 4 {
			t.Fatalf("%s: eight runs should differ, got %d distinct", o.dungeon, len(seen))
		}
	}
	h := load(t, "hospedeiro")
	h.join("p1")
	h.matureIn("p1", organs[0])
	set := func(e, key string, v int64) {
		ent := h.s.Entities[core.ID(e)]
		ent.Num[key] = v
		h.s.Entities[core.ID(e)] = ent
	}
	set("baco", "hemacias", 90)
	set("baco", "antigenos", 5)
	h.mustAct("player", "p1", "entrar-masmorra", map[string]core.ID{"dungeon": "centro-germinativo"})
	d, _ := h.pendingDungeonDecision("p1")
	got := modifierOptions(d)
	if !slices.Contains(got, "baco-congestionado") || slices.Contains(got, "polpa-limpa") || slices.Contains(got, "tolerancia") {
		t.Fatalf("a congested spleen offers its congestion, not the clean pulp nor tolerance, got %v", got)
	}
}
