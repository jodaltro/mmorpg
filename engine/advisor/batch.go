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

// BatchAdvisor answers several decisions that share one snapshot in a single
// call. Each decision still gets its own result: a bad or missing answer for
// one never spoils the others, and the engine revalidates every one.
type BatchAdvisor interface {
	Advisor
	DecideBatch(ctx context.Context, universe string, group string, ds []core.Decision) []BatchResult
}

// BatchResult is the outcome for one decision of a batch.
type BatchResult struct {
	Decision string
	Answer   Answer
	Err      error
}

// MaxBatch bounds a single request so cost, latency and size stay predictable.
const MaxBatch = 32

func mapProbs(in map[string]float64, back map[string]string) map[string]float64 {
	if len(in) == 0 {
		return nil
	}
	out := map[string]float64{}
	for k, p := range in {
		if id, ok := back[k]; ok && !math.IsNaN(p) && p >= 0 && p <= 1 {
			out[id] = p
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// DecideBatch sends the decisions as named choice questions of one request.
// Context stays per question so nothing leaks between them; option ids are
// opaque, as in Decide.
func (j *Jev) DecideBatch(ctx context.Context, universe, group string, ds []core.Decision) []BatchResult {
	out := make([]BatchResult, len(ds))
	for i, d := range ds {
		out[i].Decision = d.ID
		out[i].Err = errors.New("no_answer")
	}
	fail := func(err error) []BatchResult {
		for i := range out {
			out[i].Err = err
		}
		return out
	}
	if j.APIKey == "" {
		return fail(errors.New("missing_api_key"))
	}
	if len(ds) == 0 || len(ds) > MaxBatch {
		return fail(errors.New("invalid_batch"))
	}
	questions := map[string]jevQuestion{}
	contexts := map[string]any{}
	backs := map[string]map[string]string{}
	names := make([]string, len(ds))
	for i, d := range ds {
		if len(d.Options) < 2 || len(d.Options) > 64 || instructions[d.Kind] == "" {
			out[i].Err = errors.New("invalid_decision")
			continue
		}
		q := "q" + strconv.Itoa(i+1)
		names[i] = q
		criteria := map[string]string{}
		back := map[string]string{}
		for k, o := range d.Options {
			key := "o" + strconv.Itoa(k+1)
			criteria[key] = clip(o.Title+". "+o.Desc, 400)
			back[key] = o.ID
		}
		lines := []string{}
		for _, c := range head(d.Context, 32) {
			lines = append(lines, clip(c, 256))
		}
		questions[q] = jevQuestion{Type: "choice", Instructions: instructions[d.Kind], Criteria: criteria}
		contexts[q] = lines
		backs[q] = back
	}
	if len(questions) == 0 {
		return out
	}
	body, err := json.Marshal(jevRequest{Model: j.model(), State: map[string]any{"universe": universe, "group": group, "contexts": contexts}, Questions: questions})
	if err != nil {
		return fail(errors.New("invalid_request"))
	}
	timeout := j.Timeout
	if timeout <= 0 {
		timeout = 10 * time.Second
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	url := j.URL
	if url == "" {
		url = JevEndpoint
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return fail(errors.New("invalid_endpoint"))
	}
	req.Header.Set("Authorization", "Bearer "+j.APIKey)
	req.Header.Set("Content-Type", "application/json")
	client := j.Client
	if client == nil {
		client = &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	}
	started := time.Now()
	res, err := client.Do(req)
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return fail(errors.New("provider_timeout"))
		}
		return fail(errors.New("provider_unavailable"))
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fail(errors.New("provider_http_error"))
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 4<<20+1))
	if err != nil || len(raw) > 4<<20 {
		return fail(errors.New("invalid_response"))
	}
	var wire struct {
		ID    string `json:"id"`
		Model string `json:"model"`
		Usage *struct {
			Cost *float64 `json:"cost"`
		} `json:"usage"`
		Answers map[string]struct {
			Type          string             `json:"type"`
			Choice        string             `json:"choice"`
			Confidence    *float64           `json:"confidence"`
			Probabilities map[string]float64 `json:"probabilities"`
		} `json:"answers"`
	}
	if json.Unmarshal(raw, &wire) != nil {
		return fail(errors.New("invalid_response"))
	}
	if !strings.HasPrefix(wire.Model, j.model()) || strings.Contains(wire.Model, j.APIKey) || len(wire.Model) > 64 {
		return fail(errors.New("invalid_model"))
	}
	latency := time.Since(started).Milliseconds()
	var cost *float64
	if wire.Usage != nil && wire.Usage.Cost != nil && *wire.Usage.Cost >= 0 && !math.IsInf(*wire.Usage.Cost, 0) && !math.IsNaN(*wire.Usage.Cost) {
		share := *wire.Usage.Cost / float64(len(questions)) // the call's cost, split evenly for audit
		cost = &share
	}
	call := ""
	if validCall(wire.ID) && !strings.Contains(wire.ID, j.APIKey) {
		call = wire.ID
	}
	for i, q := range names {
		if q == "" {
			continue
		}
		a, ok := wire.Answers[q]
		if !ok || a.Type != "choice" || backs[q][a.Choice] == "" {
			out[i].Err = errors.New("invalid_choice")
			continue
		}
		if a.Confidence != nil && (math.IsNaN(*a.Confidence) || *a.Confidence < 0 || *a.Confidence > 1) {
			out[i].Err = errors.New("invalid_confidence")
			continue
		}
		out[i].Err = nil
		out[i].Answer = Answer{Choice: backs[q][a.Choice], Provider: "jev", Model: wire.Model, Call: call, Confidence: a.Confidence, Cost: cost,
			LatencyMS: latency, Probabilities: mapProbs(a.Probabilities, backs[q])}
	}
	return out
}
