package scenarios

import (
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// A newborn cell is a stranger until it does something; then the stroma
// invites it to dive into the blood, and entering the blood completes it.
func TestHospedeiroFirstDiveAfterTheFirstDeed(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	if got := h.s.Entities["p1"].Region; got != "medula" {
		t.Fatalf("born in %q, want the marrow", got)
	}
	h.tick(10)
	for _, q := range h.s.Quests {
		if q.Holder == "p1" {
			t.Fatalf("offer before the first deed: %+v", q)
		}
	}
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	if q.Giver != "estroma" {
		t.Fatalf("the stroma should call, got %q", q.Giver)
	}
	h.accept("p1", q)
	h.move("p1", "sangue")
	h.tick(2)
	if q, _ := h.quest("p1", "primeiro-mergulho"); q.State != "done" {
		t.Fatalf("diving into the blood should complete it, state %q", q.State)
	}
}

// Knowledge changes the world: the player sees the virion up close, tells
// Dendra, and Dendra (acting on what she now believes) arms the defenses.
func TestHospedeiroTellingDendraArmsTheDefense(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.tick(6) // the first outbreak starts at tick 5
	h.move("p1", "sangue")
	h.mustAct("adapter", "p1", "derrotar-virus", nil)
	if holds, ok := h.believes("p1", "assinatura", "virion"); !ok || !holds {
		t.Fatal("defeating a virion should teach its signature")
	}
	if holds, ok := h.believes("dendra", "assinatura", "virion"); ok && holds {
		t.Fatal("Dendra cannot know before being told")
	}
	h.mustAct("player", "p1", "contar", map[string]core.ID{"npc": "dendra", "p": "assinatura", "s": "virion"})
	h.tick(3)
	if !h.fact("", "defesa-armada", "sangue", "") {
		t.Fatal("Dendra should arm the defense once she knows the virion")
	}
}

// Without anyone playing, the body still regulates itself: the cytokine
// alarm makes Neva fight, the focus goes out and a new outbreak follows.
func TestHospedeiroBodyRegulatesItselfWithoutPlayers(t *testing.T) {
	h := load(t, "hospedeiro")
	h.tick(240)
	kinds := map[string]int{}
	for _, e := range h.w.Chronicle(&h.s, 0).Events {
		kinds[e.Kind]++
	}
	if kinds["cura"] < 1 || kinds["surto"] < 2 {
		t.Fatalf("expected outbreaks to be cured and to return, got %v", kinds)
	}
}

// The first memory is a unique scenario: only one cell deciphers it first,
// it needs to know the virion's language, and the story moves on for all.
func TestHospedeiroFirstMemoryIsUnique(t *testing.T) {
	early := load(t, "hospedeiro")
	early.join("p1")
	early.mustAct("adapter", "p1", "derrotar-virus", nil)
	if early.act("player", "p1", "ler-codigo", nil) == nil {
		t.Fatal("the fragment cannot be read before it appears")
	}

	h := load(t, "hospedeiro")
	h.join("p1", "p2")
	h.tick(26) // the strange code appears at tick 25
	if h.act("player", "p2", "ler-codigo", nil) == nil {
		t.Fatal("reading the fragment requires knowing the virion")
	}
	// Seeing a virion up close teaches its language. (Told by gossip later,
	// the others learn it too: that is how knowledge spreads in the body.)
	h.mustAct("adapter", "p1", "derrotar-virus", nil)
	h.mustAct("player", "p1", "ler-codigo", nil)
	h.tick(1)
	if got := h.s.Entities["p1"].Tag["title"]; got != "Primeira Lembrança" {
		t.Fatalf("p1 should carry the title, got %q", got)
	}
	if !h.fact("", "reescrita-revelada", "medula", "") {
		t.Fatal("the claim should reveal the Rewriting to the world")
	}
	h.mustAct("adapter", "p2", "derrotar-virus", nil)
	h.mustAct("player", "p2", "ler-codigo", nil)
	h.tick(1)
	if got := h.s.Entities["p2"].Tag["title"]; got != "" {
		t.Fatalf("only the first claims the scenario, p2 got %q", got)
	}
}

func (h *harness) eventKinds(holder core.ID) map[string]int {
	out := map[string]int{}
	for _, e := range h.s.Events {
		if e.Holder == holder {
			out[e.Kind]++
		}
	}
	return out
}

// A hunt quest follows what the player does in combat, and pays in things the
// player feels: evolutionary pressure and a repair of the cell.
func TestHospedeiroHuntQuestPaysInEvolutionAndRepair(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.move("p1", "sangue")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil) // seen acting in the blood: Neva now knows this cell
	h.tick(8) // the outbreak starts at tick 5
	q := h.steer("p1", "caca-no-capilar")
	if q.Giver != "neva" {
		t.Fatalf("Neva should call the hunt, got %q", q.Giver)
	}
	h.accept("p1", q)
	before := h.s.Entities["p1"].Num["pressao"]
	h.fight("p1", 5)
	h.tick(2)
	if got, _ := h.quest("p1", "caca-no-capilar"); got.State != "done" {
		t.Fatalf("five kills should complete the hunt, state %q", got.State)
	}
	if h.s.Entities["p1"].Num["pressao"] < before+5 {
		t.Fatalf("the hunt pays evolutionary pressure: %d -> %d", before, h.s.Entities["p1"].Num["pressao"])
	}
	if h.eventKinds("p1")["bonus-reparo"] < 1 {
		t.Fatal("the hunt should also repair the cell (the client turns this event into healing)")
	}
}

// Evolving is itself something to be asked about, and the veteran reward is a
// guaranteed mutation (enough pressure to overflow the threshold).
func TestHospedeiroEvolutionQuestsFollowTheGenome(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	h.accept("p1", q)
	h.move("p1", "sangue")
	h.tick(2)
	g := h.steer("p1", "primeiro-gene")
	h.accept("p1", g)
	h.fight("p1", 4)
	offer := h.waitOffer("p1")
	h.mustAct("player", "p1", "evoluir", map[string]core.ID{"gene": core.ID(offer.Featured)})
	h.tick(2)
	if got, _ := h.quest("p1", "primeiro-gene"); got.State != "done" {
		t.Fatalf("expressing a gene completes the quest, state %q", got.State)
	}
	if h.s.Entities["p1"].Num["pressao"] < 3 {
		t.Fatalf("the quest pays pressure, got %d", h.s.Entities["p1"].Num["pressao"])
	}
}

// Dodging is counted by the engine when the game server confirms it, and a
// quest can ask for it.
func TestHospedeiroDodgeQuestCountsConfirmedDodges(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.move("p1", "sangue")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.tick(8)
	h.fight("p1", 3)
	q := h.steer("p1", "dancar-com-o-perigo")
	h.accept("p1", q)
	for i := 0; i < 3; i++ {
		h.mustAct("adapter", "p1", "esquivar", nil)
	}
	h.tick(2)
	if got, _ := h.quest("p1", "dancar-com-o-perigo"); got.State != "done" {
		t.Fatalf("three confirmed dodges complete it, state %q", got.State)
	}
}
