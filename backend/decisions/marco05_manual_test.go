package decisions

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"
)

// Paid manual battery: requires separate explicit authorization AND opt-in flag.
// At most three provider calls, 15s each; stop after missing usage or cumulative $0.001.
func TestManualMarco05JevComparison(t *testing.T) {
	if os.Getenv("JEV_MARCO05_MANUAL") != "1" {
		t.Skip("paid Marco 05 comparison requires authorization and JEV_MARCO05_MANUAL=1")
	}
	key, e := ResolveOpenRouterAPIKey(".env")
	if e != nil || key == "" {
		t.Fatal("manual_secret_configuration_unavailable")
	}
	total := 0.0
	for _, r := range marco05Histories() {
		r.EventID = fmt.Sprintf("manual-m05-%s-%d", r.ActorID, time.Now().UnixNano())
		s := service(t, &OpenRouterJevProvider{APIKey: key, Timeout: 15 * time.Second})
		out, e := s.Evaluate(context.Background(), r)
		if e != nil {
			t.Fatal(safeReason(e))
		}
		baseline, _ := (DeterministicDecisionProvider{}).Decide(context.Background(), r)
		b, _ := json.Marshal(map[string]any{"profile": r.ActorID, "candidateCount": len(r.Candidates), "choice": out.Choice, "baseline": baseline.Choice, "fallback": out.Fallback, "latencyMs": out.LatencyMS, "usage": out.Usage})
		t.Log(string(b))
		if out.Fallback {
			t.Fatal("real_provider_not_validated_fallback_only")
		}
		if out.Usage == nil || out.Usage.Cost == nil {
			t.Fatal("usage_missing_stop_manual_battery")
		}
		total += *out.Usage.Cost
		if total >= .001 {
			t.Log("manual_budget_reached_remaining_cases_not_run")
			break
		}
	}
}
