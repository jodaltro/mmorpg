package decisions

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"sync"
	"time"
)

type DecisionService interface {
	Evaluate(context.Context, Request) (Response, error)
}
type Service struct {
	Provider          DecisionProvider
	MinimumConfidence float64 // 0 disables gating; calibrate before setting a production threshold.
	Timeout           time.Duration
	Directory         string
	Logger            *slog.Logger
	mu                sync.Mutex // Single local prototype instance: serializes evaluation and durable deduplication.
}
type storedDecision struct {
	Version     int      `json:"version"`
	Checksum    string   `json:"checksum"`
	Fingerprint string   `json:"fingerprint"`
	Request     Request  `json:"request"`
	Response    Response `json:"response"`
}

func hash(value any) string {
	b, _ := json.Marshal(value)
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
func identity(r Request) string { return hash([]string{r.ActorID, r.WorldID, r.EventID, r.PolicyID}) }
func (s *Service) Evaluate(ctx context.Context, r Request) (Response, error) {
	if err := r.Validate(); err != nil {
		return Response{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.Directory == "" {
		return Response{}, ErrStorage
	}
	path := filepath.Join(s.Directory, identity(r)+".json")
	if b, err := os.ReadFile(path); err == nil {
		var saved storedDecision
		if json.Unmarshal(b, &saved) != nil || saved.Version != 1 || saved.Checksum != storedChecksum(saved) || saved.Fingerprint != hash(saved.Request) || identity(saved.Request) != identity(r) || validateStored(saved) != nil {
			return Response{}, ErrStorage
		}
		if saved.Fingerprint != hash(r) {
			return Response{}, ErrConflict
		}
		return saved.Response, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return Response{}, ErrStorage
	}
	started := time.Now()
	det := DeterministicDecisionProvider{}
	var selected Selection
	var reason string
	var attempt *Selection
	if len(r.EligibleConsequences) == 0 {
		selected, _ = det.Decide(ctx, r)
	} else {
		timeout := s.Timeout
		if timeout <= 0 {
			timeout = 6 * time.Second
		}
		bounded, cancel := context.WithTimeout(ctx, timeout)
		provider := s.Provider
		if provider == nil {
			provider = det
		}
		var err error
		selected, err = provider.Decide(bounded, r)
		cancel()
		if err == nil {
			err = validateSelection(r, selected)
		}
		if err == nil && s.MinimumConfidence > 0 && (selected.Confidence == nil || *selected.Confidence < s.MinimumConfidence) {
			copy := selected
			attempt = &copy
			err = errors.New("low_confidence")
		}
		if err != nil {
			if _, ok := provider.(*OpenRouterJevProvider); ok && selected.DecisionID != "" && attempt == nil {
				copy := auditableAttempt(r, selected)
				attempt = &copy
			}
			// Error messages from arbitrary providers must never become log or response text.
			reason = safeReason(err)
			selected, _ = det.Decide(ctx, r)
		}
	}
	out := Response{Version: 1, EventID: r.EventID, ActorID: r.ActorID, WorldID: r.WorldID, StateVersion: r.StateVersion, PolicyID: r.PolicyID,
		Selection: selected, LatencyMS: time.Since(started).Milliseconds(), Fallback: reason != "", FallbackReason: reason, Attempt: attempt}
	saved := storedDecision{Version: 1, Fingerprint: hash(r), Request: r, Response: out}
	saved.Checksum = storedChecksum(saved)
	if err := writeStored(path, saved); err != nil {
		return Response{}, ErrStorage
	}
	if s.Logger != nil {
		measured := selected
		if attempt != nil {
			measured = *attempt
		}
		s.Logger.Info("decision", "decisionId", measured.DecisionID, "model", measured.Model, "choice", out.Choice, "confidence", measured.Confidence,
			"probabilities", measured.Probabilities, "latencyMs", out.LatencyMS, "usage", measured.Usage, "fallback", out.Fallback, "reason", reason)
	}
	return out, nil
}
func safeReason(err error) string {
	for _, code := range []string{"missing_api_key", "provider_timeout", "provider_unavailable", "provider_http_error", "invalid_response", "invalid_choice", "invalid_probabilities", "invalid_usage", "low_confidence"} {
		if err.Error() == code {
			return code
		}
	}
	return "provider_error"
}
func validateStored(s storedDecision) error {
	r, o := s.Request, s.Response
	if r.Validate() != nil || o.Version != 1 || o.EventID != r.EventID || o.ActorID != r.ActorID || o.WorldID != r.WorldID || o.PolicyID != r.PolicyID || o.StateVersion != r.StateVersion || o.LatencyMS < 0 {
		return ErrStorage
	}
	return validateSelection(r, o.Selection)
}
func storedChecksum(s storedDecision) string {
	return hash(struct {
		Request  Request
		Response Response
	}{s.Request, s.Response})
}
func auditableAttempt(r Request, s Selection) Selection {
	if !slices.Contains(r.EligibleConsequences, s.Choice) {
		s.Choice = ""
	}
	if s.Confidence != nil && !validProbability(*s.Confidence) {
		s.Confidence = nil
	}
	probe := s
	probe.Choice = r.EligibleConsequences[0]
	probe.Usage = nil
	if validateSelection(r, probe) != nil {
		s.Probabilities = nil
	}
	probe = s
	probe.Choice = r.EligibleConsequences[0]
	probe.Probabilities = nil
	if validateSelection(r, probe) != nil {
		s.Usage = nil
	}
	return s
}
func writeStored(path string, value storedDecision) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".decision-*.tmp")
	if err != nil {
		return err
	}
	name := f.Name()
	defer os.Remove(name)
	if _, err = f.Write(b); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(name, path) // New per-event file only; never replace an existing decision.
}
