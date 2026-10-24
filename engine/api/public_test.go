package api

import (
	"bufio"
	"compress/gzip"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/sim"
	"github.com/jodaltro/mmorpg/engine/store"
	"github.com/jodaltro/mmorpg/engine/universe"
)

func serverWith(t *testing.T, o Options) (*sim.Runner, *httptest.Server) {
	w, err := universe.Load("../../universes/valdoria/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	r, _ := sim.Open(w, &store.Memory{}, sim.Options{})
	s := httptest.NewServer(HandlerWith(r, o))
	t.Cleanup(func() { s.Close(); r.Close() })
	return r, s
}

func do(t *testing.T, method, url, token, body string, hdr ...string) (int, map[string]any, http.Header) {
	t.Helper()
	req, _ := http.NewRequest(method, url, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for i := 0; i+1 < len(hdr); i += 2 {
		req.Header.Set(hdr[i], hdr[i+1])
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	var out map[string]any
	json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out, res.Header
}

func session(t *testing.T, base, body string) (int, map[string]any) {
	code, out, _ := do(t, "POST", base+"/v1/session", "", body)
	return code, out
}

func joinBody(id string) string {
	return `{"version":1,"requestId":"j-` + id + `","origin":"adapter","kind":"join","actor":"` + id + `","name":"X"}`
}

func TestSessionIssuesStableIdentity(t *testing.T) {
	_, s := serverWith(t, Options{Public: true, Key: []byte(strings.Repeat("k", 32))})
	code, a := session(t, s.URL, `{"version":1}`)
	if code != 200 || !strings.HasPrefix(a["id"].(string), "cel-") || len(a["id"].(string)) != 14 || a["token"] == "" || a["public"] != true {
		t.Fatalf("%d %v", code, a)
	}
	if caps := a["capabilities"].(map[string]any); caps["reset"] != false {
		t.Fatalf("caps %v", caps)
	}
	code, b := session(t, s.URL, `{"version":1,"id":"`+a["id"].(string)+`","token":"`+a["token"].(string)+`"}`)
	if code != 200 || b["id"] != a["id"] || b["token"] != a["token"] {
		t.Fatalf("%d %v", code, b)
	}
	for _, bad := range []string{
		`{"version":1,"id":"` + a["id"].(string) + `","token":"nope"}`,
		`{"version":1,"id":"` + a["id"].(string) + `"}`,
		`{"version":1,"id":"cel-outro","token":"` + a["token"].(string) + `"}`,
	} {
		if code, out := session(t, s.URL, bad); code != 401 || out["error"] != "invalid_token" {
			t.Fatalf("%s -> %d %v", bad, code, out)
		}
	}
	if code, _ := session(t, s.URL, `{"version":2}`); code != 400 {
		t.Fatal(code)
	}
}

func TestSessionInDevAcceptsLocalIdentity(t *testing.T) {
	_, s := serverWith(t, Options{})
	code, out := session(t, s.URL, `{"version":1,"id":"cel-antigo"}`)
	if code != 200 || out["id"] != "cel-antigo" || out["token"] == "" || out["public"] != false {
		t.Fatalf("%d %v", code, out)
	}
	if out["capabilities"].(map[string]any)["reset"] != true {
		t.Fatal("dev must allow reset")
	}
	// Commands need no token in development.
	if code, o, _ := do(t, "POST", s.URL+"/v1/commands", "", joinBody("p1")); code != 200 {
		t.Fatalf("%d %v", code, o)
	}
}

func TestPublicRequiresTokenForActor(t *testing.T) {
	_, s := serverWith(t, Options{Public: true, Key: []byte(strings.Repeat("k", 32))})
	_, ana := session(t, s.URL, `{"version":1}`)
	_, bia := session(t, s.URL, `{"version":1}`)
	idA, tokA := ana["id"].(string), ana["token"].(string)
	idB, tokB := bia["id"].(string), bia["token"].(string)
	cmd := s.URL + "/v1/commands"
	if code, out, _ := do(t, "POST", cmd, "", joinBody(idA)); code != 401 || out["error"] != "unauthorized" {
		t.Fatalf("no token: %d %v", code, out)
	}
	if code, _, _ := do(t, "POST", cmd, tokB, joinBody(idA)); code != 401 {
		t.Fatalf("another actor's token: %d", code)
	}
	if code, out, _ := do(t, "POST", cmd, tokA, joinBody(idA)); code != 200 {
		t.Fatalf("right token: %d %v", code, out)
	}
	if code, _, _ := do(t, "POST", cmd, tokB, joinBody(idB)); code != 200 {
		t.Fatal(code)
	}
	for _, p := range []string{"/v1/views/", "/v1/affordances/"} {
		if code, _, _ := do(t, "GET", s.URL+p+idA, "", ""); code != 401 {
			t.Fatalf("%s no token %d", p, code)
		}
		if code, _, _ := do(t, "GET", s.URL+p+idA, tokB, ""); code != 401 {
			t.Fatalf("%s other token %d", p, code)
		}
		if code, _, _ := do(t, "GET", s.URL+p+idA, tokA, ""); code != 200 {
			t.Fatalf("%s right token %d", p, code)
		}
	}
	// 401 before knowing whether the id exists: same answer for unknown ids.
	if code, _, _ := do(t, "GET", s.URL+"/v1/views/nao-existe", tokA, ""); code != 401 {
		t.Fatal(code)
	}
	// Open endpoints.
	for _, p := range []string{"/v1/health", "/v1/chronicle", "/v1/players"} {
		if code, _, _ := do(t, "GET", s.URL+p, "", ""); code != 200 {
			t.Fatalf("%s %d", p, code)
		}
	}
}

func TestPublicStreamAcceptsQueryToken(t *testing.T) {
	_, s := serverWith(t, Options{Public: true, Key: []byte(strings.Repeat("k", 32))})
	_, ana := session(t, s.URL, `{"version":1}`)
	id, tok := ana["id"].(string), ana["token"].(string)
	do(t, "POST", s.URL+"/v1/commands", tok, joinBody(id))
	if code, _, _ := do(t, "GET", s.URL+"/v1/stream/"+id, "", ""); code != 401 {
		t.Fatalf("no token %d", code)
	}
	res, err := http.Get(s.URL + "/v1/stream/" + id + "?token=" + tok)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		t.Fatal(res.StatusCode)
	}
	line, _ := bufio.NewReader(res.Body).ReadString('\n')
	if !strings.HasPrefix(line, "event: view") {
		t.Fatalf("first line %q", line)
	}
}

func TestResetOffInPublicOnInDev(t *testing.T) {
	body := `{"version":1,"confirm":"new-world"}`
	_, pub := serverWith(t, Options{Public: true})
	if code, out, _ := do(t, "POST", pub.URL+"/v1/world/reset", "", body); code != 403 || out["error"] != "reset_disabled" {
		t.Fatalf("%d %v", code, out)
	}
	_, dev := serverWith(t, Options{})
	if code, out, _ := do(t, "POST", dev.URL+"/v1/world/reset", "", body); code != 200 {
		t.Fatalf("%d %v", code, out)
	}
}

func TestOriginSameHostOnly(t *testing.T) {
	_, s := serverWith(t, Options{})
	host := strings.TrimPrefix(s.URL, "http://")
	if code, _, _ := do(t, "GET", s.URL+"/v1/health", "", "", "Origin", "http://"+host); code != 200 {
		t.Fatalf("same host %d", code)
	}
	if code, out, _ := do(t, "GET", s.URL+"/v1/health", "", "", "Origin", "https://evil.example"); code != 403 || out["error"] != "cross_origin_refused" {
		t.Fatalf("other origin %d %v", code, out)
	}
}

func TestRateLimits(t *testing.T) {
	_, s := serverWith(t, Options{Public: true})
	limited := 0
	for i := 0; i < 120; i++ {
		code, _, h := do(t, "GET", s.URL+"/v1/health", "", "", "CF-Connecting-IP", "9.9.9.9")
		if code == 429 {
			limited++
			if h.Get("Retry-After") == "" {
				t.Fatal("no Retry-After")
			}
		}
	}
	if limited == 0 {
		t.Fatal("general limit never fired")
	}
	if code, _, _ := do(t, "GET", s.URL+"/v1/health", "", "", "CF-Connecting-IP", "8.8.8.8"); code != 200 {
		t.Fatalf("another IP must be unaffected: %d", code)
	}
	ok := 0
	for i := 0; i < 8; i++ {
		code, _, _ := do(t, "POST", s.URL+"/v1/session", "", `{"version":1}`, "CF-Connecting-IP", "7.7.7.7")
		if code == 200 {
			ok++
		} else if code != 429 {
			t.Fatal(code)
		}
	}
	if ok != 6 {
		t.Fatalf("session burst: %d ok, want 6", ok)
	}
}

func TestLimiterForgetsIdleBuckets(t *testing.T) {
	l := newLimiter(1, 2)
	now := l.now()
	l.now = func() time.Time { return now }
	for i := 0; i < 50; i++ {
		l.take("ip-" + strings.Repeat("x", i))
	}
	now = now.Add(5 * time.Minute)
	l.take("novo")
	if len(l.m) != 1 {
		t.Fatalf("%d buckets kept", len(l.m))
	}
}

func TestStaticServing(t *testing.T) {
	dir := t.TempDir()
	write := func(name, body string) {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("index.html", "<html>jogo</html>")
	write("index.wasm", "WASMRAW")
	write("index.wasm.br", "WASMBR")
	write("index.pck", "PCKRAW")
	var gz strings.Builder
	zw := gzip.NewWriter(&gz)
	zw.Write([]byte("JSGZ"))
	zw.Close()
	write("index.js", "JSRAW")
	write("index.js.gz", gz.String())
	write("segredo.txt", "nao")
	os.Mkdir(filepath.Join(dir, "sub"), 0o755)
	write("sub/a.json", "{}")
	outside := filepath.Join(filepath.Dir(dir), "fora.html")
	os.WriteFile(outside, []byte("FORA"), 0o644)
	defer os.Remove(outside)

	_, s := serverWith(t, Options{Web: dir})
	get := func(p string, hdr ...string) (int, string, http.Header) {
		req, _ := http.NewRequest("GET", s.URL+p, nil)
		for i := 0; i+1 < len(hdr); i += 2 {
			req.Header.Set(hdr[i], hdr[i+1])
		}
		tr := &http.Transport{DisableCompression: true}
		res, err := (&http.Client{Transport: tr, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}).Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		b, _ := io.ReadAll(res.Body)
		return res.StatusCode, string(b), res.Header
	}
	if code, body, h := get("/"); code != 200 || body != "<html>jogo</html>" || !strings.HasPrefix(h.Get("Content-Type"), "text/html") ||
		h.Get("X-Content-Type-Options") != "nosniff" || h.Get("Cache-Control") != "no-cache" || h.Get("ETag") == "" {
		t.Fatalf("index: %d %q %v", code, body, h)
	}
	if code, body, h := get("/index.wasm"); code != 200 || body != "WASMRAW" || h.Get("Content-Type") != "application/wasm" || h.Get("Content-Encoding") != "" || h.Get("Vary") == "" {
		t.Fatalf("wasm: %d %q %v", code, body, h)
	}
	if code, body, h := get("/index.wasm", "Accept-Encoding", "gzip, br"); code != 200 || body != "WASMBR" || h.Get("Content-Encoding") != "br" || h.Get("Content-Type") != "application/wasm" {
		t.Fatalf("br: %d %q %v", code, body, h)
	}
	if code, body, h := get("/index.js", "Accept-Encoding", "gzip"); code != 200 || h.Get("Content-Encoding") != "gzip" || !strings.HasPrefix(h.Get("Content-Type"), "text/javascript") || body != gz.String() {
		t.Fatalf("gz: %d %v", code, h)
	}
	if code, body, _ := get("/index.js", "Accept-Encoding", "br"); code != 200 || body != "JSRAW" {
		t.Fatalf("raw fallback: %d %q", code, body)
	}
	if code, _, h := get("/index.pck"); code != 200 || h.Get("Content-Type") != "application/octet-stream" {
		t.Fatalf("pck: %d %v", code, h)
	}
	if code, _, _ := get("/index.html", "If-None-Match", func() string { _, _, h := get("/index.html"); return h.Get("ETag") }()); code != 304 {
		t.Fatalf("revalidation: %d", code)
	}
	for _, p := range []string{"/segredo.txt", "/sub/", "/sub", "/nao-existe.js", "/../fora.html", "/%2e%2e/fora.html", "/sub/../../fora.html", "/..%2ffora.html", "/%2e%2e%5cfora.html"} {
		code, body, _ := get(p)
		if code == 200 || strings.Contains(body, "FORA") || strings.Contains(body, "nao") && p == "/segredo.txt" {
			t.Fatalf("%s leaked: %d %q", p, code, body)
		}
	}
	if code, _, _ := get("/sub/a.json"); code != 200 {
		t.Fatal(code)
	}
	if code, body, _ := get("/v1/health"); code != 200 || !strings.Contains(body, `"status":"ok"`) {
		t.Fatalf("health swallowed: %d %q", code, body)
	}
	req, _ := http.NewRequest("POST", s.URL+"/index.html", nil)
	if res, _ := http.DefaultClient.Do(req); res.StatusCode != 405 {
		t.Fatalf("POST static: %d", res.StatusCode)
	}
}

func TestKeyPersistsAcrossRestarts(t *testing.T) {
	dir := t.TempDir()
	k1, err := LoadOrCreateKey(dir)
	if err != nil || len(k1) != 32 {
		t.Fatal(err, len(k1))
	}
	k2, _ := LoadOrCreateKey(dir)
	if string(k1) != string(k2) {
		t.Fatal("key changed on reopen")
	}
	if st, _ := os.Stat(filepath.Join(dir, "session.key")); st == nil {
		t.Fatal("no key file")
	}
	_, a := serverWith(t, Options{Public: true, Key: k1})
	_, b := serverWith(t, Options{Public: true, Key: k2})
	code1, o1 := session(t, a.URL, `{"version":1}`)
	if code1 != 200 {
		t.Fatal(code1)
	}
	code2, o2 := session(t, b.URL, `{"version":1,"id":"`+o1["id"].(string)+`","token":"`+o1["token"].(string)+`"}`)
	if code2 != 200 || o2["token"] != o1["token"] {
		t.Fatalf("token did not survive restart: %d %v", code2, o2)
	}
}

func TestEdgeSecretClosesTheAPIToEverythingElse(t *testing.T) {
	_, srv := serverWith(t, Options{Public: true, EdgeSecret: "s3cret"})
	if code, _, _ := do(t, "GET", srv.URL+"/v1/health", "", "", "Cf-Ray", "1-AMS"); code != 403 {
		t.Fatalf("through Cloudflare, no secret: %d", code)
	}
	if code, _, _ := do(t, "GET", srv.URL+"/v1/health", "", "", "Cf-Ray", "1-AMS", "X-Edge-Secret", "wrong"); code != 403 {
		t.Fatalf("through Cloudflare, wrong secret: %d", code)
	}
	if code, _, _ := do(t, "GET", srv.URL+"/v1/health", "", "", "Cf-Ray", "1-AMS", "X-Edge-Secret", "s3cret"); code != 200 {
		t.Fatalf("through Cloudflare, right secret: %d", code)
	}
	if code, _, _ := do(t, "GET", srv.URL+"/v1/health", "", ""); code != 200 {
		t.Fatalf("straight on loopback (the developer's own client): %d", code)
	}
	// the real client address comes from the edge: one noisy client does not use up another's sessions
	for i := 0; i < 6; i++ {
		if code, _, _ := do(t, "POST", srv.URL+"/v1/session", "", `{"version":1}`, "Cf-Ray", "1-AMS", "X-Edge-Secret", "s3cret", "X-Client-IP", "203.0.113.7"); code != 200 {
			t.Fatalf("session %d: %d", i, code)
		}
	}
	if code, _, _ := do(t, "POST", srv.URL+"/v1/session", "", `{"version":1}`, "Cf-Ray", "1-AMS", "X-Edge-Secret", "s3cret", "X-Client-IP", "203.0.113.7"); code != 429 {
		t.Fatalf("7th session from one client: %d", code)
	}
	if code, _, _ := do(t, "POST", srv.URL+"/v1/session", "", `{"version":1}`, "Cf-Ray", "1-AMS", "X-Edge-Secret", "s3cret", "X-Client-IP", "203.0.113.8"); code != 200 {
		t.Fatalf("another client: %d", code)
	}
}
