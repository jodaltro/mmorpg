package api

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"net"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/sim"
)

// Options turns the development handler into a public one.
type Options struct {
	Public bool   // tokens required, reset off, rate limits on
	Key    []byte // HMAC key for session tokens; empty means an ephemeral random key
	Web    string // directory of static files served at "/" (empty: none)

	// EdgeSecret, when set in public mode, closes the API to everything but the edge in front of it (the Worker that proxies the
	// tunnel): a request must carry it in X-Edge-Secret, and only then is X-Client-IP believed.
	EdgeSecret string
}

const keyFile = "session.key"

// LoadOrCreateKey reads <dir>/session.key, creating it (32 random bytes, 0600)
// on first use, so tokens survive restarts.
func LoadOrCreateKey(dir string) ([]byte, error) {
	p := filepath.Join(dir, keyFile)
	if b, err := os.ReadFile(p); err == nil {
		if len(b) != 32 {
			return nil, errors.New("session.key is corrupt")
		}
		return b, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	if err := os.WriteFile(p, b, 0o600); err != nil {
		return nil, err
	}
	return b, nil
}

type auth struct {
	public   bool
	key      []byte
	general  *limiter
	sessions *limiter
}

func newAuth(o Options) *auth {
	a := &auth{public: o.Public, key: o.Key}
	if len(a.key) == 0 {
		a.key = make([]byte, 32)
		rand.Read(a.key)
	}
	if o.Public {
		a.general = newLimiter(30, 60)
		a.sessions = newLimiter(6.0/60.0, 6)
	}
	return a
}

func (a *auth) token(id string) string {
	m := hmac.New(sha256.New, a.key)
	m.Write([]byte("player:" + id))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}

func (a *auth) valid(id, token string) bool {
	return id != "" && token != "" && hmac.Equal([]byte(a.token(id)), []byte(token))
}

// allow checks the bearer token for id (public mode only). On failure it has
// already written the 401.
func (a *auth) allow(rw http.ResponseWriter, q *http.Request, id string, queryToken bool) bool {
	if !a.public {
		return true
	}
	t := ""
	if h := q.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
		t = strings.TrimPrefix(h, "Bearer ")
	} else if queryToken {
		t = q.URL.Query().Get("token")
	}
	if !a.valid(id, t) {
		reply(rw, 401, errorBody{Version, "unauthorized"})
		return false
	}
	return true
}

type sessionRequest struct {
	Version int    `json:"version"`
	ID      string `json:"id,omitempty"`
	Token   string `json:"token,omitempty"`
	Name    string `json:"name,omitempty"`
}

type sessionResponse struct {
	Version      int            `json:"version"`
	ID           string         `json:"id"`
	Token        string         `json:"token"`
	Capabilities map[string]any `json:"capabilities"`
	Public       bool           `json:"public"`
}

func (a *auth) session(rw http.ResponseWriter, q *http.Request, r *sim.Runner) {
	var in sessionRequest
	if !decode(rw, q, &in) {
		return
	}
	if in.Version != Version || len(in.ID) > 64 {
		reply(rw, 400, errorBody{Version, "invalid_contract"})
		return
	}
	id := in.ID
	if id == "" {
		s := r.Snapshot()
		for {
			b := make([]byte, 5)
			if _, err := rand.Read(b); err != nil {
				reply(rw, 500, errorBody{Version, "session_unavailable"})
				return
			}
			id = "cel-" + hex.EncodeToString(b)
			if _, taken := s.Entities[core.ID(id)]; !taken {
				break
			}
		}
	} else if a.public && !a.valid(id, in.Token) {
		reply(rw, 401, errorBody{Version, "invalid_token"})
		return
	}
	reply(rw, 200, sessionResponse{Version: Version, ID: id, Token: a.token(id), Capabilities: map[string]any{"reset": !a.public}, Public: a.public})
}

// limited applies the per-IP rate limits.
func (a *auth) limited(next http.Handler) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, q *http.Request) {
		ip := clientIP(q)
		lim := a.general
		if q.Method == http.MethodPost && q.URL.Path == "/v1/session" {
			lim = a.sessions
		}
		if ok, wait := lim.take(ip); !ok {
			rw.Header().Set("Retry-After", strconv.Itoa(int(wait.Seconds())+1))
			reply(rw, 429, errorBody{Version, "rate_limited"})
			return
		}
		next.ServeHTTP(rw, q)
	})
}

// edgeOnly lets through only requests that carry the edge secret, and takes the real client address from the edge. Anything that
// came through Cloudflare carries Cf-Ray (an attacker cannot strip it), so the secret is demanded of exactly the traffic that could
// have skipped the Worker; a request straight on loopback (the developer's own client) is let through, still bound by its token.
func edgeOnly(secret string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, q *http.Request) {
		if q.Header.Get("Cf-Ray") == "" {
			next.ServeHTTP(rw, q)
			return
		}
		if !hmac.Equal([]byte(q.Header.Get("X-Edge-Secret")), []byte(secret)) {
			reply(rw, 403, errorBody{Version, "edge_required"})
			return
		}
		q.Header.Del("CF-Connecting-IP")
		if ip := strings.TrimSpace(q.Header.Get("X-Client-IP")); ip != "" {
			q.Header.Set("CF-Connecting-IP", ip)
		}
		q.Header.Del("X-Client-IP")
		next.ServeHTTP(rw, q)
	})
}

func clientIP(q *http.Request) string {
	if v := strings.TrimSpace(q.Header.Get("CF-Connecting-IP")); v != "" {
		return v
	}
	if h, _, err := net.SplitHostPort(q.RemoteAddr); err == nil {
		return h
	}
	return q.RemoteAddr
}

type bucket struct {
	tokens float64
	last   time.Time
}

type limiter struct {
	mu    sync.Mutex
	rate  float64 // tokens per second
	burst float64
	m     map[string]*bucket
	swept time.Time
	now   func() time.Time
}

func newLimiter(rate, burst float64) *limiter {
	return &limiter{rate: rate, burst: burst, m: map[string]*bucket{}, now: time.Now}
}

func (l *limiter) take(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	if now.Sub(l.swept) > time.Minute {
		for k, b := range l.m { // a bucket idle long enough is full again: forget it
			if now.Sub(b.last).Seconds()*l.rate >= l.burst {
				delete(l.m, k)
			}
		}
		l.swept = now
	}
	b := l.m[key]
	if b == nil {
		b = &bucket{tokens: l.burst, last: now}
		l.m[key] = b
	}
	b.tokens += now.Sub(b.last).Seconds() * l.rate
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.last = now
	if b.tokens < 1 {
		return false, time.Duration((1 - b.tokens) / l.rate * float64(time.Second))
	}
	b.tokens--
	return true, 0
}

var mimeTypes = map[string]string{
	".html":        "text/html; charset=utf-8",
	".js":          "text/javascript; charset=utf-8",
	".wasm":        "application/wasm",
	".pck":         "application/octet-stream",
	".png":         "image/png",
	".json":        "application/json",
	".css":         "text/css; charset=utf-8",
	".svg":         "image/svg+xml",
	".ico":         "image/x-icon",
	".webmanifest": "application/manifest+json",
}

// staticHandler serves root read-only: no listings, no traversal, and
// pre-compressed siblings (.br, .gz) negotiated by Accept-Encoding.
func staticHandler(root string) http.Handler {
	return http.HandlerFunc(func(rw http.ResponseWriter, q *http.Request) {
		if q.Method != http.MethodGet && q.Method != http.MethodHead {
			rw.Header().Set("Allow", "GET, HEAD")
			reply(rw, 405, errorBody{Version, "method_not_allowed"})
			return
		}
		for _, seg := range strings.Split(q.URL.Path, "/") {
			if seg == ".." || strings.ContainsAny(seg, "\\\x00") {
				http.NotFound(rw, q)
				return
			}
		}
		rel := path.Clean("/" + q.URL.Path)
		if rel == "/" {
			rel = "/index.html"
		}
		full := filepath.Join(root, filepath.FromSlash(rel))
		ct, known := mimeTypes[strings.ToLower(path.Ext(rel))]
		if !known {
			http.NotFound(rw, q)
			return
		}
		h := rw.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Cache-Control", "no-cache")
		h.Add("Vary", "Accept-Encoding")
		file, enc := full, ""
		ae := q.Header.Get("Accept-Encoding")
		for _, c := range []struct{ ext, name string }{{".br", "br"}, {".gz", "gzip"}} {
			if acceptsEncoding(ae, c.name) {
				if st, err := os.Stat(full + c.ext); err == nil && st.Mode().IsRegular() {
					file, enc = full+c.ext, c.name
					break
				}
			}
		}
		f, err := os.Open(file)
		if err != nil {
			http.NotFound(rw, q)
			return
		}
		defer f.Close()
		st, err := f.Stat()
		if err != nil || !st.Mode().IsRegular() {
			http.NotFound(rw, q)
			return
		}
		h.Set("Content-Type", ct)
		h.Set("ETag", `"`+strconv.FormatInt(st.Size(), 36)+"-"+strconv.FormatInt(st.ModTime().UnixNano(), 36)+`"`)
		if enc != "" {
			h.Set("Content-Encoding", enc)
		}
		http.ServeContent(rw, q, "", st.ModTime(), f)
	})
}

func acceptsEncoding(header, name string) bool {
	for _, part := range strings.Split(header, ",") {
		tok := strings.TrimSpace(strings.SplitN(part, ";", 2)[0])
		if tok == name {
			params := strings.ReplaceAll(part, " ", "")
			return !(strings.HasSuffix(params, ";q=0") || strings.Contains(params, ";q=0.0"))
		}
	}
	return false
}
