package scenarios

import (
	"context"
	"fmt"
	"os"
	"slices"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
)

// collectDecisions runs the real Hospedeiro without any advisor and keeps every
// NPC and conflict decision at the moment it was created, so the same labelled
// snapshots can be put to each variant.
func collectDecisions(t *testing.T, ticks int) []core.Decision {
	h := load(t, "hospedeiro")
	seen := map[string]bool{}
	var out []core.Decision
	for i := 0; i < ticks; i++ {
		h.tick(1)
		for _, k := range []string{core.DecisionConflict, core.DecisionNPC} {
			for _, d := range pending(h.s, k) {
				if !seen[d.ID] {
					seen[d.ID] = true
					out = append(out, d)
				}
			}
		}
	}
	return out
}

func median(xs []int64) int64 {
	if len(xs) == 0 {
		return 0
	}
	s := slices.Clone(xs)
	slices.Sort(s)
	return s[len(s)/2]
}

// Live comparison (billed, opt-in): the same real decisions answered one per
// call and in batches of 8/16/32, with Jev 1.13 and, if the endpoint accepts it,
// 1.14. Reports latency, cost, validity, agreement with the deterministic
// default and agreement between single and batch. Nothing here is asserted as
// "better": only validity is a failure.
func TestLiveJevBatchComparison(t *testing.T) {
	if os.Getenv("JEV_LIVE") != "1" {
		t.Skip("JEV_LIVE not set: live Jev calls are opt-in")
	}
	envFile := os.Getenv("JEV_ENV_FILE")
	if envFile == "" {
		envFile = "../.env"
	}
	key, err := advisor.ResolveKey(envFile)
	if err != nil || key == "" {
		t.Fatal("OPENROUTER_API_KEY unavailable")
	}
	all := collectDecisions(t, 1500)
	if len(all) < 32 {
		t.Fatalf("need at least 32 real decisions, got %d", len(all))
	}
	t.Logf("%d real decisions collected (npc/conflict)", len(all))
	for _, model := range []string{advisor.JevModel, "typesafe/jev-1.14"} {
		jev := &advisor.Jev{APIKey: key, Model: model, Timeout: 60 * time.Second}
		probe := jev.DecideBatch(context.Background(), "hospedeiro", "probe", all[:1])
		if probe[0].Err != nil {
			t.Logf("%s: not usable at the endpoint (%v) — skipped", model, probe[0].Err)
			continue
		}
		// One question per call.
		var single []advisor.BatchResult
		var lat []int64
		var cost float64
		for _, d := range all[:16] {
			r := jev.DecideBatch(context.Background(), "hospedeiro", "single", []core.Decision{d})[0]
			single = append(single, r)
			if r.Err == nil {
				lat = append(lat, r.Answer.LatencyMS)
				if r.Answer.Cost != nil {
					cost += *r.Answer.Cost
				}
			}
		}
		valid, agree := 0, 0
		for i, r := range single {
			if r.Err == nil {
				valid++
				if r.Answer.Choice == all[i].Default {
					agree++
				}
			}
		}
		t.Logf("%s single x16: valid=%d/16 same-as-default=%d p50=%dms cost=$%.6f", model, valid, agree, median(lat), cost)
		for _, n := range []int{8, 16, 32} {
			started := time.Now()
			res := jev.DecideBatch(context.Background(), "hospedeiro", "batch", all[:n])
			wall := time.Since(started).Milliseconds()
			valid, agree, same, compared := 0, 0, 0, 0
			var cost float64
			for i, r := range res {
				if r.Err != nil {
					continue
				}
				valid++
				if r.Answer.Cost != nil {
					cost += *r.Answer.Cost
				}
				if r.Answer.Choice == all[i].Default {
					agree++
				}
				if i < len(single) && single[i].Err == nil {
					compared++
					if single[i].Answer.Choice == r.Answer.Choice {
						same++
					}
				}
			}
			t.Logf("%s batch x%d: valid=%d/%d same-as-default=%d single-vs-batch-same=%d/%d wall=%dms cost=$%.6f (%.1fms/question)",
				model, n, valid, n, agree, same, compared, wall, cost, float64(wall)/float64(n))
			for _, r := range res {
				if r.Err != nil {
					t.Logf("  failed question: %s", fmt.Sprint(r.Err))
					break
				}
			}
			if valid == 0 {
				t.Errorf("%s batch x%d: no valid answer at all", model, n)
			}
		}
	}
}
