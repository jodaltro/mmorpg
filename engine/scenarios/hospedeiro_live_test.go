package scenarios

import (
	"context"
	"os"
	"sort"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/advisor"
	"github.com/jodaltro/mmorpg/engine/core"
)

// Live, billed calls to Jev for every kind of decision a Hospedeiro player produces (mutation, class, ability, body, granuloma
// modifier), with two players who live differently. Jev answers each decision as it appears (the way the server would) and the
// test reports, per kind, how often Jev chose something other than the engine's default, plus latency and cost.
// Opt-in: JEV_LIVE=1; the key comes from OPENROUTER_API_KEY or the file named by JEV_ENV_FILE (default ../.env).
func TestLiveJevHospedeiroPlayerDecisions(t *testing.T) {
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
	h.join("lutador", "andarilho")
	for _, p := range []core.ID{"lutador", "andarilho"} {
		h.mustAct("adapter", p, "absorver-nutriente", nil)
		h.move(p, "sangue")
	}

	type stat struct {
		n, differs int
		latency    int64
		cost       float64
		choices    []string
	}
	stats := map[string]*stat{}
	asked := map[string]bool{}
	var answerPass func()
	answer := func() { // answering can create more decisions (the slots of a composed offer): keep going until nothing new
		for before := -1; before != len(asked); {
			before = len(asked)
			answerPass()
		}
	}
	answerPass = func() {
		ids := make([]string, 0, len(h.s.Decisions))
		for id := range h.s.Decisions {
			ids = append(ids, id)
		}
		sort.Strings(ids)
		for _, id := range ids {
			d := h.s.Decisions[id]
			if asked[id] || len(d.Options) < 2 || d.Kind == "world" {
				continue
			}
			asked[id] = true
			a, err := jev.Decide(context.Background(), "hospedeiro", d)
			if err != nil {
				t.Fatalf("%s: %v", id, err)
			}
			if !hasOption(d.Options, a.Choice) {
				t.Fatalf("%s: Jev chose outside the options: %+v", id, a)
			}
			st := stats[d.Kind]
			if st == nil {
				st = &stat{}
				stats[d.Kind] = st
			}
			st.n++
			st.latency += a.LatencyMS
			if a.Cost != nil {
				st.cost += *a.Cost
			}
			if a.Choice != d.Default {
				st.differs++
			}
			st.choices = append(st.choices, d.Subject+":"+a.Choice)
			h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: id, Choice: a.Choice, Provider: a.Provider, Model: a.Model, Call: a.Call, Confidence: a.Confidence})
		}
	}

	for round := 0; round < 20; round++ {
		h.repeat("adapter", "lutador", "estilo-chicote", 4)
		h.repeat("adapter", "lutador", "derrotar-virus", 3)
		h.repeat("adapter", "andarilho", "estilo-impulso", 4)
		h.repeat("adapter", "andarilho", "esquivar", 3)
		h.repeat("adapter", "andarilho", "estilo-explorar", 3)
		h.repeat("adapter", "andarilho", "derrotar-virus", 1)
		h.tick(3)
		answer()
		for _, p := range []core.ID{"lutador", "andarilho"} {
			if round == 6 {
				if _, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: p, Action: "entrar-masmorra", Args: granuloma}); err == nil {
					h.tick(1)
					answer()
				}
			}
		}
	}
	kinds := make([]string, 0, len(stats))
	for k := range stats {
		kinds = append(kinds, k)
	}
	sort.Strings(kinds)
	total := 0
	for _, k := range kinds {
		s := stats[k]
		total += s.n
		t.Logf("%-10s asked=%d chose-other-than-default=%d mean-latency=%dms cost=$%.6f choices=%v", k, s.n, s.differs, s.latency/int64(s.n), s.cost, s.choices)
	}
	for _, who := range []core.ID{"lutador", "andarilho"} {
		t.Logf("%s design=%v offer=%v building=%v", who, h.s.Looks[who].Traits, h.s.Genomes[who].Offer, h.s.Genomes[who].Building)
	}
	for _, want := range []string{"evolution", "lineage", "appearance", "design", "evolution-slot"} {
		if stats[want] == nil {
			t.Errorf("no %s decision reached Jev", want)
		}
	}
	if total == 0 {
		t.Fatal("Jev was never asked")
	}
}
