package decisions

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
)

func worldFixture() Request {
	candidates := worldDefinitions()
	for i := range candidates {
		candidates[i].CauseID = "fact:authority-" + candidates[i].ID
		candidates[i].Context = []string{"verified-history"}
	}
	return Request{Version: 1, EventID: "world:player:offline-clearing:7", ActorID: "player", WorldID: "offline-clearing", StateVersion: 7, PolicyID: WorldPolicyID,
		CharacterFacts: []string{"investigation-confirmed", "tracking-confirmed", "wolf-defeated", "prepared-attack-dodged"}, NPCKnowledge: []string{"mira:investigation-confirmed", "orin:prepared-attack-dodged"}, RegionState: []string{"forest-threat"}, Candidates: candidates, EligibleConsequences: []string{"forest-alert", "new-threat-tracks", "hunter-training", "none"}}
}
func worldWire(choice string) string {
	return `{"id":"gen-dec-world","model":"typesafe/jev-1.13-20260917","provider":"TypeSafe","answers":{"world_event":{"type":"choice","choice":"` + choice + `","confidence":0.4,"probabilities":{"forest-alert":0.1,"new-threat-tracks":0.6,"hunter-training":0.1,"none":0.2}}},"usage":{"input_tokens":100,"output_tokens":20,"cost":0.000001}}`
}
func TestWorldCandidatesAndJevQuestion(t *testing.T) {
	r := worldFixture()
	if r.Validate() != nil {
		t.Fatal("valid fixture rejected")
	}
	q, err := BuildJevRequest(r)
	if err != nil || q.Model != Model || len(q.Questions) != 1 || len(q.Questions["world_event"].Criteria) != 4 {
		t.Fatal(q, err)
	}
	for _, id := range r.EligibleConsequences {
		if q.Questions["world_event"].Criteria[id] == "" {
			t.Fatal(id)
		}
	}
	if !strings.Contains(q.Questions["world_event"].Instructions, "Independent") {
		t.Fatal("independent policy missing")
	}
}
func TestWorldInvalidContracts(t *testing.T) {
	mutations := []func(*Request){
		func(r *Request) { r.Candidates[0].AuthorizedActions = []string{"grant-ability"} },
		func(r *Request) { r.Candidates[0].Conditions.Children = nil },
		func(r *Request) { r.Candidates[0].CauseID = "unverified" },
		func(r *Request) { r.CharacterFacts = []string{"tracking-confirmed"} },
		func(r *Request) { r.NPCKnowledge = nil },
		func(r *Request) { r.RegionState = []string{"forest-safe"} },
		func(r *Request) { r.EligibleConsequences[3] = "invented" },
		func(r *Request) { r.Candidates[1] = r.Candidates[0] },
	}
	for i, mutate := range mutations {
		r := worldFixture()
		mutate(&r)
		if r.Validate() == nil {
			t.Fatalf("accepted invalid case %d", i)
		}
	}
}
func TestWorldValidOpenRouterSelectionAndNoSelection(t *testing.T) {
	for _, choice := range []string{"new-threat-tracks", "none"} {
		t.Run(choice, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				var q JevRequest
				if json.NewDecoder(r.Body).Decode(&q) != nil || q.Questions["world_event"].Type != "choice" {
					t.Error("question")
				}
				io.WriteString(w, worldWire(choice))
			}))
			defer server.Close()
			out, err := service(t, provider(server)).Evaluate(context.Background(), worldFixture())
			if err != nil || out.Fallback || out.Choice != choice || *out.Confidence != 0.4 || out.Probabilities["new-threat-tracks"] != 0.6 {
				t.Fatal(out, err)
			}
		})
	}
}
func TestWorldInvalidJevSelectionFallsBack(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, worldWire("grant-xp")) }))
	defer server.Close()
	out, err := service(t, provider(server)).Evaluate(context.Background(), worldFixture())
	if err != nil || !out.Fallback || out.Choice != "forest-alert" || out.FallbackReason != "invalid_choice" {
		t.Fatal(out, err)
	}
}
func TestWorldUnavailableProviderAndLowConfidenceUsePersistedFallback(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, worldWire("new-threat-tracks")) }))
	defer server.Close()
	s := service(t, provider(server))
	s.MinimumConfidence = 0.5
	out, err := s.Evaluate(context.Background(), worldFixture())
	if err != nil || !out.Fallback || out.Choice != "forest-alert" || out.Attempt == nil || out.Attempt.Choice != "new-threat-tracks" {
		t.Fatal(out, err)
	}
	server.Close()
	s2 := service(t, provider(server))
	unavailable, err := s2.Evaluate(context.Background(), worldFixture())
	if err != nil || !unavailable.Fallback {
		t.Fatal(unavailable, err)
	}
}
func TestWorldRestartCacheAndContextConflict(t *testing.T) {
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls++; io.WriteString(w, worldWire("hunter-training")) }))
	defer server.Close()
	s := service(t, provider(server))
	r := worldFixture()
	first, err := s.Evaluate(context.Background(), r)
	if err != nil {
		t.Fatal(err)
	}
	restarted := &Service{Directory: s.Directory, Provider: provider(server)}
	second, err := restarted.Evaluate(context.Background(), r)
	if err != nil || hash(first) != hash(second) || calls != 1 {
		t.Fatal("cache", calls, err)
	}
	r.StateVersion++
	_, err = restarted.Evaluate(context.Background(), r)
	if !errors.Is(err, ErrConflict) {
		t.Fatal("revision conflict", err)
	}
}
func TestWorldIndependentCandidatesRemainAvailable(t *testing.T) {
	s := service(t, DeterministicDecisionProvider{})
	r := worldFixture()
	first, err := s.Evaluate(context.Background(), r)
	if err != nil || first.Choice != "forest-alert" {
		t.Fatal(first, err)
	}
	r.Candidates = r.Candidates[1:]
	r.EligibleConsequences = slices.Clone(r.EligibleConsequences[1:])
	r.EventID = "world-next"
	r.StateVersion++
	next, err := s.Evaluate(context.Background(), r)
	if err != nil || next.Choice != "new-threat-tracks" {
		t.Fatal(next, err)
	}
}
func TestWorldNoCandidatesSkipsProvider(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { t.Error("unexpected provider call") }))
	defer server.Close()
	r := worldFixture()
	r.Candidates = nil
	r.EligibleConsequences = nil
	out, err := service(t, provider(server)).Evaluate(context.Background(), r)
	if err != nil || out.Choice != "" {
		t.Fatal(out, err)
	}
}
func TestWorldHTTPRejectsUnknownFieldsAndPreservesV1Reaction(t *testing.T) {
	handler := Handler(service(t, DeterministicDecisionProvider{}))
	b, _ := json.Marshal(worldFixture())
	for _, body := range []string{string(b), strings.TrimSuffix(string(b), "}") + `,"apiKey":"forbidden"}`} {
		req := httptest.NewRequest(http.MethodPost, "/v1/decisions/evaluate", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, req)
		expected := 200
		if strings.Contains(body, "apiKey") {
			expected = 400
		}
		if recorder.Code != expected {
			t.Fatal(recorder.Code, recorder.Body.String())
		}
	}
	if _, err := BuildJevRequest(fixture()); err != nil {
		t.Fatal("v1 regression", err)
	}
}
