package api

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/sim"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

func setup(t *testing.T) (*sim.Runner, *httptest.Server) {
	w, err := universe.Load("../../universes/valdoria/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	r, _ := sim.Open(w, &store.Memory{}, sim.Options{})
	s := httptest.NewServer(Handler(r))
	t.Cleanup(func() { s.Close(); r.Close() })
	return r, s
}

func post(t *testing.T, url, body string) (int, map[string]any) {
	res, err := http.Post(url+"/v1/commands", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	var out map[string]any
	json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out
}

func TestCommandsAndPerObserverViews(t *testing.T) {
	r, s := setup(t)
	for _, b := range []string{
		`{"version":1,"requestId":"j1","origin":"adapter","kind":"join","actor":"p1","name":"Ana"}`,
		`{"version":1,"requestId":"j2","origin":"adapter","kind":"join","actor":"p2","name":"Bia"}`,
	} {
		if code, out := post(t, s.URL, b); code != 200 {
			t.Fatalf("%d %v", code, out)
		}
	}
	for i := 0; i < 6; i++ {
		r.Tick()
	}
	if code, _ := post(t, s.URL, `{"version":1,"requestId":"a1","origin":"player","kind":"act","actor":"p1","action":"examinar-poco"}`); code != 200 {
		t.Fatal(code)
	}
	if code, _ := post(t, s.URL, `{"version":1,"requestId":"a2","origin":"player","kind":"act","actor":"p1","action":"seguir-rastro"}`); code != 409 {
		t.Fatalf("adapter-only action from a player must be 409, got %d", code)
	}
	for _, bad := range []string{
		`{"version":1,"requestId":"t","origin":"system","kind":"tick"}`,
		`{"version":1,"requestId":"x","origin":"advisor","kind":"resolve","actor":"p1"}`,
		`{"version":1,"requestId":"x","origin":"player","kind":"act","actor":"p1","action":"examinar-poco","damage":999}`,
	} {
		if code, _ := post(t, s.URL, bad); code != 400 {
			t.Fatalf("%s accepted with %d", bad, code)
		}
	}
	get := func(path string) core.View {
		res, err := http.Get(s.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		var v core.View
		json.NewDecoder(res.Body).Decode(&v)
		return v
	}
	if v := get("/v1/views/p1"); len(v.Beliefs) != 1 {
		t.Fatalf("p1 view %+v", v.Beliefs)
	}
	if v := get("/v1/views/p2"); len(v.Beliefs) != 0 {
		t.Fatalf("p2 must not see p1 knowledge: %+v", v.Beliefs)
	}
	req, _ := http.NewRequest("GET", s.URL+"/v1/views/p1", nil)
	req.Header.Set("Origin", "https://evil.example")
	if res, _ := http.DefaultClient.Do(req); res.StatusCode != 403 {
		t.Fatalf("cross-origin browser call must be refused, got %d", res.StatusCode)
	}
}

func TestStreamPushesOnlyVisibleEvents(t *testing.T) {
	r, s := setup(t)
	post(t, s.URL, `{"version":1,"requestId":"j1","origin":"adapter","kind":"join","actor":"p1"}`)
	post(t, s.URL, `{"version":1,"requestId":"j2","origin":"adapter","kind":"join","actor":"p2"}`)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, "GET", s.URL+"/v1/stream/p2", nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	sc := bufio.NewScanner(res.Body)
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() && !strings.HasPrefix(sc.Text(), "event: view") {
	}
	go func() {
		for i := 0; i < 6; i++ {
			r.Tick()
		}
		post(t, s.URL, `{"version":1,"requestId":"a1","origin":"player","kind":"act","actor":"p1","action":"examinar-poco"}`)
		r.Tick()
	}()
	sawOmen := false
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		var m StreamMessage
		json.Unmarshal([]byte(line[6:]), &m)
		for _, e := range m.Events {
			if e.Holder == "p1" {
				t.Fatalf("p2 stream leaked a private event of p1: %+v", e)
			}
			if e.Kind == "omen" {
				sawOmen = true
			}
		}
		if m.Tick >= 7 {
			break
		}
	}
	if !sawOmen {
		t.Fatal("public world events must be pushed to every observer")
	}
}
