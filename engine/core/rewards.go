package core

import (
	"hash/fnv"
	"slices"
	"strconv"
)

// RewardInfo describes actual configured effects independently of their UI.
type RewardInfo struct {
	Kind        string `json:"kind"`
	ID          string `json:"id,omitempty"`
	Name        string `json:"name"`
	Desc        string `json:"desc,omitempty"`
	Rarity      string `json:"rarity,omitempty"`
	Amount      int64  `json:"amount,omitempty"`
	Owned       bool   `json:"owned,omitempty"`
	Conditional bool   `json:"conditional,omitempty"`
}

func (w *World) rewardInfo(s *State, p ID, effects []Effect) []RewardInfo {
	out := []RewardInfo{}
	for _, e := range effects {
		r := RewardInfo{Conditional: e.If != nil}
		switch e.Op {
		case "acquire-gene":
			r = w.geneReward(s, p, e.V)
			r.Conditional = e.If != nil
		case "grant":
			k, ok := w.skill(e.V)
			if !ok {
				continue
			}
			r.Kind, r.ID, r.Name, r.Desc, r.Rarity = "skill", k.ID, k.Name, k.Desc, k.Rarity
			_, r.Owned = s.Skills[p][k.ID]
		case "adjust":
			if e.E != "$self" && e.E != "" {
				continue
			}
			r.Kind, r.ID, r.Name, r.Amount = "number", e.K, e.K, e.D
			r.Desc = e.Text
		default:
			continue
		}
		out = append(out, r)
	}
	return out
}

func (w *World) geneReward(s *State, p ID, id string) RewardInfo {
	m, _ := w.mutation(id)
	g := s.Genomes[p]
	return RewardInfo{Kind: "gene", ID: id, Name: m.Name, Desc: m.Desc, Rarity: m.Rarity, Owned: slices.Contains(g.Genes, id) || slices.Contains(g.Library, id)}
}

// Separate pools let authors reserve a specialty slot and fill the rest with general rewards.
type RewardPool struct {
	Genes []string `json:"genes"`
	Take  int      `json:"take"`
}
type ExpeditionPreview struct {
	Token      string       `json:"token"`
	Choices    []RewardInfo `json:"choices"`
	Guaranteed []RewardInfo `json:"guaranteed"`
	First      []RewardInfo `json:"first,omitempty"`
}

func rewardHash(value string) uint64 { h := fnv.New64a(); h.Write([]byte(value)); return h.Sum64() }

// Only victory advances this cycle. Waiting, leaving and reconnecting cannot reroll prizes.
func (w *World) rewardDraft(s *State, p ID, d DungeonDef) (int64, []string) {
	cycle := s.Receipts["loot-cycle|"+string(p)+"|"+d.ID]
	key := string(p) + "|" + d.ID + "|" + strconv.FormatInt(cycle, 10)
	seed := int64(rewardHash(key) >> 1)
	out := []string{}
	for group, pool := range d.RewardPools {
		candidates := []string{}
		for _, id := range pool.Genes {
			m, _ := w.mutation(id)
			if slices.Contains(out, id) || w.geneReward(s, p, id).Owned || (m.Eligible != nil && !w.Holds(s, *m.Eligible, Bind{"self": p})) {
				continue
			}
			candidates = append(candidates, id)
		}
		salt := key + "|" + strconv.Itoa(group) + "|"
		slices.SortFunc(candidates, func(a, b string) int {
			ha, hb := rewardHash(salt+a), rewardHash(salt+b)
			if ha < hb {
				return -1
			}
			if ha > hb {
				return 1
			}
			if a < b {
				return -1
			}
			if a > b {
				return 1
			}
			return 0
		})
		for _, id := range candidates[:min(pool.Take, len(candidates))] {
			if len(out) >= 3 {
				break
			}
			out = append(out, id)
		}
	}
	return seed, out
}
func expeditionToken(seed int64, genes []string) string {
	key := strconv.FormatInt(seed, 10)
	for _, id := range genes {
		key += "|" + id
	}
	return strconv.FormatUint(rewardHash(key), 16)
}
func (w *World) expeditionPreview(s *State, p ID, d DungeonDef, seed int64, genes []string) ExpeditionPreview {
	v := ExpeditionPreview{Token: expeditionToken(seed, genes), Choices: []RewardInfo{}, Guaranteed: w.rewardInfo(s, p, d.Rewards)}
	for _, id := range genes {
		v.Choices = append(v.Choices, w.geneReward(s, p, id))
	}
	if s.Receipts["dungeon-first|"+d.ID] == 0 {
		v.First = w.rewardInfo(s, p, d.FirstClear)
	}
	return v
}
func (w *World) startDungeon(s *State, origin string, p ID, args map[string]ID, cause string) error {
	run, ok := s.Delves[p]
	if origin != "player" || !ok || run.State != "ready" {
		return reject("dungeon not ready")
	}
	if token := string(args["preview"]); token != "" && token != expeditionToken(run.Seed, run.RewardGenes) {
		return reject("expedition changed")
	}
	run.State = "active"
	s.Delves[p] = run
	w.emit(s, Event{Kind: "dungeon-started", Holder: p, Text: run.Dungeon, Cause: cause})
	return nil
}
func (w *World) claimDungeon(s *State, origin string, p ID, args map[string]ID, cause string) error {
	run, ok := s.Delves[p]
	id := string(args["gene"])
	if origin == "player" && ok && run.State == "cleared" && run.RewardClaimed == "" && id == "none" && len(run.RewardGenes) > 0 && slices.ContainsFunc(run.RewardGenes, func(g string) bool { return !w.geneReward(s, p, g).Owned }) == false {
		run.RewardClaimed = "owned"
		s.Delves[p] = run
		return nil
	}
	if origin != "player" || !ok || run.State != "cleared" || run.RewardClaimed != "" || !slices.Contains(run.RewardGenes, id) {
		return reject("reward unavailable")
	}
	if w.geneReward(s, p, id).Owned {
		return reject("gene already owned; choose another reward")
	}
	w.acquireGene(s, p, id, cause)
	run.RewardClaimed = id
	s.Delves[p] = run
	w.emit(s, Event{Kind: "dungeon-reward-claimed", Holder: p, Text: id, Cause: cause, Data: map[string]string{"gene": id}})
	return nil
}
