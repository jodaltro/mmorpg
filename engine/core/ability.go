package core

import (
	"slices"
	"strconv"
	"strings"
)

// Class abilities: skills that belong to a lineage. A cell is born into its
// class with its starter ability; the rest are acquired by living, in three
// ways: quests that grant one, deeds that discover one (the skill's learn
// condition), and the body itself, where the advisor (Jev) decides which of the
// class abilities awakens next from how the player has been playing. The engine
// only decides who knows what; clients draw and run the abilities.

// AbilitiesDef paces the advisor-decided awakenings.
type AbilitiesDef struct {
	Every    Tick  `json:"every"`    // ticks between awakenings
	MinDeeds int64 `json:"minDeeds"` // new deeds needed since the last one
}

func (w *World) compileAbilities() error {
	a := w.U.Abilities
	for _, k := range w.U.Skills {
		if k.Class == "" {
			if k.Starter || k.Offer {
				return invalid("skill %s: starter/offer need a class", k.ID)
			}
			continue
		}
		if _, ok := w.lineageDef(k.Class); !ok {
			return invalid("skill %s: unknown class %q", k.ID, k.Class)
		}
	}
	if a == nil {
		return nil
	}
	if a.Every < 1 || a.MinDeeds < 0 || w.U.Differentiation == nil {
		return invalid("abilities")
	}
	return nil
}

// grantStarters teaches the starter abilities of a lineage the player just became.
func (w *World) grantStarters(s *State, p ID, lineage, cause string) {
	for _, k := range w.U.Skills {
		if k.Starter && k.Class == lineage {
			w.grantSkill(s, p, k.ID, "starter", cause)
		}
	}
}

// abilityCandidates are the class abilities the body may still awaken.
func (w *World) abilityCandidates(s *State, p ID) []SkillDef {
	cur, _ := w.lineageOf(s, p)
	out := []SkillDef{}
	if cur == "" {
		return out
	}
	for _, k := range w.U.Skills {
		if _, has := s.Skills[p][k.ID]; !has && k.Offer && k.Class == cur {
			out = append(out, k)
		}
	}
	return out
}

func (w *World) abilityFit(s *State, p ID, k SkillDef) int64 {
	score := int64(0)
	for _, t := range k.Tags {
		score += min(s.Styles[p][t], 10)
	}
	return score
}

func (w *World) abilityTick(s *State, cause string) {
	a := w.U.Abilities
	if a == nil || s.Tick%a.Every != 0 {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind != w.U.PlayerKind {
			continue
		}
		key := "ability|" + string(p)
		total := w.totalDeeds(s, p)
		if total-s.Receipts[key] < a.MinDeeds {
			continue
		}
		if slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == "ability" && s.Decisions[k].Subject == string(p)
		}) {
			continue
		}
		cands := w.abilityCandidates(s, p)
		if len(cands) == 0 {
			continue
		}
		best := cands[0]
		for _, c := range cands {
			if w.abilityFit(s, p, c) > w.abilityFit(s, p, best) {
				best = c
			}
		}
		if len(cands) == 1 {
			s.Receipts[key] = total
			w.grantSkill(s, p, best.ID, "awakened", cause)
			continue
		}
		opts := make([]Option, 0, len(cands))
		for _, c := range cands {
			desc := c.Desc + " (" + c.Rarity + ")"
			if len(c.Tags) > 0 {
				desc += " [path: " + strings.Join(c.Tags, ", ") + "]"
			}
			opts = append(opts, Option{ID: c.ID, Title: c.Name, Desc: desc})
		}
		id := "ability:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
		ctx := w.profile(s, p)
		ctx = append(ctx, w.genomeText(s, p))
		if w.U.Appearance != nil {
			ctx = append(ctx, w.behaviourText(s, p))
		}
		s.Decisions[id] = Decision{ID: id, Kind: "ability", Subject: string(p), Options: opts, Default: best.ID,
			Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
	}
}

// decideAbility awakens the advisor's pick after revalidating it.
func (w *World) decideAbility(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	if w.U.Abilities == nil || !slices.ContainsFunc(w.abilityCandidates(s, p), func(k SkillDef) bool { return k.ID == choice }) {
		return reject("choice no longer valid")
	}
	delete(s.Decisions, d.ID)
	s.Receipts["ability|"+string(p)] = w.totalDeeds(s, p)
	w.grantSkill(s, p, choice, "awakened", cause)
	return nil
}
