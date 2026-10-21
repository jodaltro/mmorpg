package scenarios

import (
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func (h *harness) has(p core.ID, skill string) bool {
	_, ok := h.s.Skills[p][skill]
	return ok
}

func (h *harness) atHour(from, to int64) {
	for i := 0; i < 200; i++ {
		x := h.w.Hour(&h.s)
		if from <= to && x >= from && x < to || from > to && (x >= from || x < to) {
			return
		}
		h.tick(1)
	}
}

// Habits teach skills, and skills change what deeds do.
func TestHabitTeachesSkillThatChangesDeeds(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "mina")
	for i := 0; i < 5; i++ {
		h.mustAct("adapter", "p1", "minerar", nil)
	}
	h.move("p1", "vila")
	for i := 0; i < 3; i++ {
		h.mustAct("player", "p1", "forjar", nil)
	}
	if !h.has("p1", "martelo-firme") {
		t.Fatal("forging three times teaches Martelo Firme")
	}
	ev := h.events2("skill-learned", "p1")
	if len(ev) == 0 || ev[len(ev)-1].Data["rarity"] != "comum" {
		t.Fatalf("the system window announces the skill and rarity: %+v", ev)
	}
	before := h.s.Entities["p1"].Num["forge"]
	h.mustAct("player", "p1", "forjar", nil)
	if h.s.Entities["p1"].Num["forge"] != before+2 {
		t.Fatal("with Martelo Firme each forging counts double")
	}
}

// An absurd skill (sleeping anywhere) opens a hidden quest that feeds the
// main story: the dream gives the clue that unlocks the unique scenario.
func TestSillySkillLeadsIntoTheMainStory(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	for i := 0; i < 5; i++ {
		h.atHour(20, 4)
		h.mustAct("player", "p1", "descansar", nil)
		h.tick(30)
	}
	if !h.has("p1", "cochilo-estrategico") {
		t.Fatal("five naps teach Cochilo Estrategico")
	}
	h.accept("p1", h.steer("p1", "sonho-do-selo"))
	h.atHour(20, 4)
	h.mustAct("player", "p1", "sonhar", nil)
	if !h.fact("p1", "noticed", "p1", "poco") {
		t.Fatal("the dream counts as noticing the corruption")
	}
	if q := h.steer("p1", "cenario-origem"); q.Rank != "S" {
		t.Fatal("the dreamer is offered the unique scenario")
	}
}

// Frieren-style useless spells: found by luck, fused into something useful,
// and a rare one becomes public fame.
func TestUselessSpellsFuseAndBecomeFamous(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.move("p1", "floresta")
	for i := 0; i < 400 && !h.has("p1", "florescer"); i++ {
		h.s.Entities["p1"].Num["herbs"] = 0
		h.mustAct("adapter", "p1", "colher-ervas-campo", nil)
		h.tick(1)
	}
	if !h.has("p1", "florescer") {
		t.Fatal("Florescer is eventually found while gathering herbs")
	}
	h.s.Skills["p1"]["cha-morno"] = h.s.Tick // as if found in the ruins
	h.move("p1", "estrada")
	h.mustAct("player", "p1", "servir-cha", nil)
	if !h.has("p1", "cha-de-flores") {
		t.Fatal("two useless spells plus serving tea fuse into Cha de Flores")
	}
	if !h.has("p1", "cha-de-flores") || len(h.events("fame")) == 0 {
		t.Fatal("a rare skill becomes public fame")
	}
	if b, ok := h.s.Beliefs["p1"]["|legacy-hint|ruinas|"]; !ok || b.Holds {
		t.Fatal("Tomas stories make the player look into the legacy rumor")
	}
}

// Skills open alternative solutions to existing quests.
func TestSkillsOpenAlternativePaths(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.s.Facts["|ore-cursed|mina|"] = core.Fact{P: "ore-cursed", S: "mina"}
	h.s.Entities["p1"].Num["ore"] = 1
	h.move("p1", "mina")
	if err := h.act("player", "p1", "purificar-minerio", nil); !isRejected(err) {
		t.Fatal("without Elena or the spell the ore cannot be purified")
	}
	h.s.Skills["p1"] = map[string]core.Tick{"remover-ferrugem": 1}
	h.mustAct("player", "p1", "purificar-minerio", nil)
	h.happen("bandidos")
	h.move("p1", "estrada")
	if err := h.act("adapter", "p1", "recuperar-mercadorias", nil); !isRejected(err) {
		t.Fatal("without fighting or Passo Leve the goods stay with the bandits")
	}
	h.s.Skills["p1"]["passo-leve"] = 1
	h.mustAct("adapter", "p1", "recuperar-mercadorias", nil)
}

// Lebrinos: a hidden people whose techniques exist nowhere else; an epic
// technique earns respect where it was learned; only one becomes Guardian.
func TestLebrinosTeachTheirOwnTechniques(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	for _, p := range []core.ID{"p1", "p2"} {
		h.s.Facts[string(p)+"|found-den|"+string(p)+"|toca"] = core.Fact{Holder: p, P: "found-den", S: p, O: "toca"}
		h.s.Entities[p].Num["herbs"] = 1
		h.accept(p, h.steer(p, "lebrinos-gentileza"))
		h.move(p, "toca")
		h.mustAct("player", p, "presentear-pipo", nil)
		if !h.has(p, "passo-leve") {
			t.Fatalf("Pipo teaches Passo Leve to %s", p)
		}
		h.accept(p, h.steer(p, "lebrinos-lamina"))
		for i := 0; i < 5; i++ {
			h.mustAct("player", p, "treinar-sora", nil)
		}
		if !h.has(p, "corte-lunar") {
			t.Fatalf("Sora teaches Corte Lunar to %s", p)
		}
	}
	if h.s.Relations["pipo|p1"] < 4 {
		t.Fatal("an epic technique earns respect from the people around")
	}
	h.tick(1)
	if h.s.Arcs["lua"].Beats["guardiao"].State != "open" {
		t.Fatal("the guardian scenario opens once the lebrinos wake up")
	}
	h.s.Facts["p2|white-boar-slain|p2|floresta"] = core.Fact{Holder: "p2", P: "white-boar-slain", S: "p2", O: "floresta"}
	h.mustAct("player", "p2", "treinar-sora", nil)
	if !h.has("p2", "salto-lunar") || h.s.Entities["p2"].Tag["title"] != "Guardiao da Toca" {
		t.Fatal("the first worthy player becomes Guardian with a legendary technique")
	}
	if !h.has("p1", "amigo-dos-lebrinos") || h.has("p1", "salto-lunar") {
		t.Fatal("the other gets their own rare continuation, never the legendary one")
	}
	ctx := ""
	for _, d := range h.s.Decisions {
		if d.Subject == "p1" {
			ctx = strings.Join(d.Context, " ")
		}
	}
	if ctx != "" && !strings.Contains(ctx, "Corte Lunar") {
		t.Fatalf("Jev sees the skills: %s", ctx)
	}
}

// A rare skill must come from a habit, not from waiting: gossip reaches every
// player, so Ouvido de Taverna also needs nights spent resting in the village.
func TestTavernEarNeedsNightsInTheVillage(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	h.tick(600)
	if n := h.s.Deeds["p1"]["rumor"]; n < 20 {
		t.Fatalf("gossip should reach an idle player: %d rumors", n)
	}
	if h.has("p1", "ouvido-de-taverna") {
		t.Fatal("hearing rumors alone must not teach a rare skill")
	}
	for i := 0; i < 2; i++ {
		h.atHour(20, 4)
		h.mustAct("player", "p1", "descansar", nil)
		h.tick(30)
	}
	if !h.has("p1", "ouvido-de-taverna") {
		t.Fatal("rumors plus two nights resting in the village teach Ouvido de Taverna")
	}
}
