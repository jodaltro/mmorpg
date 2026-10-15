package journey

import (
	"errors"
	"fmt"
	"slices"
	"sort"
)

var ErrIntent = errors.New("invalid_world_intent")

type Encounter struct {
	Creature  string `json:"creature"`
	HP        int    `json:"hp"`
	Turn      int    `json:"turn"`
	Phase     string `json:"phase"`
	Range     int    `json:"range"`
	Fractured bool   `json:"fractured"`
	Marked    bool   `json:"marked"`
	Burn      int    `json:"burn"`
	Defended  int    `json:"defended"`
	Collected bool   `json:"collected"`
}
type State struct {
	Region        string              `json:"region"`
	HP            int                 `json:"hp"`
	Step          int                 `json:"step"`
	Poison        int                 `json:"poison"`
	Facts         map[string]bool     `json:"facts"`
	Inventory     map[string]int      `json:"inventory"`
	Abilities     map[string]bool     `json:"abilities"`
	Equipment     map[string]string   `json:"equipment"`
	Relationships map[string]int      `json:"relationships"`
	Knowledge     map[string][]string `json:"knowledge"`
	Opportunities map[string]string   `json:"opportunities"`
	Cooldowns     map[string]int      `json:"cooldowns"`
	Pending       map[string]int      `json:"pending"`
	Encounter     *Encounter          `json:"encounter,omitempty"`
}
type World struct {
	Facts   map[string]bool   `json:"facts"`
	Authors map[string]string `json:"authors"`
}
type Action struct {
	Kind   string `json:"kind"`
	Target string `json:"target"`
}
type Change struct {
	State      State
	World      World
	NewFacts   []string
	NewEvents  []string
	Candidates []string
}

func NewState() State {
	return State{Region: "valdoria", HP: 100, Facts: map[string]bool{"visited:valdoria": true}, Inventory: map[string]int{}, Abilities: map[string]bool{}, Equipment: map[string]string{}, Relationships: map[string]int{}, Knowledge: map[string][]string{}, Opportunities: map[string]string{}, Cooldowns: map[string]int{}, Pending: map[string]int{}}
}
func NewWorld() World { return World{Facts: map[string]bool{}, Authors: map[string]string{}} }
func cloneMap[K comparable, V any](in map[K]V) map[K]V {
	r := map[K]V{}
	for k, v := range in {
		r[k] = v
	}
	return r
}
func clone(s State) State {
	s.Facts = cloneMap(s.Facts)
	s.Inventory = cloneMap(s.Inventory)
	s.Abilities = cloneMap(s.Abilities)
	s.Equipment = cloneMap(s.Equipment)
	s.Relationships = cloneMap(s.Relationships)
	s.Knowledge = cloneMap(s.Knowledge)
	for k, v := range s.Knowledge {
		s.Knowledge[k] = slices.Clone(v)
	}
	s.Opportunities = cloneMap(s.Opportunities)
	s.Cooldowns = cloneMap(s.Cooldowns)
	s.Pending = cloneMap(s.Pending)
	if s.Encounter != nil {
		e := *s.Encounter
		s.Encounter = &e
	}
	return s
}
func all(s State, w World, req []string) bool {
	for _, f := range req {
		if !s.Facts[f] && !w.Facts[f] {
			return false
		}
	}
	return true
}
func canPay(s State, cost map[string]int) bool {
	for k, v := range cost {
		if s.Inventory[k] < v {
			return false
		}
	}
	return true
}
func (c Catalog) eligible(s State, w World, o Opportunity) bool {
	if s.Opportunities[o.ID] == "completed" || s.Opportunities[o.ID] == "ignored" || s.Pending[o.ID] > 0 || !all(s, w, o.Requires) || !canPay(s, o.Costs) {
		return false
	}
	for _, f := range o.Excludes {
		if s.Facts[f] || w.Facts[f] {
			return false
		}
	}
	if o.Shared && w.Facts[o.Fact] {
		return false
	}
	return true
}

// Availability is derived; only three visible opportunities at once. Completing/ignoring one
// reveals another. All eligible IDs are retained as decision candidates, never lost to RNG.
func (c Catalog) Refresh(s *State, w World) []string {
	candidates := []string{}
	for _, o := range c.Opportunities {
		if c.eligible(*s, w, o) {
			candidates = append(candidates, o.ID)
		}
	}
	sort.Strings(candidates)
	for k, v := range s.Opportunities {
		if v == "available" {
			delete(s.Opportunities, k)
		}
	}
	visible := 0
	for _, id := range candidates {
		o, _ := c.Opportunity(id)
		if o.Region == s.Region && visible < 3 {
			s.Opportunities[id] = "available"
			visible++
		}
	}
	return candidates
}

// Step applies one validated abstract interaction/turn to copies. Invalid commands have no
// side effects. Persistence wraps its outputs in a transaction; simulations use this same code.
func (c Catalog) Step(before State, world World, actor string, a Action) (Change, error) {
	s := clone(before)
	w := World{Facts: cloneMap(world.Facts), Authors: cloneMap(world.Authors)}
	out := Change{}
	add := func(f string) {
		if !s.Facts[f] {
			s.Facts[f] = true
			out.NewFacts = append(out.NewFacts, f)
		}
	}
	shared := func(o Opportunity) {
		if !w.Facts[o.Fact] {
			w.Facts[o.Fact] = true
			w.Authors[o.Fact] = actor
			out.NewEvents = append(out.NewEvents, o.ID)
		}
	}
	grant := func(o Opportunity) {
		for k, n := range o.Rewards {
			s.Inventory[k] += n
		}
		if o.Ability != "" {
			s.Abilities[o.Ability] = true
		}
		s.Opportunities[o.ID] = "completed"
		delete(s.Pending, o.ID)
		add("done:" + o.ID)
		add(o.Fact)
		if o.NPC != "" {
			s.Relationships[o.NPC] = min(100, s.Relationships[o.NPC]+1)
			s.Knowledge[o.NPC] = append(s.Knowledge[o.NPC], o.Fact)
		}
		if o.Shared {
			shared(o)
		}
	}
	if len(a.Target) > 128 || len(a.Kind) > 48 {
		return Change{}, ErrIntent
	}
	active := s.Encounter != nil && s.Encounter.Phase != "defeated" && s.Encounter.Phase != "escaped"
	combatAction := a.Kind == "attack" || a.Kind == "dodge" || a.Kind == "guard" || a.Kind == "approach" || a.Kind == "ability" || a.Kind == "use"
	if active && !combatAction && a.Kind != "retreat" {
		return Change{}, ErrIntent
	}
	if s.HP <= 0 && a.Kind != "rest" && a.Kind != "retreat" {
		return Change{}, ErrIntent
	}
	switch a.Kind {
	case "retreat":
		if !active && s.HP > 0 {
			return Change{}, ErrIntent
		}
		if s.Encounter != nil {
			s.Encounter.Phase = "escaped"
		}
		s.HP = max(1, s.HP)
		s.Poison = 0
	case "travel":
		r, ok := c.Region(s.Region)
		if !ok || !slices.Contains(r.Connections, a.Target) {
			return Change{}, ErrIntent
		}
		s.Region = a.Target
		add("visited:" + a.Target)
	case "observe", "gather":
		n, ok := c.Node(a.Target)
		if !ok || n.Region != s.Region || s.Facts["node:"+n.ID] || !all(s, w, n.Requires) || n.Ability != "" && !s.Abilities[n.Ability] {
			return Change{}, ErrIntent
		}
		if slices.Contains(n.Requires, "done:mining-tools") && s.Equipment["tool"] != "mining-pick" {
			return Change{}, ErrIntent
		}
		for k, v := range n.Items {
			s.Inventory[k] += v
		}
		add("node:" + n.ID)
		add(n.Fact)
	case "talk":
		n, ok := c.NPC(a.Target)
		if !ok || n.Region != s.Region || s.Facts["talk:"+n.ID] {
			return Change{}, ErrIntent
		}
		add("talk:" + n.ID)
		for _, f := range n.Knowledge {
			add(f)
			s.Knowledge[n.ID] = append(s.Knowledge[n.ID], f)
		}
		s.Relationships[n.ID] = 1
	case "challenge":
		if s.Encounter != nil && !s.Encounter.Collected && s.Encounter.Phase != "escaped" {
			return Change{}, ErrIntent
		}
		if a.Target == "training-dummy" && s.Region == "valdoria" {
			s.Encounter = &Encounter{Creature: a.Target, HP: 40, Phase: "ready"}
			break
		}
		x, ok := c.Creature(a.Target)
		if !ok || x.Region != s.Region || s.Facts["loot:"+x.ID] || !all(s, w, x.Requires) {
			return Change{}, ErrIntent
		}
		r := 0
		if x.Pattern == "flying" {
			r = 2
		}
		s.Encounter = &Encounter{Creature: x.ID, HP: x.HP, Range: r, Phase: "ready"}
	case "attack", "dodge", "guard", "approach", "ability":
		if !active {
			return Change{}, ErrIntent
		}
		if e := c.combat(&s, a, add); e != nil {
			return Change{}, e
		}
	case "loot":
		e := s.Encounter
		if e == nil || e.Creature != a.Target || e.Phase != "defeated" || e.Collected {
			return Change{}, ErrIntent
		}
		if x, ok := c.Creature(e.Creature); ok && x.Region != s.Region {
			return Change{}, ErrIntent
		}
		if e.Creature == "training-dummy" && s.Region != "valdoria" {
			return Change{}, ErrIntent
		}
		e.Collected = true
		if x, ok := c.Creature(e.Creature); ok {
			for k, v := range x.Loot {
				s.Inventory[k] += v
			}
			add("loot:" + x.ID)
		}
	case "complete":
		o, ok := c.Opportunity(a.Target)
		if !ok || o.Region != s.Region || !c.eligible(s, w, o) {
			return Change{}, ErrIntent
		}
		for k, n := range o.Costs {
			s.Inventory[k] -= n
			if s.Inventory[k] == 0 {
				delete(s.Inventory, k)
			}
		}
		if o.After > 0 {
			s.Pending[o.ID] = s.Step + o.After + 1
			s.Opportunities[o.ID] = "pending"
			add("scheduled:" + o.ID)
		} else {
			grant(o)
		}
	case "ignore":
		o, ok := c.Opportunity(a.Target)
		if !ok || o.Region != s.Region || !c.eligible(s, w, o) {
			return Change{}, ErrIntent
		}
		s.Opportunities[o.ID] = "ignored"
		add("ignored:" + o.ID)
	case "equip":
		i, ok := c.Item(a.Target)
		if !ok || i.Use != "equipment" || s.Inventory[i.ID] < 1 {
			return Change{}, ErrIntent
		}
		s.Equipment[i.Slot] = i.ID
	case "use":
		i, ok := c.Item(a.Target)
		if !ok || s.Inventory[i.ID] < 1 || !slices.Contains([]string{"heal", "antidote", "burn", "purify"}, i.Use) {
			return Change{}, ErrIntent
		}
		switch i.Use {
		case "heal":
			if s.HP >= 100 {
				return Change{}, ErrIntent
			}
			s.HP = min(100, s.HP+i.Power)
		case "antidote":
			if s.Poison <= 0 {
				return Change{}, ErrIntent
			}
			s.Poison = 0
		case "burn":
			if !active {
				return Change{}, ErrIntent
			}
			s.Encounter.Burn = 3
		case "purify":
			s.Poison = 0
			s.HP = min(100, s.HP+i.Power)
			if active {
				s.Encounter.Fractured = true
			}
		}
		s.Inventory[i.ID]--
		if s.Inventory[i.ID] == 0 {
			delete(s.Inventory, i.ID)
		}
		if active {
			if e := c.combat(&s, Action{Kind: "item-turn"}, add); e != nil {
				return Change{}, e
			}
		}
	case "rest":
		if active || s.Region != "valdoria" {
			return Change{}, ErrIntent
		}
		s.HP = 100
		s.Poison = 0
	case "tick":
		if a.Target != "" {
			return Change{}, ErrIntent
		}
	default:
		return Change{}, ErrIntent
	}
	s.Step++
	due := []string{}
	for id, step := range s.Pending {
		if step <= s.Step {
			due = append(due, id)
		}
	}
	sort.Strings(due)
	for _, id := range due {
		o, ok := c.Opportunity(id)
		if !ok {
			return Change{}, fmt.Errorf("unknown schedule")
		}
		if o.Shared && w.Facts[o.Fact] {
			// Another author won while this sourced consequence was pending.
			// Return the reserved materials exactly once; delete Pending before replay.
			for item, quantity := range o.Costs {
				s.Inventory[item] += quantity
			}
			s.Opportunities[id] = "cancelled"
			delete(s.Pending, id)
			add("cancelled:" + id)
		} else {
			grant(o)
		}
	}
	out.Candidates = c.Refresh(&s, w)
	out.State = s
	out.World = w
	return out, nil
}

func (c Catalog) combat(s *State, a Action, add func(string)) error {
	e := s.Encounter
	x, ok := c.Creature(e.Creature)
	training := e.Creature == "training-dummy"
	if !ok && !training {
		return ErrIntent
	}
	if training {
		x = Creature{ID: e.Creature, HP: 40, Damage: 6, Pattern: "pursuit"}
	}
	damage, defense, enemyTurn := 0, 0, true
	power := func(slot string) int { i, _ := c.Item(s.Equipment[slot]); return i.Power }
	switch a.Kind {
	case "attack":
		if e.Range > 0 || e.Phase == "hidden" {
			damage = 0
		} else {
			damage = 20 + power("weapon")
			if e.Phase == "exposed" && s.Abilities["weakness-reading"] {
				damage += 10
			}
			if x.Pattern == "armored" && !e.Fractured {
				damage = max(1, damage-14)
			}
			if x.Pattern == "ethereal" && !e.Fractured {
				damage = max(1, damage/3)
			}
			if x.Pattern == "shield" && e.Phase != "exposed" && !e.Fractured {
				damage = max(1, damage/4)
			}
		}
	case "dodge":
		if e.Phase != "preparing" && e.Phase != "hidden" {
			return ErrIntent
		}
		defense = 100
		e.Defended++
		e.Phase = "exposed"
		enemyTurn = false
		add("practice:dodge")
	case "guard":
		if e.Phase != "preparing" {
			return ErrIntent
		}
		defense = x.Damage / 2
		e.Defended++
		add("practice:guard")
	case "approach":
		if e.Range <= 0 {
			return ErrIntent
		}
		e.Range--
	case "ability":
		ab, ok := c.Ability(a.Target)
		if !ok || !s.Abilities[ab.ID] || s.Cooldowns[ab.ID] > s.Step || ab.Cooldown == 0 {
			return ErrIntent
		}
		switch ab.Effect {
		case "counter":
			if e.Phase != "preparing" {
				return ErrIntent
			}
			damage = 25
			defense = 100
			e.Phase = "exposed"
			enemyTurn = false
		case "fracture":
			if e.Range > 0 {
				return ErrIntent
			}
			e.Fractured = true
			damage = 18
		case "stealth":
			e.Range = 0
			e.Phase = "exposed"
			enemyTurn = false
		case "seismic":
			e.Range = 0
			e.Fractured = true
			damage = 22
			e.Phase = "exposed"
			enemyTurn = false
		case "mark":
			e.Marked = true
			e.Range = 0
		case "burn":
			if s.Equipment["tool"] != "alchemist-kit" {
				return ErrIntent
			}
			e.Burn = 3
			damage = 8
		case "guard":
			if e.Phase != "preparing" {
				return ErrIntent
			}
			defense = 100
			e.Defended++
			add("practice:guard")
		case "purify":
			s.Poison = 0
			s.HP = min(100, s.HP+5)
			e.Fractured = true
			damage = 12
			if x.Pattern == "ethereal" {
				damage = 30
			}
		default:
			return ErrIntent
		}
		s.Cooldowns[ab.ID] = s.Step + ab.Cooldown + 1
	case "item-turn":
	default:
		return ErrIntent
	}
	if e.Marked && damage > 0 {
		damage += 5
	}
	if e.Burn > 0 {
		damage += 10
		e.Burn--
	}
	e.HP = max(0, e.HP-damage)
	if e.HP == 0 {
		e.Phase = "defeated"
		add("defeat:" + e.Creature)
		e.Turn++
		return nil
	}
	if enemyTurn {
		if e.Phase == "preparing" || e.Phase == "hidden" {
			hit := max(0, x.Damage-power("armor")-power("cloak")-defense)
			s.HP = max(0, s.HP-hit)
			if x.Pattern == "venom" && hit > 0 {
				s.Poison = 3
			}
			e.Phase = "ready"
			if x.Pattern == "flying" && !e.Marked {
				e.Range = min(2, e.Range+1)
			}
		} else {
			e.Phase = "preparing"
			if x.Pattern == "burrow" && !e.Fractured {
				e.Phase = "hidden"
			}
		}
	}
	if x.Pattern == "regenerate" && e.Burn == 0 && !e.Fractured {
		e.HP = min(x.HP, e.HP+6)
	}
	if x.Pattern == "charge" && e.Phase == "ready" {
		e.Range = 1
	}
	if s.Poison > 0 {
		poison := 6
		if s.Abilities["toxic-resistance"] {
			poison = 2
		}
		poison = max(0, poison-power("charm"))
		s.HP = max(0, s.HP-poison)
		s.Poison--
	}
	e.Turn++
	return nil
}

// LegalActions returns intentions, not rewards. It also lets deterministic simulation
// explore only accepted operations. Each candidate is revalidated by Step at execution.
func (c Catalog) LegalActions(s State, w World) []Action {
	trial := []Action{{Kind: "tick"}, {Kind: "rest"}, {Kind: "retreat"}}
	if r, ok := c.Region(s.Region); ok {
		for _, id := range r.Connections {
			trial = append(trial, Action{"travel", id})
		}
	}
	for _, n := range c.Nodes {
		if n.Region == s.Region && !s.Facts["node:"+n.ID] {
			trial = append(trial, Action{"gather", n.ID})
		}
	}
	for _, n := range c.NPCs {
		if n.Region == s.Region && !s.Facts["talk:"+n.ID] {
			trial = append(trial, Action{"talk", n.ID})
		}
	}
	for _, x := range c.Creatures {
		if x.Region == s.Region {
			trial = append(trial, Action{"challenge", x.ID}, Action{"loot", x.ID})
		}
	}
	trial = append(trial, Action{"challenge", "training-dummy"}, Action{"loot", "training-dummy"})
	for _, k := range []string{"attack", "dodge", "guard", "approach"} {
		trial = append(trial, Action{k, ""})
	}
	for _, a := range c.Abilities {
		if s.Abilities[a.ID] {
			trial = append(trial, Action{"ability", a.ID})
		}
	}
	for _, i := range c.Items {
		if s.Inventory[i.ID] > 0 {
			trial = append(trial, Action{"equip", i.ID}, Action{"use", i.ID})
		}
	}
	for _, o := range c.Opportunities {
		if o.Region == s.Region && c.eligible(s, w, o) {
			trial = append(trial, Action{"complete", o.ID}, Action{"ignore", o.ID})
		}
	}
	out := []Action{}
	for _, a := range trial {
		if _, e := c.Step(s, w, "preview", a); e == nil {
			out = append(out, a)
		}
	}
	return out
}
