package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func setReserve(h *harness, v int64) {
	setNum(h, "medula", "reserva", v)
}

// Osteia (the stroma) works the marrow niche by herself: when the reserve is
// below what the body wants she anchors, passes vesicles to the stem cells and
// the reserve really grows; a full reserve leaves her patrolling the sinusoids.
func TestOsteiaFeedsTheMarrowNicheWithoutPlayers(t *testing.T) {
	h := load(t, "hospedeiro")
	setReserve(h, 10)
	start := h.s.Entities["medula"].Num["reserva"]
	fed := false
	for i := 0; i < 120; i++ {
		h.tick(1)
		if h.s.NPCs["estroma"].Task == "nutrir-nicho-medular" {
			fed = true
		}
	}
	if !fed || h.s.NPCs["estroma"].Done < 3 {
		t.Fatalf("Osteia never worked the niche: %+v", h.s.NPCs["estroma"])
	}
	if got := h.s.Entities["medula"].Num["reserva"]; got <= start+10 {
		t.Fatalf("the niche was fed but the reserve did not rise: %d -> %d", start, got)
	}
	setReserve(h, 100)
	for i := 0; i < 80; i++ {
		h.tick(1)
	}
	if st := h.s.NPCs["estroma"]; st.Task == "nutrir-nicho-medular" {
		t.Fatalf("with a full reserve she must not keep feeding it: %+v", st)
	}
}

// Without the stroma an emptied marrow stays empty: the new cohorts stop, and
// the crisis opens and escalates. With her, the same body recovers by itself
// and her work is credited to the crisis.
func TestMarrowExhaustionOpensEscalatesAndRecoversOnlyWithTheStroma(t *testing.T) {
	bare := loadWithoutPops(t, "hospedeiro", "npc:estroma", "npc:esplena")
	setReserve(bare, 0)
	opened := false
	var worst int64
	for i := 0; i < 400; i++ {
		bare.tick(1)
		_, live := byDef(bare.s, "medula-esgotada")
		opened = opened || len(live) > 0
		for _, c := range live {
			worst = max(worst, c.Peak)
		}
	}
	if !opened || worst < 70 {
		t.Fatalf("an emptied marrow with nobody to feed it must become a crisis (opened=%v peak=%d)", opened, worst)
	}

	h := load(t, "hospedeiro")
	setReserve(h, 0)
	resolved := false
	credited := false
	for i := 0; i < 900 && !resolved; i++ {
		h.tick(1)
		all, _ := byDef(h.s, "medula-esgotada")
		for _, c := range all {
			resolved = resolved || c.Phase == core.PhaseResolved
			for k, n := range c.Credit {
				if n > 0 && k != "" {
					credited = true
				}
			}
		}
	}
	if !resolved {
		t.Fatalf("with Osteia the marrow should recover: %+v reserve=%d", h.s.NPCs["estroma"], h.s.Entities["medula"].Num["reserva"])
	}
	if !credited {
		t.Fatal("the stroma's work must be credited to the crisis")
	}
}

// The chain of the plan (P12.2): old red cells pile up in the spleen, Esplena
// returns their iron to the marrow, the marrow turns iron into reserve and the
// reserve into new cells in the blood.
func TestSpleenIronMarrowReserveChain(t *testing.T) {
	h := loadWithoutPops(t, "hospedeiro", "npc:estroma") // only the iron can refill the reserve
	setNum(h, "baco", "hemacias", 90)
	setReserve(h, 20)
	h.tick(1)
	ironSeen := false
	reserveBefore := h.s.Entities["medula"].Num["reserva"]
	for i := 0; i < 200; i++ {
		h.tick(1)
		if h.s.Entities["medula"].Num["ferro"] > 0 {
			ironSeen = true
		}
	}
	if !ironSeen {
		t.Fatal("recycled iron never reached the marrow")
	}
	if got := h.s.Entities["baco"].Num["hemacias"]; got >= 90 {
		t.Fatalf("Esplena did not clear the spleen: %d", got)
	}
	if got := h.s.Entities["medula"].Num["reserva"]; got <= reserveBefore {
		t.Fatalf("the iron did not become reserve: %d -> %d", reserveBefore, got)
	}
}
