package decisions

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"
)

// Explicit manual opt-in only. Regression suites never enable this environment flag.
func TestManualWorldOpenRouter(t *testing.T) {
	if os.Getenv("JEV_MANUAL_TEST") != "1" {
		t.Skip("manual paid validation requires JEV_MANUAL_TEST=1")
	}
	key, err := ResolveOpenRouterAPIKey(".env")
	if err != nil {
		t.Fatal("invalid_secret_configuration")
	}
	if key == "" {
		t.Skip("OPENROUTER_API_KEY is not configured")
	}
	r := worldFixture()
	r.EventID = fmt.Sprintf("manual-world-%d", time.Now().UnixNano())
	started := time.Now()
	result, err := (&OpenRouterJevProvider{APIKey: key, Timeout: 15 * time.Second}).Decide(context.Background(), r)
	if err != nil {
		t.Fatal(safeReason(err))
	}
	evidence := map[string]any{"decisionId": result.DecisionID, "model": result.Model, "choice": result.Choice, "confidence": result.Confidence, "probabilities": result.Probabilities, "latencyMs": time.Since(started).Milliseconds(), "usage": result.Usage, "candidateCount": len(r.Candidates), "context": "synthetic verified-rule fixture"}
	b, _ := json.Marshal(evidence)
	t.Log(string(b))
}
