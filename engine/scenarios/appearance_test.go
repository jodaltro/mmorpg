package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) appearanceDecision(p core.ID) (core.Decision, bool) {
	for _, d := range h.s.Decisions {
		if d.Kind == "appearance" && d.Subject == string(p) {
			return d, true
		}
	}
	return core.Decision{}, false
}

func (h *harness) repeat(origin string, p core.ID, action string, n int) {
	for i := 0; i < n; i++ {
		h.mustAct(origin, p, action, nil)
	}
}

// waitLook ticks until p has a body (the default applies at the deadline).
func (h *harness) waitLook(p core.ID) *core.LookView {
	h.t.Helper()
	for i := 0; i < 60; i++ {
		if v, _ := h.w.View(&h.s, p, 1); v.Look != nil {
			return v.Look
		}
		h.tick(1)
	}
	h.t.Fatalf("%s never got a body", p)
	return nil
}

func TestBodyFollowsHowEachPlayerPlays(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1", "p2")
	h.move("p1", "sangue")
	h.move("p2", "sangue")
	// p1 fights, p2 runs and dodges.
	h.repeat("adapter", "p1", "estilo-chicote", 14)
	h.repeat("adapter", "p1", "derrotar-virus", 6)
	h.repeat("adapter", "p2", "estilo-impulso", 10)
	h.repeat("adapter", "p2", "esquivar", 6)
	h.repeat("adapter", "p2", "estilo-explorar", 8)
	a, b := h.waitLook("p1"), h.waitLook("p2")
	if a.Variant != "cacador" || b.Variant != "andarilho" {
		t.Fatalf("a fighter becomes a hunter and a runner a wanderer, got %s / %s", a.Variant, b.Variant)
	}
	if a.Axes["ferocidade"] <= b.Axes["ferocidade"] || b.Axes["agilidade"] <= a.Axes["agilidade"] {
		t.Fatalf("each body leans where its owner plays: %v vs %v", a.Axes, b.Axes)
	}
	seen := false
	v, _ := h.w.View(&h.s, "p2", 1)
	for _, o := range v.Others {
		if o.ID == "p1" && o.Look != nil && o.Look.Variant == "cacador" {
			seen = true
		}
	}
	if !seen {
		t.Fatal("other players see your body")
	}
}

func TestAdvisorChoosesTheBodyAndIsRevalidated(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.repeat("adapter", "p1", "estilo-chicote", 22)
	d := core.Decision{}
	for i := 0; i < 60; i++ {
		var ok bool
		if d, ok = h.appearanceDecision("p1"); ok {
			break
		}
		h.tick(1)
	}
	if d.ID == "" || len(d.Options) < 6 || d.Default != "cacador" {
		t.Fatalf("expected a decision with every variant and a fitting default, got %+v", d)
	}
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "inventado", Provider: "test"}); err == nil {
		t.Fatal("a variant outside the options is refused")
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: "diplomata", Provider: "test"})
	if got := h.waitLook("p1"); got.Variant != "diplomata" {
		t.Fatalf("the advisor's pick becomes the body, got %s", got.Variant)
	}
}

func TestBodyDoesNotChangeWithoutNewDeeds(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.repeat("adapter", "p1", "estilo-chicote", 22)
	first := h.waitLook("p1")
	at := h.s.Looks["p1"].At
	h.tick(120)
	if _, ok := h.appearanceDecision("p1"); ok || h.s.Looks["p1"].At != at {
		t.Fatalf("no reconsideration without new deeds (first %s)", first.Variant)
	}
}
