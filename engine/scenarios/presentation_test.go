package scenarios

import (
	"encoding/json"
	"os"
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// The Godot client keeps where things stand and what they are called in
// data/presentation.json. It may only mention what the universe has, so a
// renamed action or region cannot silently leave the client pointing at nothing.
func TestClientPresentationMatchesTheUniverse(t *testing.T) {
	h := load(t, "valdoria")
	raw, err := os.ReadFile("../../clients/godot/data/presentation.json")
	if err != nil {
		t.Fatal(err)
	}
	var p struct {
		POIs []struct {
			ID      string    `json:"id"`
			Region  string    `json:"region"`
			Rel     []float64 `json:"rel"`
			Label   string    `json:"label"`
			With    string    `json:"with"`
			Actions []string  `json:"actions"`
		} `json:"pois"`
		Anim   map[string]string   `json:"anim"`
		Greet  map[string][]string `json:"greet"`
		Glyphs map[string]struct {
			Symbol string `json:"symbol"`
			Color  string `json:"color"`
			Title  string `json:"title"`
		} `json:"glyphs"`
	}
	if err := json.Unmarshal(raw, &p); err != nil {
		t.Fatal(err)
	}
	actions := map[string]bool{}
	for _, a := range h.w.U.Actions {
		actions[a.ID] = true
	}
	regions := map[string]bool{}
	for _, e := range h.w.U.Entities {
		if slices.Contains(h.w.U.RegionKinds, e.Kind) {
			regions[string(e.ID)] = true
		}
	}
	ids := map[string]bool{}
	for _, poi := range p.POIs {
		if poi.ID == "" || ids[poi.ID] || poi.Label == "" || len(poi.Rel) != 3 || !regions[poi.Region] {
			t.Fatalf("poi %+v", poi)
		}
		ids[poi.ID] = true
		if poi.With != "" && h.s.Entities[core.ID(poi.With)].ID == "" {
			t.Fatalf("poi %s stands for unknown entity %q", poi.ID, poi.With)
		}
		if poi.With == "" && len(poi.Actions) == 0 {
			t.Fatalf("poi %s anchors nothing", poi.ID)
		}
		for _, a := range poi.Actions {
			if !actions[a] {
				t.Fatalf("poi %s anchors unknown action %q", poi.ID, a)
			}
		}
	}
	for a := range p.Anim {
		if !actions[a] {
			t.Fatalf("animation for unknown action %q", a)
		}
	}
	for id, lines := range p.Greet {
		if h.s.Entities[core.ID(id)].Kind != "npc" || len(lines) == 0 {
			t.Fatalf("greetings for %q", id)
		}
	}
	// Every glyph the world knows has a symbol and a colour on the client, and the client invents none.
	for _, g := range h.w.U.Glyphs {
		pg, ok := p.Glyphs[g.ID]
		if !ok || pg.Symbol == "" || len(pg.Color) != 6 {
			t.Fatalf("glyph %q has no presentation", g.ID)
		}
		if pg.Title != g.Title {
			t.Fatalf("glyph %q: client title %q differs from the universe's %q", g.ID, pg.Title, g.Title)
		}
	}
	for id := range p.Glyphs {
		if _, ok := h.w.Glyph(id); !ok {
			t.Fatalf("the client has a glyph the world does not: %q", id)
		}
	}
}
