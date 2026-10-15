package journey

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
	"slices"
	"sort"
	"strings"
)

var Profiles = []string{"combatant", "explorer", "researcher", "collector", "mixed", "ignores-opportunities"}

type JourneyResult struct {
	Profile              string         `json:"profile"`
	Seed                 int64          `json:"seed"`
	Actions              []Action       `json:"actions"`
	Abilities            []string       `json:"abilities"`
	Regions              []string       `json:"regions"`
	Completed            []string       `json:"completed"`
	Ignored              []string       `json:"ignored"`
	Inventory            map[string]int `json:"inventory"`
	Relationships        map[string]int `json:"relationships"`
	Facts                int            `json:"facts"`
	AvailableButUnchosen []string       `json:"availableButUnchosen"`
	Digest               string         `json:"digest"`
}
type ProfileSummary struct {
	Profile        string   `json:"profile"`
	Count          int      `json:"count"`
	MeanAbilities  float64  `json:"meanAbilities"`
	MeanRegions    float64  `json:"meanRegions"`
	MeanCompleted  float64  `json:"meanCompleted"`
	MeanIgnored    float64  `json:"meanIgnored"`
	Abilities      []string `json:"abilities"`
	Completed      []string `json:"completed"`
	UniqueOutcomes int      `json:"uniqueOutcomes"`
}
type SimulationReport struct {
	Version                    int                 `json:"version"`
	Seed                       int64               `json:"seed"`
	Steps                      int                 `json:"steps"`
	Journeys                   []JourneyResult     `json:"journeys"`
	Profiles                   []ProfileSummary    `json:"profiles"`
	UnreachedOpportunities     []string            `json:"unreachedOpportunities"`
	OpportunityProfiles        map[string][]string `json:"opportunityProfiles"`
	MonopolizedOpportunities   []string            `json:"monopolizedOpportunities"`
	DuplicateConsequences      int                 `json:"duplicateConsequences"`
	StateConflicts             int                 `json:"stateConflicts"`
	RepetitiveNontravelActions int                 `json:"repetitiveNontravelActions"`
	RoleOutcomeDistance        float64             `json:"roleOutcomeDistance"`
	SamePolicyDistance         float64             `json:"samePolicyDistance"`
	SharedHistoricalProof      bool                `json:"sharedHistoricalProof"`
	SharedCohort               []JourneyResult     `json:"sharedCohort"`
	HistoricalAuthors          map[string]string   `json:"historicalAuthors"`
}

func keys(m map[string]bool) []string {
	a := []string{}
	for k, v := range m {
		if v {
			a = append(a, k)
		}
	}
	sort.Strings(a)
	return a
}
func allowed(profile string, c Catalog, s State, a Action) bool {
	if a.Kind == "tick" || a.Kind == "rest" || a.Kind == "retreat" || a.Kind == "travel" || a.Kind == "loot" || a.Kind == "attack" || a.Kind == "dodge" || a.Kind == "guard" || a.Kind == "approach" || a.Kind == "ability" || a.Kind == "use" || a.Kind == "equip" {
		return true
	}
	if a.Kind == "ignore" {
		return profile == "ignores-opportunities"
	}
	if a.Kind == "complete" {
		if profile == "ignores-opportunities" {
			return false
		}
		o, _ := c.Opportunity(a.Target)
		switch profile {
		case "combatant":
			return slices.Contains([]string{"weakness-reading", "hunter-mark", "counterattack", "reinforced-guard", "seismic-impact", "toxic-resistance"}, o.Ability) || slices.Contains([]string{"forge-blade", "forge-mail", "brew-healing"}, o.ID)
		case "explorer":
			return slices.Contains([]string{"silent-step", "ancestral-sense", "hunter-mark"}, o.Ability)
		case "collector":
			return o.Ability == "" || slices.Contains([]string{"fracturing-strike", "seismic-impact", "toxic-resistance", "silent-step", "extract-essence", "ancestral-sense"}, o.Ability)
		default:
			return true
		}
	}
	if a.Kind == "challenge" {
		if profile == "explorer" || profile == "ignores-opportunities" {
			return false
		}
		if profile == "researcher" {
			return slices.Contains([]string{"corrupted-wolf", "echo-wisp", "asterion-guardian", "training-dummy"}, a.Target)
		}
		return true
	}
	if a.Kind == "talk" {
		if profile == "combatant" {
			return slices.Contains([]string{"brann", "orin", "mira", "tessa", "nera", "helena"}, a.Target)
		}
		if profile == "explorer" {
			return slices.Contains([]string{"lia", "ivo", "enya", "soren", "orin"}, a.Target)
		}
		return true
	}
	if a.Kind == "gather" {
		if profile == "combatant" {
			return slices.Contains([]string{"forest-tracks", "forest-herbs", "forest-spring", "marsh-reeds"}, a.Target)
		}
		return true
	}
	return false
}
func actionScore(profile string, c Catalog, s State, w World, a Action, counts map[string]int) int {
	if !allowed(profile, c, s, a) {
		return -10000
	}
	active := s.Encounter != nil && s.Encounter.Phase != "defeated" && s.Encounter.Phase != "escaped"
	if active {
		e := s.Encounter
		x, _ := c.Creature(e.Creature)
		if a.Kind == "retreat" {
			if s.HP <= 15 {
				return 200
			}
			return -1000
		}
		if a.Kind == "use" {
			if s.HP < 45 && a.Target == "healing-draught" {
				return 140
			}
			return -20
		}
		if a.Kind == "ability" {
			ab, _ := c.Ability(a.Target)
			switch ab.Effect {
			case "mark":
				if e.Range > 0 {
					return 160
				}
			case "seismic":
				if e.Range > 0 || e.Phase == "hidden" {
					return 150
				}
			case "fracture":
				if (x.Pattern == "armored" || x.Pattern == "shield") && !e.Fractured {
					return 150
				}
			case "purify":
				if x.Pattern == "ethereal" && !e.Fractured || s.Poison > 0 {
					return 155
				}
			case "burn":
				if x.Pattern == "regenerate" && e.Burn == 0 && e.Phase != "preparing" {
					return 145
				}
			case "counter":
				if e.Phase == "preparing" {
					return 140
				}
			case "guard":
				if !s.Facts["practice:guard"] {
					return 145
				}
			}
			return 35
		}
		if a.Kind == "dodge" {
			return 120
		}
		if a.Kind == "guard" {
			if !s.Facts["practice:guard"] {
				return 125
			}
			return 10
		}
		if a.Kind == "approach" {
			return 105
		}
		if a.Kind == "attack" {
			return 100
		}
		return -1000
	}
	switch a.Kind {
	case "loot":
		return 200
	case "ignore":
		return 190
	case "complete":
		o, _ := c.Opportunity(a.Target)
		if o.Ability != "" && !s.Abilities[o.Ability] {
			return 150
		}
		if o.Shared {
			return 145
		}
		if len(o.Rewards) > 0 {
			return 135
		}
		return 40
	case "gather":
		if profile == "collector" {
			return 110
		}
		if profile == "explorer" {
			return 100
		}
		return 80
	case "talk":
		if profile == "researcher" {
			return 110
		}
		return 90
	case "challenge":
		if a.Target == "training-dummy" {
			if s.Facts["practice:dodge"] && s.Facts["practice:guard"] {
				return -1000
			}
			return 95
		}
		if profile == "combatant" {
			return 115
		}
		if s.HP < 35 {
			return -200
		}
		return 70
	case "equip":
		i, _ := c.Item(a.Target)
		if s.Equipment[i.Slot] == i.ID {
			return -1000
		}
		if i.Slot == "tool" {
			needPick := s.Region == "kharum" && (!s.Facts["node:iron-vein"] || !s.Facts["node:copper-vein"])
			if i.ID == "mining-pick" && !needPick || i.ID == "alchemist-kit" && needPick {
				return -1000
			}
		}
		return 120
	case "rest":
		if s.HP < 85 {
			return 130
		}
		return -1000
	case "use":
		if s.HP < 65 && a.Target == "healing-draught" {
			return 130
		}
		return -1000
	case "tick":
		if len(s.Pending) > 0 {
			return 130
		}
		return -1000
	case "travel":
		if !s.Facts["visited:"+a.Target] {
			return 65
		}
		return 20 - counts["travel:"+a.Target]%5
	}
	return -1000
}
func (c Catalog) Simulate(profile string, seed int64, steps int) (JourneyResult, error) {
	r, _, e := c.SimulateShared(profile, seed, steps, NewWorld())
	return r, e
}
func (c Catalog) SimulateShared(profile string, seed int64, steps int, world World) (JourneyResult, World, error) {
	if !slices.Contains(Profiles, profile) {
		return JourneyResult{}, world, fmt.Errorf("unknown profile")
	}
	rng := rand.New(rand.NewSource(seed))
	s := NewState()
	w := World{Facts: cloneMap(world.Facts), Authors: cloneMap(world.Authors)}
	counts := map[string]int{}
	seen := map[string]bool{}
	result := JourneyResult{Profile: profile, Seed: seed, Actions: []Action{}}
	for i := 0; i < steps; i++ {
		legal := c.LegalActions(s, w)
		best := -10000
		choices := []Action{}
		for _, a := range legal {
			score := actionScore(profile, c, s, w, a, counts)
			if score > best {
				best = score
				choices = []Action{a}
			} else if score == best {
				choices = append(choices, a)
			}
		}
		if len(choices) == 0 || best < -500 {
			break
		}
		a := choices[rng.Intn(len(choices))]
		change, e := c.Step(s, w, profile, a)
		if e != nil {
			return result, w, e
		}
		for _, f := range change.NewFacts {
			if s.Facts[f] {
				return result, w, fmt.Errorf("duplicate consequence")
			}
		}
		for _, id := range change.NewEvents {
			o, _ := c.Opportunity(id)
			if w.Facts[o.Fact] {
				return result, w, fmt.Errorf("duplicate historical event")
			}
		}
		for k, n := range change.State.Inventory {
			if n <= 0 || n > 1000000 {
				return result, w, fmt.Errorf("invalid inventory %s", k)
			}
		}
		if change.State.HP < 0 || change.State.HP > 100 {
			return result, w, fmt.Errorf("invalid hp")
		}
		visible := 0
		for id, status := range change.State.Opportunities {
			if status == "available" {
				visible++
			}
			if status == "completed" && !change.State.Facts["done:"+id] {
				return result, w, fmt.Errorf("completion without historical source")
			}
			if status == "ignored" && change.State.Facts["done:"+id] {
				return result, w, fmt.Errorf("conflicting opportunity states")
			}
		}
		if visible > 3 {
			return result, w, fmt.Errorf("opportunity cap violated")
		}
		for slot, id := range change.State.Equipment {
			i, ok := c.Item(id)
			if !ok || i.Slot != slot || change.State.Inventory[id] <= 0 {
				return result, w, fmt.Errorf("equipment without ownership")
			}
		}
		s, w = change.State, change.World
		result.Actions = append(result.Actions, a)
		counts[a.Kind+":"+a.Target]++
		for _, id := range change.Candidates {
			seen[id] = true
		}
	}
	result.Abilities = keys(s.Abilities)
	result.Regions = []string{}
	for _, r := range c.Regions {
		if s.Facts["visited:"+r.ID] {
			result.Regions = append(result.Regions, r.ID)
		}
	}
	sort.Strings(result.Regions)
	result.Completed = []string{}
	result.Ignored = []string{}
	for id, status := range s.Opportunities {
		if status == "completed" {
			result.Completed = append(result.Completed, id)
		}
		if status == "ignored" {
			result.Ignored = append(result.Ignored, id)
		}
	}
	sort.Strings(result.Completed)
	sort.Strings(result.Ignored)
	for id := range seen {
		if !slices.Contains(result.Completed, id) {
			result.AvailableButUnchosen = append(result.AvailableButUnchosen, id)
		}
	}
	sort.Strings(result.AvailableButUnchosen)
	result.Inventory = s.Inventory
	result.Relationships = s.Relationships
	result.Facts = len(s.Facts)
	b, _ := json.Marshal(result)
	sum := sha256.Sum256(b)
	result.Digest = hex.EncodeToString(sum[:])
	return result, w, nil
}
func outcome(r JourneyResult) []string {
	a := []string{}
	for _, id := range r.Abilities {
		a = append(a, "ability:"+id)
	}
	for _, id := range r.Completed {
		a = append(a, "opportunity:"+id)
	}
	for id, n := range r.Relationships {
		a = append(a, fmt.Sprintf("relationship:%s:%d", id, n))
	}
	sort.Strings(a)
	return a
}
func distance(a, b []string) float64 {
	u := map[string]bool{}
	inter := 0
	for _, x := range a {
		u[x] = true
	}
	for _, x := range b {
		if u[x] {
			inter++
		}
		u[x] = true
	}
	if len(u) == 0 {
		return 0
	}
	return 1 - float64(inter)/float64(len(u))
}
func (c Catalog) RunSimulations(seed int64, perProfile, steps int) (SimulationReport, error) {
	r := SimulationReport{Version: 1, Seed: seed, Steps: steps, OpportunityProfiles: map[string][]string{}, Journeys: []JourneyResult{}, Profiles: []ProfileSummary{}, UnreachedOpportunities: []string{}, MonopolizedOpportunities: []string{}}
	first := []JourneyResult{}
	ablated := []JourneyResult{}
	for pi, p := range Profiles {
		summary := ProfileSummary{Profile: p, Count: perProfile}
		abilities, completed, unique := map[string]bool{}, map[string]bool{}, map[string]bool{}
		for i := 0; i < perProfile; i++ {
			runSeed := seed + int64(i)
			j, e := c.Simulate(p, runSeed, steps)
			if e != nil {
				return r, e
			}
			r.Journeys = append(r.Journeys, j)
			if i == 0 {
				first = append(first, j)
				a, e := c.Simulate("mixed", seed+int64(pi), steps)
				if e != nil {
					return r, e
				}
				ablated = append(ablated, a)
			}
			summary.MeanAbilities += float64(len(j.Abilities))
			summary.MeanRegions += float64(len(j.Regions))
			summary.MeanCompleted += float64(len(j.Completed))
			summary.MeanIgnored += float64(len(j.Ignored))
			for _, id := range j.Abilities {
				abilities[id] = true
			}
			for _, id := range j.Completed {
				completed[id] = true
			}
			unique[strings.Join(outcome(j), "|")] = true
			actionCounts := map[string]int{}
			for _, a := range j.Actions {
				if a.Kind != "travel" && a.Kind != "attack" && a.Kind != "dodge" && a.Kind != "approach" && a.Kind != "ability" {
					actionCounts[a.Kind+":"+a.Target]++
				}
			}
			for _, n := range actionCounts {
				if n > 3 {
					r.RepetitiveNontravelActions += n - 3
				}
			}
		}
		summary.MeanAbilities /= float64(perProfile)
		summary.MeanRegions /= float64(perProfile)
		summary.MeanCompleted /= float64(perProfile)
		summary.MeanIgnored /= float64(perProfile)
		summary.Abilities = keys(abilities)
		summary.Completed = keys(completed)
		summary.UniqueOutcomes = len(unique)
		r.Profiles = append(r.Profiles, summary)
		for id := range completed {
			r.OpportunityProfiles[id] = append(r.OpportunityProfiles[id], p)
		}
		_ = pi
	}
	for _, o := range c.Opportunities {
		ps := r.OpportunityProfiles[o.ID]
		if len(ps) == 0 {
			r.UnreachedOpportunities = append(r.UnreachedOpportunities, o.ID)
		}
		if len(ps) == 1 {
			r.MonopolizedOpportunities = append(r.MonopolizedOpportunities, o.ID)
		}
	}
	sort.Strings(r.UnreachedOpportunities)
	sort.Strings(r.MonopolizedOpportunities)
	pairs := 0
	for i := range first {
		for j := i + 1; j < len(first); j++ {
			r.RoleOutcomeDistance += distance(outcome(first[i]), outcome(first[j]))
			r.SamePolicyDistance += distance(outcome(ablated[i]), outcome(ablated[j]))
			pairs++
		}
	}
	r.RoleOutcomeDistance /= float64(pairs)
	r.SamePolicyDistance /= float64(pairs)
	// Same shared world: a second actor benefits from an authored beacon without inheriting facts.
	w := NewWorld()
	author := NewState()
	author.Region = "asterion"
	o, _ := c.Opportunity("asterion-beacon")
	for _, f := range o.Requires {
		author.Facts[f] = true
	}
	for k, n := range o.Costs {
		author.Inventory[k] = n
	}
	event, e := c.Step(author, w, "author", Action{"complete", o.ID})
	if e != nil {
		return r, e
	}
	other := NewState()
	other.Region = "asterion"
	talk, e := c.Step(other, event.World, "observer", Action{"talk", "enya"})
	if e != nil {
		return r, e
	}
	heard, e := c.Step(talk.State, talk.World, "observer", Action{"complete", "beacon-attunement"})
	if e != nil {
		return r, e
	}
	r.SharedHistoricalProof = heard.State.Abilities["ancestral-sense"] && len(other.Inventory) == 0 && event.World.Authors[o.Fact] == "author"
	sharedWorld := NewWorld()
	for _, profile := range []string{"mixed", "explorer", "combatant", "researcher", "collector", "ignores-opportunities"} {
		j, next, e := c.SimulateShared(profile, seed, steps, sharedWorld)
		if e != nil {
			return r, e
		}
		r.SharedCohort = append(r.SharedCohort, j)
		sharedWorld = next
	}
	r.HistoricalAuthors = sharedWorld.Authors
	return r, nil
}
