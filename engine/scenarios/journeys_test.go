package scenarios

import (
	"slices"
	"sort"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// persona plays one style of player, like tools/unreal/scenarios.ps1 does
// through the Unreal client, but with the deterministic advisor only.
type persona struct {
	id     core.ID
	style  string   // dominant play style the world must learn ("" = none)
	likes  []string // accepts offers with one of these tags...
	avoids []string // ...unless they also have one of these
	play   func(h *harness, p core.ID, round int)
}

// goTo reports a move only when the player is elsewhere.
func (h *harness) goTo(p, region core.ID) {
	h.t.Helper()
	if h.s.Entities[p].Region != region {
		h.move(p, region)
	}
}

// tryAct attempts a deed; rejections are part of playing.
func (h *harness) tryAct(origin string, p core.ID, action string, args map[string]core.ID) {
	if err := h.act(origin, p, action, args); err != nil && !isRejected(err) {
		h.t.Fatalf("%s by %s: %v", action, p, err)
	}
}

func journeyPersonas() []persona {
	return []persona{
		{id: "bruno", style: "combat", likes: []string{"combat"}, play: func(h *harness, p core.ID, r int) {
			switch r % 6 {
			case 4:
				h.goTo(p, "vila")
				h.tryAct("adapter", p, "cacar-lobos", nil)
				h.tryAct("adapter", p, "defender-vila", nil)
			case 5:
				h.goTo(p, "estrada")
				h.tryAct("adapter", p, "enfrentar-bandidos", nil)
				h.tryAct("adapter", p, "escoltar-caravana", nil)
			default:
				h.goTo(p, "floresta")
				h.tryAct("adapter", p, "cacar-javali", nil)
				h.tryAct("adapter", p, "cacar-javali-branco", nil)
			}
		}},
		{id: "clara", style: "help", likes: []string{"help", "mystery"}, avoids: []string{"combat"}, play: func(h *harness, p core.ID, r int) {
			h.goTo(p, "vila")
			if _, known := h.believes(p, "poisoned", "poco"); !known || r%10 == 0 {
				h.tryAct("player", p, "examinar-poco", nil)
			}
			for _, npc := range []core.ID{"mira", "elena", "orin", "brom", "nino"} {
				h.tryAct("player", p, "contar-veneno", map[string]core.ID{"npc": npc})
			}
			h.tryAct("player", p, "purificar-poco", nil)
			h.tryAct("player", p, "acalmar-doentes", nil)
			h.tryAct("player", p, "diagnosticar", nil)
			h.tryAct("player", p, "consertar-telhado", nil)
		}},
		{id: "davi", play: func(h *harness, p core.ID, r int) {}},
		{id: "elisa", style: "explore", likes: []string{"explore"}, avoids: []string{"combat"}, play: func(h *harness, p core.ID, r int) {
			switch r % 4 {
			case 0:
				h.goTo(p, "mina")
				h.tryAct("adapter", p, "minerar", nil)
			case 1:
				h.goTo(p, "ruinas")
				h.tryAct("adapter", p, "explorar-ruinas", nil)
			default:
				h.goTo(p, "floresta")
				h.tryAct("adapter", p, "colher-ervas-campo", nil)
				h.tryAct("adapter", p, "achar-crianca", nil)
				h.tryAct("adapter", p, "seguir-rastro", nil)
			}
		}},
		{id: "fabio", style: "craft", likes: []string{"craft"}, avoids: []string{"combat"}, play: func(h *harness, p core.ID, r int) {
			if r%3 == 0 {
				h.goTo(p, "mina")
				h.tryAct("adapter", p, "minerar", nil)
				h.tryAct("adapter", p, "minerar", nil)
				return
			}
			h.goTo(p, "vila")
			h.tryAct("player", p, "forjar", nil)
			h.tryAct("player", p, "contribuir-obra", nil)
			h.tryAct("player", p, "purificar-minerio", nil)
			h.tryAct("player", p, "consertar-telhado", nil)
		}},
	}
}

func dominant(m map[string]int64) string {
	best, hi := "", int64(0)
	for _, k := range sortedTags(m) {
		if m[k] > hi {
			best, hi = k, m[k]
		}
	}
	return best
}

func sortedTags(m map[string]int64) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func jaccard(a, b map[string]bool) float64 {
	inter, union := 0, len(b)
	for k := range a {
		if b[k] {
			inter++
		} else {
			union++
		}
	}
	if union == 0 {
		return 1
	}
	return float64(inter) / float64(union)
}

// Different play styles must lead to different journeys in Valdoria:
// the world learns each style, offers different quests, rare skills are
// not handed to everyone, and refusing everything is itself a path.
func TestPlayStylesMakeDifferentJourneys(t *testing.T) {
	const rounds = 300
	personas := journeyPersonas()
	quests := map[core.ID]map[string]bool{}
	worlds := map[core.ID]*harness{}
	for _, ps := range personas {
		h := load(t, "valdoria")
		h.join(ps.id)
		seen := map[string]bool{}
		for r := 0; r < rounds; r++ {
			for _, k := range sortedQuestKeys(h.s.Quests) {
				q := h.s.Quests[k]
				if q.Holder != ps.id {
					continue
				}
				seen[q.Def] = true
				if q.State != "offered" {
					continue
				}
				kind := "decline"
				for _, t := range h.w.U.Quests[questIndex(h, q.Def)].Tags {
					if slices.Contains(ps.avoids, t) {
						kind = "decline"
						break
					}
					if slices.Contains(ps.likes, t) {
						kind = "accept"
					}
				}
				if _, err := h.try(core.Command{Kind: kind, Origin: "player", Actor: ps.id, Quest: q.Key}); err != nil && !isRejected(err) {
					t.Fatalf("%s %s: %v", kind, q.Def, err)
				}
			}
			ps.play(h, ps.id, r)
			h.tick(1)
		}
		quests[ps.id], worlds[ps.id] = seen, h
		t.Logf("%s: styles=%v deeds=%v quests=%v skills=%v", ps.id, h.s.Styles[ps.id], h.s.Deeds[ps.id], setKeys(seen), skillIDs(h, ps.id))
	}

	for _, ps := range personas {
		h := worlds[ps.id]
		if ps.style != "" {
			if got := dominant(h.s.Styles[ps.id]); got != ps.style {
				t.Errorf("%s plays %s but the world learned %s: %v", ps.id, ps.style, got, h.s.Styles[ps.id])
			}
		}
		if len(quests[ps.id]) == 0 {
			t.Errorf("%s was never offered a quest", ps.id)
		}
	}
	for i, a := range personas {
		for _, b := range personas[i+1:] {
			if j := jaccard(quests[a.id], quests[b.id]); j >= 0.6 {
				t.Errorf("%s and %s saw nearly the same quests (Jaccard %.2f): %v / %v", a.id, b.id, j, setKeys(quests[a.id]), setKeys(quests[b.id]))
			}
		}
	}
	for _, k := range worlds[personas[0].id].w.U.Skills {
		if k.Rarity == "comum" || k.Rarity == "incomum" {
			continue
		}
		all := true
		for _, ps := range personas {
			all = all && worlds[ps.id].has(ps.id, k.ID)
		}
		if all {
			t.Errorf("every persona learned the %s skill %s", k.Rarity, k.ID)
		}
	}
	if !worlds["davi"].has("davi", "teimosia-lendaria") {
		t.Error("refusing everything earns Teimosia Lendaria")
	}
	for _, ps := range personas {
		if ps.id != "davi" && worlds[ps.id].has(ps.id, "teimosia-lendaria") {
			t.Errorf("%s accepts quests and should not be legendarily stubborn", ps.id)
		}
	}
}

func questIndex(h *harness, def string) int {
	for i, q := range h.w.U.Quests {
		if q.ID == def {
			return i
		}
	}
	h.t.Fatalf("unknown quest %s", def)
	return -1
}

func sortedQuestKeys(m map[string]core.Quest) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func setKeys(m map[string]bool) string {
	keys := []string{}
	for k := range m {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	return strings.Join(keys, ",")
}

func skillIDs(h *harness, p core.ID) string {
	keys := []string{}
	for k := range h.s.Skills[p] {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	return strings.Join(keys, ",")
}
