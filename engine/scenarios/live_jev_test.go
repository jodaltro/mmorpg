package scenarios

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
)

// Live, billed calls to Jev with real decisions taken from a running world.
// Opt-in: JEV_LIVE=1 and OPENROUTER_API_KEY (or engine/.env).
func TestLiveJevDecidesRealWorldDecisions(t *testing.T) {
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
	jev := &advisor.Jev{APIKey: key, Timeout: 15 * time.Second}

	h := load(t, "valdoria")
	h.join("ana", "bia")
	h.tick(6)
	h.mustAct("player", "ana", "examinar-poco", nil)
	h.mustAct("player", "bia", "examinar-poco", nil)
	h.mustAct("player", "bia", "contar-veneno", map[string]core.ID{"npc": "orin"})
	h.tick(1)
	var decisions []core.Decision
	for _, d := range h.s.Decisions {
		decisions = append(decisions, d)
	}
	q := h.steer("ana", "cenario-origem")
	h.accept("ana", q)
	h.mustAct("adapter", "ana", "seguir-rastro", nil)
	decisions = append(decisions, h.s.Decisions["story:maldicao:origem"])

	for _, d := range decisions {
		if d.ID == "" || len(d.Options) < 2 {
			continue
		}
		start := time.Now()
		a, err := jev.Decide(context.Background(), "valdoria", d)
		el := time.Since(start)
		if err != nil {
			t.Fatalf("%s: %v after %v", d.ID, err, el)
		}
		valid := false
		for _, o := range d.Options {
			valid = valid || o.ID == a.Choice
		}
		if !valid || !strings.HasPrefix(a.Model, advisor.JevModel) || a.Call == "" {
			t.Fatalf("%s: invalid answer %+v", d.ID, a)
		}
		conf, cost := -1.0, -1.0
		if a.Confidence != nil {
			conf = *a.Confidence
		}
		if a.Cost != nil {
			cost = *a.Cost
		}
		t.Logf("%-22s options=%d choice=%q model=%s confidence=%.2f latency=%dms cost=$%.6f",
			d.ID, len(d.Options), a.Choice, a.Model, conf, a.LatencyMS, cost)
		// The engine accepts it as a real resolution.
		if d.Kind == "story" {
			h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: a.Choice, Provider: a.Provider, Model: a.Model, Call: a.Call, Confidence: a.Confidence})
			if h.s.Arcs["maldicao"].Current != a.Choice {
				t.Fatal("story branch not applied")
			}
		}
	}
}
