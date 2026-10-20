package core

import "slices"

var rarities = []string{"comum", "incomum", "rara", "epica", "lendaria", "absurda"}

// builtinDeeds are counted by the engine itself, besides every action id.
var builtinDeeds = []string{"move", "rumor", "decline", "quest"}

func (w *World) skill(id string) (SkillDef, bool) {
	i := slices.IndexFunc(w.U.Skills, func(k SkillDef) bool { return k.ID == id })
	if i < 0 {
		return SkillDef{}, false
	}
	return w.U.Skills[i], true
}

// count records that p did something (players only).
func (w *World) count(s *State, p ID, deed string) {
	if s.Entities[p].Kind != w.U.PlayerKind {
		return
	}
	if s.Deeds[p] == nil {
		s.Deeds[p] = map[string]int64{}
	}
	s.Deeds[p][deed]++
}

// grantSkill teaches a skill once and announces it like a system window.
func (w *World) grantSkill(s *State, p ID, id, how, cause string) {
	k, ok := w.skill(id)
	if !ok || s.Entities[p].Kind != w.U.PlayerKind {
		return
	}
	if _, has := s.Skills[p][id]; has {
		return
	}
	if s.Skills[p] == nil {
		s.Skills[p] = map[string]Tick{}
	}
	s.Skills[p][id] = s.Tick
	w.emit(s, Event{Kind: "skill-learned", Holder: p, Text: k.Name, Cause: cause,
		Data: map[string]string{"skill": id, "rarity": k.Rarity, "desc": k.Desc, "how": how}})
	w.fame(s, p, k, cause)
}

// fame: rare skills become part of the public chronicle (and of what Jev
// reads); epic and legendary ones also earn respect from the people who
// share the place where it happened.
func (w *World) fame(s *State, p ID, k SkillDef, cause string) {
	rank := slices.Index(rarities, k.Rarity)
	if rank < slices.Index(rarities, "rara") {
		return
	}
	text := "Dizem que " + s.Entities[p].Name + " aprendeu " + k.Name + "."
	if k.Rarity == "absurda" {
		text = "Corre um boato engracado: " + s.Entities[p].Name + " aprendeu " + k.Name + "."
	}
	w.emit(s, Event{Kind: "fame", Actor: p, Public: true, Text: text,
		Cause: cause, Data: map[string]string{"skill": k.ID, "rarity": k.Rarity}})
	if k.Rarity != "epica" && k.Rarity != "lendaria" {
		return
	}
	region := s.Entities[p].Region
	for _, id := range sortedIDs(s.Entities) {
		e := s.Entities[id]
		if id != p && region != "" && e.Region == region && e.Kind != w.U.PlayerKind && w.perceives[e.Kind] {
			s.Relations[relKey(id, p)] = min(s.Relations[relKey(id, p)]+1, 10)
		}
	}
}

// discover checks every skill p does not know yet: doing the right things,
// in the right place, at the right time, with some luck, teaches it.
func (w *World) discover(s *State, p ID, cause string) {
	if s.Entities[p].Kind != w.U.PlayerKind {
		return
	}
	for _, k := range w.U.Skills {
		if k.Learn == nil {
			continue
		}
		if _, has := s.Skills[p][k.ID]; has {
			continue
		}
		if w.Holds(s, *k.Learn, Bind{"self": p}) {
			w.grantSkill(s, p, k.ID, "discovered", cause)
		}
	}
}

// SkillView is a learned skill as the player sees it.
type SkillView struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Desc   string `json:"desc"`
	Rarity string `json:"rarity"`
	At     Tick   `json:"at"`
}

func (w *World) skillsOf(s *State, p ID) []SkillView {
	out := []SkillView{}
	for _, id := range sortedKeys(s.Skills[p]) {
		if k, ok := w.skill(id); ok {
			out = append(out, SkillView{ID: id, Name: k.Name, Desc: k.Desc, Rarity: k.Rarity, At: s.Skills[p][id]})
		}
	}
	return out
}
