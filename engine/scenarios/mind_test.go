package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// Player model: deeds teach the world a play style, and the default offer
// (without Jev) favors quests that match it.
func TestPlayStyleShapesOffers(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "mina")
	for i := 0; i < 3; i++ {
		h.mustAct("adapter", "p1", "minerar", nil)
	}
	h.move("p1", "vila")
	h.mustAct("player", "p1", "forjar", nil)
	if h.s.Styles["p1"]["craft"] < 4 {
		t.Fatalf("crafting deeds must be learned: %+v", h.s.Styles["p1"])
	}
	learned := h.s.Tick
	seen := false
	for i := 0; i < 40 && !seen; i++ {
		for _, d := range h.s.Decisions {
			if d.Subject == "p1" && d.Created > learned {
				seen = true
				if joined := strings.Join(d.Context, " | "); !strings.Contains(joined, "play style learned from deeds: craft=") {
					t.Fatalf("Jev must see the play style: %s", joined)
				}
			}
		}
		for _, q := range h.s.Quests {
			if q.Holder == "p1" && q.State == "offered" {
				h.do(core.Command{Kind: "decline", Origin: "player", Actor: "p1", Quest: q.Key})
			}
		}
		h.tick(1)
	}
	if !seen {
		t.Fatal("expected a new offer decision after the deeds")
	}
	q := h.steer("p1", "martelo-incansavel")
	if q.Def != "martelo-incansavel" {
		t.Fatal("a crafter is offered crafting quests")
	}
}

// Gossip: news travels between people who share a place, with provenance.
func TestGossipSpreadsBeliefs(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.move("p2", "floresta")
	h.tick(6)
	h.mustAct("player", "p1", "examinar-poco", nil) // p1 in the village knows
	if _, ok := h.believes("p2", "poisoned", "poco"); ok {
		t.Fatal("p2 is away and cannot know yet")
	}
	h.move("p2", "vila")
	h.tick(3)
	b, ok := h.s.Beliefs["p2"]["|poisoned|poco|"]
	if !ok || !b.Holds || b.Source != "rumor" || b.From == "" {
		t.Fatalf("p2 should hear the rumor in the village: %+v", b)
	}
	if len(h.events2("rumor", "p2")) == 0 {
		t.Fatal("the player is told what they heard")
	}
	if b.At != h.s.Beliefs[b.From]["|poisoned|poco|"].At {
		t.Fatal("a rumor keeps the age of the original observation")
	}
}

// Relationships: NPCs remember each player. Refusing again and again makes
// the giver stop calling; helping builds trust that unlocks new quests.
func TestNPCsRememberEachPlayer(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.introduce("p1")
	for i := 0; i < 3; i++ {
		q := h.steer("p1", "javali")
		h.do(core.Command{Kind: "decline", Origin: "player", Actor: "p1", Quest: q.Key})
		h.tick(int(h.w.U.Limits.DeclineCooldown) + 1)
	}
	if r := h.s.Relations["kael|p1"]; r != -3 {
		t.Fatalf("Kael remembers three refusals: %d", r)
	}
	for i := 0; i < 30; i++ {
		h.tick(1)
		if q, ok := h.quest("p1", "javali"); ok && q.State == "offered" {
			t.Fatal("Kael no longer calls a player who keeps refusing him")
		}
	}
	h2 := load(t, "valdoria")
	h2.join("p2")
	h2.introduce("p2")
	h2.s.Relations["mira|p2"] = 4 // helped Mira many times
	h2.tick(1)
	if q := h2.steer("p2", "segredo-mira"); q.Rank != "B" {
		t.Fatalf("trust unlocks Mira's secret: %+v", q)
	}
}

// Pacing: intense happenings raise tension; at the peak the director's
// default brings relief instead of another crisis; tension decays.
func TestDirectorPacesTension(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.happen("desabamento")
	if h.s.Tension <= h.w.U.Director.Calm {
		t.Fatalf("a crisis raises tension: %d", h.s.Tension)
	}
	h.s.Tension = h.w.U.Director.Peak + 8 // a run of crises
	since := h.s.Tick
	var d core.Decision
	for i := 0; i < 20; i++ {
		if x, ok := worldDecision(h); ok && x.Created > since {
			d = x
			break
		}
		h.tick(1)
	}
	if !strings.Contains(strings.Join(d.Context, " "), "pacing phase: relax") {
		t.Fatalf("the director must tell Jev it is time to relax: %v", d.Context)
	}
	lowest := int64(1 << 30)
	for _, o := range d.Options {
		for _, hp := range h.w.U.Happenings {
			if hp.ID == o.ID && hp.Intensity < lowest {
				lowest = hp.Intensity
			}
		}
	}
	for _, hp := range h.w.U.Happenings {
		if hp.ID == d.Default && hp.Intensity != lowest {
			t.Fatalf("after a peak the default is the calmest option, got %s", d.Default)
		}
	}
	before := h.s.Tension
	h.tick(20)
	if h.s.Tension >= before {
		t.Fatal("tension decays over time")
	}
}
