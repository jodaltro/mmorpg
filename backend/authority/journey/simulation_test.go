package journey

import (
	"encoding/json"
	"slices"
	"testing"
)

func TestJourneySimulationReplayAndRoleDifferences(t *testing.T) {
	c := catalog(t)
	a, e := c.Simulate("mixed", 505000, 240)
	if e != nil {
		t.Fatal(e)
	}
	b, e := c.Simulate("mixed", 505000, 240)
	if e != nil {
		t.Fatal(e)
	}
	ba, _ := json.Marshal(a)
	bb, _ := json.Marshal(b)
	if string(ba) != string(bb) {
		t.Fatal("same seed/intent policy did not replay")
	}
	ignored, e := c.Simulate("ignores-opportunities", 505000, 240)
	if e != nil {
		t.Fatal(e)
	}
	if len(ignored.Abilities) != 0 || len(ignored.Completed) != 0 || len(ignored.Regions) != 5 || len(ignored.Ignored) < 3 || ignored.Facts < 15 {
		t.Fatal("ignoring optional opportunities blocked exploration or granted skills")
	}
	if len(a.Abilities) < 8 || distance(outcome(a), outcome(ignored)) < .5 {
		t.Fatal("role decisions did not yield distinct journeys")
	}
}
func TestSimulationReachabilityAndNoSingleProfileMonopoly(t *testing.T) {
	c := catalog(t)
	r, e := c.RunSimulations(505000, 2, 240)
	if e != nil {
		t.Fatal(e)
	}
	if len(r.UnreachedOpportunities) > 0 || len(r.MonopolizedOpportunities) > 0 {
		t.Fatal("unreached/monopolized content", r.UnreachedOpportunities, r.MonopolizedOpportunities)
	}
	if r.RoleOutcomeDistance <= r.SamePolicyDistance || r.DuplicateConsequences != 0 || r.StateConflicts != 0 || !r.SharedHistoricalProof {
		t.Fatal("simulation quality gate failed")
	}
	if len(r.SharedCohort) != 6 || r.HistoricalAuthors["world:asterion-beacon"] != "mixed" {
		t.Fatal("shared-world cohort did not retain unique authorship")
	}
	for _, j := range r.SharedCohort {
		if j.Profile != "mixed" && slices.Contains(j.Completed, "asterion-beacon") {
			t.Fatal("historical event repeated in same world")
		}
	}
	for _, p := range r.Profiles {
		if p.Profile == "mixed" && !slices.Contains(p.Completed, "asterion-beacon") {
			t.Fatal("historical event unreachable in actual legal journey")
		}
	}
}
func TestEquipmentPolicyDoesNotOscillateAndLootHasRegionalScope(t *testing.T) {
	c := catalog(t)
	s := NewState()
	w := NewWorld()
	s.Inventory["mining-pick"] = 1
	s.Inventory["alchemist-kit"] = 1
	s.Equipment["tool"] = "alchemist-kit"
	if actionScore("mixed", c, s, w, Action{"equip", "mining-pick"}, map[string]int{}) >= 0 {
		t.Fatal("irrelevant tool switch preferred")
	}
	s.Encounter = &Encounter{Creature: "corrupted-wolf", HP: 0, Phase: "defeated"}
	if _, e := c.Step(s, w, "test", Action{"loot", "corrupted-wolf"}); e == nil {
		t.Fatal("loot collected from a different region")
	}
}
