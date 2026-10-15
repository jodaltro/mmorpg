package journey

import (
	"encoding/json"
	"reflect"
	"testing"
)

func catalog(t *testing.T) Catalog {
	t.Helper()
	c, e := Load()
	if e != nil {
		t.Fatal(e)
	}
	return c
}
func step(t *testing.T, c Catalog, s State, w *World, k, id string) State {
	t.Helper()
	r, e := c.Step(s, *w, "test-actor", Action{k, id})
	if e != nil {
		t.Fatalf("%s/%s: %v", k, id, e)
	}
	*w = r.World
	return r.State
}
func TestVersionedCatalogAndInvalidDefinitions(t *testing.T) {
	c := catalog(t)
	if len(c.Regions) != 5 || len(c.Creatures) != 9 || len(c.Abilities) != 12 || len(c.Items) != 38 || len(c.NPCs) != 12 || len(c.Opportunities) != 31 {
		t.Fatal("content counts changed")
	}
	for _, kind := range []string{"duplicate", "missing-reference", "impossible-condition", "dependency-cycle", "unused-item", "invalid-reward", "invalid-effect"} {
		t.Run(kind, func(t *testing.T) {
			b, _ := json.Marshal(c)
			var bad Catalog
			json.Unmarshal(b, &bad)
			switch kind {
			case "duplicate":
				bad.Items = append(bad.Items, bad.Items[0])
			case "missing-reference":
				bad.Nodes[0].Region = "missing"
			case "impossible-condition":
				bad.Opportunities[0].Requires = []string{"talk:mira"}
				bad.Opportunities[0].Excludes = []string{"talk:mira"}
			case "dependency-cycle":
				bad.Opportunities[0].Requires = []string{"done:forest-observation"}
				bad.Opportunities[1].Requires = []string{"done:forest-sample"}
			case "unused-item":
				bad.Items = append(bad.Items, Item{ID: "unused", Use: "material"})
			case "invalid-reward":
				bad.Opportunities[0].Rewards = map[string]int{"corruption-sample": -1}
			case "invalid-effect":
				bad.Abilities[0].Effect = "decorative"
			}
			if bad.Validate() == nil {
				t.Fatal("invalid catalog accepted")
			}
		})
	}
}
func TestDiscoveryRoutesAndOptionalOpportunities(t *testing.T) {
	c := catalog(t)
	w := NewWorld()
	s := NewState()
	s = step(t, c, s, &w, "travel", "gray-forest")
	s = step(t, c, s, &w, "gather", "forest-tracks")
	s = step(t, c, s, &w, "talk", "orin")
	s = step(t, c, s, &w, "complete", "hunter-mark-training")
	if !s.Abilities["hunter-mark"] {
		t.Fatal("tracking did not unlock mark")
	}
	s = step(t, c, s, &w, "travel", "valdoria")
	s = step(t, c, s, &w, "talk", "lia")
	s = step(t, c, s, &w, "ignore", "silent-grove-route")
	s = step(t, c, s, &w, "travel", "gray-forest")
	s = step(t, c, s, &w, "travel", "echo-marsh")
	s = step(t, c, s, &w, "gather", "marsh-memory")
	s = step(t, c, s, &w, "talk", "ivo")
	s = step(t, c, s, &w, "complete", "silent-marsh-route")
	if !s.Abilities["silent-step"] || s.Opportunities["silent-grove-route"] != "ignored" {
		t.Fatal("alternative route blocked by ignoring")
	}
	empty := NewState()
	if len(empty.Knowledge) != 0 || len(empty.Relationships) != 0 {
		t.Fatal("NPC global knowledge leaked")
	}
}
func TestIllegalIntentLeavesInputsUnchanged(t *testing.T) {
	c := catalog(t)
	s, w := NewState(), NewWorld()
	before := clone(s)
	bw := NewWorld()
	_, e := c.Step(s, w, "actor", Action{"gather", "ancestral-glyph"})
	if e == nil || !reflect.DeepEqual(s, before) || !reflect.DeepEqual(w, bw) {
		t.Fatal("invalid extraction mutated inputs")
	}
	if _, e = c.Step(s, w, "actor", Action{"travel", "asterion"}); e == nil {
		t.Fatal("nonadjacent travel accepted")
	}
}
func TestDistinctCreatureMechanics(t *testing.T) {
	c := catalog(t)
	for _, id := range []string{"corrupted-wolf", "thorn-boar", "venom-spider", "cave-bat", "stone-sentinel", "burrow-crawler", "echo-wisp", "mire-hydra", "asterion-guardian"} {
		t.Run(id, func(t *testing.T) {
			x, _ := c.Creature(id)
			s := NewState()
			s.Region = x.Region
			w := NewWorld()
			s = step(t, c, s, &w, "challenge", id)
			before := s.Encounter.HP
			s = step(t, c, s, &w, "attack", "")
			switch x.Pattern {
			case "flying":
				if s.Encounter.HP != before || s.Encounter.Range != 2 {
					t.Fatal("flying creature reachable by melee")
				}
			case "armored":
				if before-s.Encounter.HP != 6 {
					t.Fatal("armor ineffective")
				}
			case "ethereal":
				if before-s.Encounter.HP != 6 {
					t.Fatal("ethereal resistance ineffective")
				}
			case "shield":
				if before-s.Encounter.HP != 5 {
					t.Fatal("shield ineffective")
				}
			case "burrow":
				if s.Encounter.Phase != "hidden" {
					t.Fatal("burrow did not hide")
				}
			case "regenerate":
				if before-s.Encounter.HP != 14 {
					t.Fatal("hydra did not regenerate")
				}
			case "venom":
				s = step(t, c, s, &w, "guard", "")
				if s.Poison != 2 || s.HP >= 100-x.Damage/2 {
					t.Fatal("venom did not tick")
				}
			default:
				if s.Encounter.Phase != "preparing" {
					t.Fatal("missing telegraph")
				}
			}
		})
	}
}
func TestAllTwelveAbilitiesHaveFunctionalEffects(t *testing.T) {
	c := catalog(t)
	for _, ab := range c.Abilities {
		t.Run(ab.ID, func(t *testing.T) {
			s := NewState()
			s.Abilities[ab.ID] = true
			w := NewWorld()
			s.Region = "gray-forest"
			s.Equipment["tool"] = "alchemist-kit"
			s.Encounter = &Encounter{Creature: "corrupted-wolf", HP: 60, Phase: "preparing"}
			switch ab.Effect {
			case "weakness":
				s.Encounter.Phase = "exposed"
				s = step(t, c, s, &w, "attack", "")
				if s.Encounter.HP != 30 {
					t.Fatal("weakness bonus missing")
				}
			case "toxic":
				s.Poison = 3
				s = step(t, c, s, &w, "guard", "")
				if s.HP != 90 {
					t.Fatalf("toxin reduction missing: hp %d", s.HP)
				}
			case "extract":
				s.Encounter = nil
				s.Region = "echo-marsh"
				s.Facts["defeat:echo-wisp"] = true
				s = step(t, c, s, &w, "gather", "echo-extraction")
				if s.Inventory["echo-essence"] != 2 {
					t.Fatal("extraction failed")
				}
			case "sense":
				s.Encounter = nil
				s.Region = "asterion"
				s = step(t, c, s, &w, "gather", "ancestral-glyph")
				if !s.Facts["lore:glyph"] {
					t.Fatal("glyph not revealed")
				}
			default:
				if ab.Effect == "purify" {
					s.Poison = 3
					s.Encounter.Creature = "echo-wisp"
				}
				s = step(t, c, s, &w, "ability", ab.ID)
				if s.Cooldowns[ab.ID] == 0 {
					t.Fatal("cooldown not established")
				}
				switch ab.Effect {
				case "counter":
					if s.Encounter.HP != 35 || s.HP != 100 {
						t.Fatal("counter did not interrupt")
					}
				case "fracture":
					if !s.Encounter.Fractured {
						t.Fatal("fracture failed")
					}
				case "stealth", "seismic":
					if s.Encounter.Phase != "exposed" {
						t.Fatal("opening failed")
					}
				case "mark":
					if !s.Encounter.Marked {
						t.Fatal("mark failed")
					}
				case "burn":
					if s.Encounter.Burn != 2 || s.Encounter.HP != 42 {
						t.Fatal("combustion failed")
					}
				case "guard":
					if s.HP != 100 {
						t.Fatal("reinforced defense failed")
					}
				case "purify":
					if s.Poison != 0 || s.Encounter.HP != 30 {
						t.Fatal("purification failed")
					}
				}
			}
		})
	}
}
func TestEquipmentConsumptionAndReplayConditions(t *testing.T) {
	c := catalog(t)
	s := NewState()
	w := NewWorld()
	s.Inventory["healing-draught"] = 1
	s.Inventory["iron-blade"] = 1
	s.HP = 60
	s = step(t, c, s, &w, "use", "healing-draught")
	if s.HP != 95 || s.Inventory["healing-draught"] != 0 {
		t.Fatal("consumable integrity")
	}
	s = step(t, c, s, &w, "equip", "iron-blade")
	s = step(t, c, s, &w, "challenge", "training-dummy")
	s = step(t, c, s, &w, "attack", "")
	if s.Encounter.HP != 15 {
		t.Fatal("equipment has no effect")
	}
	s = step(t, c, s, &w, "dodge", "")
	s = step(t, c, s, &w, "attack", "")
	s = step(t, c, s, &w, "loot", "training-dummy")
	if len(s.Inventory) != 1 {
		t.Fatal("dummy granted resources")
	}
}
func TestHistoricalEventAuthorshipAndSharedConsequences(t *testing.T) {
	c := catalog(t)
	w := NewWorld()
	s := NewState()
	s.Region = "asterion"
	o, _ := c.Opportunity("asterion-beacon")
	for _, f := range o.Requires {
		s.Facts[f] = true
	}
	for k, n := range o.Costs {
		s.Inventory[k] = n
	}
	r, e := c.Step(s, w, "first", Action{"complete", o.ID})
	if e != nil {
		t.Fatal(e)
	}
	if r.World.Authors[o.Fact] != "first" || len(r.NewEvents) != 1 {
		t.Fatal("authorship missing")
	}
	if _, e = c.Step(s, r.World, "second", Action{"complete", o.ID}); e == nil {
		t.Fatal("world event repeated")
	}
	if len(w.Facts) != 0 {
		t.Fatal("shared input mutated")
	}
}
func TestScheduledConsequencesAndOpportunityCap(t *testing.T) {
	c := catalog(t)
	w := NewWorld()
	s := NewState()
	s.Region = "kharum"
	o, _ := c.Opportunity("mines-awakening")
	for _, f := range o.Requires {
		s.Facts[f] = true
	}
	for k, n := range o.Costs {
		s.Inventory[k] = n
	}
	s = step(t, c, s, &w, "complete", o.ID)
	if w.Facts[o.Fact] {
		t.Fatal("scheduled effect fired early")
	}
	s = step(t, c, s, &w, "tick", "")
	s = step(t, c, s, &w, "tick", "")
	if !w.Facts[o.Fact] || s.Opportunities[o.ID] != "completed" {
		t.Fatal("schedule did not execute")
	}
	s = step(t, c, s, &w, "tick", "")
	if len(w.Authors) != 1 {
		t.Fatal("duplicate scheduled effect")
	}
	for _, o := range c.Opportunities {
		for _, f := range o.Requires {
			s.Facts[f] = true
		}
		for k, n := range o.Costs {
			s.Inventory[k] += n
		}
	}
	s.Region = "valdoria"
	c.Refresh(&s, w)
	available := 0
	for _, v := range s.Opportunities {
		if v == "available" {
			available++
		}
	}
	if available > 3 {
		t.Fatal("opportunity cap exceeded")
	}
}
func TestCompetingScheduledWorldConsequenceReturnsReservedMaterialsOnce(t *testing.T) {
	c := catalog(t)
	w := NewWorld()
	a, b := NewState(), NewState()
	o, _ := c.Opportunity("mines-awakening")
	a.Region = "kharum"
	b.Region = "kharum"
	for _, f := range o.Requires {
		a.Facts[f] = true
		b.Facts[f] = true
	}
	for k, n := range o.Costs {
		a.Inventory[k] = n
		b.Inventory[k] = n
	}
	a = step(t, c, a, &w, "complete", o.ID)
	b = step(t, c, b, &w, "complete", o.ID)
	a = step(t, c, a, &w, "tick", "")
	a = step(t, c, a, &w, "tick", "")
	b = step(t, c, b, &w, "tick", "")
	b = step(t, c, b, &w, "tick", "")
	if b.Opportunities[o.ID] != "cancelled" || a.Opportunities[o.ID] != "completed" {
		t.Fatal("world schedule race states")
	}
	for k, n := range o.Costs {
		if b.Inventory[k] != n {
			t.Fatal("reservation not returned")
		}
	}
	b = step(t, c, b, &w, "tick", "")
	for k, n := range o.Costs {
		if b.Inventory[k] != n {
			t.Fatal("refund repeated")
		}
	}
}
