//go:build js && wasm

package main

import (
	"encoding/json"
	"syscall/js"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/personal"
)

func main() {
	var session *personal.Session
	fn := js.FuncOf(func(_ js.Value, args []js.Value) any {
		var q struct {
			Op         string               `json:"op"`
			Universe   json.RawMessage      `json:"universe"`
			Commands   []core.Command       `json:"commands"`
			Path       string               `json:"path"`
			Body       json.RawMessage      `json:"body"`
			Checkpoint *personal.Checkpoint `json:"checkpoint"`
		}
		var response any
		if err := json.Unmarshal([]byte(args[0].String()), &q); err != nil {
			response = map[string]any{"error": err.Error()}
		} else if q.Op == "open" {
			var err error
			session, err = personal.OpenCached(q.Universe, q.Commands, q.Checkpoint)
			if err != nil {
				response = map[string]any{"error": err.Error()}
			} else {
				response = map[string]any{"ready": true, "checkpoint": session.Checkpoint()}
			}
		} else if session != nil {
			before := len(session.Journal)
			res := session.Request(q.Path, q.Body)
			out := map[string]any{"response": res, "commands": session.Journal[before:]}
			if before/128 != len(session.Journal)/128 {
				out["checkpoint"] = session.Checkpoint()
			}
			response = out
		} else {
			response = map[string]any{"error": "not_ready"}
		}
		encoded, _ := json.Marshal(response)
		return string(encoded)
	})
	js.Global().Set("worldsimLocal", fn)
	select {}
}
