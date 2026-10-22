package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) signs(p core.ID) map[string]core.SignView {
	h.t.Helper()
	v, ok := h.w.View(&h.s, p, 5)
	if !ok {
		h.t.Fatalf("no view for %s", p)
	}
	out := map[string]core.SignView{}
	for _, sg := range v.Signs {
		out[sg.ID] = sg
	}
	return out
}

func (h *harness) tickToHour(hour int64) {
	for h.w.Hour(&h.s) != hour {
		h.tick(1)
	}
}

func (h *harness) tickUntilFact(p, s string) {
	h.t.Helper()
	for i := 0; i < 200; i++ {
		for _, f := range h.s.Facts {
			if f.P == p && string(f.S) == s {
				return
			}
		}
		h.tick(1)
	}
	h.t.Fatalf("fact %s %s never came to be", p, s)
}

// A sign is the effect of a hidden truth: it exists only while the truth
// holds, and showing it never names the cause.
func TestSignShowsTheEffectNeverTheCause(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	if _, there := h.signs("p1")["agua-turva"]; there {
		t.Fatal("clear water before the poisoning")
	}
	h.tickUntilFact("poisoned", "poco")
	sg, there := h.signs("p1")["agua-turva"]
	if !there {
		t.Fatal("murky water once the well is poisoned")
	}
	v, _ := h.w.View(&h.s, "p1", 5)
	b, _ := json.Marshal(v.Signs)
	if strings.Contains(string(b), "poisoned") || strings.Contains(sg.Look, "veneno") {
		t.Fatalf("a sign must not name its cause: %s", b)
	}
	for _, f := range v.Facts {
		if f.P == "poisoned" {
			t.Fatal("seeing the sign is not knowing the fact")
		}
	}
	if _, here := h.signs("p1")["veios-brilham"]; here {
		t.Fatal("signs belong to a place: the mine's are not in the village")
	}
}

// Examining a sign is how the world teaches: the observer ends up believing,
// by observation, what the sign points to.
func TestExaminingASignFormsAnObservedBelief(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	if err := h.act("player", "p1", "examinar", map[string]core.ID{"sign": "veios-brilham"}); err == nil {
		t.Fatal("cannot examine what is in another place")
	}
	d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "examinar", Args: map[string]core.ID{"sign": "agua-turva"}})
	if len(d.Events) == 0 || d.Events[0].Kind != "examined" || d.Events[0].Public {
		t.Fatalf("a private account of what was seen: %+v", d.Events)
	}
	b, ok := h.s.Beliefs["p1"]["|poisoned|poco|"]
	if !ok || !b.Holds || b.Source != "observation" {
		t.Fatalf("belief after examining: %+v", b)
	}
}

// Seeing takes more than being there: a night sign needs the night, and the
// white boar's track needs someone who knows how to look.
func TestSignsAskForTheHourAndForSkill(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	h.tickToHour(12)
	if _, there := h.signs("p1")["pegada-branca"]; there {
		t.Fatal("not by day")
	}
	h.tickToHour(23)
	if _, there := h.signs("p1")["pegada-branca"]; there {
		t.Fatal("not at night for someone who never hunted")
	}
	h.s.Entities["p1"].Num["hunts"] = 1
	if _, there := h.signs("p1")["pegada-branca"]; !there {
		t.Fatal("a hunter sees the track at night")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "pegada-branca"})
	if _, ok := h.s.Facts["p1|white-boar-sign|p1|floresta"]; !ok {
		t.Fatalf("the track becomes a private clue; facts: %v", h.s.Facts)
	}
}

// You can only tell what you believe; people answer by what they already know,
// and by whether it is still true.
func TestTellingBeliefsAndHowPeopleReact(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	tell := func(npc core.ID) (string, error) {
		d, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "contar",
			Args: map[string]core.ID{"npc": npc, "p": "poisoned", "s": "poco"}})
		for _, e := range d.Events {
			if e.Kind == "told" {
				return e.Text, err
			}
		}
		return "", err
	}
	if _, err := tell("mira"); err == nil {
		t.Fatal("nobody can tell what they do not believe")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "agua-turva"})
	if _, err := tell("kael"); err == nil {
		t.Fatal("Kael is in the forest: the listener must be here")
	}
	first, err := tell("mira")
	if err != nil || !strings.Contains(first, "antidoto") {
		t.Fatalf("Mira takes the news: %q %v", first, err)
	}
	if b := h.s.Beliefs["mira"]["|poisoned|poco|"]; !b.Holds || b.Source != "communication" || b.From != "p1" {
		t.Fatalf("Mira's belief: %+v", b)
	}
	if second, _ := tell("mira"); !strings.Contains(second, "Eu sei") {
		t.Fatalf("she already knows: %q", second)
	}
	// The world moves on: the well is clean, and what p1 believes is stale.
	delete(h.s.Facts, "|poisoned|poco|")
	if stale, _ := tell("brom"); !strings.Contains(stale, "limpo") {
		t.Fatalf("out of date: %q", stale)
	}
	if b, ok := h.s.Beliefs["brom"]["|poisoned|poco|"]; ok && b.Holds {
		t.Fatal("Brom must not take in something no longer true")
	}
}

// What can be tried follows what is seen and believed.
func TestAffordancesIncludeExamineAndTell(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickUntilFact("poisoned", "poco")
	find := func(action string, with core.ID) bool {
		for _, a := range h.w.Affordances(&h.s, "p1") {
			if a.Action == action && (with == "" || a.With == with) {
				return true
			}
		}
		return false
	}
	if !find("examinar", "") {
		t.Fatal("the murky water can be examined")
	}
	if find("contar", "mira") {
		t.Fatal("nothing to tell before believing something")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "agua-turva"})
	if !find("contar", "mira") {
		t.Fatal("now Mira can be told")
	}
}

// Tomas draws a sketch: two places appear on the map without going there.
func TestSketchRevealsPlacesOnTheMap(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", h.s.Entities["tomas"].Region)
	h.mustAct("player", "p1", "pedir-esboco", nil)
	if !found(h, "p1", "floresta") || !found(h, "p1", "mina") || found(h, "p1", "toca") {
		t.Fatal("the sketch shows the forest and the mine, not the den")
	}
	if err := h.act("player", "p1", "pedir-esboco", nil); err == nil {
		t.Fatal("one sketch is enough")
	}
}

// The discovery bot knows nothing of the universe: it only does what the
// engine offers (examine what it can see, tell what it believes). If the
// village riddles can be solved this way, they have a way in that needs no
// outside information.
func TestDiscoveryBotSolvesTheVillageRiddles(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	done := map[string]bool{}
	for i := 0; i < 150; i++ {
		for _, a := range h.w.Affordances(&h.s, "p1") {
			if a.Action != "examinar" && a.Action != "contar" {
				continue
			}
			key := a.Action + "|" + string(a.With)
			for _, k := range []string{"npc", "p", "s", "o", "sign"} {
				key += "|" + string(a.Args[k])
			}
			if done[key] {
				continue
			}
			if err := h.act("player", "p1", a.Action, a.Args); err == nil {
				done[key] = true
			}
		}
		h.tick(1)
	}
	for _, f := range []string{"den-trail", "anvil-mark", "nameless-grave"} {
		if _, ok := h.s.Facts["p1|"+f+"|p1|"+map[string]string{"den-trail": "toca", "anvil-mark": "ruinas", "nameless-grave": "vila"}[f]]; !ok {
			t.Fatalf("the bot never found %s", f)
		}
	}
	// The story moves on (Mira purifies the well later), so the proof is in the deeds.
	if h.s.Deeds["p1"]["examinar:agua-turva"] == 0 || h.s.Deeds["p1"]["contar"] == 0 {
		t.Fatalf("the bot should have examined the murky water and told someone: %v", h.s.Deeds["p1"])
	}
}

// The dawn song is heard at the chapel only at dawn, and examining it leaves
// a private clue.
func TestDawnSongSignOnlyAtDawn(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tickToHour(12)
	if _, there := h.signs("p1")["cancao-alvorada"]; there {
		t.Fatal("no singing at noon")
	}
	h.tickToHour(6)
	if _, there := h.signs("p1")["cancao-alvorada"]; !there {
		t.Fatal("the chapel sings at dawn")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "cancao-alvorada"})
	if _, ok := h.s.Facts["p1|dawn-song|p1|vila"]; !ok {
		t.Fatal("examining leaves a private clue")
	}
}

// The glint in the mine is only seen by someone who has already worked the
// veins; searching may find the coin (and then the glint is gone), and a miss
// says so.
func TestCoinGlintAppearsAfterMiningAndFindsTheCoin(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "mina")
	if _, there := h.signs("p1")["brilho-na-pedra"]; there {
		t.Fatal("nobody notices a glint before working the veins")
	}
	h.mustAct("adapter", "p1", "minerar", nil)
	if _, there := h.signs("p1")["brilho-na-pedra"]; !there {
		t.Fatal("after mining the glint is noticed")
	}
	misses := 0
	for i := 0; i < 80; i++ {
		if _, ok := h.s.Facts["p1|old-coin|p1|mina"]; ok {
			break
		}
		d := h.do(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "examinar", Args: map[string]core.ID{"sign": "brilho-na-pedra"}})
		for _, e := range d.Events {
			if e.Kind == "coin-miss" {
				misses++
			}
		}
		h.tick(1)
	}
	if _, ok := h.s.Facts["p1|old-coin|p1|mina"]; !ok {
		t.Fatalf("the coin is found eventually (%d misses)", misses)
	}
	if misses == 0 {
		t.Fatal("a 25% chance should have missed at least once")
	}
	if _, there := h.signs("p1")["brilho-na-pedra"]; there {
		t.Fatal("the glint is gone once the coin is found")
	}
}

// Landmarks: from another region a sign is only seen, never examined, and a
// sign that depends on a hidden truth (the seal's glow, at night) gives that
// truth away to anyone looking at the horizon, which is the point.
func TestFarSignsAreLandmarksOnly(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	sg, ok := h.signs("p1")["torre-asterion"]
	if !ok || !sg.Far {
		t.Fatalf("the tower is seen from the village as a landmark: %+v", sg)
	}
	if err := h.act("player", "p1", "examinar", map[string]core.ID{"sign": "torre-asterion"}); err == nil {
		t.Fatal("a landmark cannot be examined from afar")
	}
	for _, a := range h.w.Affordances(&h.s, "p1") {
		if a.Action == "examinar" && a.Args["sign"] == "torre-asterion" {
			t.Fatal("no affordance to examine what is far away")
		}
	}
	h.tickUntilFact("seal-broken", "selo")
	h.tickToHour(23)
	if g, there := h.signs("p1")["selo-brilha"]; !there || !g.Far {
		t.Fatal("once the seal breaks, its glow is a landmark at night")
	}
	h.tickToHour(12)
	if _, there := h.signs("p1")["selo-brilha"]; there {
		t.Fatal("by day the glow is not seen")
	}
	h.move("p1", "ruinas")
	if g := h.signs("p1")["torre-asterion"]; g.Far {
		t.Fatal("at the ruins the tower is right here")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "torre-asterion"})
}

// A torch is a fact the game server confirms; it burns for a while. Only a lit
// torch shows the draught in the dark gallery.
func TestTorchBurnsThenGoesOutAndRevealsTheDraught(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "mina")
	if _, there := h.signs("p1")["corrente-de-ar"]; there {
		t.Fatal("no draught is felt in the dark")
	}
	h.mustAct("adapter", "p1", "acender-tocha", nil)
	if err := h.act("adapter", "p1", "acender-tocha", nil); err == nil {
		t.Fatal("one torch at a time")
	}
	if _, there := h.signs("p1")["corrente-de-ar"]; !there {
		t.Fatal("the flame leans toward the wall")
	}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "corrente-de-ar"})
	if _, ok := h.s.Facts["p1|tunnel-known|p1|ruinas"]; !ok {
		t.Fatal("the passage becomes known")
	}
	h.tick(41)
	if _, ok := h.s.Facts["p1|torch-lit|p1|"]; ok {
		t.Fatal("the torch burned out")
	}
	if _, there := h.signs("p1")["corrente-de-ar"]; there {
		t.Fatal("without the flame, no draught")
	}
	h.mustAct("adapter", "p1", "acender-tocha", nil)
}

// Asterion's writing is read bit by bit, and what you already carry decides
// what the words mean.
func TestRunesAreReadBitByBit(t *testing.T) {
	read := func(h *harness, sign string) {
		h.t.Helper()
		h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": core.ID(sign)})
	}
	linked := func(h *harness) bool { _, ok := h.s.Facts["p1|legacy-link|p1|ruinas"]; return ok }

	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "ruinas")
	if _, there := h.signs("p1")["inscricao-salao"]; there {
		t.Fatal("the hall's phrase is only noticed after the entrance")
	}
	read(h, "inscricao-entrada")
	if linked(h) {
		t.Fatal("without Brom's anvil mark, the symbols mean nothing yet")
	}
	if _, there := h.signs("p1")["inscricao-salao"]; !there {
		t.Fatal("the entrance opens the next inscription")
	}
	read(h, "inscricao-salao")
	if linked(h) {
		t.Fatal("without the nameless grave, the phrase is only an epitaph")
	}

	h2 := load(t, "valdoria")
	h2.join("p1")
	h2.s.Facts["p1|anvil-mark|p1|ruinas"] = core.Fact{Holder: "p1", P: "anvil-mark", S: "p1", O: "ruinas"}
	h2.s.Facts["p1|nameless-grave|p1|vila"] = core.Fact{Holder: "p1", P: "nameless-grave", S: "p1", O: "vila"}
	h2.move("p1", "ruinas")
	read(h2, "inscricao-entrada")
	if !linked(h2) {
		t.Fatal("with the anvil mark, the entrance symbols are the same as Brom's")
	}
}

// The torch is also a tool: burning the bramble in the forest uncovers an old
// slab, which repeats the symbols of Asterion and, for someone who carries
// Brom's anvil mark, ties the trail together.
func TestTorchBurnsTheBrambleAndUncoversTheSlab(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	if err := h.act("adapter", "p1", "queimar-sarca", nil); err == nil {
		t.Fatal("it takes a lit torch to burn the bramble")
	}
	h.mustAct("adapter", "p1", "acender-tocha", nil)
	if _, there := h.signs("p1")["laje-do-musgo"]; there {
		t.Fatal("the slab is hidden behind the thorns")
	}
	h.mustAct("adapter", "p1", "queimar-sarca", nil)
	if err := h.act("adapter", "p1", "queimar-sarca", nil); err == nil {
		t.Fatal("the bramble burns once")
	}
	if _, there := h.signs("p1")["laje-do-musgo"]; !there {
		t.Fatal("the slab shows among the ashes")
	}
	h.s.Facts["p1|anvil-mark|p1|ruinas"] = core.Fact{Holder: "p1", P: "anvil-mark", S: "p1", O: "ruinas"}
	h.mustAct("player", "p1", "examinar", map[string]core.ID{"sign": "laje-do-musgo"})
	for _, f := range []string{"p1|rune-forge|p1|ruinas", "p1|legacy-link|p1|ruinas"} {
		if _, ok := h.s.Facts[f]; !ok {
			t.Fatalf("missing clue %s", f)
		}
	}
}

// Putting the clues together is a way into the Forgotten Anvil, besides
// forging or exploring the ruins.
func TestLegacyLinkOpensTheForgottenAnvil(t *testing.T) {
	offered := func(link bool) bool {
		h := load(t, "valdoria")
		h.join("p1")
		h.introduce("p1")
		if h.s.Beliefs["p1"] == nil {
			h.s.Beliefs["p1"] = map[string]core.Belief{}
		}
		h.s.Beliefs["p1"]["|legacy-hint|ruinas|"] = core.Belief{P: "legacy-hint", S: "ruinas", Holds: true, Source: "communication", From: "brom"}
		if link {
			h.s.Facts["p1|legacy-link|p1|ruinas"] = core.Fact{Holder: "p1", P: "legacy-link", S: "p1", O: "ruinas"}
		}
		h.s.Facts["|legacy-hint|ruinas|"] = core.Fact{P: "legacy-hint", S: "ruinas"}
		for i := 0; i < 40; i++ {
			for _, q := range h.s.Quests {
				if q.Holder == "p1" && q.Def == "cenario-bigorna" {
					return true
				}
			}
			if d, ok := h.offerDecision("p1"); ok {
				for _, o := range d.Options {
					if strings.HasPrefix(o.ID, "cenario-bigorna|") {
						h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: o.ID, Provider: "test"})
					}
				}
			}
			h.tick(1)
		}
		return false
	}
	if offered(false) {
		t.Fatal("without the link or forging, the anvil is not offered")
	}
	if !offered(true) {
		t.Fatal("with the link the anvil scenario is offered")
	}
}
