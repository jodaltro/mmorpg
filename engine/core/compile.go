package core

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
)

// World is a validated, indexed universe. It is immutable after Compile.
type World struct {
	U         Universe
	actions   map[string]ActionDef
	rules     map[string]RuleDef
	agents    map[ID]AgentDef
	arcs      map[string]ArcDef
	beats     map[string]map[string]BeatDef
	quests    map[string]QuestDef
	kinds     map[string]bool
	preds     map[string]bool
	perceives map[string]bool
	regions   map[string]bool
}

var ErrUniverse = errors.New("invalid_universe")

func invalid(format string, a ...any) error {
	return fmt.Errorf("%w: %s", ErrUniverse, fmt.Sprintf(format, a...))
}

// Compile validates a universe. Everything a world may do is checked here,
// so a running world never meets an unknown rule, predicate or entity.
func Compile(u Universe) (*World, error) {
	w := &World{U: u, actions: map[string]ActionDef{}, rules: map[string]RuleDef{}, agents: map[ID]AgentDef{},
		arcs: map[string]ArcDef{}, beats: map[string]map[string]BeatDef{}, quests: map[string]QuestDef{},
		kinds: map[string]bool{}, preds: map[string]bool{}, perceives: map[string]bool{}, regions: map[string]bool{}}
	if u.Version != 1 {
		return nil, invalid("unsupported version %d", u.Version)
	}
	if u.ID == "" {
		return nil, invalid("missing id")
	}
	for _, k := range u.Kinds {
		if k == "" || w.kinds[k] {
			return nil, invalid("duplicate/empty kind %q", k)
		}
		w.kinds[k] = true
	}
	for _, p := range u.Predicates {
		if p == "" || w.preds[p] {
			return nil, invalid("duplicate/empty predicate %q", p)
		}
		w.preds[p] = true
	}
	if u.Acquaintance != "" && !w.preds[u.Acquaintance] {
		return nil, invalid("acquaintance predicate %q is not declared", u.Acquaintance)
	}
	if u.TickSeconds < 0 {
		return nil, invalid("tickSeconds must not be negative")
	}
	if !w.kinds[u.PlayerKind] || u.Player.Kind != u.PlayerKind {
		return nil, invalid("player kind %q", u.PlayerKind)
	}
	for _, k := range u.Perceivers {
		if !w.kinds[k] {
			return nil, invalid("unknown perceiver kind %q", k)
		}
		w.perceives[k] = true
	}
	for _, k := range u.RegionKinds {
		if !w.kinds[k] || k == u.PlayerKind {
			return nil, invalid("region kind %q", k)
		}
		w.regions[k] = true
	}
	seenSkill := map[string]bool{}
	for _, k := range u.Skills {
		if k.ID == "" || seenSkill[k.ID] || k.Name == "" || !slices.Contains(rarities, k.Rarity) {
			return nil, invalid("skill %q", k.ID)
		}
		seenSkill[k.ID] = true
	}
	ents := map[ID]string{}
	for _, e := range u.Entities {
		if e.ID == "" || ents[e.ID] != "" || strings.HasPrefix(string(e.ID), "$") {
			return nil, invalid("duplicate/empty entity %q", e.ID)
		}
		if !w.kinds[e.Kind] {
			return nil, invalid("entity %s has unknown kind %q", e.ID, e.Kind)
		}
		ents[e.ID] = e.Kind
	}
	for _, e := range append([]EntitySeed{u.Player}, u.Entities...) {
		if e.Region != "" && !w.regions[ents[e.Region]] {
			return nil, invalid("entity %s: region %q is not a place", e.ID, e.Region)
		}
	}
	if len(w.regions) > 0 && u.Player.Region == "" {
		return nil, invalid("player needs a starting region")
	}
	l := u.Limits
	if u.DayLength < 0 {
		return nil, invalid("dayLength")
	}
	if l.QuestGap < 0 {
		return nil, invalid("limits")
	}
	if l.MaxActiveQuests < 1 || l.DecisionTimeout < 1 || l.DeclineCooldown < 0 || l.OfferExpiry < 1 || l.MaxEvents < 16 {
		return nil, invalid("limits")
	}
	v := &validator{w: w, ents: ents}
	for _, f := range u.Facts {
		if !w.preds[f.P] || ents[f.S] == "" || f.O != "" && ents[f.O] == "" || f.Holder != "" && ents[f.Holder] == "" {
			return nil, invalid("initial fact %s %s", f.P, f.S)
		}
	}
	for _, b := range u.Beliefs {
		if !w.preds[b.P] || ents[b.Who] == "" || ents[b.S] == "" || b.O != "" && ents[b.O] == "" {
			return nil, invalid("initial belief %s %s", b.P, b.Who)
		}
	}
	for _, a := range u.Actions {
		if a.ID == "" || w.actions[a.ID].ID != "" || len(a.By) == 0 {
			return nil, invalid("action %q", a.ID)
		}
		for _, by := range a.By {
			if !slices.Contains([]string{"player", "agent", "adapter"}, by) {
				return nil, invalid("action %s: origin %q", a.ID, by)
			}
		}
		w.actions[a.ID] = a
	}
	for _, r := range u.Rules {
		if r.ID == "" || w.rules[r.ID].ID != "" || r.Every < 0 || r.ForEach != "" && !w.kinds[r.ForEach] {
			return nil, invalid("rule %q", r.ID)
		}
		w.rules[r.ID] = r
	}
	for _, sc := range u.Schedules {
		if w.rules[sc.Rule].ID == "" || sc.At < 1 {
			return nil, invalid("schedule %s", sc.Rule)
		}
	}
	for _, a := range u.Actions {
		vars := map[string]bool{"self": true}
		for _, p := range a.Params {
			if p.Name == "" || p.Name == "self" || vars[p.Name] || !w.kinds[p.Kind] {
				return nil, invalid("action %s param %q", a.ID, p.Name)
			}
			vars[p.Name] = true
		}
		if e := v.cond(a.Requires, vars, "action "+a.ID); e != nil {
			return nil, e
		}
		if e := v.effects(a.Effects, vars, "action "+a.ID); e != nil {
			return nil, e
		}
	}
	// Scheduled rules inherit the bindings of whoever scheduled them, so the
	// variable set of a rule is every name that can reach it.
	ruleVars := map[string]map[string]bool{}
	for _, r := range u.Rules {
		ruleVars[r.ID] = map[string]bool{"self": true, "it": r.ForEach != ""}
	}
	for _, a := range u.Actions {
		for _, e := range a.Effects {
			if e.Op == "schedule" && ruleVars[e.Rule] != nil {
				for _, p := range a.Params {
					ruleVars[e.Rule][p.Name] = true
				}
			}
		}
	}
	for _, r := range u.Rules {
		if e := v.cond(r.When, ruleVars[r.ID], "rule "+r.ID); e != nil {
			return nil, e
		}
		if e := v.effects(r.Effects, ruleVars[r.ID], "rule "+r.ID); e != nil {
			return nil, e
		}
	}
	if e := w.compileAgents(v); e != nil {
		return nil, e
	}
	if e := w.compileArcs(v); e != nil {
		return nil, e
	}
	if e := w.compileQuests(v); e != nil {
		return nil, e
	}
	if e := w.compileDirector(v); e != nil {
		return nil, e
	}
	for _, k := range u.Skills {
		if k.Learn != nil {
			if e := v.cond(*k.Learn, map[string]bool{"self": true}, "skill "+k.ID); e != nil {
				return nil, e
			}
			// Discovery is re-checked constantly, so luck there would add up
			// until everyone has the skill. Put chance in an action effect.
			if usesChance(*k.Learn) {
				return nil, invalid("skill %s: chance in learn conditions; use an action effect with if+grant", k.ID)
			}
		}
	}
	return w, nil
}

func (w *World) compileDirector(v *validator) error {
	seen := map[string]bool{}
	for _, h := range w.U.Happenings {
		if h.ID == "" || h.ID == "none" || seen[h.ID] || h.Title == "" || h.Cooldown < 0 || len(h.Effects) == 0 {
			return invalid("happening %q", h.ID)
		}
		seen[h.ID] = true
		if e := v.cond(h.When, map[string]bool{}, "happening "+h.ID); e != nil {
			return e
		}
		if e := v.effects(h.Effects, map[string]bool{}, "happening "+h.ID); e != nil {
			return e
		}
	}
	if d := w.U.Director; d != nil && (d.Every < 1 || len(w.U.Happenings) == 0 || d.Decay < 0 || d.Decay > 100 || d.Peak < 0 || d.Calm < 0 || d.Peak > 0 && d.Calm >= d.Peak) {
		return invalid("director")
	}
	if g := w.U.Gossip; g != nil {
		if g.Every < 1 || len(g.Kinds) == 0 || len(g.Predicates) == 0 {
			return invalid("gossip")
		}
		for _, k := range g.Kinds {
			if !w.kinds[k] {
				return invalid("gossip kind %q", k)
			}
		}
		for _, p := range g.Predicates {
			if !w.preds[p] {
				return invalid("gossip predicate %q", p)
			}
		}
		for p := range g.Texts {
			if !w.preds[p] {
				return invalid("gossip text for unknown predicate %q", p)
			}
		}
	}
	if w.U.Director == nil && len(w.U.Happenings) > 0 {
		return invalid("happenings without director")
	}
	return nil
}

func (w *World) compileAgents(v *validator) error {
	for _, a := range w.U.Agents {
		if v.ents[a.Entity] == "" || w.agents[a.Entity].Entity != "" || a.Think < 0 {
			return invalid("agent %q", a.Entity)
		}
		seen := map[string]bool{}
		for _, g := range a.Goals {
			act, ok := w.actions[g.Action]
			if g.ID == "" || seen[g.ID] || !ok || !slices.Contains(act.By, "agent") || g.Cooldown < 0 {
				return invalid("agent %s goal %q", a.Entity, g.ID)
			}
			seen[g.ID] = true
			for _, p := range act.Params {
				if g.Args[p.Name] == "" {
					return invalid("agent %s goal %s: missing arg %s", a.Entity, g.ID, p.Name)
				}
			}
			for name, ref := range g.Args {
				if !slices.ContainsFunc(act.Params, func(p Param) bool { return p.Name == name }) {
					return invalid("agent %s goal %s: unknown arg %s", a.Entity, g.ID, name)
				}
				if e := v.ref(ref, map[string]bool{"self": true}, "goal "+g.ID); e != nil {
					return e
				}
			}
			if e := v.cond(g.When, map[string]bool{"self": true}, "goal "+g.ID); e != nil {
				return e
			}
		}
		w.agents[a.Entity] = a
	}
	return nil
}

// compileArcs checks that every story is a DAG whose beats are all
// reachable from its start: no dead chapters, no infinite loops.
func (w *World) compileArcs(v *validator) error {
	for _, a := range w.U.Arcs {
		if a.ID == "" || w.arcs[a.ID].ID != "" {
			return invalid("arc %q", a.ID)
		}
		beats := map[string]BeatDef{}
		for _, b := range a.Beats {
			if b.ID == "" || beats[b.ID].ID != "" {
				return invalid("arc %s beat %q", a.ID, b.ID)
			}
			beats[b.ID] = b
		}
		if beats[a.Start].ID == "" {
			return invalid("arc %s start %q", a.ID, a.Start)
		}
		self := map[string]bool{"self": true}
		for _, b := range a.Beats {
			for _, n := range b.Next {
				if beats[n].ID == "" {
					return invalid("arc %s beat %s: next %q", a.ID, b.ID, n)
				}
			}
			if b.Unique && b.AdvanceWhen != nil {
				return invalid("arc %s beat %s: unique beats advance on claim", a.ID, b.ID)
			}
			if e := v.cond(b.Opens, map[string]bool{}, "beat "+b.ID); e != nil {
				return e
			}
			if e := v.cond(b.Goal, self, "beat "+b.ID); e != nil {
				return e
			}
			if e := v.effects(b.Claim, self, "beat "+b.ID); e != nil {
				return e
			}
			if e := v.effects(b.Rival, map[string]bool{"self": true, "claimant": true}, "beat "+b.ID); e != nil {
				return e
			}
			if b.Contender != nil {
				if e := v.cond(*b.Contender, self, "beat "+b.ID+" contender"); e != nil {
					return e
				}
			}
			if b.AdvanceWhen != nil {
				if e := v.cond(*b.AdvanceWhen, map[string]bool{}, "beat "+b.ID); e != nil {
					return e
				}
			}
		}
		state := map[string]int{}
		var visit func(string) error
		visit = func(id string) error {
			if state[id] == 1 {
				return invalid("arc %s: cycle at %s", a.ID, id)
			}
			if state[id] == 2 {
				return nil
			}
			state[id] = 1
			for _, n := range beats[id].Next {
				if e := visit(n); e != nil {
					return e
				}
			}
			state[id] = 2
			return nil
		}
		if e := visit(a.Start); e != nil {
			return e
		}
		for _, b := range a.Beats {
			if state[b.ID] != 2 {
				return invalid("arc %s: unreachable beat %s", a.ID, b.ID)
			}
		}
		w.arcs[a.ID] = a
		w.beats[a.ID] = beats
	}
	return nil
}

func (w *World) compileQuests(v *validator) error {
	for _, q := range w.U.Quests {
		if q.ID == "" || w.quests[q.ID].ID != "" || strings.Contains(q.ID, "|") || q.Title == "" {
			return invalid("quest %q", q.ID)
		}
		if (q.Arc == "") != (q.Beat == "") || q.Arc != "" && w.beats[q.Arc][q.Beat].ID == "" {
			return invalid("quest %s: beat %s/%s", q.ID, q.Arc, q.Beat)
		}
		vars := map[string]bool{"self": true}
		for _, p := range q.Params {
			if p.Name == "" || vars[p.Name] || !w.kinds[p.Kind] {
				return invalid("quest %s param %q", q.ID, p.Name)
			}
			where := map[string]bool{"it": true}
			for k := range vars {
				where[k] = true
			}
			if e := v.cond(p.Where, where, "quest "+q.ID); e != nil {
				return e
			}
			vars[p.Name] = true
		}
		if e := v.cond(q.Eligible, map[string]bool{"self": true}, "quest "+q.ID); e != nil {
			return e
		}
		if q.Giver != "" {
			if e := v.ref(q.Giver, vars, "quest "+q.ID+" giver"); e != nil {
				return e
			}
			if q.Giver == "$self" {
				return invalid("quest %s: a player cannot be their own giver", q.ID)
			}
		}
		if q.Region != "" {
			if e := v.place(q.Region, vars, "quest "+q.ID+" region"); e != nil {
				return e
			}
		}
		if e := v.cond(q.Goal, vars, "quest "+q.ID); e != nil {
			return e
		}
		if e := v.effects(q.Rewards, vars, "quest "+q.ID); e != nil {
			return e
		}
		if q.TimeLimit < 0 {
			return invalid("quest %s: time limit", q.ID)
		}
		if q.Fail != nil {
			if e := v.cond(*q.Fail, vars, "quest "+q.ID+" fail"); e != nil {
				return e
			}
		}
		if e := v.effects(q.FailEffects, vars, "quest "+q.ID+" failEffects"); e != nil {
			return e
		}
		if e := v.effects(q.OnDecline, vars, "quest "+q.ID+" onDecline"); e != nil {
			return e
		}
		stageIDs := map[string]bool{}
		for _, st := range q.Stages {
			if st.ID == "" || stageIDs[st.ID] {
				return invalid("quest %s stage %q", q.ID, st.ID)
			}
			stageIDs[st.ID] = true
			if e := v.cond(st.When, vars, "quest "+q.ID+" stage "+st.ID); e != nil {
				return e
			}
			if st.Goal != nil {
				if e := v.cond(*st.Goal, vars, "quest "+q.ID+" stage "+st.ID); e != nil {
					return e
				}
			}
			if e := v.effects(st.Effects, vars, "quest "+q.ID+" stage "+st.ID); e != nil {
				return e
			}
		}
		w.quests[q.ID] = q
	}
	return nil
}

type validator struct {
	w    *World
	ents map[ID]string
}

func (v *validator) ref(r string, vars map[string]bool, where string) error {
	if r == "" {
		return invalid("%s: empty reference", where)
	}
	if strings.HasPrefix(r, "$") {
		if !vars[r[1:]] {
			return invalid("%s: unbound variable %s", where, r)
		}
		return nil
	}
	if v.ents[ID(r)] == "" {
		return invalid("%s: unknown entity %s", where, r)
	}
	return nil
}

func usesChance(c Cond) bool {
	if c.Chance != nil {
		return true
	}
	for _, x := range append(append([]Cond{}, c.All...), c.Any...) {
		if usesChance(x) {
			return true
		}
	}
	return c.Not != nil && usesChance(*c.Not)
}

// place is a reference to a region: a variable, or a literal place entity.
func (v *validator) place(r string, vars map[string]bool, where string) error {
	if e := v.ref(r, vars, where); e != nil {
		return e
	}
	if !strings.HasPrefix(r, "$") && !v.w.regions[v.ents[ID(r)]] {
		return invalid("%s: %s is not a place", where, r)
	}
	return nil
}

func (v *validator) pattern(p *Pattern, vars map[string]bool, where string) error {
	if !v.w.preds[p.P] {
		return invalid("%s: unknown predicate %q", where, p.P)
	}
	if e := v.ref(p.S, vars, where); e != nil {
		return e
	}
	if p.O != "" {
		return v.ref(p.O, vars, where)
	}
	return nil
}

func (v *validator) cond(c Cond, vars map[string]bool, where string) error {
	n := 0
	if c.All != nil {
		n++
		for _, x := range c.All {
			if e := v.cond(x, vars, where); e != nil {
				return e
			}
		}
	}
	if c.Any != nil {
		n++
		if len(c.Any) == 0 {
			return invalid("%s: empty any", where)
		}
		for _, x := range c.Any {
			if e := v.cond(x, vars, where); e != nil {
				return e
			}
		}
	}
	if c.Not != nil {
		n++
		if e := v.cond(*c.Not, vars, where); e != nil {
			return e
		}
	}
	if c.Fact != nil {
		n++
		if e := v.pattern(c.Fact, vars, where); e != nil {
			return e
		}
		if c.Fact.Private && !vars["self"] {
			return invalid("%s: private fact without $self", where)
		}
	}
	if k := c.Knows; k != nil {
		n++
		who := k.Who
		if who == "" {
			who = "$self"
		}
		if e := v.ref(who, vars, where); e != nil {
			return e
		}
		if e := v.pattern(&Pattern{P: k.P, S: k.S, O: k.O}, vars, where); e != nil {
			return e
		}
	}
	if c.Num != nil {
		n++
		if !slices.Contains([]string{"<", "<=", "==", "!=", ">=", ">"}, c.Num.Op) || c.Num.K == "" {
			return invalid("%s: num comparison", where)
		}
		if e := v.ref(c.Num.E, vars, where); e != nil {
			return e
		}
	}
	if c.Tag != nil {
		n++
		if c.Tag.K == "" {
			return invalid("%s: tag comparison", where)
		}
		if e := v.ref(c.Tag.E, vars, where); e != nil {
			return e
		}
	}
	if b := c.Beat; b != nil {
		n++
		if v.w.beats[b.Arc][b.Beat].ID == "" && !slices.ContainsFunc(v.w.U.Arcs, func(a ArcDef) bool {
			return a.ID == b.Arc && slices.ContainsFunc(a.Beats, func(x BeatDef) bool { return x.ID == b.Beat })
		}) {
			return invalid("%s: unknown beat %s/%s", where, b.Arc, b.Beat)
		}
		if !slices.Contains([]string{"locked", "open", "claimed"}, b.State) {
			return invalid("%s: beat state %q", where, b.State)
		}
	}
	if c.In != nil {
		n++
		if e := v.ref(c.In.E, vars, where); e != nil {
			return e
		}
		if e := v.place(c.In.Region, vars, where); e != nil {
			return e
		}
	}
	if c.Chance != nil {
		n++
		if c.Chance.Seed == "" || c.Chance.Permille < 1 || c.Chance.Permille > 1000 {
			return invalid("%s: chance", where)
		}
	}
	if c.Time != nil {
		n++
		if v.w.U.DayLength < 1 || c.Time.From < 0 || c.Time.From > 23 || c.Time.To < 0 || c.Time.To > 24 {
			return invalid("%s: time needs dayLength and hours 0-24", where)
		}
	}
	if c.Has != nil {
		n++
		if !slices.ContainsFunc(v.w.U.Skills, func(k SkillDef) bool { return k.ID == c.Has.Skill }) {
			return invalid("%s: unknown skill %q", where, c.Has.Skill)
		}
		if c.Has.E != "" {
			if e := v.ref(c.Has.E, vars, where); e != nil {
				return e
			}
		} else if !vars["self"] {
			return invalid("%s: has without $self", where)
		}
	}
	if c.Deeds != nil {
		n++
		_, isAction := v.w.actions[c.Deeds.Action]
		if !isAction && !slices.Contains(builtinDeeds, c.Deeds.Action) || !slices.Contains([]string{"<", "<=", "==", "!=", ">=", ">"}, c.Deeds.Op) {
			return invalid("%s: deeds %q", where, c.Deeds.Action)
		}
		if c.Deeds.E != "" {
			if e := v.ref(c.Deeds.E, vars, where); e != nil {
				return e
			}
		} else if !vars["self"] {
			return invalid("%s: deeds without $self", where)
		}
	}
	if c.Rel != nil {
		n++
		if !slices.Contains([]string{"<", "<=", "==", "!=", ">=", ">"}, c.Rel.Op) {
			return invalid("%s: rel comparison", where)
		}
		if e := v.ref(c.Rel.A, vars, where); e != nil {
			return e
		}
		if e := v.ref(c.Rel.B, vars, where); e != nil {
			return e
		}
	}
	if c.Near != nil {
		n++
		if e := v.ref(c.Near.A, vars, where); e != nil {
			return e
		}
		if e := v.ref(c.Near.B, vars, where); e != nil {
			return e
		}
	}
	if n > 1 {
		return invalid("%s: condition node with %d operators", where, n)
	}
	return nil
}

func (v *validator) effects(list []Effect, vars map[string]bool, where string) error {
	for _, e := range list {
		if e.If != nil {
			if err := v.cond(*e.If, vars, where); err != nil {
				return err
			}
		}
		switch e.Op {
		case "assert", "retract", "observe":
			if e.Fact == nil {
				return invalid("%s: %s without fact", where, e.Op)
			}
			if err := v.pattern(e.Fact, vars, where); err != nil {
				return err
			}
			if e.Op == "observe" && e.Fact.Private {
				return invalid("%s: observe applies to world facts", where)
			}
		case "inform":
			if e.Fact == nil || e.Fact.Private {
				return invalid("%s: inform needs a world fact", where)
			}
			if err := v.pattern(e.Fact, vars, where); err != nil {
				return err
			}
			if err := v.ref(e.To, vars, where); err != nil {
				return err
			}
		case "adjust", "set":
			if e.K == "" || e.Op == "adjust" && e.D == 0 {
				return invalid("%s: %s needs key/delta", where, e.Op)
			}
			if err := v.ref(e.E, vars, where); err != nil {
				return err
			}
		case "grant":
			if !slices.ContainsFunc(v.w.U.Skills, func(k SkillDef) bool { return k.ID == e.V }) {
				return invalid("%s: grant unknown skill %q", where, e.V)
			}
			if e.E != "" {
				if err := v.ref(e.E, vars, where); err != nil {
					return err
				}
			} else if !vars["self"] {
				return invalid("%s: grant without $self", where)
			}
		case "relate":
			if e.D == 0 {
				return invalid("%s: relate needs a delta", where)
			}
			if err := v.ref(e.E, vars, where); err != nil {
				return err
			}
			if err := v.ref(e.To, vars, where); err != nil {
				return err
			}
		case "relocate":
			if err := v.ref(e.E, vars, where); err != nil {
				return err
			}
			if err := v.place(e.To, vars, where); err != nil {
				return err
			}
		case "schedule":
			if v.w.rules[e.Rule].ID == "" || e.After < 1 {
				return invalid("%s: schedule %q", where, e.Rule)
			}
		case "emit":
			if e.Text == "" || e.Event == "" {
				return invalid("%s: emit needs event and text", where)
			}
			if e.Reveals != nil {
				if err := v.pattern(e.Reveals, vars, where); err != nil {
					return err
				}
			}
		default:
			return invalid("%s: unknown op %q", where, e.Op)
		}
	}
	return nil
}

// Fingerprint identifies the exact universe definition. A command log is
// only replayed against the universe that produced it.
func (w *World) Fingerprint() string {
	b, err := json.Marshal(w.U)
	if err != nil {
		panic(err)
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}
