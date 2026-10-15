package decisions

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"
)

type DecisionProvider interface {
	Decide(context.Context, Request) (Selection, error)
}
type DeterministicDecisionProvider struct{}

func (DeterministicDecisionProvider) Decide(_ context.Context, r Request) (Selection, error) {
	if err := r.Validate(); err != nil {
		return Selection{}, err
	}
	s := Selection{DecisionID: "det:" + identity(r), Model: "deterministic-v1", Provider: "deterministic"}
	// Mirrors the existing first-candidate deterministic policy in Unity.
	if len(r.EligibleConsequences) > 0 {
		s.Choice = r.EligibleConsequences[0]
	}
	return s, nil
}

type ChoiceQuestion struct {
	Type         string            `json:"type"`
	Instructions string            `json:"instructions"`
	Criteria     map[string]string `json:"criteria"`
}
type JevRequest struct {
	Model     string                    `json:"model"`
	State     Request                   `json:"state"`
	Questions map[string]ChoiceQuestion `json:"questions"`
}

func BuildJevRequest(r Request) (JevRequest, error) {
	if err := r.Validate(); err != nil {
		return JevRequest{}, err
	}
	if len(r.EligibleConsequences) == 0 {
		return JevRequest{}, errors.New("no_eligible_consequences")
	}
	criteria := map[string]string{}
	for _, id := range r.EligibleConsequences {
		criteria[id] = r.optionDescriptions()[id]
	}
	instructions := "Choose Mira's contextual reaction to this already validated sample delivery. Use only the supplied criteria IDs. Character facts are background; Mira may react only to her NPC knowledge. No rewards, abilities, items, new events or free dialogue."
	if r.PolicyID == WorldPolicyID {
		instructions = "Prioritize one supplied eligible world candidate, or choose none to defer these optional events. Independent candidates remain eligible in subsequent evaluations. Use facts, regional conditions and sourced NPC knowledge only. No inventory, rewards, abilities, damage or arbitrary actions. Choice probabilities are distinct from confidence."
	}
	return JevRequest{Model: Model, State: r, Questions: map[string]ChoiceQuestion{r.questionID(): {
		Type: "choice", Instructions: instructions, Criteria: criteria}}}, nil
}

type OpenRouterJevProvider struct {
	Client  *http.Client
	APIKey  string
	URL     string // Injection for tests only; executable always uses the official endpoint.
	Timeout time.Duration
}

func (p *OpenRouterJevProvider) Decide(ctx context.Context, r Request) (Selection, error) {
	if p.APIKey == "" {
		return Selection{}, errors.New("missing_api_key")
	}
	payload, err := BuildJevRequest(r)
	if err != nil {
		return Selection{}, err
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return Selection{}, errors.New("invalid_request")
	}
	timeout := p.Timeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	url := p.URL
	if url == "" {
		url = Endpoint
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return Selection{}, errors.New("invalid_endpoint")
	}
	req.Header.Set("Authorization", "Bearer "+p.APIKey)
	req.Header.Set("Content-Type", "application/json")
	client := p.Client
	if client == nil {
		client = &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	res, err := client.Do(req)
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return Selection{}, errors.New("provider_timeout")
		}
		return Selection{}, errors.New("provider_unavailable") // Never expose network error text or upstream bodies.
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return Selection{}, errors.New("provider_http_error")
	}
	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20+1))
	if err != nil || len(body) > 1<<20 {
		return Selection{}, errors.New("invalid_response")
	}
	var wire struct {
		ID       string `json:"id"`
		Model    string `json:"model"`
		Provider string `json:"provider"`
		Answers  map[string]struct {
			Type          string             `json:"type"`
			Choice        string             `json:"choice"`
			Confidence    *float64           `json:"confidence"`
			Probabilities map[string]float64 `json:"probabilities"`
		} `json:"answers"`
		Usage *Usage `json:"usage"`
	}
	if json.Unmarshal(body, &wire) != nil {
		return Selection{}, errors.New("invalid_response")
	}
	answer, ok := wire.Answers[r.questionID()]
	if !ok || len(wire.Answers) != 1 || answer.Type != "choice" || answer.Confidence == nil || answer.Probabilities == nil {
		return Selection{}, errors.New("invalid_response")
	}
	s := Selection{DecisionID: wire.ID, Model: wire.Model, Provider: wire.Provider, Choice: answer.Choice, Confidence: answer.Confidence, Probabilities: answer.Probabilities, Usage: wire.Usage}
	// Never reflect arbitrary provider text (which could include credentials) into storage or logs.
	if wire.Provider != "TypeSafe" || (wire.Model != Model && !(len(wire.Model) == len(Model)+9 && wire.Model[:len(Model)+1] == Model+"-" && digits(wire.Model[len(Model)+1:]))) || len(wire.ID) > 128 || !safeID(wire.ID) || !strings.HasPrefix(wire.ID, "gen-dec-") || strings.Contains(wire.ID, p.APIKey) {
		return Selection{}, errors.New("invalid_response")
	}
	if err := validateSelection(r, s); err != nil {
		return s, err // Sanitized identity and any valid billing metrics can still be audited.
	}
	return s, nil
}
func digits(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return len(s) > 0
}
func safeID(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' || c == '_') {
			return false
		}
	}
	return true
}
