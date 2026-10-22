package scenarios

import "testing"

// A newcomer who has done nothing is a stranger: the system may still speak
// (quests without a giver), but no NPC reaches out on behalf of a stranger.
func TestStrangerGetsNoOfferFromGivers(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tick(60)
	for _, q := range h.s.Quests {
		if q.Holder == "p1" && q.Giver != "" {
			t.Fatalf("%s offered %q to someone they never saw", q.Giver, q.Def)
		}
	}
}

// Doing something where people are makes them know you. Others hear of you
// through gossip, and travellers carry the news to other places.
func TestWitnessedDeedMakesPlayerKnown(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.mustAct("player", "p1", "examinar-poco", nil) // in the village
	if !h.knowsOf("mira", "p1") || !h.knowsOf("brom", "p1") {
		t.Fatal("villagers who saw the deed must know p1")
	}
	if h.knowsOf("tomas", "p1") || h.knowsOf("kael", "p1") {
		t.Fatal("people elsewhere did not see anything")
	}
	// Who has met whom travels slowly: not at once, but within a while p2 hears of p1.
	h.tick(3)
	if h.knowsOf("p2", "p1") && h.knowsOf("tomas", "p1") {
		t.Fatal("news of a stranger should not reach everyone within one round")
	}
	for i := 0; i < 120 && !h.knowsOf("p2", "p1"); i++ {
		h.tick(1)
	}
	if !h.knowsOf("p2", "p1") {
		t.Fatal("p2 should hear of p1 in the village in the end")
	}
	// A traveller who hears of p1 does not carry it on: who has met whom is the villagers' own talk.
	h.move("p2", "estrada")
	h.tick(60)
	if b, ok := h.s.Beliefs["tomas"]["|met|tomas|p1"]; ok && b.From == "p2" {
		t.Fatal("travellers do not spread who knows whom (Tomas may hear it from the villagers, never from p2)")
	}
	// Now Mira, who saw p1, may call them; the quest names her as giver.
	if q := h.steer("p1", "ervas-mira"); q.Giver != "mira" {
		t.Fatalf("Mira should reach p1 once she knows them: %+v", q)
	}
}
