package decisions

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
	"sync/atomic"
	"testing"
	"time"
)

// Different valid histories exercise the existing Jev world policy, without claiming
// the advisory service proves client facts or owns expanded-world consequences.
func marco05Histories() []Request {
	all := worldFixture()
	all.EventID = "m05-research-history"
	all.ActorID = "researcher"
	all.WorldID = "m05-jev-test"
	all.StateVersion = 20
	tracking := worldFixture()
	tracking.EventID = "m05-combat-history"
	tracking.ActorID = "combatant"
	tracking.WorldID = all.WorldID
	tracking.StateVersion = 12
	tracking.CharacterFacts = []string{"tracking-confirmed", "wolf-defeated", "prepared-attack-dodged"}
	tracking.NPCKnowledge = []string{"orin:prepared-attack-dodged"}
	tracking.Candidates = slices.Clone(tracking.Candidates[1:])
	tracking.EligibleConsequences = slices.Clone(tracking.EligibleConsequences[1:])
	training := worldFixture()
	training.EventID = "m05-training-history"
	training.ActorID = "explorer"
	training.WorldID = all.WorldID
	training.StateVersion = 7
	training.CharacterFacts = []string{"prepared-attack-dodged"}
	training.NPCKnowledge = []string{"orin:prepared-attack-dodged"}
	training.RegionState = []string{"forest-safe"}
	training.Candidates = slices.Clone(training.Candidates[2:])
	training.EligibleConsequences = slices.Clone(training.EligibleConsequences[2:])
	return []Request{all, tracking, training}
}
func TestMarco05HistoriesChoicesPersistCostsLatencyAndStateChanges(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		var body JevRequest
		if json.NewDecoder(r.Body).Decode(&body) != nil {
			t.Error("invalid question")
			return
		}
		time.Sleep(20 * time.Millisecond)
		choice := body.State.EligibleConsequences[0]
		prob := map[string]float64{}
		for _, id := range body.State.EligibleConsequences {
			prob[id] = 0
		}
		prob[choice] = 1
		json.NewEncoder(w).Encode(map[string]any{"id": "gen-dec-m05-choice", "model": Model, "provider": "TypeSafe", "answers": map[string]any{"world_event": map[string]any{"type": "choice", "choice": choice, "confidence": .7, "probabilities": prob}}, "usage": map[string]any{"input_tokens": 125, "output_tokens": 20, "cost": .000001}})
	}))
	defer server.Close()
	s := service(t, provider(server))
	for _, r := range marco05Histories() {
		t.Run(r.ActorID, func(t *testing.T) {
			out, e := s.Evaluate(context.Background(), r)
			if e != nil || out.Fallback || out.Choice != r.EligibleConsequences[0] || out.LatencyMS < 15 || out.Usage == nil || out.Usage.Cost == nil || *out.Usage.Cost != .000001 {
				t.Fatalf("decision/telemetry: %+v %v", out, e)
			}
			before := calls.Load()
			restarted := &Service{Directory: s.Directory, Provider: provider(server)}
			cached, e := restarted.Evaluate(context.Background(), r)
			if e != nil || calls.Load() != before || cached.DecisionID != out.DecisionID || cached.LatencyMS != out.LatencyMS {
				t.Fatal("choice not durable across restart")
			}
			r.StateVersion++
			if _, e = restarted.Evaluate(context.Background(), r); !errors.Is(e, ErrConflict) {
				t.Fatal("changed history reused cached decision")
			}
			r.EventID += "-next"
			if _, e = restarted.Evaluate(context.Background(), r); e != nil {
				t.Fatal("fresh evaluation rejected after state change")
			}
		})
	}
	if calls.Load() != 6 {
		t.Fatal("provider called per replay or unexpectedly", calls.Load())
	}
}
func TestMarco05CandidateCapsAndDeterministicContingency(t *testing.T) {
	r := marco05Histories()[0]
	r.Candidates = append(r.Candidates, r.Candidates[0])
	r.EligibleConsequences = append(r.EligibleConsequences, "forest-alert")
	if r.Validate() == nil {
		t.Fatal("more than three simultaneous candidates accepted")
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(503) }))
	defer server.Close()
	s := service(t, provider(server))
	for _, r := range marco05Histories() {
		out, e := s.Evaluate(context.Background(), r)
		if e != nil || !out.Fallback || out.Choice != r.EligibleConsequences[0] || out.FallbackReason != "provider_http_error" {
			t.Fatal("nondeterministic contingency", out, e)
		}
	}
	empty := marco05Histories()[0]
	empty.EventID = "m05-no-opportunity"
	empty.Candidates = nil
	empty.EligibleConsequences = nil
	if out, e := s.Evaluate(context.Background(), empty); e != nil || out.Choice != "" {
		t.Fatal("empty candidate set yielded event")
	}
}
