package decisions

import "slices"

const WorldPolicyID = "world-context-v1"

type WorldCondition struct {
	RuleID    string           `json:"ruleId"`
	Value     string           `json:"value"`
	SubjectID string           `json:"subjectId"`
	Kind      int              `json:"kind"`
	Time      int64            `json:"time"`
	Children  []WorldCondition `json:"children"`
}
type EventCandidate struct {
	Version           int            `json:"version"`
	ID                string         `json:"id"`
	Type              string         `json:"type"`
	Scope             string         `json:"scope"`
	CauseID           string         `json:"causeId"`
	RuleID            string         `json:"ruleId"`
	Context           []string       `json:"context"`
	AuthorizedActions []string       `json:"authorizedActions"`
	Conditions        WorldCondition `json:"conditions"`
}

var worldDescriptions = map[string]string{
	"forest-alert":      "Schedule a sourced public warning after Mira confirmed the corruption investigation; do not disclose private facts before publication.",
	"new-threat-tracks": "Place interactive new forest traces when tracking, verified wolf combat and a regional threat support further investigation with Orin.",
	"hunter-training":   "Offer optional practice after a verified dodge of a prepared attack and a sourced report known to Orin. No ability reward.",
	"none":              "Do not initiate another optional world event in this context. Guaranteed existing Journey progression remains available.",
}

func (r Request) optionDescriptions() map[string]string {
	if r.PolicyID == WorldPolicyID {
		return worldDescriptions
	}
	return descriptions
}
func (r Request) questionID() string {
	if r.PolicyID == WorldPolicyID {
		return "world_event"
	}
	return "mira_reaction"
}
func worldFact(kind string) WorldCondition {
	return WorldCondition{Kind: 2, Value: kind, RuleID: "fact:" + kind}
}
func worldKnown(npc, kind string) WorldCondition {
	return WorldCondition{Kind: 3, Value: kind, SubjectID: npc, RuleID: "knowledge:" + npc + ":" + kind}
}
func worldDefinitions() []EventCandidate {
	threat := WorldCondition{Kind: 4, RuleID: "regional-threat"}
	return []EventCandidate{
		{Version: 1, ID: "forest-alert", Type: "delayed-public-notice", Scope: "region", RuleID: "alert-v1", AuthorizedActions: []string{"schedule-notice"}, Conditions: WorldCondition{RuleID: "alert-v1", Children: []WorldCondition{worldFact("investigation-confirmed"), worldKnown("mira", "investigation-confirmed"), threat}}},
		{Version: 1, ID: "new-threat-tracks", Type: "interactive-investigation", Scope: "character-region", RuleID: "tracks-v1", AuthorizedActions: []string{"spawn-tracks"}, Conditions: WorldCondition{RuleID: "tracks-v1", Children: []WorldCondition{worldFact("tracking-confirmed"), worldFact("wolf-defeated"), threat}}},
		{Version: 1, ID: "hunter-training", Type: "optional-training", Scope: "character", RuleID: "training-v1", AuthorizedActions: []string{"offer-training"}, Conditions: WorldCondition{RuleID: "training-v1", Children: []WorldCondition{worldFact("prepared-attack-dodged"), worldKnown("orin", "prepared-attack-dodged")}}},
	}
}
func equalCondition(a, b WorldCondition) bool {
	if a.RuleID != b.RuleID || a.Kind != b.Kind || a.Value != b.Value || a.SubjectID != b.SubjectID || a.Time != b.Time || len(a.Children) != len(b.Children) {
		return false
	}
	for i := range a.Children {
		if !equalCondition(a.Children[i], b.Children[i]) {
			return false
		}
	}
	return true
}
func (r Request) conditionHolds(c WorldCondition) bool {
	switch c.Kind {
	case 0:
		for _, child := range c.Children {
			if !r.conditionHolds(child) {
				return false
			}
		}
		return true
	case 2:
		return slices.Contains(r.CharacterFacts, c.Value)
	case 3:
		return slices.Contains(r.NPCKnowledge, c.SubjectID+":"+c.Value)
	case 4:
		return slices.Contains(r.RegionState, "forest-threat") && !slices.Contains(r.RegionState, "forest-safe")
	}
	return false
}
func (r Request) validateWorld() error {
	if len(r.Candidates) > 3 || len(r.EligibleConsequences) > 4 {
		return ErrInvalid
	}
	if len(r.Candidates) == 0 {
		if len(r.EligibleConsequences) != 0 {
			return ErrInvalid
		}
		return nil
	}
	if len(r.EligibleConsequences) != len(r.Candidates)+1 || r.EligibleConsequences[len(r.Candidates)] != "none" {
		return ErrInvalid
	}
	seen := map[string]bool{}
	for i, c := range r.Candidates {
		if c.Version != 1 || c.ID != r.EligibleConsequences[i] || seen[c.ID] || len(c.Context) > 64 || len(c.CauseID) > 256 || len(c.CauseID) < 6 || c.CauseID[:5] != "fact:" {
			return ErrInvalid
		}
		seen[c.ID] = true
		for _, v := range c.Context {
			if len(v) > 256 {
				return ErrInvalid
			}
		}
		found := false
		for _, definition := range worldDefinitions() {
			if c.ID == definition.ID {
				found = c.Type == definition.Type && c.Scope == definition.Scope && c.RuleID == definition.RuleID && slices.Equal(c.AuthorizedActions, definition.AuthorizedActions) && equalCondition(c.Conditions, definition.Conditions) && r.conditionHolds(c.Conditions)
			}
		}
		if !found {
			return ErrInvalid
		}
	}
	return nil
}
