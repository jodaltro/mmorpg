package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func designDecisions(h *harness, p core.ID) map[string]core.Decision {
	out := map[string]core.Decision{}
	for _, d := range h.s.Decisions {
		if d.Kind == "design" && d.Subject == string(p) {
			out[strings.Split(d.ID, ":")[1]] = d
		}
	}
	return out
}

func lifeOf(h *harness) {
	h.join("lutador", "andarilho")
	for _, p := range []core.ID{"lutador", "andarilho"} {
		h.move(p, "sangue")
	}
	h.repeat("adapter", "lutador", "estilo-chicote", 14)
	h.repeat("adapter", "lutador", "derrotar-virus", 8)
	h.repeat("adapter", "andarilho", "estilo-impulso", 10)
	h.repeat("adapter", "andarilho", "esquivar", 8)
	h.repeat("adapter", "andarilho", "estilo-explorar", 8)
}

// The advisor designs the traits of each cell; the default (the options whose affinities fit the body) applies at the deadline,
// so two players who live differently end up with different signatures even without any advisor.
func TestDesignTraitsFollowHowEachPlayerLivesByDefault(t *testing.T) {
	h := load(t, "hospedeiro")
	lifeOf(h)
	h.tick(46) // the design is reconsidered at tick 45 and the defaults apply at the deadline
	a, b := h.waitLook("lutador"), h.waitLook("andarilho")
	if len(a.Traits) != 19 || len(b.Traits) != 19 {
		t.Fatalf("every trait is designed, got %v / %v", a.Traits, b.Traits)
	}
	if a.Traits["nucleo"] == b.Traits["nucleo"] && a.Traits["membrana"] == b.Traits["membrana"] && a.Traits["efeito"] == b.Traits["efeito"] {
		t.Fatalf("different lives, different cells: %v vs %v", a.Traits, b.Traits)
	}
	if a.Traits["membrana"] != "espinhosa" || a.Traits["efeito"] != "chama" {
		t.Fatalf("a fighter is spiny and burns, got %v", a.Traits)
	}
	if b.Traits["efeito"] != "eletrico" {
		t.Fatalf("a runner crackles, got %v", b.Traits)
	}
}

// The advisor's answer must be one of the options of that very trait and is revalidated; the design keeps what the advisor picked.
func TestDesignAdvisorChoiceIsRevalidatedAndKept(t *testing.T) {
	h := load(t, "hospedeiro")
	lifeOf(h)
	for i := 0; i < 45 && len(designDecisions(h, "lutador")) == 0; i++ {
		h.tick(1)
	}
	ds := designDecisions(h, "lutador")
	if len(ds) != 19 {
		t.Fatalf("every trait is asked together, got %d", len(ds))
	}
	nucleo := ds["nucleo"]
	if _, err := h.try(core.Command{Kind: "resolve", Origin: "advisor", Decision: nucleo.ID, Choice: "ondulada"}); !isRejected(err) {
		t.Fatalf("an option of another trait is refused, got %v", err)
	}
	h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: nucleo.ID, Choice: "trevo", Provider: "test"})
	if got := h.waitLook("lutador").Traits["nucleo"]; got != "trevo" {
		t.Fatalf("the advisor's nucleus is kept, got %q", got)
	}
	h.tick(4) // the other traits fall back to their defaults
	if tr := h.waitLook("lutador").Traits; tr["nucleo"] != "trevo" || len(tr) != 19 {
		t.Fatalf("the rest completes by default without undoing the advisor's pick: %v", tr)
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("replaying the design log gives another world")
	}
}

// The first design comes early, after a few deeds, so a new cell soon has a face of its own (later redesigns wait for more life).
func TestDesignFirstOneComesEarly(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.move("p1", "sangue")
	h.repeat("adapter", "p1", "estilo-chicote", 4)
	h.repeat("adapter", "p1", "derrotar-virus", 3)
	for i := 0; i < 12 && len(designDecisions(h, "p1")) == 0; i++ {
		h.tick(1)
	}
	if len(designDecisions(h, "p1")) != 19 {
		t.Fatalf("seven deeds are enough for the first design, got %d decisions", len(designDecisions(h, "p1")))
	}
}
