package scenarios

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
)

// Live, billed call to Jev for the rota decision of the Hospedeiro (opt-in: JEV_LIVE=1; the key comes from OPENROUTER_API_KEY or
// the file named by JEV_ENV_FILE, default ../.env). Records the latency and cost, and checks the engine takes the answer.
func TestLiveJevPointsTheCellToAPlace(t *testing.T) {
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

	h := load(t, "hospedeiro")
	h.join("p1")
	h.move("p1", "sangue")
	var d core.Decision
	for i := 0; i < 30 && d.ID == ""; i++ {
		h.tick(1)
		for _, x := range h.s.Decisions {
			if x.Kind == "rota" {
				d = x
			}
		}
	}
	if d.ID == "" || len(d.Options) < 2 {
		t.Fatal("no rota decision to ask Jev about")
	}
	start := time.Now()
	a, err := jev.Decide(context.Background(), "hospedeiro", d)
	if err != nil {
		t.Fatalf("%s: %v after %v", d.ID, err, time.Since(start))
	}
	if !hasOption(d.Options, a.Choice) {
		t.Fatalf("Jev chose something outside the options: %+v", a)
	}
	cost := -1.0
	if a.Cost != nil {
		cost = *a.Cost
	}
	t.Logf("rota options=%d choice=%q default=%q model=%s latency=%dms cost=$%.6f", len(d.Options), a.Choice, d.Default, a.Model, a.LatencyMS, cost)
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: a.Choice, Provider: a.Provider, Model: a.Model, Call: a.Call, Confidence: a.Confidence})
	v, _ := h.w.View(&h.s, "p1", 50)
	if v.Explore.Route != a.Choice {
		t.Fatalf("the engine did not take Jev's route: %q", v.Explore.Route)
	}
}

func hasOption(opts []core.Option, id string) bool {
	for _, o := range opts {
		if o.ID == id {
			return true
		}
	}
	return false
}
