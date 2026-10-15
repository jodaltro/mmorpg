package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"mmorpg/authority/journey"
	"os"
)

func main() {
	seed := flag.Int64("seed", 505000, "Reproducible root seed")
	per := flag.Int("per-profile", 20, "Journeys per profile")
	steps := flag.Int("steps", 240, "Maximum confirmed actions per journey")
	output := flag.String("output", "../../Docs/Validation/m05-simulation.json", "Report destination")
	flag.Parse()
	if *per < 1 || *per > 1000 || *steps < 1 || *steps > 2000 {
		os.Exit(1)
	}
	c, e := journey.Load()
	if e != nil {
		fmt.Println("invalid catalog")
		os.Exit(1)
	}
	r, e := c.RunSimulations(*seed, *per, *steps)
	if e != nil {
		fmt.Println("simulation invariant failed:", e)
		os.Exit(1)
	}
	b, _ := json.MarshalIndent(r, "", "  ")
	if os.WriteFile(*output, b, 0600) != nil {
		os.Exit(1)
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"journeys": len(r.Journeys), "seed": r.Seed, "stateConflicts": r.StateConflicts, "duplicateConsequences": r.DuplicateConsequences, "unreachedOpportunities": r.UnreachedOpportunities, "monopolizedOpportunities": r.MonopolizedOpportunities, "roleOutcomeDistance": r.RoleOutcomeDistance, "samePolicyDistance": r.SamePolicyDistance, "sharedHistoricalProof": r.SharedHistoricalProof, "profiles": r.Profiles})
}
