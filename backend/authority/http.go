package authority

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strings"
	"time"
	"mmorpg/authority/journey"
)

func Handler(store *Store, auth Authenticator) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		reply(w, 200, map[string]any{"version": 1, "status": "ok"})
	})
	mux.HandleFunc("/v1/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		if r.Header.Get("Origin") != "" {
			reply(w, 403, map[string]string{"error": "origin_forbidden"})
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
		defer cancel()
		authorization := r.Header.Get("Authorization")
		if !strings.HasPrefix(authorization, "Bearer ") || strings.ContainsAny(strings.TrimPrefix(authorization, "Bearer "), " \r\n\t") {
			fail(w, ErrUnauthorized)
			return
		}
		identity, e := auth.Verify(ctx, strings.TrimPrefix(authorization, "Bearer "))
		if e != nil {
			fail(w, ErrUnauthorized)
			return
		}
		parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
		if len(parts)==2&&parts[1]=="content"&&r.Method=="GET" { c,e:=journey.Load();if e!=nil{fail(w,ErrUnavailable)}else{reply(w,200,c)};return }
		if len(parts) == 3 && parts[1] == "development" && parts[2] == "imports" && r.Method == "POST" {
			if !store.EnableDevImport {
				fail(w, ErrNotFound)
				return
			}
			var in DevelopmentImport
			r.Body = http.MaxBytesReader(w, r.Body, 4*1024*1024)
			if !decodeImport(w, r, &in) {
				return
			}
			c, e := store.Import(ctx, identity.UserID, in)
			if e != nil {
				fail(w, e)
			} else {
				reply(w, 201, c)
			}
			return
		}
		if len(parts) == 2 && parts[1] == "characters" {
			switch r.Method {
			case "GET":
				ids, e := store.List(ctx, identity.UserID)
				if e != nil {
					fail(w, e)
				} else {
					reply(w, 200, map[string]any{"version": 1, "characterIds": ids})
				}
			case "POST":
				var in CreateCharacter
				if !decode(w, r, &in) {
					return
				}
				c, e := store.Create(ctx, identity.UserID, in)
				if e != nil {
					fail(w, e)
				} else {
					reply(w, 201, c)
				}
			default:
				w.WriteHeader(405)
			}
			return
		}
		if len(parts) == 3 && parts[1] == "characters" && r.Method == "GET" {
			c, e := store.Read(ctx, identity.UserID, parts[2])
			if e != nil {
				fail(w, e)
			} else {
				reply(w, 200, c)
			}
			return
		}
		if len(parts) == 4 && parts[1] == "characters" && parts[3] == "intentions" && r.Method == "POST" {
			var in Intent
			if !decode(w, r, &in) {
				return
			}
			c, e := store.Apply(ctx, identity.UserID, parts[2], in)
			if e != nil {
				fail(w, e)
			} else {
				reply(w, 200, c)
			}
			return
		}
		if len(parts) == 5 && parts[1] == "worlds" && parts[3] == "regions" && r.Method == "GET" {
			region, e := store.ReadRegion(ctx, identity.UserID, parts[2], parts[4])
			if e != nil {
				fail(w, e)
			} else {
				reply(w, 200, region)
			}
			return
		}
		reply(w, 404, map[string]string{"error": "not_found"})
	})
	return mux
}
func decode(w http.ResponseWriter, r *http.Request, out any) bool {
	media, _, e := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if e != nil || media != "application/json" {
		reply(w, 415, map[string]string{"error": "json_required"})
		return false
	}
	d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 65536))
	d.DisallowUnknownFields()
	if d.Decode(out) != nil || d.Decode(new(any)) != io.EOF {
		fail(w, ErrInvalid)
		return false
	}
	return true
}
func decodeImport(w http.ResponseWriter, r *http.Request, out any) bool {
	media, _, e := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if e != nil || media != "application/json" {
		reply(w, 415, map[string]string{"error": "json_required"})
		return false
	}
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if d.Decode(out) != nil || d.Decode(new(any)) != io.EOF {
		fail(w, ErrInvalid)
		return false
	}
	return true
}
func fail(w http.ResponseWriter, e error) {
	code, status := "storage_unavailable", 503
	switch {
	case errors.Is(e, ErrUnauthorized):
		code, status = "session_expired_or_invalid", 401
		w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
	case errors.Is(e, ErrInvalid):
		code, status = "invalid_intent", 400
	case errors.Is(e, ErrNotFound):
		code, status = "not_found", 404
	case errors.Is(e, ErrConflict):
		code, status = "revision_or_request_conflict", 409
	}
	reply(w, status, map[string]string{"error": code})
}
func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
