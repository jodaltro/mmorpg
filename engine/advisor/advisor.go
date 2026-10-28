// Package advisor connects world decisions to an external chooser such as
// Jev. Advisors only pick among options the engine already validated; the
// engine revalidates the answer and applies a deterministic default at the
// deadline, so a slow or absent advisor never blocks the world or combat.
package advisor

import (
	"context"
	"errors"

	"github.com/jodaltro/mmorpg/engine/core"
)

type Answer struct {
	Choice     string
	Provider   string
	Model      string
	Call       string
	Confidence *float64
	Cost       *float64
	LatencyMS  int64
	// Probabilities by option id, when the provider gives them. Kept for audit
	// only: the engine never reads them to decide anything.
	Probabilities map[string]float64
}

type Advisor interface {
	Decide(ctx context.Context, universe string, d core.Decision) (Answer, error)
}

var ErrNoChoice = errors.New("advisor_no_choice")

// Deterministic answers with the engine default. Useful to exercise the
// asynchronous path without any external service.
type Deterministic struct{}

func (Deterministic) Decide(_ context.Context, _ string, d core.Decision) (Answer, error) {
	if d.Default == "" {
		return Answer{}, ErrNoChoice
	}
	return Answer{Choice: d.Default, Provider: "deterministic", Model: "default-v1"}, nil
}
