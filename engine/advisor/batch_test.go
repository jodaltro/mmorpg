package advisor

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
)

func npcDecision(id string) core.Decision {
	return core.Decision{ID: id, Kind: core.DecisionNPC, Subject: "neva", Default: "defender-pulmao",
		Options: []core.Option{{ID: "defender-pulmao", Title: "Defend"}, {ID: "vigiar-pulmao", Title: "Patrol"}, {ID: core.WaitChoice, Title: "Wait"}},
		Context: []string{"npc: Neva in sangue", "believes foco at pulmao"}}
}

func batchServer(t *testing.T, reply func(req map[string]any) (int, string)) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		if strings.Contains(string(b), "defender-pulmao") || strings.Contains(string(b), "test-key") {
			t.Error("internal ids or the key reached the provider")
		}
		var req map[string]any
		_ = json.Unmarshal(b, &req)
		code, body := reply(req)
		w.WriteHeader(code)
		_, _ = w.Write([]byte(body))
	}))
}

func TestBatchOneRequestManyQuestionsMappedBack(t *testing.T) {
	calls := 0
	s := batchServer(t, func(req map[string]any) (int, string) {
		calls++
		if n := len(req["questions"].(map[string]any)); n != 3 {
			t.Errorf("want 3 questions in one call, got %d", n)
		}
		return 200, `{"id":"gen-dec-9","model":"typesafe/jev-1.13","usage":{"cost":0.003},"answers":{
			"q1":{"type":"choice","choice":"o3","confidence":0.8,"probabilities":{"o1":0.1,"o2":0.1,"o3":0.8}},
			"q2":{"type":"choice","choice":"o1"},
			"q3":{"type":"choice","choice":"o2"}}}`
	})
	defer s.Close()
	res := (&Jev{APIKey: "test-key", URL: s.URL}).DecideBatch(context.Background(), "hospedeiro", "npc", []core.Decision{npcDecision("a"), npcDecision("b"), npcDecision("c")})
	if calls != 1 || len(res) != 3 {
		t.Fatalf("calls=%d results=%d", calls, len(res))
	}
	want := []string{core.WaitChoice, "defender-pulmao", "vigiar-pulmao"}
	for i, r := range res {
		if r.Err != nil || r.Answer.Choice != want[i] || r.Decision != []string{"a", "b", "c"}[i] {
			t.Fatalf("%d: %+v", i, r)
		}
	}
	if p := res[0].Answer.Probabilities; p[core.WaitChoice] != 0.8 || len(p) != 3 {
		t.Fatalf("probabilities must come back by option id: %v", p)
	}
	if c := res[0].Answer.Cost; c == nil || *c < 0.00099 || *c > 0.00101 {
		t.Fatalf("cost is split evenly across the questions: %v", c)
	}
}

func TestBatchPartialAnswersFailOnlyTheirOwnQuestion(t *testing.T) {
	s := batchServer(t, func(map[string]any) (int, string) {
		return 200, `{"model":"typesafe/jev-1.13","answers":{
			"q1":{"type":"choice","choice":"o1"},
			"q2":{"type":"choice","choice":"o99"},
			"q4":{"type":"choice","choice":"o2","confidence":7}}}`
	})
	defer s.Close()
	ds := []core.Decision{npcDecision("a"), npcDecision("b"), npcDecision("c"), npcDecision("d")}
	res := (&Jev{APIKey: "test-key", URL: s.URL}).DecideBatch(context.Background(), "hospedeiro", "npc", ds)
	if res[0].Err != nil {
		t.Fatalf("the valid answer must survive: %+v", res[0])
	}
	for i := 1; i < 4; i++ {
		if res[i].Err == nil {
			t.Errorf("question %d (unknown option / missing / bad confidence) must fail", i+1)
		}
	}
}

func TestBatchProviderFailuresFailEveryQuestion(t *testing.T) {
	ds := []core.Decision{npcDecision("a"), npcDecision("b")}
	for name, body := range map[string]string{"not json": `<html>`, "wrong model": `{"model":"x/y","answers":{}}`} {
		s := batchServer(t, func(map[string]any) (int, string) { return 200, body })
		for _, r := range (&Jev{APIKey: "test-key", URL: s.URL}).DecideBatch(context.Background(), "u", "npc", ds) {
			if r.Err == nil {
				t.Errorf("%s: must fail", name)
			}
		}
		s.Close()
	}
	s := batchServer(t, func(map[string]any) (int, string) { return 500, `boom` })
	defer s.Close()
	if r := (&Jev{APIKey: "test-key", URL: s.URL}).DecideBatch(context.Background(), "u", "npc", ds); r[0].Err == nil || r[1].Err == nil {
		t.Fatal("http error must fail all")
	}
	slow := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { time.Sleep(300 * time.Millisecond) }))
	defer slow.Close()
	started := time.Now()
	r := (&Jev{APIKey: "test-key", URL: slow.URL, Timeout: 50 * time.Millisecond}).DecideBatch(context.Background(), "u", "npc", ds)
	if r[0].Err == nil || time.Since(started) > 250*time.Millisecond {
		t.Fatalf("timeout must cut the call: %v after %v", r[0].Err, time.Since(started))
	}
}

func TestBatchLimitsAndModelOverride(t *testing.T) {
	j := &Jev{APIKey: "test-key", URL: "http://127.0.0.1:1"}
	if r := j.DecideBatch(context.Background(), "u", "npc", nil); len(r) != 0 {
		t.Fatal("empty batch has no results")
	}
	many := make([]core.Decision, MaxBatch+1)
	for i := range many {
		many[i] = npcDecision("x")
	}
	if r := j.DecideBatch(context.Background(), "u", "npc", many); r[0].Err == nil {
		t.Fatal("an oversize batch must be refused")
	}
	var model string
	s := batchServer(t, func(req map[string]any) (int, string) {
		model, _ = req["model"].(string)
		return 200, `{"model":"typesafe/jev-1.14","answers":{"q1":{"type":"choice","choice":"o1"}}}`
	})
	defer s.Close()
	res := (&Jev{APIKey: "test-key", URL: s.URL, Model: "typesafe/jev-1.14"}).DecideBatch(context.Background(), "u", "npc", []core.Decision{npcDecision("a")})
	if model != "typesafe/jev-1.14" || res[0].Err != nil {
		t.Fatalf("model=%q %+v", model, res[0])
	}
	// A 1.13 client does not accept a 1.14 reply.
	if r := (&Jev{APIKey: "test-key", URL: s.URL}).DecideBatch(context.Background(), "u", "npc", []core.Decision{npcDecision("a")}); r[0].Err == nil {
		t.Fatal("model mismatch must be rejected")
	}
}
