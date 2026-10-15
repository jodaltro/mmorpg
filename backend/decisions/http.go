package decisions

import (
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
)

func Handler(service DecisionService) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(405)
			return
		}
		reply(w, 200, map[string]any{"version": 1, "status": "ok"})
	})
	mux.HandleFunc("/v1/decisions/evaluate", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(405)
			return
		}
		// No browser CORS or cross-origin POSTs to the local billable interface.
		if r.Header.Get("Origin") != "" {
			reply(w, 403, map[string]string{"error": "origin_forbidden"})
			return
		}
		if r.Header.Get("Content-Type") != "application/json" {
			reply(w, 415, map[string]string{"error": "json_required"})
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 32768)
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		var request Request
		if decoder.Decode(&request) != nil || decoder.Decode(new(any)) != io.EOF {
			reply(w, 400, map[string]string{"error": "invalid_request"})
			return
		}
		result, err := service.Evaluate(r.Context(), request)
		if err != nil {
			status, code := 503, "decision_storage_unavailable"
			if errors.Is(err, ErrInvalid) {
				status, code = 400, "invalid_request"
			} else if errors.Is(err, ErrConflict) {
				status, code = 409, "event_context_conflict"
			}
			reply(w, status, map[string]string{"error": code})
			return
		}
		reply(w, 200, result)
	})
	return mux
}
func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func LocalAddress(address string) bool {
	host, _, err := net.SplitHostPort(address)
	return err == nil && host == "127.0.0.1"
}
