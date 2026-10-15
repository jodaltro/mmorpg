package authority

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"math/big"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var ErrUnauthorized = errors.New("unauthorized")

type Identity struct{ UserID string }
type Authenticator interface {
	Verify(context.Context, string) (Identity, error)
}
type accessClaims struct {
	jwt.RegisteredClaims
	Role string `json:"role"`
}
type jwk struct {
	KID string   `json:"kid"`
	KTY string   `json:"kty"`
	ALG string   `json:"alg"`
	Use string   `json:"use"`
	N   string   `json:"n"`
	E   string   `json:"e"`
	CRV string   `json:"crv"`
	X   string   `json:"x"`
	Y   string   `json:"y"`
	Ops []string `json:"key_ops"`
}
type SupabaseAuth struct {
	URL, PublishableKey, Mode, Audience string
	Client                              *http.Client
	mu                                  sync.Mutex
	keys                                []jwk
	fetched                             time.Time
}

func NewSupabaseAuth(raw, key, mode, audience string, allowLocal bool) (*SupabaseAuth, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Path != "" && u.Path != "/" || (u.Scheme != "https" && !(allowLocal && u.Scheme == "http" && u.Hostname() == "127.0.0.1")) || (mode != "jwks" && mode != "auth-server") || audience != "authenticated" || key == "" || strings.HasPrefix(key, "sb_secret_") {
		return nil, errors.New("invalid_auth_configuration")
	}
	// Legacy anon JWT is public, but service_role is never accepted as configuration.
	if strings.Count(key, ".") == 2 {
		c := jwt.MapClaims{}
		_, _, e := jwt.NewParser().ParseUnverified(key, c)
		if e != nil || c["role"] != "anon" {
			return nil, errors.New("invalid_auth_configuration")
		}
	}
	return &SupabaseAuth{URL: strings.TrimRight(raw, "/"), PublishableKey: key, Mode: mode, Audience: audience, Client: &http.Client{Timeout: 5 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}}, nil
}
func (a *SupabaseAuth) Verify(ctx context.Context, raw string) (Identity, error) {
	if raw == "" || len(raw) > 16384 {
		return Identity{}, ErrUnauthorized
	}
	claims := &accessClaims{}
	opts := []jwt.ParserOption{jwt.WithIssuer(a.URL + "/auth/v1"), jwt.WithAudience(a.Audience), jwt.WithExpirationRequired(), jwt.WithIssuedAt()}
	if a.Mode == "jwks" {
		opts = append(opts, jwt.WithValidMethods([]string{"RS256", "ES256"}))
		t, e := jwt.ParseWithClaims(raw, claims, func(t *jwt.Token) (any, error) {
			kid, ok := t.Header["kid"].(string)
			if !ok || kid == "" || len(kid) > 128 {
				return nil, ErrUnauthorized
			}
			return a.publicKey(ctx, kid, t.Method.Alg())
		}, opts...)
		if e != nil || !t.Valid {
			return Identity{}, ErrUnauthorized
		}
	} else {
		// Parsing never authenticates; the project's Auth Server must confirm the exact bearer token.
		t, _, e := jwt.NewParser().ParseUnverified(raw, claims)
		if e != nil || t.Method.Alg() != "HS256" || jwt.NewValidator(opts...).Validate(claims) != nil {
			return Identity{}, ErrUnauthorized
		}
		req, e := http.NewRequestWithContext(ctx, "GET", a.URL+"/auth/v1/user", nil)
		if e != nil {
			return Identity{}, ErrUnauthorized
		}
		req.Header.Set("apikey", a.PublishableKey)
		req.Header.Set("Authorization", "Bearer "+raw)
		res, e := a.Client.Do(req)
		if e != nil {
			return Identity{}, ErrUnauthorized
		}
		defer res.Body.Close()
		var user struct {
			ID string `json:"id"`
		}
		if res.StatusCode != 200 || json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&user) != nil || user.ID != claims.Subject {
			return Identity{}, ErrUnauthorized
		}
	}
	id, e := uuid.Parse(claims.Subject)
	if e != nil || id == uuid.Nil || claims.Subject != id.String() || claims.Role != "authenticated" || claims.IssuedAt == nil {
		return Identity{}, ErrUnauthorized
	}
	return Identity{UserID: id.String()}, nil
}
func (a *SupabaseAuth) publicKey(ctx context.Context, kid, alg string) (any, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	// Fixed endpoint; never follow token-controlled jku/x5u or redirects. Refresh at most once per minute.
	if a.fetched.IsZero() || time.Since(a.fetched) > time.Minute {
		req, e := http.NewRequestWithContext(ctx, "GET", a.URL+"/auth/v1/.well-known/jwks.json", nil)
		if e != nil {
			return nil, ErrUnauthorized
		}
		res, e := a.Client.Do(req)
		if e != nil {
			return nil, ErrUnauthorized
		}
		defer res.Body.Close()
		var doc struct {
			Keys []jwk `json:"keys"`
		}
		if res.StatusCode != 200 || json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&doc) != nil || len(doc.Keys) > 16 {
			return nil, ErrUnauthorized
		}
		a.keys = doc.Keys
		a.fetched = time.Now()
	}
	for _, k := range a.keys {
		if k.KID != kid || k.ALG != alg || k.Use != "" && k.Use != "sig" {
			continue
		}
		if len(k.Ops) > 0 {
			verify := false
			for _, op := range k.Ops {
				if op == "verify" {
					verify = true
				}
			}
			if !verify {
				continue
			}
		}
		if k.KTY == "RSA" && alg == "RS256" {
			n, e := base64.RawURLEncoding.DecodeString(k.N)
			if e != nil {
				return nil, ErrUnauthorized
			}
			b, e := base64.RawURLEncoding.DecodeString(k.E)
			if e != nil || len(b) > 4 {
				return nil, ErrUnauthorized
			}
			exponent := 0
			for _, v := range b {
				exponent = exponent*256 + int(v)
			}
			modulus := new(big.Int).SetBytes(n)
			if modulus.BitLen() < 2048 || modulus.BitLen() > 8192 || exponent < 3 || exponent%2 == 0 {
				return nil, ErrUnauthorized
			}
			return &rsa.PublicKey{N: modulus, E: exponent}, nil
		}
		if k.KTY == "EC" && alg == "ES256" && k.CRV == "P-256" {
			x, e := base64.RawURLEncoding.DecodeString(k.X)
			if e != nil || len(x) != 32 {
				return nil, ErrUnauthorized
			}
			y, e := base64.RawURLEncoding.DecodeString(k.Y)
			if e != nil || len(y) != 32 {
				return nil, ErrUnauthorized
			}
			p := &ecdsa.PublicKey{Curve: elliptic.P256(), X: new(big.Int).SetBytes(x), Y: new(big.Int).SetBytes(y)}
			if !p.Curve.IsOnCurve(p.X, p.Y) {
				return nil, ErrUnauthorized
			}
			return p, nil
		}
	}
	return nil, ErrUnauthorized
}
