package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// 28/10/2026: crises were over before a player could get there (the lung in half a
// minute, the tumor and the wound the moment they opened). Left to itself the body
// now takes minutes to contain a crisis, so going to help is worth it; it still gets
// out of trouble on its own.
func TestACrisisAsksForHelpForMinutesWhenNobodyComes(t *testing.T) {
	h := load(t, "hospedeiro")
	demanding := map[string]core.Tick{} // instance -> ticks it asked for attention
	contained := map[string]bool{}
	for i := 0; i < 9000; i++ {
		h.tick(1)
		for _, id := range sortedConflictIDs(h.s) {
			c := h.s.Conflicts[id]
			if c.Phase == core.PhaseActive || c.Phase == core.PhaseCritical {
				if !contained[id] {
					demanding[id]++
				}
			} else {
				contained[id] = true
			}
		}
	}
	byDef := map[string][]core.Tick{}
	for id, n := range demanding {
		if contained[id] {
			byDef[h.s.Conflicts[id].Def] = append(byDef[h.s.Conflicts[id].Def], n)
		}
	}
	if len(byDef) < 4 {
		t.Fatalf("the body must contain several kinds of crisis on its own: %v", byDef)
	}
	for def, ns := range byDef {
		sum := core.Tick(0)
		for _, n := range ns {
			sum += n
		}
		mean := sum / core.Tick(len(ns))
		t.Logf("%-22s contained %2d times, asked for help %3d ticks on average (%.1f min)", def, len(ns), mean, float64(mean)*float64(h.w.U.TickSeconds)/60)
		if mean < 45 { // three minutes at four seconds a tick
			t.Errorf("%s is over too soon on its own: %d ticks on average", def, mean)
		}
	}
}
