package decisions

import (
	"errors"
	"math"
	"slices"
	"strings"
)

const PolicyID = "mira-reaction-v1"
const Model = "typesafe/jev-1.13"
const Endpoint = "https://openrouter.ai/api/alpha/decisions"

var reactionOrder = []string{"mira-scientific", "mira-concern", "mira-suspicion", "mira-neutral"}
var descriptions = map[string]string{
	"mira-scientific": "Scientific curiosity about how the valid resin sample reveals the spread of forest corruption.",
	"mira-concern":    "Concern about protecting the forest from the confirmed corruption.",
	"mira-suspicion":  "Caution about the origin of the resin, while acknowledging the delivered sample is valid.",
	"mira-neutral":    "Neutral acknowledgement and recording of the valid sample.",
}

type Request struct {
	Version              int              `json:"version"`
	EventID              string           `json:"eventId"`
	ActorID              string           `json:"actorId"`
	WorldID              string           `json:"worldId"`
	StateVersion         int64            `json:"stateVersion"`
	PolicyID             string           `json:"policyId"`
	CharacterFacts       []string         `json:"characterFacts"`
	NPCKnowledge         []string         `json:"npcKnowledge"`
	RegionState          []string         `json:"regionState"`
	EligibleConsequences []string         `json:"eligibleConsequences"`
	Candidates           []EventCandidate `json:"candidates,omitempty"`
}
type Usage struct {
	InputTokens  *int64   `json:"input_tokens,omitempty"`
	OutputTokens *int64   `json:"output_tokens,omitempty"`
	Cost         *float64 `json:"cost,omitempty"`
}
type Selection struct {
	DecisionID    string             `json:"decisionId"`
	Model         string             `json:"model"`
	Provider      string             `json:"provider"`
	Choice        string             `json:"selectedConsequence"`
	Confidence    *float64           `json:"confidence,omitempty"`
	Probabilities map[string]float64 `json:"probabilities,omitempty"`
	Usage         *Usage             `json:"usage,omitempty"`
}
type Response struct {
	Version      int    `json:"version"`
	EventID      string `json:"eventId"`
	ActorID      string `json:"actorId"`
	WorldID      string `json:"worldId"`
	StateVersion int64  `json:"stateVersion"`
	PolicyID     string `json:"policyId"`
	Selection
	LatencyMS      int64      `json:"latencyMs"`
	Fallback       bool       `json:"fallback"`
	FallbackReason string     `json:"fallbackReason,omitempty"`
	Attempt        *Selection `json:"attempt,omitempty"`
}

var ErrInvalid = errors.New("invalid_request")
var ErrConflict = errors.New("event_context_conflict")
var ErrStorage = errors.New("decision_storage_unavailable")

func (r Request) Validate() error {
	if r.Version != 1 || (r.PolicyID != PolicyID && r.PolicyID != WorldPolicyID) || r.StateVersion < 0 {
		return ErrInvalid
	}
	for _, id := range []string{r.EventID, r.ActorID, r.WorldID} {
		if strings.TrimSpace(id) == "" || len(id) > 128 || strings.ContainsAny(id, "\r\n\x00") {
			return ErrInvalid
		}
	}
	for _, list := range [][]string{r.CharacterFacts, r.NPCKnowledge, r.RegionState} {
		if len(list) > 64 {
			return ErrInvalid
		}
		for _, value := range list {
			if len(value) > 256 {
				return ErrInvalid
			}
		}
	}
	if r.PolicyID == WorldPolicyID {
		return r.validateWorld()
	}
	if len(r.Candidates) > 0 {
		return ErrInvalid
	}
	if len(r.EligibleConsequences) > 4 {
		return ErrInvalid
	}
	seen := map[string]bool{}
	for _, id := range r.EligibleConsequences {
		if _, ok := descriptions[id]; !ok || seen[id] {
			return ErrInvalid
		}
		seen[id] = true
	}
	// The local client supplies validated facts; these checks are consistency checks, not multiplayer authority.
	if len(r.EligibleConsequences) > 0 && (!slices.Contains(r.CharacterFacts, "EvidenceDelivered") ||
		!slices.Contains(r.NPCKnowledge, "corruption-sample") || !slices.Contains(r.NPCKnowledge, "forest-sample") ||
		!slices.Contains(r.RegionState, "forest-corruption-confirmed")) {
		return ErrInvalid
	}
	return nil
}
func validProbability(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) && v >= 0 && v <= 1 }
func validateSelection(r Request, s Selection) error {
	if len(r.EligibleConsequences) == 0 {
		if s.Choice != "" {
			return errors.New("invalid_choice")
		}
		return nil
	}
	if !slices.Contains(r.EligibleConsequences, s.Choice) || s.DecisionID == "" || s.Model == "" || s.Provider == "" {
		return errors.New("invalid_choice")
	}
	if s.Confidence != nil && !validProbability(*s.Confidence) {
		return errors.New("invalid_probabilities")
	}
	if s.Probabilities != nil {
		sum := 0.0
		if len(s.Probabilities) != len(r.EligibleConsequences) {
			return errors.New("invalid_probabilities")
		}
		for id, p := range s.Probabilities {
			if !slices.Contains(r.EligibleConsequences, id) || !validProbability(p) {
				return errors.New("invalid_probabilities")
			}
			sum += p
		}
		if math.Abs(sum-1) > 0.02 {
			return errors.New("invalid_probabilities")
		}
	}
	if u := s.Usage; u != nil {
		if (u.InputTokens != nil && *u.InputTokens < 0) || (u.OutputTokens != nil && *u.OutputTokens < 0) || (u.Cost != nil && (math.IsNaN(*u.Cost) || math.IsInf(*u.Cost, 0) || *u.Cost < 0)) {
			return errors.New("invalid_usage")
		}
	}
	return nil
}
