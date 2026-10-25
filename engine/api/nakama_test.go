package api

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAdapterCredentialSeparatesPlayersFromGameServer(t *testing.T) {
	_, s := serverWith(t, Options{Public: true, AdapterKey: strings.Repeat("s", 32)})
	_, guest := session(t, s.URL, `{"version":1}`)
	id, token := guest["id"].(string), guest["token"].(string)
	if code, _, _ := do(t, "POST", s.URL+"/v1/commands", token, joinBody(id)); code != 403 {
		t.Fatalf("client cannot confirm happenings: %d", code)
	}
	if code, _, _ := do(t, "POST", s.URL+"/v1/commands", "", joinBody(id), "X-Adapter-Key", strings.Repeat("s", 32)); code != 200 {
		t.Fatalf("trusted game server cannot join: %d", code)
	}
	if code, _, _ := do(t, "GET", s.URL+"/v1/views/"+id, token, ""); code != 200 {
		t.Fatalf("player cannot read own view: %d", code)
	}
	if code, _, _ := do(t, "POST", s.URL+"/v1/session", "", `{"version":1,"id":"nk-server-owned"}`, "X-Adapter-Key", strings.Repeat("s", 32)); code != 200 {
		t.Fatalf("server cannot provision stable Nakama identity: %d", code)
	}
	if code, _, _ := do(t, "POST", s.URL+"/v1/session", "", `{"version":1,"id":"nk-server-owned"}`); code != 401 {
		t.Fatalf("guest claimed server identity: %d", code)
	}
}

func TestNakamaProxyPreservesPathAndHidesServiceCredentials(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.RequestURI() != "/v2/rpc/hosp_world?x=1" || r.Header.Get("X-Adapter-Key") != "" || r.Header.Get("X-Edge-Secret") != "" {
			t.Errorf("unsafe upstream request: %s", r.URL.RequestURI())
		}
		io.WriteString(w, `{"ok":true}`)
	}))
	defer upstream.Close()
	_, s := serverWith(t, Options{NakamaURL: upstream.URL, Web: t.TempDir()})
	if code, body, _ := do(t, "POST", s.URL+"/nakama/v2/rpc/hosp_world?x=1", "", "{}", "X-Adapter-Key", "private", "X-Edge-Secret", "private"); code != 200 || body["ok"] != true {
		t.Fatalf("proxy under web static handler: %d %v", code, body)
	}
	r := httptest.NewRecorder()
	nakamaProxy("http://example.com").ServeHTTP(r, httptest.NewRequest("GET", "/nakama/ws", nil))
	if r.Code != 503 {
		t.Fatal("proxy accepted non-loopback upstream")
	}
}
