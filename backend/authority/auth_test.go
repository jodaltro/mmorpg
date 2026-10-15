package authority

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

func claims(issuer string) accessClaims {
	return accessClaims{RegisteredClaims: jwt.RegisteredClaims{Subject: uuid.NewString(), Issuer: issuer + "/auth/v1", Audience: jwt.ClaimStrings{"authenticated"}, IssuedAt: jwt.NewNumericDate(time.Now().Add(-time.Minute)), ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))}, Role: "authenticated"}
}
func token(t *testing.T, method jwt.SigningMethod, c accessClaims, key any, kid string) string {
	t.Helper()
	x := jwt.NewWithClaims(method, c)
	if kid != "" {
		x.Header["kid"] = kid
	}
	s, e := x.SignedString(key)
	if e != nil {
		t.Fatal(e)
	}
	return s
}
func TestJWKSAlgorithmsAndClaims(t *testing.T) {
	rsaKey, e := rsa.GenerateKey(rand.Reader, 2048)
	if e != nil {
		t.Fatal(e)
	}
	ec, e := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if e != nil {
		t.Fatal(e)
	}
	keys := []jwk{{KID: "rsa", KTY: "RSA", ALG: "RS256", Use: "sig", N: base64.RawURLEncoding.EncodeToString(rsaKey.N.Bytes()), E: base64.RawURLEncoding.EncodeToString(big.NewInt(int64(rsaKey.E)).Bytes())}, {KID: "ec", KTY: "EC", ALG: "ES256", CRV: "P-256", Use: "sig", X: base64.RawURLEncoding.EncodeToString(ec.X.FillBytes(make([]byte, 32))), Y: base64.RawURLEncoding.EncodeToString(ec.Y.FillBytes(make([]byte, 32)))}}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/v1/.well-known/jwks.json" {
			t.Error("unexpected path")
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"keys": keys})
	}))
	defer server.Close()
	a, e := NewSupabaseAuth(server.URL, "sb_publishable_test", "jwks", "authenticated", true)
	if e != nil {
		t.Fatal(e)
	}
	for _, test := range []struct {
		name   string
		method jwt.SigningMethod
		key    any
		kid    string
	}{{"rsa", jwt.SigningMethodRS256, rsaKey, "rsa"}, {"ec", jwt.SigningMethodES256, ec, "ec"}} {
		t.Run(test.name, func(t *testing.T) {
			c := claims(server.URL)
			id, e := a.Verify(context.Background(), token(t, test.method, c, test.key, test.kid))
			if e != nil || id.UserID != c.Subject {
				t.Fatal("valid signature rejected")
			}
		})
	}
	for _, name := range []string{"issuer", "audience", "expired", "missing-exp", "missing-iat", "future-iat", "future-nbf", "subject", "role", "unknown-key", "forged-signature", "symmetric-downgrade", "missing-key", "unsigned"} {
		t.Run(name, func(t *testing.T) {
			c := claims(server.URL)
			method := jwt.SigningMethod(jwt.SigningMethodRS256)
			var key any = rsaKey
			kid := "rsa"
			switch name {
			case "issuer":
				c.Issuer = "https://attacker.invalid/auth/v1"
			case "audience":
				c.Audience = jwt.ClaimStrings{"other"}
			case "expired":
				c.ExpiresAt = jwt.NewNumericDate(time.Now().Add(-time.Minute))
			case "missing-exp":
				c.ExpiresAt = nil
			case "missing-iat":
				c.IssuedAt = nil
			case "future-iat":
				c.IssuedAt = jwt.NewNumericDate(time.Now().Add(time.Hour))
			case "future-nbf":
				c.NotBefore = jwt.NewNumericDate(time.Now().Add(time.Hour))
			case "subject":
				c.Subject = "player"
			case "role":
				c.Role = "service_role"
			case "unknown-key":
				kid = "other"
			case "forged-signature":
				key, _ = rsa.GenerateKey(rand.Reader, 2048)
			case "symmetric-downgrade":
				method = jwt.SigningMethodHS256
				key = []byte("not-a-trusted-secret")
			case "missing-key":
				kid = ""
			case "unsigned":
				method = jwt.SigningMethodNone
				key = jwt.UnsafeAllowNoneSignatureType
			}
			if _, e := a.Verify(context.Background(), token(t, method, c, key, kid)); e == nil {
				t.Fatal("invalid token accepted")
			}
		})
	}
}
func TestLegacyAuthServerConfirmsIdentityAndFailsClosed(t *testing.T) {
	accepted := ""
	user := ""
	status := 200
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/v1/user" || r.Header.Get("apikey") != "sb_publishable_test" || r.Header.Get("Authorization") != "Bearer "+accepted {
			w.WriteHeader(401)
			return
		}
		w.WriteHeader(status)
		_ = json.NewEncoder(w).Encode(map[string]string{"id": user})
	}))
	defer server.Close()
	a, _ := NewSupabaseAuth(server.URL, "sb_publishable_test", "auth-server", "authenticated", true)
	c := claims(server.URL)
	accepted = token(t, jwt.SigningMethodHS256, c, []byte("test-only-shared-secret"), "")
	user = c.Subject
	if _, e := a.Verify(context.Background(), accepted); e != nil {
		t.Fatal("auth-confirmed token rejected")
	}
	status = 401
	if _, e := a.Verify(context.Background(), accepted); e == nil {
		t.Fatal("rejected token accepted")
	}
	status = 200
	user = uuid.NewString()
	if _, e := a.Verify(context.Background(), accepted); e == nil {
		t.Fatal("mismatched identity accepted")
	}
	user = c.Subject
	c.ExpiresAt = jwt.NewNumericDate(time.Now().Add(-time.Minute))
	accepted = token(t, jwt.SigningMethodHS256, c, []byte("test-only-shared-secret"), "")
	if _, e := a.Verify(context.Background(), accepted); e == nil {
		t.Fatal("expired token accepted")
	}
	server.Close()
	if _, e := a.Verify(context.Background(), "bad-token"); e == nil {
		t.Fatal("malformed token accepted")
	}
}
func TestAuthConfigurationRejectsSecretsRedirectsAndRemoteHTTP(t *testing.T) {
	for _, url := range []string{"http://evil.invalid", "https://u:p@example.com", "https://example.com?key=x", "https://example.com/path", "https://example.com#x"} {
		if _, e := NewSupabaseAuth(url, "sb_publishable_test", "jwks", "authenticated", true); e == nil {
			t.Fatal("unsafe URL accepted")
		}
	}
	for _, key := range []string{"", "sb_secret_not-real", token(t, jwt.SigningMethodHS256, accessClaims{Role: "service_role"}, []byte("test"), "")} {
		if _, e := NewSupabaseAuth("https://example.com", key, "jwks", "authenticated", false); e == nil {
			t.Fatal("secret configuration accepted")
		}
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "https://example.com/never", 302) }))
	defer server.Close()
	a, _ := NewSupabaseAuth(server.URL, "sb_publishable_test", "auth-server", "authenticated", true)
	if _, e := a.Verify(context.Background(), token(t, jwt.SigningMethodHS256, claims(server.URL), []byte("test"), "")); e == nil {
		t.Fatal("redirect accepted")
	}
}

type fakeAuth struct{ user string }

func (a fakeAuth) Verify(_ context.Context, raw string) (Identity, error) {
	if raw != "test-token" {
		return Identity{}, ErrUnauthorized
	}
	return Identity{UserID: a.user}, nil
}
func TestHTTPRejectsUnauthenticatedRewardsAndUnknownFields(t *testing.T) {
	h := Handler(&Store{}, fakeAuth{uuid.NewString()})
	for _, tc := range []struct {
		name, body, authorization, origin string
		status                            int
	}{{"no-session", `{}`, "", "", 401}, {"invalid-session", `{}`, "Bearer bad", "", 401}, {"reward-field", `{"version":1,"damage":999}`, "Bearer test-token", "", 400}, {"reward-kind-extra", `{"version":1,"kind":"CreatureDefeated","inventory":{"corruption-sample":20}}`, "Bearer test-token", "", 400}, {"unknown-owner", `{"version":1,"ownerId":"attacker"}`, "Bearer test-token", "", 400}, {"json-extra", `{} {}`, "Bearer test-token", "", 400}, {"origin", `{}`, "Bearer test-token", "https://evil.invalid", 403}} {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest("POST", "/v1/characters/"+uuid.NewString()+"/intentions", strings.NewReader(tc.body))
			r.Header.Set("Content-Type", "application/json")
			r.Header.Set("Authorization", tc.authorization)
			r.Header.Set("Origin", tc.origin)
			w := httptest.NewRecorder()
			h.ServeHTTP(w, r)
			if w.Code != tc.status {
				t.Fatalf("status %d", w.Code)
			}
			if strings.Contains(w.Body.String(), "test-token") {
				t.Fatal("credential leaked")
			}
		})
	}
}
