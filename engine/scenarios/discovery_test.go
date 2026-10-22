package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func found(h *harness, who, place core.ID) bool {
	v, ok := h.w.View(&h.s, who, 10)
	if !ok {
		h.t.Fatalf("no view for %s", who)
	}
	for _, f := range v.Facts {
		if f.P == h.w.U.Discovered && f.S == who && f.O == place {
			return true
		}
	}
	return false
}

// A map starts blank: the village where the character appears is known, and
// every other place is revealed only by going there. Nobody else's map shows.
func TestPlacesAreDiscoveredByGoingThere(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	if !found(h, "p1", "vila") {
		t.Fatal("the starting place must be known")
	}
	if found(h, "p1", "toca") || found(h, "p1", "ruinas") {
		t.Fatal("hidden places must start unknown")
	}
	h.move("p1", "floresta")
	h.move("p1", "toca")
	if !found(h, "p1", "floresta") || !found(h, "p1", "toca") {
		t.Fatal("entering a place must reveal it")
	}
	if found(h, "p2", "toca") {
		t.Fatal("p2 never went there")
	}
}

// OnJoin lets a universe shape the arrival: effects run with $self bound.
func TestOnJoinEffectsRunForTheNewcomer(t *testing.T) {
	h := load(t, "valdoria")
	u := h.w.U
	one := int64(3)
	u.OnJoin = []core.Effect{{Op: "adjust", E: "$self", K: "reputation", D: one}}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	h.w, h.s = w, core.NewState(w)
	h.join("p1")
	if got := h.s.Entities["p1"].Num["reputation"]; got != 3 {
		t.Fatalf("reputation = %d, want 3", got)
	}
}
