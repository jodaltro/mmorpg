package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func nv(h *harness, e core.ID, k string) int64 { return h.s.Entities[e].Num[k] }

// runUntil ticks until stop() holds or max ticks pass, and returns the ticks used.
func runUntil(h *harness, max int, stop func() bool) int {
	for i := 1; i <= max; i++ {
		h.tick(1)
		if stop() {
			return i
		}
	}
	return max
}

func resolvedOf(h *harness, def string) bool {
	all, _ := byDef(h.s, def)
	for _, c := range all {
		if c.Phase == core.PhaseResolved {
			return true
		}
	}
	return false
}

func openedOf(h *harness, def string) bool {
	all, _ := byDef(h.s, def)
	return len(all) > 0
}

func creditedBy(h *harness, def string, npc string) bool {
	all, _ := byDef(h.s, def)
	for _, c := range all {
		for k, n := range c.Credit {
			if n > 0 && strings.HasPrefix(k, npc+"|") {
				return true
			}
		}
	}
	return false
}

// P12.3: liver and kidney. Toxins the liver cannot clear become urea; when the
// cells that filter are gone the kidney is overloaded; with them the same
// overload clears much faster, and the work is credited to the crisis.
func TestKidneyOverloadCascadesFromTheLiverAndNefraClearsIt(t *testing.T) {
	bare := loadWithoutPops(t, "hospedeiro", "hepatocitos_figado", "npc:kupffer", "nefrons_rim", "npc:nefra")
	setNum(bare, "figado", "toxina", 100)
	runUntil(bare, 3000, func() bool { return openedOf(bare, "sobrecarga-renal") })
	if !openedOf(bare, "sobrecarga-renal") {
		t.Fatalf("a liver that cannot clear toxins must end up overloading the kidney (urea %d)", nv(bare, "rim", "ureia"))
	}

	slow := loadWithoutPops(t, "hospedeiro", "nefrons_rim", "npc:nefra")
	setNum(slow, "rim", "ureia", 90)
	withoutHelp := runUntil(slow, 1500, func() bool { return resolvedOf(slow, "sobrecarga-renal") })
	fast := load(t, "hospedeiro")
	setNum(fast, "rim", "ureia", 90)
	withHelp := runUntil(fast, 1500, func() bool { return resolvedOf(fast, "sobrecarga-renal") })
	if !resolvedOf(fast, "sobrecarga-renal") || withHelp >= withoutHelp {
		t.Fatalf("Nefra and the nephrons must clear the overload faster: %d ticks with, %d without", withHelp, withoutHelp)
	}
	if !creditedBy(fast, "sobrecarga-renal", "nefra") {
		t.Fatal("the filtering must be credited to the crisis")
	}
}

// P12.4: gut. Entera feeds the flora so a collapse is a short crisis, and she
// passes nutrients from the gut to the blood.
func TestEnteraRestoresTheFloraAndFeedsTheBlood(t *testing.T) {
	bare := loadWithoutPops(t, "hospedeiro", "flora_intestinal", "npc:entera")
	setNum(bare, "intestino", "microbiota", 5)
	bare.tick(300)
	if nv(bare, "intestino", "microbiota") >= 45 {
		t.Fatalf("with no flora and no Entera the gut must stay in dysbiosis: %d", nv(bare, "intestino", "microbiota"))
	}
	h := loadWithoutPops(t, "hospedeiro", "flora_intestinal")
	setNum(h, "intestino", "microbiota", 5)
	runUntil(h, 800, func() bool { return resolvedOf(h, "disbiose-intestinal") })
	if !resolvedOf(h, "disbiose-intestinal") || !creditedBy(h, "disbiose-intestinal", "entera") {
		t.Fatalf("Entera alone must bring the flora back and be credited (microbiota %d)", nv(h, "intestino", "microbiota"))
	}

	g := load(t, "hospedeiro")
	setNum(g, "intestino", "alimento", 90)
	setNum(g, "sangue", "glicose", 20)
	peak := int64(0)
	for i := 0; i < 80; i++ {
		g.tick(1)
		peak = max(peak, nv(g, "sangue", "glicose"))
	}
	if peak <= 40 {
		t.Fatalf("nutrients must pass from the gut to the blood: glucose peaked at %d", peak)
	}
}

// P12.5: lymph node. The antigens of the spleen reach the node and become
// memory; regulation costs tolerance; when tolerance breaks the reaction is a
// crisis that ends only as tolerance returns.
func TestLymphNodeLearnsAndRegulationCostsTolerance(t *testing.T) {
	h := load(t, "hospedeiro")
	setNum(h, "baco", "antigenos", 80)
	h.tick(400)
	if nv(h, "linfonodo", "memoria") < 4 {
		t.Fatalf("antigens from the spleen must become memory in the node: %d", nv(h, "linfonodo", "memoria"))
	}

	r := load(t, "hospedeiro")
	setNum(r, "linfonodo", "tolerancia", 100)
	setNum(r, "corpo", "inflamacao", 100)
	spent := false
	for i := 0; i < 80; i++ {
		r.tick(1)
		setNum(r, "corpo", "inflamacao", 100)
		if nv(r, "linfonodo", "tolerancia") <= 90 {
			spent = true
		}
	}
	if !spent || r.s.NPCs["regina"].Done < 2 {
		t.Fatalf("Regina must work the storm and pay for it in tolerance: %+v tolerance=%d", r.s.NPCs["regina"], nv(r, "linfonodo", "tolerancia"))
	}
	if nv(r, "linfonodo", "tolerancia") < 25 {
		t.Fatalf("she must keep a reserve of tolerance instead of burning all of it: %d", nv(r, "linfonodo", "tolerancia"))
	}

	b := load(t, "hospedeiro")
	setNum(b, "linfonodo", "tolerancia", 8)
	setNum(b, "corpo", "inflamacao", 90)
	b.tick(2)
	if !openedOf(b, "reacao-exagerada") {
		t.Fatal("broken tolerance with high inflammation must open the overreaction crisis")
	}
	// The storm eases (inflammation stays moderate) and tolerance climbs back by itself until the crisis closes.
	runUntil(b, 900, func() bool {
		setNum(b, "corpo", "inflamacao", 50)
		return resolvedOf(b, "reacao-exagerada")
	})
	if !resolvedOf(b, "reacao-exagerada") {
		t.Fatalf("tolerance returns by itself, so the crisis must end (tolerance %d)", nv(b, "linfonodo", "tolerancia"))
	}
}

// P12.6: brain. Low blood oxygen starves it and glia shortens the recovery.
func TestBrainStarvesWithoutOxygenAndGliaSpeedsTheRecovery(t *testing.T) {
	h := load(t, "hospedeiro")
	for i := 0; i < 150; i++ {
		setNum(h, "sangue", "oxigenio", 10)
		h.tick(1)
	}
	if nv(h, "cerebro", "energia") > 55 || !openedOf(h, "sofrimento-cerebral") {
		t.Fatalf("a brain without oxygen must lose energy and suffer: energy %d", nv(h, "cerebro", "energia"))
	}
	slow := loadWithoutPops(t, "hospedeiro", "glia_cerebro", "npc:gliana")
	setNum(slow, "cerebro", "energia", 15)
	setNum(slow, "cerebro", "residuos", 60)
	without := runUntil(slow, 1500, func() bool { return resolvedOf(slow, "sofrimento-cerebral") })
	fast := load(t, "hospedeiro")
	setNum(fast, "cerebro", "energia", 15)
	setNum(fast, "cerebro", "residuos", 60)
	with := runUntil(fast, 1500, func() bool { return resolvedOf(fast, "sofrimento-cerebral") })
	if !resolvedOf(fast, "sofrimento-cerebral") || with >= without || !creditedBy(fast, "sofrimento-cerebral", "gliana") {
		t.Fatalf("glia must shorten the crisis and be credited: %d ticks with, %d without", with, without)
	}
}

// P12.6: a tumor takes territory and grows with inflammation until the NK
// cells contain it.
func TestTumorTakesTerritoryAndNKCellsContainIt(t *testing.T) {
	free := loadWithoutPops(t, "hospedeiro", "nk_corpo", "npc:nika")
	setNum(free, "tumor", "massa", 12)
	setNum(free, "corpo", "inflamacao", 50)
	free.tick(300)
	if nv(free, "tumor", "massa") < 40 {
		t.Fatalf("with no NK cells the tumor must grow: %d", nv(free, "tumor", "massa"))
	}
	h := load(t, "hospedeiro")
	setNum(h, "tumor", "massa", 12)
	setNum(h, "corpo", "inflamacao", 50)
	runUntil(h, 600, func() bool { return resolvedOf(h, "tumor-intestinal") })
	if !resolvedOf(h, "tumor-intestinal") || !creditedBy(h, "tumor-intestinal", "nika") || nv(h, "tumor", "massa") != 0 {
		t.Fatalf("Nika and the NK cells must clear the tumor and be credited: mass %d", nv(h, "tumor", "massa"))
	}
}

func forceBody(h *harness) {
	setNum(h, "pele", "ferida", 80)
	setNum(h, "figado", "toxina", 100)
	setNum(h, "baco", "hemacias", 95)
	setNum(h, "rim", "ureia", 90)
	setNum(h, "linfonodo", "tolerancia", 8)
	setNum(h, "corpo", "inflamacao", 85)
	setNum(h, "cerebro", "energia", 20)
	setNum(h, "tumor", "massa", 15)
	setNum(h, "intestino", "microbiota", 5)
	setNum(h, "medula", "reserva", 5)
}

// P12.7: cascades. Everything goes wrong at once: the engine keeps several
// crises alive together, deterministically; different cells work on different
// crises and the body gets out of it by itself.
func TestEveryOrganInCrisisAtOnceIsDeterministicAndRecoverable(t *testing.T) {
	defs := []string{"ferida-na-pele", "sobrecarga-hepatica", "congestao-esplenica", "sobrecarga-renal", "reacao-exagerada", "sofrimento-cerebral", "tumor-intestinal", "disbiose-intestinal", "medula-esgotada"}
	run := func() (*harness, int) {
		h := load(t, "hospedeiro")
		forceBody(h)
		concurrent := 0
		for i := 0; i < 2500; i++ {
			h.tick(1)
			live := 0
			for _, d := range defs {
				_, l := byDef(h.s, d)
				live += len(l)
			}
			concurrent = max(concurrent, live)
		}
		return h, concurrent
	}
	a, concurrent := run()
	b, _ := run()
	if a.s.Digest() != b.s.Digest() {
		t.Fatal("the same body in the same trouble must evolve identically")
	}
	if concurrent < 6 {
		t.Fatalf("expected at least six crises alive together, saw %d", concurrent)
	}
	closed, workers := 0, map[string]bool{}
	for _, d := range defs {
		if resolvedOf(a, d) {
			closed++
		}
		all, _ := byDef(a.s, d)
		for _, c := range all {
			for k := range c.Credit {
				if i := strings.LastIndex(k, "|"); i > 0 {
					workers[k[:i]] = true
				}
			}
		}
	}
	if closed < 7 {
		t.Fatalf("the body must get out of it by itself: %d of %d crises closed", closed, len(defs))
	}
	if len(workers) < 6 {
		t.Fatalf("different cells must cooperate across the crises, saw %v", workers)
	}
	t.Logf("%d crises at once, %d closed, %d different cells credited", concurrent, closed, len(workers))
}
