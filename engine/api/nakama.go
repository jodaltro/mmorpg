package api

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

// The same public origin serves assets, world intentions and Nakama WebSockets.
// Only the client API is exposed; PostgreSQL, gRPC and the Nakama console remain local.
func nakamaProxy(target string) http.Handler {
	u, err := url.Parse(target)
	if err != nil || u.Scheme != "http" || (u.Hostname() != "127.0.0.1" && u.Hostname() != "localhost") {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { reply(w, 503, errorBody{Version, "nakama_unavailable"}) })
	}
	p := httputil.NewSingleHostReverseProxy(u)
	original := p.Director
	p.Director = func(r *http.Request) {
		r.URL.Path = strings.TrimPrefix(r.URL.Path, "/nakama")
		r.URL.RawPath = ""
		original(r)
		r.Host = u.Host
		r.Header.Del("X-Adapter-Key")
		r.Header.Del("X-Edge-Secret")
	}
	p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		reply(w, 503, errorBody{Version, "nakama_unavailable"})
	}
	return p
}
