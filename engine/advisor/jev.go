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
	Model   string // empty means JevModel; e.g. typesafe/jev-1.14 for the A/B
}

func (j *Jev) model() string {
	if j.Model != "" {
		return j.Model
	}
	return JevModel
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
	"offer":          "Choose the single opportunity that best fits this player now, given what they know, what they did recently, their learned play style, how the giver feels about them and what is happening in the world. Prefer variety and personal relevance; the fit score is a hint, not a rule. Use only the supplied criteria IDs.",
	"world":          "You are the director of a shared persistent world. Choose which of the supplied happenings occurs now, or none, so the world feels alive, coherent with recent events and the ongoing story, and gives players new things to react to. Follow the pacing phase in the context: in build-up prefer intense threats, in relax prefer calm or relieving happenings (or none), in sustain keep a mix. Strongly prefer variety: favor happenings that never happened or happened long ago, and avoid repeating the same kind of event. Use only the supplied criteria IDs.",
	"evolution":      "Every player's rooted goal is to evolve. Choose the single mutation this player's body leans towards now, judging from how they have been living: the play style learned from their deeds, their skills, stats, knowledge, completed quests and the genes they already express. Prefer deepening the path they are clearly on; when their deeds point somewhere new, follow that. The fit score is a hint, not a rule. Use only the supplied criteria IDs.",
	"appearance":     "Every player's body is procedural and personal. Choose the single body variant that best reflects how this particular person plays: which attacks they favour, how they move and dodge, what they eat, who they talk to and befriend, what they know and which genes they express. Make this player recognisable and different from others. The fit score is a hint, not a rule. Use only the supplied criteria IDs.",
	"lineage":        "Every player is born undifferentiated and grows into a lineage of cells, which permanently shapes their body and abilities. Choose the single lineage this player's body leans towards, judging from how they have been living: the play style learned from their deeds, the attacks they favour, how they move, who they befriend, their genes and what they know. Pick the path that fits this person, not the strongest one. The fit score is a hint, not a rule. Use only the supplied criteria IDs.",
	"ability":        "A cell of a lineage keeps awakening abilities as it lives. Choose the single ability this player's body awakens next, judging from how they have been playing: the attacks they favour, how they move and dodge, who they befriend, what they know and the genes they express. Pick the ability that expands what this particular person already does, or opens the path their deeds point to. The fit score is a hint, not a rule. Use only the supplied criteria IDs.",
	"dungeon":        "A player is about to enter a dungeon. Choose the single modifier that makes this particular run most interesting for them: one that tests how they actually play (their favourite attacks, how they move, what they have learned and the genes they express) without being unfair, or that opens a path their deeds point to. Use only the supplied criteria IDs.",
	"evolution-slot": "One slot of a player's mutation offer is being composed. The context says what the other slots are. Choose the single mutation that gives this slot its own reason to exist for this particular player: deepen the path their life points to, offer a surprising alternative that fits who they could become, or hedge. Avoid mutations that merely repeat what is already offered or expressed. Use only the supplied criteria IDs.",
	"design":         "You are the designer of one procedural trait of a player's cell in a living body. The first context line names the trait. Choose the single option that makes this particular cell distinctive and true to how this person lives: their play style, deeds, class, genes, the places they made home. Other traits are being designed in parallel, so be bold and specific rather than choosing the safe average. Use only the supplied criteria IDs.",
	"rota":           "A cell is exploring the body of its host. Choose the single hidden place to point it to next, judging from how this particular player lives: the genes they express, what they already found, how they play, and the state of the body. Prefer a place that fits who they are or opens a path they have not walked; avoid sending them back over ground they know. Use only the supplied criteria IDs.",
	"npc":            "A named cell of a living body is idle and could start one of several tasks, or keep its routine and wait. Choose what it should do next, judging only from what this cell itself believes and remembers, the public state of the crisis and the priorities listed. Prefer the task that responds to a real, current need; prefer waiting when nothing is needed or the information is insufficient. Use only the supplied criteria IDs.",
	"conflict":       "A persistent crisis of a living body has just started or escalated. Choose how the body responds, spending its finite reserve only when the numbers justify it: severity, the trend implied by the peak, how many defenders and carriers remain and how often it came back. Prefer keeping the reserve when the cohorts are holding the threat. Use only the supplied criteria IDs.",
	"attention":      "Several crises of a living body are alive at once and its defenders, carriers and marrow reserve are finite. Choose which single crisis the body should concentrate on now, judging from phase, severity, how long it has lasted, how often it came back and what it could cascade into. Prefer the one where concentrating effort changes the outcome most, not simply the one that looks loudest. Use only the supplied criteria IDs.",
	"story":          "Choose how the shared world story continues after this chapter, given who concluded it and the recent public events. Prefer the continuation that makes the world feel reactive and coherent. Use only the supplied criteria IDs.",
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
	for _, c := range head(d.Context, 32) {
		ctxLines = append(ctxLines, clip(c, 256))
	}
	body, err := json.Marshal(jevRequest{Model: j.model(),
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
	started := time.Now()
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
		ID    string `json:"id"`
		Model string `json:"model"`
		Usage *struct {
			Cost *float64 `json:"cost"`
		} `json:"usage"`
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
	if !strings.HasPrefix(wire.Model, j.model()) || strings.Contains(wire.Model, j.APIKey) || len(wire.Model) > 64 {
		return Answer{}, errors.New("invalid_model")
	}
	ans := Answer{Choice: back[a.Choice], Provider: "jev", Model: wire.Model, Confidence: a.Confidence, LatencyMS: time.Since(started).Milliseconds()}
	ans.Probabilities = mapProbs(a.Probabilities, back)
	if validCall(wire.ID) && !strings.Contains(wire.ID, j.APIKey) {
		ans.Call = wire.ID
	}
	if wire.Usage != nil && wire.Usage.Cost != nil && *wire.Usage.Cost >= 0 && !math.IsInf(*wire.Usage.Cost, 0) {
		ans.Cost = wire.Usage.Cost
	}
	return ans, nil
}

func validCall(id string) bool {
	if !strings.HasPrefix(id, "gen-dec-") || len(id) > 128 {
		return false
	}
	for _, c := range id {
		if !(c >= 0x61 && c <= 0x7a || c >= 0x41 && c <= 0x5a || c >= 0x30 && c <= 0x39 || c == 0x2d || c == 0x5f) {
			return false
		}
	}
	return true
}

func head(xs []string, n int) []string {
	if len(xs) > n {
		return xs[:n]
	}
	return xs
}

func clip(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
