package personal

import (
	"encoding/json"
	"os"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func TestPrivateJournalReplayAndIsolation(t *testing.T) {
	definition, err := os.ReadFile("../../universes/hospedeiro/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	s, err := Open(definition, nil)
	if err != nil {
		t.Fatal(err)
	}
	response := s.Request("/v1/commands", json.RawMessage(`{"version":1,"requestId":"join:a","origin":"adapter","kind":"join","actor":"alice","name":"Alice","region":"medula"}`))
	if response.Status != 200 {
		t.Fatal(response)
	}
	for i := 0; i < 30; i++ {
		if r := s.Request("/tick", nil); r.Status != 200 {
			t.Fatal(r)
		}
	}
	if r := s.Request("/v1/views/alice?limit=20", nil); r.Status != 200 {
		t.Fatal(r)
	}
	replayed, err := Open(definition, s.Journal)
	if err != nil {
		t.Fatal(err)
	}
	if replayed.State.Digest() != s.State.Digest() {
		t.Fatal("private journal lost deterministic replay")
	}
	cache := s.Checkpoint()
	s.Request("/tick", nil)
	cached, err := OpenCached(definition, s.Journal, &cache)
	if err != nil || cached.State.Digest() != s.State.Digest() {
		t.Fatal("cached replay differs", err)
	}
	if cached.restoredCount != cache.Count {
		t.Fatal("valid checkpoint was not used")
	}
	cache.Digest = "corrupt"
	cached, err = OpenCached(definition, s.Journal, &cache)
	if err != nil || cached.State.Digest() != s.State.Digest() {
		t.Fatal("corrupt cache did not fall back to journal", err)
	}
	if cached.restoredCount != 0 {
		t.Fatal("corrupt checkpoint was used")
	}
	other, _ := Open(definition, nil)
	if r := other.Request("/v1/views/alice", nil); r.Status != 404 {
		t.Fatal("private worlds leaked players")
	}
	before := s.State.Digest()
	count := len(s.Journal)
	s.Request("/v1/commands", json.RawMessage(`{"version":1,"requestId":"bad","origin":"player","kind":"act","actor":"alice","action":"inventar-recompensa"}`))
	if len(s.Journal) != count || s.State.Digest() != before {
		t.Fatal("rejected action was saved")
	}
	_, err = Open(definition, append(s.Journal, core.Command{Version: 1, RequestID: "tick:999", Kind: "tick", Origin: "system"}))
	if err == nil {
		t.Fatal("corrupt journal accepted")
	}
}
