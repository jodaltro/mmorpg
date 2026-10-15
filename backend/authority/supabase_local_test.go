package authority

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Opt-in real Auth + PostgreSQL. Remote mode requires explicit development opt-in and existing accounts; no resets.
func TestSupabaseLocalAuthAndPersistentCharacters(t *testing.T) {
	if os.Getenv("SUPABASE_LOCAL_TEST") != "1" && os.Getenv("SUPABASE_DEV_TEST") != "1" {
		t.Skip("real Supabase development configuration required; not executed")
	}
	if LoadEnvironmentFile(os.Getenv("AUTH_ENV_FILE")) != nil {
		t.Fatal("explicit Auth configuration file unavailable")
	}
	endpoint := strings.TrimRight(os.Getenv("SUPABASE_URL"), "/")
	key := os.Getenv("SUPABASE_PUBLISHABLE_KEY")
	local := strings.HasPrefix(endpoint, "http://127.0.0.1:")
	if !local && (os.Getenv("SUPABASE_DEV_TEST") != "1" || os.Getenv("ALLOW_REMOTE_DEV_TEST") != "1" || !strings.HasPrefix(endpoint, "https://")) {
		t.Fatal("remote test requires explicit approved development opt-in")
	}
	auth, e := NewSupabaseAuth(endpoint, key, os.Getenv("AUTH_MODE"), "authenticated", true)
	if e != nil {
		t.Fatal("invalid public Auth configuration")
	}
	cfg, e := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if e != nil || (!local && (cfg.ConnConfig.TLSConfig == nil || cfg.ConnConfig.TLSConfig.InsecureSkipVerify)) {
		t.Fatal("verified TLS required for development DB")
	}
	if !local {
		for _, f := range cfg.ConnConfig.Fallbacks {
			if f.TLSConfig == nil || f.TLSConfig.InsecureSkipVerify {
				t.Fatal("TLS downgrade forbidden")
			}
		}
	}
	ctx := context.Background()
	pool, e := pgxpool.NewWithConfig(ctx, cfg)
	if e != nil {
		t.Fatal("database unavailable")
	}
	defer pool.Close()
	store := &Store{Pool: pool}
	if store.CheckRole(ctx) != nil {
		t.Fatal("limited DB role required")
	}
	tx, e := pool.Begin(ctx)
	if e != nil {
		t.Fatal(e)
	}
	_, e = tx.Exec(ctx, `set local role game_backend`)
	var testWorld bool
	if e == nil {
		e = tx.QueryRow(ctx, `select is_test from game.worlds where id='marco05-dev'`).Scan(&testWorld)
	}
	tx.Rollback(ctx)
	if e != nil || !testWorld {
		t.Fatal("explicit seeded test world required")
	}
	client := &http.Client{Timeout: 10 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	type authSession struct {
		Access    string `json:"access_token"`
		Refresh   string `json:"refresh_token"`
		ErrorCode string `json:"error_code"`
		User      struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	signup := func(label string) authSession {
		email, password, path := "marco05-"+uuid.NewString()+"@example.test", uuid.NewString()+"!aA2", "/auth/v1/signup"
		if !local {
			email = os.Getenv("SUPABASE_TEST_EMAIL_" + label)
			password = os.Getenv("SUPABASE_TEST_PASSWORD_" + label)
			path = "/auth/v1/token?grant_type=password"
			if email == "" || password == "" {
				t.Fatal("configure two existing development users locally; no remote accounts will be created")
			}
		}
		payload, _ := json.Marshal(map[string]string{"email": email, "password": password})
		r, _ := http.NewRequest("POST", endpoint+path, bytes.NewReader(payload))
		r.Header.Set("Content-Type", "application/json")
		r.Header.Set("apikey", key)
		res, e := client.Do(r)
		if e != nil {
			t.Fatal("local Auth unavailable")
		}
		defer res.Body.Close()
		var session authSession
		decoded := json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&session)
		if res.StatusCode != 200 || decoded != nil || session.Access == "" || session.Refresh == "" {
			code := "auth_response_rejected"
			for _, known := range []string{"invalid_credentials", "email_not_confirmed", "user_banned", "email_provider_disabled", "signup_disabled", "over_request_rate_limit", "unexpected_failure"} {
				if session.ErrorCode == known {
					code = known
				}
			}
			t.Fatalf("Auth user %s login failed: HTTP %d, %s", label, res.StatusCode, code)
		}
		verified, e := auth.Verify(ctx, session.Access)
		if e != nil || verified.UserID != session.User.ID {
			t.Fatal("real Auth verification failed")
		}
		return session
	}
	a, b := signup("A"), signup("B")
	if a.User.ID == b.User.ID {
		t.Fatal("identities not independent")
	}
	server := httptest.NewServer(Handler(store, auth))
	defer server.Close()
	call := func(access, method, path string, in any, status int) Character {
		var body []byte
		if in != nil {
			body, _ = json.Marshal(in)
		}
		r, _ := http.NewRequest(method, server.URL+path, bytes.NewReader(body))
		r.Header.Set("Authorization", "Bearer "+access)
		if in != nil {
			r.Header.Set("Content-Type", "application/json")
		}
		res, e := client.Do(r)
		if e != nil {
			t.Fatal("local authority transport failed")
		}
		defer res.Body.Close()
		if res.StatusCode != status {
			t.Fatalf("%s expected %d got %d", path, status, res.StatusCode)
		}
		var c Character
		if status < 300 && strings.Contains(path, "characters") {
			if json.NewDecoder(res.Body).Decode(&c) != nil {
				t.Fatal("invalid character projection")
			}
		}
		return c
	}
	ca := call(a.Access, "POST", "/v1/characters", CreateCharacter{Version: 1, WorldID: "marco05-dev", Name: "Supabase A"}, 201)
	cb := call(b.Access, "POST", "/v1/characters", CreateCharacter{Version: 1, WorldID: "marco05-dev", Name: "Supabase B"}, 201)
	call(b.Access, "GET", "/v1/characters/"+ca.ID, nil, 404)
	call(a.Access, "GET", "/v1/characters/"+cb.ID, nil, 404)
	apply := func(c Character, kind, target string) Character {
		return call(a.Access, "POST", "/v1/characters/"+c.ID+"/intentions", Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: c.Revision, Kind: kind, TargetID: target}, 200)
	}
	ca = apply(ca, "start-encounter", "corrupted-wolf")
	for i := 0; i < 3; i++ {
		ca = apply(ca, "attack", ca.Encounter.ID)
		if i < 2 {
			ca = apply(ca, "dodge", ca.Encounter.ID)
		}
	}
	ca = apply(ca, "collect", ca.Encounter.ID)
	ca = apply(ca, "deliver-mira", "mira")
	if len(ca.Abilities) != 1 || len(ca.Inventory) != 0 || ca.Relationships["mira"] != 1 {
		t.Fatal("legitimate acquisition/delivery failed")
	}
	other := call(b.Access, "GET", "/v1/characters/"+cb.ID, nil, 200)
	if len(other.Facts) != 0 || len(other.Abilities) != 0 || len(other.Knowledge) != 0 {
		t.Fatal("private state leaked")
	}
	time.Sleep(16 * time.Second)
	ca = apply(ca, "tick", "")
	ra, e := store.ReadRegion(ctx, a.User.ID, "marco05-dev", "gray-forest")
	rb, e2 := store.ReadRegion(ctx, b.User.ID, "marco05-dev", "gray-forest")
	if e != nil || e2 != nil || ra != rb || !ra.NoticePublished {
		t.Fatal("region not shared")
	}
	payload, _ := json.Marshal(map[string]string{"refresh_token": a.Refresh})
	r, _ := http.NewRequest("POST", endpoint+"/auth/v1/token?grant_type=refresh_token", bytes.NewReader(payload))
	r.Header.Set("apikey", key)
	r.Header.Set("Content-Type", "application/json")
	res, e := client.Do(r)
	if e != nil {
		t.Fatal("refresh unavailable")
	}
	defer res.Body.Close()
	var renewed authSession
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&renewed) != nil {
		t.Fatal("refresh failed")
	}
	if verified, e := auth.Verify(ctx, renewed.Access); e != nil || verified.UserID != a.User.ID {
		t.Fatal("refreshed identity changed")
	}
	persisted := call(renewed.Access, "GET", "/v1/characters/"+ca.ID, nil, 200)
	if persisted.Revision != ca.Revision || len(persisted.Abilities) != 1 {
		t.Fatal("state lost after refresh")
	}
	t.Log(fmt.Sprintf("two real Supabase development users; private characters; shared region; persistent validated rewards; refresh; world=%s", ca.WorldID))
}
