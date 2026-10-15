// Package journey owns expanded-world rules shared by persistence and simulation.
// Unity consumes public definitions and authoritative projections, never reward rules.
package journey

import (
	"embed"
	"encoding/json"
	"fmt"
	"slices"
)

//go:embed content.json
var content embed.FS

type Region struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Connections []string `json:"connections"`
}
type Ability struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Effect   string `json:"effect"`
	Cooldown int    `json:"cooldown"`
}
type Item struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Use   string `json:"use"`
	Slot  string `json:"slot,omitempty"`
	Power int    `json:"power"`
}
type Creature struct {
	ID       string         `json:"id"`
	Name     string         `json:"name"`
	Region   string         `json:"region"`
	Pattern  string         `json:"pattern"`
	HP       int            `json:"hp"`
	Damage   int            `json:"damage"`
	Loot     map[string]int `json:"loot"`
	Requires []string       `json:"requires"`
}
type NPC struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Region    string   `json:"region"`
	Role      string   `json:"role"`
	Knowledge []string `json:"knowledge"`
}
type Node struct {
	ID       string         `json:"id"`
	Name     string         `json:"name"`
	Region   string         `json:"region"`
	Fact     string         `json:"fact"`
	Requires []string       `json:"requires"`
	Ability  string         `json:"ability,omitempty"`
	Items    map[string]int `json:"items"`
}
type Opportunity struct {
	ID       string         `json:"id"`
	Name     string         `json:"name"`
	Theme    string         `json:"theme"`
	Region   string         `json:"region"`
	NPC      string         `json:"npc,omitempty"`
	Requires []string       `json:"requires"`
	Excludes []string       `json:"excludes"`
	Costs    map[string]int `json:"costs"`
	Rewards  map[string]int `json:"rewards"`
	Ability  string         `json:"ability,omitempty"`
	Fact     string         `json:"fact"`
	Shared   bool           `json:"shared"`
	After    int            `json:"after"`
}
type Catalog struct {
	Version       int           `json:"version"`
	Regions       []Region      `json:"regions"`
	Abilities     []Ability     `json:"abilities"`
	Items         []Item        `json:"items"`
	Creatures     []Creature    `json:"creatures"`
	NPCs          []NPC         `json:"npcs"`
	Nodes         []Node        `json:"nodes"`
	Opportunities []Opportunity `json:"opportunities"`
}

func Load() (Catalog, error) {
	var c Catalog
	b, e := content.ReadFile("content.json")
	if e != nil {
		return c, e
	}
	if e = json.Unmarshal(b, &c); e != nil {
		return c, e
	}
	return c, c.Validate()
}
func (c Catalog) Region(id string) (Region, bool) {
	for _, v := range c.Regions {
		if v.ID == id {
			return v, true
		}
	}
	return Region{}, false
}
func (c Catalog) Ability(id string) (Ability, bool) {
	for _, v := range c.Abilities {
		if v.ID == id {
			return v, true
		}
	}
	return Ability{}, false
}
func (c Catalog) Item(id string) (Item, bool) {
	for _, v := range c.Items {
		if v.ID == id {
			return v, true
		}
	}
	return Item{}, false
}
func (c Catalog) Creature(id string) (Creature, bool) {
	for _, v := range c.Creatures {
		if v.ID == id {
			return v, true
		}
	}
	return Creature{}, false
}
func (c Catalog) NPC(id string) (NPC, bool) {
	for _, v := range c.NPCs {
		if v.ID == id {
			return v, true
		}
	}
	return NPC{}, false
}
func (c Catalog) Node(id string) (Node, bool) {
	for _, v := range c.Nodes {
		if v.ID == id {
			return v, true
		}
	}
	return Node{}, false
}
func (c Catalog) Opportunity(id string) (Opportunity, bool) {
	for _, v := range c.Opportunities {
		if v.ID == id {
			return v, true
		}
	}
	return Opportunity{}, false
}

// Reachability is a monotone closure over all alternative producers, not a naive cycle check.
// A cycle with an independently reachable entrance is allowed; a closed dependency island fails.
func (c Catalog) Validate() error {
	if c.Version != 1 {
		return fmt.Errorf("unsupported content version")
	}
	ids := map[string]bool{}
	add := func(kind, id string) error {
		if id == "" || ids[kind+":"+id] {
			return fmt.Errorf("duplicate/empty %s %s", kind, id)
		}
		ids[kind+":"+id] = true
		return nil
	}
	for _, r := range c.Regions {
		if e := add("region", r.ID); e != nil {
			return e
		}
	}
	for _, a := range c.Abilities {
		if e := add("ability", a.ID); e != nil {
			return e
		}
		if !slices.Contains([]string{"weakness", "counter", "fracture", "stealth", "toxic", "extract", "seismic", "mark", "burn", "guard", "sense", "purify"}, a.Effect) || a.Cooldown < 0 {
			return fmt.Errorf("invalid ability %s", a.ID)
		}
	}
	for _, i := range c.Items {
		if e := add("item", i.ID); e != nil {
			return e
		}
		if !slices.Contains([]string{"material", "evidence", "equipment", "heal", "antidote", "burn", "purify"}, i.Use) || i.Power < 0 {
			return fmt.Errorf("invalid item %s", i.ID)
		}
		if i.Use == "equipment" && !slices.Contains([]string{"weapon", "armor", "tool", "charm", "cloak"}, i.Slot) {
			return fmt.Errorf("invalid equipment slot")
		}
	}
	for _, n := range c.NPCs {
		if e := add("npc", n.ID); e != nil {
			return e
		}
		if !ids["region:"+n.Region] || n.Role == "" || len(n.Knowledge) == 0 {
			return fmt.Errorf("invalid npc %s", n.ID)
		}
	}
	checkItems := func(items map[string]int) error {
		for id, q := range items {
			if !ids["item:"+id] || q <= 0 || q > 20 {
				return fmt.Errorf("invalid quantity/reference %s", id)
			}
		}
		return nil
	}
	for _, r := range c.Regions {
		for _, x := range r.Connections {
			other, ok := c.Region(x)
			if !ok || !slices.Contains(other.Connections, r.ID) {
				return fmt.Errorf("invalid region connection %s", x)
			}
		}
	}
	connected := map[string]bool{"valdoria": true}
	for pass := 0; pass < len(c.Regions); pass++ {
		for _, r := range c.Regions {
			if connected[r.ID] {
				for _, id := range r.Connections {
					connected[id] = true
				}
			}
		}
	}
	for _, r := range c.Regions {
		if !connected[r.ID] {
			return fmt.Errorf("unreachable region %s", r.ID)
		}
	}
	for _, x := range c.Creatures {
		if e := add("creature", x.ID); e != nil {
			return e
		}
		if !ids["region:"+x.Region] || !slices.Contains([]string{"pursuit", "charge", "venom", "flying", "armored", "burrow", "ethereal", "regenerate", "shield"}, x.Pattern) || x.HP <= 0 || x.HP > 200 || x.Damage <= 0 || x.Damage > 40 {
			return fmt.Errorf("invalid creature %s", x.ID)
		}
		if e := checkItems(x.Loot); e != nil {
			return e
		}
	}
	for _, n := range c.Nodes {
		if e := add("node", n.ID); e != nil {
			return e
		}
		if !ids["region:"+n.Region] || n.Fact == "" || n.Ability != "" && !ids["ability:"+n.Ability] {
			return fmt.Errorf("invalid node %s", n.ID)
		}
		if e := checkItems(n.Items); e != nil {
			return e
		}
	}
	for _, o := range c.Opportunities {
		if e := add("opportunity", o.ID); e != nil {
			return e
		}
		if !ids["region:"+o.Region] || o.NPC != "" && !ids["npc:"+o.NPC] || o.Ability != "" && !ids["ability:"+o.Ability] || o.Fact == "" || o.After < 0 || !slices.Contains([]string{"forest", "mines", "swamp", "asterion"}, o.Theme) {
			return fmt.Errorf("invalid opportunity %s", o.ID)
		}
		if e := checkItems(o.Costs); e != nil {
			return e
		}
		if e := checkItems(o.Rewards); e != nil {
			return e
		}
		for _, f := range o.Requires {
			if slices.Contains(o.Excludes, f) {
				return fmt.Errorf("impossible condition %s", o.ID)
			}
		}
	}
	facts := map[string]bool{"practice:guard": true, "practice:dodge": true}
	abilities := map[string]bool{}
	availableItems := map[string]bool{}
	for _, r := range c.Regions {
		facts["visited:"+r.ID] = true
	}
	for _, n := range c.NPCs {
		facts["talk:"+n.ID] = true
		for _, f := range n.Knowledge {
			facts[f] = true
		}
	}
	all := func(req []string) bool {
		for _, f := range req {
			if !facts[f] {
				return false
			}
		}
		return true
	}
	for pass := 0; pass < 200; pass++ {
		changed := false
		produce := func(f string) {
			if !facts[f] {
				facts[f] = true
				changed = true
			}
		}
		for _, x := range c.Creatures {
			if all(x.Requires) {
				produce("defeat:" + x.ID)
				for k := range x.Loot {
					availableItems[k] = true
				}
			}
		}
		for _, n := range c.Nodes {
			if all(n.Requires) && (n.Ability == "" || abilities[n.Ability]) {
				produce(n.Fact)
				produce("node:" + n.ID)
				for k := range n.Items {
					availableItems[k] = true
				}
			}
		}
		for _, o := range c.Opportunities {
			if !all(o.Requires) {
				continue
			}
			costOK := true
			for k := range o.Costs {
				if !availableItems[k] {
					costOK = false
				}
			}
			if !costOK {
				continue
			}
			produce("done:" + o.ID)
			produce(o.Fact)
			if o.Ability != "" && !abilities[o.Ability] {
				abilities[o.Ability] = true
				changed = true
			}
			for k := range o.Rewards {
				availableItems[k] = true
			}
		}
		if !changed {
			break
		}
	}
	for _, o := range c.Opportunities {
		if !facts["done:"+o.ID] {
			return fmt.Errorf("unreachable opportunity/dependency cycle %s", o.ID)
		}
	}
	for _, n := range c.Nodes {
		if !facts[n.Fact] {
			return fmt.Errorf("unreachable node %s", n.ID)
		}
	}
	for _, a := range c.Abilities {
		if !abilities[a.ID] {
			return fmt.Errorf("unreachable ability %s", a.ID)
		}
	}
	used := map[string]bool{}
	for _, o := range c.Opportunities {
		for k := range o.Costs {
			used[k] = true
		}
	}
	for _, i := range c.Items {
		if (i.Use == "material" || i.Use == "evidence") && !used[i.ID] {
			return fmt.Errorf("item without a use %s", i.ID)
		}
	}
	return nil
}
