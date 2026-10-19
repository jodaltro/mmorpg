package advisor

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
)

const (
	JevEndpoint = "https://openrouter.ai/api/alpha/decisions"
	JevModel    = "typesafe/jev-1.13"
)

// Jev asks the OpenRouter Decisions API to choose one option. Option IDs are
// replaced by opaque o1..oN so no internal key reaches the provider, and the
// answer is mapped back and checked before it is returned.
type Jev struct {
	APIKey  string
	URL     string // tests only; empty means the official endpoint
	Client  *http.Client
	Timeout time.Duration
}

type jevQuestion struct {
	Type         string            `json:"type"`
	Instructions string            `json:"instructions"`
	Criteria     map[string]string `json:"criteria"`
}

type jevRequest struct {
	Model     string                 `json:"model"`
	State     map[string]any         `json:"state"`
	Questions map[string]jevQuestion `json:"questions"`
}

var instructions = map[string]string{
	"offer": "Choose the single opportunity that best fits this player now, given what they know, what they did recently and what is happening in the world. Prefer variety and personal relevance. Use only the supplied criteria IDs.",
	"story": "Choose how the shared world story continues after this chapter, given who concluded it and the recent public events. Prefer the continuation that makes the world feel reactive and coherent. Use only the supplied criteria IDs.",
}

func (j *Jev) Decide(ctx context.Context, universe string, d core.Decision) (Answer, error) {
	if j.APIKey == "" {
		return Answer{}, errors.New("missing_api_key")
	}
	if len(d.Options) < 2 || len(d.Options) > 64 || instructions[d.Kind] == "" {
		return Answer{}, errors.New("invalid_decision")
	}
	criteria := map[string]string{}
	back := map[string]string{}
	for i, o := range d.Options {
		k := "o" + strconv.Itoa(i+1)
		criteria[k] = clip(o.Title+". "+o.Desc, 400)
		back[k] = o.ID
	}
	ctxLines := []string{}
	for _, c := range d.Context {
		ctxLines = append(ctxLines, clip(c, 256))
	}
	body, err := json.Marshal(jevRequest{Model: JevModel,
		State:     map[string]any{"universe": universe, "decision": d.Kind, "context": ctxLines},
		Questions: map[string]jevQuestion{"choice": {Type: "choice", Instructions: instructions[d.Kind], Criteria: criteria}}})
	if err != nil {
		return Answer{}, errors.New("invalid_request")
	}
	timeout := j.Timeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	url := j.URL
	if url == "" {
		url = JevEndpoint
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return Answer{}, errors.New("invalid_endpoint")
	}
	req.Header.Set("Authorization", "Bearer "+j.APIKey)
	req.Header.Set("Content-Type", "application/json")
	client := j.Client
	if client == nil {
		client = &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	res, err := client.Do(req)
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return Answer{}, errors.New("provider_timeout")
		}
		return Answer{}, errors.New("provider_unavailable") // never expose upstream error text
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return Answer{}, errors.New("provider_http_error")
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 1<<20+1))
	if err != nil || len(raw) > 1<<20 {
		return Answer{}, errors.New("invalid_response")
	}
	var wire struct {
		Model    string `json:"model"`
		Provider string `json:"provider"`
		Answers  map[string]struct {
			Type          string             `json:"type"`
			Choice        string             `json:"choice"`
			Confidence    *float64           `json:"confidence"`
			Probabilities map[string]float64 `json:"probabilities"`
		} `json:"answers"`
	}
	if json.Unmarshal(raw, &wire) != nil {
		return Answer{}, errors.New("invalid_response")
	}
	a, ok := wire.Answers["choice"]
	if !ok || len(wire.Answers) != 1 || a.Type != "choice" || back[a.Choice] == "" {
		return Answer{}, errors.New("invalid_choice")
	}
	if a.Confidence != nil && (math.IsNaN(*a.Confidence) || *a.Confidence < 0 || *a.Confidence > 1) {
		return Answer{}, errors.New("invalid_confidence")
	}
	if !strings.HasPrefix(wire.Model, JevModel) || strings.Contains(wire.Model, j.APIKey) || len(wire.Model) > 64 {
		return Answer{}, errors.New("invalid_model")
	}
	return Answer{Choice: back[a.Choice], Provider: "jev", Model: wire.Model, Confidence: a.Confidence}, nil
}

func clip(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
