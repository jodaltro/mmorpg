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

var decision = core.Decision{ID: "offer:p1:7", Kind: "offer", Subject: "p1", Default: "avisar|p1|mira",
	Options: []core.Option{{ID: "avisar|p1|mira", Title: "Avise Mira"}, {ID: "cenario-origem|p1", Title: "Cenario Unico"}},
	Context: []string{"player: Ana", "believes poisoned poco = true (observation)"}}

func server(t *testing.T, reply func(req map[string]any) (int, string)) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-key" {
			t.Error("missing bearer")
		}
		b, _ := io.ReadAll(r.Body)
		var req map[string]any
		if err := json.Unmarshal(b, &req); err != nil {
			t.Error(err)
		}
		if strings.Contains(string(b), "cenario-origem|p1") {
			t.Error("internal option keys must not reach the provider")
		}
		code, body := reply(req)
		w.WriteHeader(code)
		w.Write([]byte(body))
	}))
}

func TestJevMapsOpaqueOptionsBack(t *testing.T) {
	s := server(t, func(req map[string]any) (int, string) {
		q := req["questions"].(map[string]any)["choice"].(map[string]any)
		if q["type"] != "choice" || len(q["criteria"].(map[string]any)) != 2 {
			t.Errorf("bad question %+v", q)
		}
		return 200, `{"id":"gen-dec-1","model":"typesafe/jev-1.13","provider":"TypeSafe","answers":{"choice":{"type":"choice","choice":"o2","confidence":0.7,"probabilities":{"o1":0.3,"o2":0.7}}}}`
	})
	defer s.Close()
	a, err := (&Jev{APIKey: "test-key", URL: s.URL}).Decide(context.Background(), "valdoria", decision)
	if err != nil || a.Choice != "cenario-origem|p1" || a.Provider != "jev" {
		t.Fatalf("%+v %v", a, err)
	}
}

func TestJevRejectsBadAnswers(t *testing.T) {
	bodies := map[string]string{
		"unknown option": `{"model":"typesafe/jev-1.13","answers":{"choice":{"type":"choice","choice":"o9"}}}`,
		"wrong model":    `{"model":"other/model","answers":{"choice":{"type":"choice","choice":"o1"}}}`,
		"bad confidence": `{"model":"typesafe/jev-1.13","answers":{"choice":{"type":"choice","choice":"o1","confidence":4}}}`,
		"not json":       `<html>`,
	}
	for name, body := range bodies {
		s := server(t, func(map[string]any) (int, string) { return 200, body })
		if _, err := (&Jev{APIKey: "test-key", URL: s.URL}).Decide(context.Background(), "valdoria", decision); err == nil {
			t.Errorf("%s accepted", name)
		}
		s.Close()
	}
	s := server(t, func(map[string]any) (int, string) { return 500, `{}` })
	if _, err := (&Jev{APIKey: "test-key", URL: s.URL}).Decide(context.Background(), "valdoria", decision); err == nil {
		t.Error("http error accepted")
	}
	s.Close()
	if _, err := (&Jev{}).Decide(context.Background(), "valdoria", decision); err == nil {
		t.Error("missing key accepted")
	}
}

func TestJevTimeout(t *testing.T) {
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(2 * time.Second):
		}
	}))
	defer s.Close()
	start := time.Now()
	_, err := (&Jev{APIKey: "test-key", URL: s.URL, Timeout: 50 * time.Millisecond}).Decide(context.Background(), "valdoria", decision)
	if err == nil || err.Error() != "provider_timeout" || time.Since(start) > time.Second {
		t.Fatalf("%v after %v", err, time.Since(start))
	}
}
