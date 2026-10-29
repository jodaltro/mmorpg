package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// 28/10/2026: besides beating invaders and touching what drifts, a player helps a crisis by carrying
// something to it (fibrin to the breach of the skin, lactate to a neuron). The game server confirms the
// delivery with an action; the engine moves the crisis's numbers and credits whoever carried it.
func TestEveryCrisisCanBeHelpedByCarryingSomethingToIt(t *testing.T) {
	h := load(t, "hospedeiro")
	for _, c := range h.w.U.Conflicts {
		var act *core.ActionDef
		for i, a := range h.w.U.Actions {
			if !strings.HasPrefix(a.ID, "entregar-") {
				continue
			}
			for _, e := range a.Effects {
				if e.Op == "contribute" && e.Rule == c.ID {
					act = &h.w.U.Actions[i]
				}
			}
		}
		if act == nil {
			t.Errorf("%s has nothing to carry to it", c.ID)
			continue
		}
		g := load(t, "hospedeiro")
		region := act.Requires.In.Region
		g.joinAt("p1", core.ID(region))
		g.joinAt("far", "medula")
		if region != "medula" {
			if err := g.act("adapter", "far", act.ID, nil); !isRejected(err) {
				t.Errorf("%s: a delivery away from the organ must be rejected: %v", act.ID, err)
			}
		}
		if err := g.act("player", "p1", act.ID, nil); !isRejected(err) {
			t.Errorf("%s: only the game server confirms a delivery: %v", act.ID, err)
		}
		if c.Severity.Of != 0 { // the crisis is bad enough to need it
			setNum(g, c.Severity.E, c.Severity.K, c.Severity.Of-50)
		} else {
			setNum(g, c.Severity.E, c.Severity.K, 50)
		}
		before := severityOf(g, c.Severity)
		g.mustAct("adapter", "p1", act.ID, nil)
		after := severityOf(g, c.Severity)
		better := after < before
		t.Logf("%-22s %-24s in %-9s severity %d -> %d", c.ID, act.ID, region, before, after)
		if !better {
			t.Errorf("%s: delivering %s must ease the crisis (%d -> %d)", c.ID, act.ID, before, after)
		}
	}
}

func severityOf(h *harness, m core.ConflictMetric) int64 {
	v := h.s.Entities[m.E].Num[m.K]
	if m.Of != 0 {
		return m.Of - v
	}
	return v
}

// 29/10/2026, the long game: one player cleared the lung in half a minute because every kill the game server
// confirmed counted. A deed of a crisis now counts once per cooldown for each player.
func TestADeedOfACrisisCountsOncePerCooldownForEachPlayer(t *testing.T) {
	h := load(t, "hospedeiro")
	h.joinAt("p1", "pulmao")
	h.joinAt("p2", "pulmao")
	setNum(h, "pulmao", "carga", 60)
	cd := core.Tick(0)
	for _, a := range h.w.U.Actions {
		if a.ID == "conter-infeccao-pulmonar" {
			cd = a.Cooldown
		}
	}
	if cd < 1 {
		t.Fatal("killing in the lung must have a cooldown")
	}
	h.mustAct("adapter", "p1", "conter-infeccao-pulmonar", nil)
	if err := h.act("adapter", "p1", "conter-infeccao-pulmonar", nil); !isRejected(err) {
		t.Fatalf("a second kill in the same moment must not count again: %v", err)
	}
	h.mustAct("adapter", "p2", "conter-infeccao-pulmonar", nil) // another player is not held back by p1
	h.tick(int(cd))
	h.mustAct("adapter", "p1", "conter-infeccao-pulmonar", nil)
}

// 29/10/2026: carrying was too easy to do instead of one's calling. Each role has its own work in the terrain of a crisis
// (breaking a barricade, healing wounded cells, cleaning debris, cooling a hot spot, marking a hidden sign, pushing a block);
// the engine rejects it without the role and it eases the crisis more than a delivery does.
func TestTerrainWorkBelongsToTheRoleAndBeatsCarrying(t *testing.T) {
	roles := []string{"combate", "limpeza", "cura", "controle", "marcacao"}
	h := load(t, "hospedeiro")
	for _, c := range h.w.U.Conflicts {
		covered := map[string]bool{}
		for _, a := range h.w.U.Actions {
			if !strings.HasPrefix(a.ID, "terreno-") || !strings.HasSuffix(a.ID, "-"+c.ID) {
				continue
			}
			region := ""
			if a.Requires.All != nil && a.Requires.All[0].In != nil {
				region = a.Requires.All[0].In.Region
			}
			g := load(t, "hospedeiro")
			g.joinAt("p1", core.ID(region))
			if c.Severity.Of != 0 {
				setNum(g, c.Severity.E, c.Severity.K, c.Severity.Of-50)
			} else {
				setNum(g, c.Severity.E, c.Severity.K, 50)
			}
			if err := g.act("adapter", "p1", a.ID, nil); !isRejected(err) {
				t.Errorf("%s: without a calling the terrain work must be rejected: %v", a.ID, err)
			}
			allowed := 0
			for _, r := range roles {
				k := load(t, "hospedeiro")
				k.joinAt("p1", core.ID(region))
				if c.Severity.Of != 0 {
					setNum(k, c.Severity.E, c.Severity.K, c.Severity.Of-50)
				} else {
					setNum(k, c.Severity.E, c.Severity.K, 50)
				}
				k.s.Entities["p1"].Tag["role"] = r
				before := severityOf(k, c.Severity)
				if err := k.act("adapter", "p1", a.ID, nil); err != nil {
					continue
				}
				allowed++
				covered[r] = true
				if severityOf(k, c.Severity) >= before {
					t.Errorf("%s as %s must ease the crisis", a.ID, r)
				}
			}
			if allowed == 0 {
				t.Errorf("%s: no role can do it", a.ID)
			}
		}
		for _, n := range c.Needs {
			if !covered[n.Role] {
				t.Errorf("%s needs %s but that role has no terrain work", c.ID, n.Role)
			}
		}
	}
}
