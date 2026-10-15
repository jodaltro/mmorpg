package decisions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func fixture() Request {
	return Request{Version: 1, EventID: "delivery-001", ActorID: "player", WorldID: "offline-clearing", StateVersion: 4, PolicyID: PolicyID,
		CharacterFacts: []string{"CreatureDefeated", "EvidenceCollected", "EvidenceDelivered", "AbilityUnlocked"}, NPCKnowledge: []string{"corruption-sample", "forest-sample"},
		RegionState: []string{"forest-corruption-confirmed"}, EligibleConsequences: append([]string{}, reactionOrder...)}
}
func wire(choice string, confidence float64) string {
	return fmt.Sprintf(`{"id":"gen-dec-test","model":"typesafe/jev-1.13-20260917","provider":"TypeSafe","answers":{"mira_reaction":{"type":"choice","choice":%q,"confidence":%g,"probabilities":{"mira-scientific":0.1,"mira-concern":0.7,"mira-suspicion":0.1,"mira-neutral":0.1}}},"usage":{"input_tokens":20,"output_tokens":10,"cost":0.000001}}`, choice, confidence)
}
func provider(server *httptest.Server) *OpenRouterJevProvider {
	return &OpenRouterJevProvider{URL: server.URL, APIKey: "test-only-not-a-real-key", Timeout: time.Second}
}
func service(t *testing.T, p DecisionProvider) *Service {
	t.Helper()
	return &Service{Provider: p, Directory: t.TempDir(), Timeout: time.Second}
}
func TestContractsRoundTrip(t *testing.T) {
	r := fixture()
	b, _ := json.Marshal(r)
	var decoded Request
	if json.Unmarshal(b, &decoded) != nil || hash(r) != hash(decoded) {
		t.Fatal("request roundtrip")
	}
	out, err := service(t, DeterministicDecisionProvider{}).Evaluate(context.Background(), r)
	if err != nil {
		t.Fatal(err)
	}
	b, _ = json.Marshal(out)
	var response Response
	if json.Unmarshal(b, &response) != nil || hash(response) != hash(out) {
		t.Fatal("response roundtrip")
	}
}
func TestBuildChoiceIncludesOnlyEligibleIDs(t *testing.T) {
	r := fixture()
	r.EligibleConsequences = []string{"mira-concern", "mira-neutral"}
	q, err := BuildJevRequest(r)
	if err != nil {
		t.Fatal(err)
	}
	if q.Model != Model || q.Questions["mira_reaction"].Type != "choice" || len(q.Questions["mira_reaction"].Criteria) != 2 {
		t.Fatal(q)
	}
	for _, id := range r.EligibleConsequences {
		if q.Questions["mira_reaction"].Criteria[id] == "" {
			t.Fatal(id)
		}
	}
}
func TestOpenRouterRequestAndAllowedSelection(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" || r.Header.Get("Authorization") != "Bearer test-only-not-a-real-key" || r.Header.Get("Content-Type") != "application/json" {
			t.Error("headers")
		}
		var request JevRequest
		if json.NewDecoder(r.Body).Decode(&request) != nil || request.Model != Model || request.Questions["mira_reaction"].Type != "choice" {
			t.Error("request")
		}
		io.WriteString(w, wire("mira-concern", 0.7))
	}))
	defer server.Close()
	out, err := service(t, provider(server)).Evaluate(context.Background(), fixture())
	if err != nil || out.Fallback || out.Choice != "mira-concern" || out.Usage == nil || out.Usage.Cost == nil {
		t.Fatalf("%+v %v", out, err)
	}
}
func TestUnknownOrIneligibleIDsRejected(t *testing.T) {
	r := fixture()
	r.EligibleConsequences = []string{"invented-reward"}
	if r.Validate() == nil {
		t.Fatal("unknown accepted")
	}
	r = fixture()
	r.NPCKnowledge = nil
	if r.Validate() == nil {
		t.Fatal("unvalidated context")
	}
	r = fixture()
	r.EligibleConsequences = []string{"mira-neutral"}
	if validateSelection(r, Selection{Choice: "mira-concern"}) == nil {
		t.Fatal("unlisted accepted")
	}
}
func TestNoEligibleDoesNotCallProvider(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls.Add(1) }))
	defer server.Close()
	r := fixture()
	r.EligibleConsequences = nil
	out, err := service(t, provider(server)).Evaluate(context.Background(), r)
	if err != nil || out.Choice != "" || calls.Load() != 0 {
		t.Fatalf("%+v %v", out, err)
	}
	if _, err = BuildJevRequest(r); err == nil {
		t.Fatal("empty choice question")
	}
}
func TestProviderFailuresFallbackAndNeverLeakCredentials(t *testing.T) {
	cases := []struct {
		name, body, reason string
		status             int
		delay              time.Duration
	}{
		{"http-invalid", "test-only-not-a-real-key", "provider_http_error", 502, 0},
		{"json-invalid", "invalid", "invalid_response", 200, 0},
		{"unknown-choice", wire("invented-reward", 0.7), "invalid_choice", 200, 0},
		{"empty-answer", `{"answers":{}}`, "invalid_response", 200, 0},
		{"timeout", wire("mira-concern", 0.7), "provider_timeout", 200, 100 * time.Millisecond},
		{"low-confidence", wire("mira-concern", 0.1), "low_confidence", 200, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				time.Sleep(tc.delay)
				w.WriteHeader(tc.status)
				io.WriteString(w, tc.body)
			}))
			defer server.Close()
			p := provider(server)
			if tc.delay > 0 {
				p.Timeout = 10 * time.Millisecond
			}
			s := service(t, p)
			s.MinimumConfidence = 0.5 // Test fixture only; no permanent gameplay threshold.
			var log bytes.Buffer
			s.Logger = slog.New(slog.NewJSONHandler(&log, nil))
			out, err := s.Evaluate(context.Background(), fixture())
			if err != nil || !out.Fallback || out.FallbackReason != tc.reason || out.Choice != "mira-scientific" {
				t.Fatalf("%+v %v", out, err)
			}
			b, _ := json.Marshal(out)
			if strings.Contains(string(b)+log.String(), p.APIKey) {
				t.Fatal("credential leaked")
			}
			if tc.reason == "low_confidence" && (out.Attempt == nil || out.Attempt.Usage == nil) {
				t.Fatal("attempt metrics lost")
			}
			if tc.reason == "invalid_choice" && (out.Attempt == nil || out.Attempt.Usage == nil || out.Attempt.Choice != "") {
				t.Fatal("invalid choice billing audit")
			}
		})
	}
}
func TestUnavailableAndMissingKey(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	p := provider(server)
	server.Close()
	for _, candidate := range []*OpenRouterJevProvider{p, {}} {
		out, err := service(t, candidate).Evaluate(context.Background(), fixture())
		if err != nil || !out.Fallback {
			t.Fatalf("%+v %v", out, err)
		}
	}
}
func TestProbabilityValidation(t *testing.T) {
	for _, body := range []string{
		strings.Replace(wire("mira-concern", 0.7), `"mira-scientific":0.1`, `"unknown":0.1`, 1),
		strings.Replace(wire("mira-concern", 0.7), `"mira-concern":0.7`, `"mira-concern":1.7`, 1),
		strings.Replace(wire("mira-concern", 0.7), `"confidence":0.7`, `"confidence":-0.1`, 1),
	} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, body) }))
		out, err := service(t, provider(server)).Evaluate(context.Background(), fixture())
		server.Close()
		if err != nil || !out.Fallback {
			t.Fatalf("%+v %v", out, err)
		}
	}
}
func TestConcurrentRepetitionAndRestartUsePersistedDecision(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		io.WriteString(w, wire("mira-concern", 0.7))
	}))
	defer server.Close()
	s := service(t, provider(server))
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			out, err := s.Evaluate(context.Background(), fixture())
			if err != nil || out.Choice != "mira-concern" {
				t.Errorf("%+v %v", out, err)
			}
		}()
	}
	wg.Wait()
	restarted := &Service{Directory: s.Directory, Provider: DeterministicDecisionProvider{}}
	out, err := restarted.Evaluate(context.Background(), fixture())
	if err != nil || out.Choice != "mira-concern" || calls.Load() != 1 {
		t.Fatalf("%+v %v calls %d", out, err, calls.Load())
	}
	files, _ := filepath.Glob(filepath.Join(s.Directory, "*.json"))
	if len(files) != 1 {
		t.Fatal(files)
	}
}
func TestChangedStateConflictsAndCorruptStorageFailsClosed(t *testing.T) {
	s := service(t, DeterministicDecisionProvider{})
	r := fixture()
	_, err := s.Evaluate(context.Background(), r)
	if err != nil {
		t.Fatal(err)
	}
	r.StateVersion++
	if _, err = s.Evaluate(context.Background(), r); err != ErrConflict {
		t.Fatal(err)
	}
	r = fixture()
	files, _ := filepath.Glob(filepath.Join(s.Directory, "*.json"))
	os.WriteFile(files[0], []byte("corrupt"), 0600)
	if _, err = s.Evaluate(context.Background(), r); err != ErrStorage {
		t.Fatal(err)
	}
}
func TestHTTPContractHealthAndErrors(t *testing.T) {
	s := service(t, DeterministicDecisionProvider{})
	server := httptest.NewServer(Handler(s))
	defer server.Close()
	res, err := http.Get(server.URL + "/healthz")
	if err != nil || res.StatusCode != 200 {
		t.Fatal(err)
	}
	res.Body.Close()
	body, _ := json.Marshal(fixture())
	for _, tc := range []struct {
		body, origin string
		want         int
	}{
		{string(body), "", 200}, {string(body), "https://untrusted.example", 403}, {"{}", "", 400}, {string(body) + "{}", "", 400},
		{strings.Replace(string(body), `"version":1`, `"version":2`, 1), "", 400},
	} {
		req, _ := http.NewRequest("POST", server.URL+"/v1/decisions/evaluate", strings.NewReader(tc.body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Origin", tc.origin)
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		if res.StatusCode != tc.want {
			t.Errorf("want %d got %d", tc.want, res.StatusCode)
		}
		res.Body.Close()
	}
	if LocalAddress("0.0.0.0:8091") || LocalAddress("[::]:8091") || !LocalAddress("127.0.0.1:8091") {
		t.Fatal("loopback")
	}
}

// Explicit opt-in. Never part of CI; never prints request headers, raw upstream responses or credentials.
func TestManualOpenRouter(t *testing.T) {
	if os.Getenv("JEV_MANUAL_TEST") != "1" {
		t.Skip("opt in with JEV_MANUAL_TEST=1")
	}
	key, keyError := ResolveOpenRouterAPIKey(".env")
	if keyError != nil {
		t.Fatal("invalid_secret_configuration")
	}
	if key == "" {
		t.Skip("OPENROUTER_API_KEY is not configured")
	}
	r := fixture()
	r.EventID = fmt.Sprintf("manual-%d", time.Now().UnixNano())
	started := time.Now()
	result, err := (&OpenRouterJevProvider{APIKey: key, Timeout: 15 * time.Second}).Decide(context.Background(), r)
	if err != nil {
		t.Fatal(safeReason(err))
	}
	evidence := map[string]any{"decisionId": result.DecisionID, "model": result.Model, "choice": result.Choice, "confidence": result.Confidence, "probabilities": result.Probabilities, "latencyMs": time.Since(started).Milliseconds(), "usage": result.Usage}
	b, _ := json.Marshal(evidence)
	t.Log(string(b))
}

func TestConfidenceGateDisabledByDefault(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, wire("mira-concern", 0.1)) }))
	defer server.Close()
	out, err := service(t, provider(server)).Evaluate(context.Background(), fixture())
	if err != nil || out.Fallback || out.Choice != "mira-concern" {
		t.Fatalf("%+v %v", out, err)
	}
}
func TestStoredChoiceChecksumAndWriteFailure(t *testing.T) {
	s := service(t, DeterministicDecisionProvider{})
	r := fixture()
	if _, err := s.Evaluate(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(s.Directory, identity(r)+".json")
	b, _ := os.ReadFile(path)
	b = bytes.Replace(b, []byte(`"selectedConsequence": "mira-scientific"`), []byte(`"selectedConsequence": "mira-neutral"`), 1)
	os.WriteFile(path, b, 0600)
	if _, err := s.Evaluate(context.Background(), r); err != ErrStorage {
		t.Fatal("checksum", err)
	}
	blocked := filepath.Join(t.TempDir(), "file")
	os.WriteFile(blocked, []byte("blocked"), 0600)
	if _, err := (&Service{Directory: blocked}).Evaluate(context.Background(), r); err != ErrStorage {
		t.Fatal("write", err)
	}
}
func TestProviderCannotEchoCredentialInDecisionID(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, strings.Replace(wire("mira-concern", 0.7), "gen-dec-test", "gen-dec-test-only-not-a-real-key", 1))
	}))
	defer server.Close()
	s := service(t, provider(server))
	var log bytes.Buffer
	s.Logger = slog.New(slog.NewJSONHandler(&log, nil))
	out, err := s.Evaluate(context.Background(), fixture())
	b, _ := json.Marshal(out)
	if err != nil || !out.Fallback || strings.Contains(string(b)+log.String(), "test-only-not-a-real-key") {
		t.Fatal("echoed credential")
	}
}
