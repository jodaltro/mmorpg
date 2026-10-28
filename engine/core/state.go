package core

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"maps"
	"slices"
	"strconv"
	"strings"
)

type Entity struct {
	ID     ID                `json:"id"`
	Kind   string            `json:"kind"`
	Name   string            `json:"name"`
	Region ID                `json:"region,omitempty"`
	Num    map[string]int64  `json:"num"`
	Tag    map[string]string `json:"tag"`
}

// Fact is ground truth. Holder "" means world scope (shared, but not
// automatically known by anyone); otherwise it is private to Holder.
type Fact struct {
	Holder ID     `json:"holder,omitempty"`
	P      string `json:"p"`
	S      ID     `json:"s"`
	O      ID     `json:"o,omitempty"`
	At     Tick   `json:"at"`
	Cause  string `json:"cause,omitempty"`
}

// Belief is what an entity thinks about a world fact, and where it came
// from. Beliefs can be stale: the world may have changed since.
type Belief struct {
	P      string `json:"p"`
	S      ID     `json:"s"`
	O      ID     `json:"o,omitempty"`
	Holds  bool   `json:"holds"`
	Source string `json:"source"` // observation | communication | publication | initial
	From   ID     `json:"from,omitempty"`
	At     Tick   `json:"at"`
}

// Event is the chronicle. Public events are seen by everyone; private ones
// only by Holder; system events (no Holder, not Public) by no client.
type Event struct {
	Seq    int64             `json:"seq"`
	At     Tick              `json:"at"`
	Kind   string            `json:"kind"`
	Actor  ID                `json:"actor,omitempty"`
	Holder ID                `json:"holder,omitempty"`
	Public bool              `json:"public,omitempty"`
	Text   string            `json:"text,omitempty"`
	Cause  string            `json:"cause,omitempty"`
	Data   map[string]string `json:"data,omitempty"`
}

type Scheduled struct {
	Key   string `json:"key"`
	Due   Tick   `json:"due"`
	Rule  string `json:"rule"`
	Bind  Bind   `json:"bind,omitempty"`
	Cause string `json:"cause,omitempty"`
}

type BeatState struct {
	State string `json:"state"` // locked | open | claimed
	By    []ID   `json:"by,omitempty"`
	At    Tick   `json:"at,omitempty"`
}

type ArcState struct {
	Current  string               `json:"current,omitempty"`
	Done     bool                 `json:"done,omitempty"`
	Choosing bool                 `json:"choosing,omitempty"`
	Beats    map[string]BeatState `json:"beats"`
	Path     []string             `json:"path"`
}

type Quest struct {
	Key    string `json:"key"`
	Def    string `json:"def"`
	Holder ID     `json:"holder"`
	Bind   Bind   `json:"bind,omitempty"`
	State  string `json:"state"` // offered active done failed declined expired withdrawn obsolete superseded abandoned
	Giver  ID     `json:"giver,omitempty"`
	Region ID     `json:"region,omitempty"`
	At     Tick   `json:"at"`
	Title  string `json:"title"`
	Desc   string `json:"desc,omitempty"`

	Rank          string       `json:"rank,omitempty"`
	Objective     string       `json:"objective,omitempty"`
	Reward        string       `json:"reward,omitempty"`
	RewardDetails []RewardInfo `json:"rewardDetails,omitempty"`
	Penalty       string       `json:"penalty,omitempty"`
	Stage         string       `json:"stage,omitempty"`
	Deadline      Tick         `json:"deadline,omitempty"`
	Acknowledged  bool         `json:"acknowledged,omitempty"` // a delivered quest remains until answered or explicitly resolved
}

type Option struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Desc  string `json:"desc,omitempty"`
}

// Decision is a pending choice offered to an external advisor (Jev).
// The world never waits for it: at Due the Default applies.
type Decision struct {
	ID      string   `json:"id"`
	Kind    string   `json:"kind"` // offer | story | world | evolution | appearance | lineage | ability | dungeon
	Subject string   `json:"subject"`
	Options []Option `json:"options"`
	Default string   `json:"default"`
	Created Tick     `json:"created"`
	Due     Tick     `json:"due"`
	Context []string `json:"context,omitempty"`
}

type State struct {
	Universe    string                   `json:"universe"`
	Revision    int64                    `json:"revision"`
	Tick        Tick                     `json:"tick"`
	Seq         int64                    `json:"seq"`
	Entities    map[ID]Entity            `json:"entities"`
	Facts       map[string]Fact          `json:"facts"`
	Beliefs     map[ID]map[string]Belief `json:"beliefs"`
	Events      []Event                  `json:"events"`
	Schedules   []Scheduled              `json:"schedules"`
	Arcs        map[string]ArcState      `json:"arcs"`
	Quests      map[string]Quest         `json:"quests"`
	Declined    map[string]Tick          `json:"declined"`
	Decisions   map[string]Decision      `json:"decisions"`
	Cooldowns   map[string]Tick          `json:"cooldowns"`
	Receipts    map[string]int64         `json:"receipts"`
	Relations   map[string]int64         `json:"relations"`           // "a|b": what a feels about b
	Styles      map[ID]map[string]int64  `json:"styles"`              // play style learned per player
	Tension     int64                    `json:"tension"`             // world tension for pacing
	Skills      map[ID]map[string]Tick   `json:"skills"`              // learned skills and when
	Deeds       map[ID]map[string]int64  `json:"deeds"`               // how often each player did each thing
	Marks       []Mark                   `json:"marks"`               // symbols travellers left in places
	Lineages    map[ID]Differ            `json:"lineages,omitempty"`  // pending lineage offers
	Looks       map[ID]Look              `json:"looks,omitempty"`     // each player's procedural body
	Genomes     map[ID]Genome            `json:"genomes,omitempty"`   // expressed genes and pending mutation offers
	Delves      map[ID]Delve             `json:"delves,omitempty"`    // each player's current or last dungeon run
	Pops        map[string]PopState      `json:"pops,omitempty"`      // cohorts: headcount and fractions of work
	Ledger      map[string]int64         `json:"ledger,omitempty"`    // exogenous sources, sinks and births/deaths
	Conflicts   map[string]ConflictState `json:"conflicts,omitempty"` // persistent crises by instance id
	ConflictSeq int64                    `json:"conflictSeq,omitempty"`
	NPCs        map[ID]NPCState          `json:"npcs,omitempty"` // what each named NPC is doing
	Helps       map[string]HelpRequest   `json:"helps,omitempty"`
	HelpSeq     int64                    `json:"helpSeq,omitempty"`
	Memories    map[ID][]MemoryEpisode   `json:"memories,omitempty"` // each NPC's own memory
	Attention   string                   `json:"attention,omitempty"`
	AttentionAt Tick                     `json:"attentionAt,omitempty"`
	Reserved    map[string]ID            `json:"reserved,omitempty"` // exclusive task keys and who holds them
}

func factKey(holder ID, p string, s, o ID) string {
	return string(holder) + "|" + p + "|" + string(s) + "|" + string(o)
}

// Digest is a canonical hash of the whole state. encoding/json sorts map
// keys and every slice is kept in deterministic order, so a replay of the
// same command log must reproduce it byte for byte.
func (s State) Digest() string {
	b, err := json.Marshal(s)
	if err != nil {
		panic(err)
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func (s *State) Clone() State {
	c := *s
	c.Entities = make(map[ID]Entity, len(s.Entities))
	for k, e := range s.Entities {
		e.Num = maps.Clone(e.Num)
		e.Tag = maps.Clone(e.Tag)
		c.Entities[k] = e
	}
	c.Facts = maps.Clone(s.Facts)
	c.Beliefs = make(map[ID]map[string]Belief, len(s.Beliefs))
	for k, b := range s.Beliefs {
		c.Beliefs[k] = maps.Clone(b)
	}
	c.Events = slices.Clone(s.Events)
	c.Schedules = slices.Clone(s.Schedules)
	for i := range c.Schedules {
		c.Schedules[i].Bind = maps.Clone(c.Schedules[i].Bind)
	}
	c.Arcs = make(map[string]ArcState, len(s.Arcs))
	for k, a := range s.Arcs {
		a.Beats = maps.Clone(a.Beats)
		for id, b := range a.Beats {
			b.By = slices.Clone(b.By)
			a.Beats[id] = b
		}
		a.Path = slices.Clone(a.Path)
		c.Arcs[k] = a
	}
	c.Quests = make(map[string]Quest, len(s.Quests))
	for k, q := range s.Quests {
		q.Bind = maps.Clone(q.Bind)
		c.Quests[k] = q
	}
	c.Declined = maps.Clone(s.Declined)
	c.Decisions = make(map[string]Decision, len(s.Decisions))
	for k, d := range s.Decisions {
		d.Options = slices.Clone(d.Options)
		d.Context = slices.Clone(d.Context)
		c.Decisions[k] = d
	}
	c.Cooldowns = maps.Clone(s.Cooldowns)
	c.Receipts = maps.Clone(s.Receipts)
	c.Relations = maps.Clone(s.Relations)
	c.Styles = make(map[ID]map[string]int64, len(s.Styles))
	for k, v := range s.Styles {
		c.Styles[k] = maps.Clone(v)
	}
	c.Skills = make(map[ID]map[string]Tick, len(s.Skills))
	for k, v := range s.Skills {
		c.Skills[k] = maps.Clone(v)
	}
	c.Lineages = make(map[ID]Differ, len(s.Lineages))
	for k, d := range s.Lineages {
		d.Offer = slices.Clone(d.Offer)
		c.Lineages[k] = d
	}
	c.Looks = make(map[ID]Look, len(s.Looks))
	for k, l := range s.Looks {
		l.Axes = maps.Clone(l.Axes)
		l.Traits = maps.Clone(l.Traits)
		c.Looks[k] = l
	}
	c.Genomes = make(map[ID]Genome, len(s.Genomes))
	for k, g := range s.Genomes {
		g.Genes, g.Offer, g.Declined, g.Building, g.Library = slices.Clone(g.Genes), slices.Clone(g.Offer), slices.Clone(g.Declined), slices.Clone(g.Building), slices.Clone(g.Library)
		g.Builds = maps.Clone(g.Builds)
		c.Genomes[k] = g
	}
	c.Pops = clonePops(s.Pops)
	c.Ledger = maps.Clone(s.Ledger)
	if s.Conflicts != nil {
		c.Conflicts = cloneConflicts(s.Conflicts)
	}
	if s.NPCs != nil {
		c.NPCs, c.Helps, c.Memories, c.Reserved = cloneNPCs(s.NPCs), maps.Clone(s.Helps), cloneMemories(s.Memories), maps.Clone(s.Reserved)
	}
	c.Marks = slices.Clone(s.Marks)
	for i := range c.Marks {
		c.Marks[i].Agree = slices.Clone(c.Marks[i].Agree)
	}
	c.Deeds = make(map[ID]map[string]int64, len(s.Deeds))
	for k, v := range s.Deeds {
		c.Deeds[k] = maps.Clone(v)
	}
	return c
}

// NewState builds tick 0 from a compiled universe.
func NewState(w *World) State {
	u := w.U
	s := State{Universe: u.ID, Entities: map[ID]Entity{}, Facts: map[string]Fact{}, Beliefs: map[ID]map[string]Belief{},
		Arcs: map[string]ArcState{}, Quests: map[string]Quest{}, Declined: map[string]Tick{}, Decisions: map[string]Decision{},
		Cooldowns: map[string]Tick{}, Receipts: map[string]int64{}, Events: []Event{}, Schedules: []Scheduled{},
		Relations: map[string]int64{}, Styles: map[ID]map[string]int64{}, Skills: map[ID]map[string]Tick{}, Deeds: map[ID]map[string]int64{}, Marks: []Mark{}, Genomes: map[ID]Genome{}}
	for _, e := range u.Entities {
		s.Entities[e.ID] = newEntity(e)
	}
	for _, f := range u.Facts {
		s.Facts[factKey(f.Holder, f.P, f.S, f.O)] = Fact{Holder: f.Holder, P: f.P, S: f.S, O: f.O, Cause: "initial"}
	}
	for _, b := range u.Beliefs {
		s.believe(b.Who, Belief{P: b.P, S: b.S, O: b.O, Holds: !b.False, Source: "initial"})
	}
	for i, sc := range u.Schedules {
		s.Schedules = append(s.Schedules, Scheduled{Key: "initial:" + strconv.Itoa(i), Due: sc.At, Rule: sc.Rule, Cause: "initial"})
	}
	sortSchedules(s.Schedules)
	for _, a := range u.Arcs {
		st := ArcState{Current: a.Start, Beats: map[string]BeatState{}, Path: []string{a.Start}}
		for _, b := range a.Beats {
			st.Beats[b.ID] = BeatState{State: "locked"}
		}
		s.Arcs[a.ID] = st
	}
	if len(u.Populations) > 0 {
		w.initPopulations(&s)
		s.Ledger = map[string]int64{}
	}
	if len(u.Conflicts) > 0 {
		s.Conflicts = map[string]ConflictState{}
	}
	if len(u.Tasks) > 0 {
		s.NPCs, s.Helps, s.Memories, s.Reserved = map[ID]NPCState{}, map[string]HelpRequest{}, map[ID][]MemoryEpisode{}, map[string]ID{}
	}
	return s
}

func newEntity(e EntitySeed) Entity {
	n := Entity{ID: e.ID, Kind: e.Kind, Name: e.Name, Region: e.Region, Num: maps.Clone(e.Num), Tag: maps.Clone(e.Tag)}
	if n.Num == nil {
		n.Num = map[string]int64{}
	}
	if n.Tag == nil {
		n.Tag = map[string]string{}
	}
	if n.Name == "" {
		n.Name = string(e.ID)
	}
	return n
}

func (s *State) believe(who ID, b Belief) {
	if s.Beliefs[who] == nil {
		s.Beliefs[who] = map[string]Belief{}
	}
	s.Beliefs[who][factKey("", b.P, b.S, b.O)] = b
}

func sortSchedules(x []Scheduled) {
	slices.SortStableFunc(x, func(a, b Scheduled) int {
		if a.Due != b.Due {
			if a.Due < b.Due {
				return -1
			}
			return 1
		}
		return strings.Compare(a.Key, b.Key)
	})
}

func sortedKeys[V any](m map[string]V) []string {
	k := make([]string, 0, len(m))
	for x := range m {
		k = append(k, x)
	}
	slices.Sort(k)
	return k
}

func sortedIDs[V any](m map[ID]V) []ID {
	k := make([]ID, 0, len(m))
	for x := range m {
		k = append(k, x)
	}
	slices.Sort(k)
	return k
}

// Revive makes a state read back from JSON fit to run: empty maps and lists do
// not survive a round trip as empty (they come back nil), and the rules write
// into them. Each one the world allocates at the start is allocated again;
// nothing that holds data is touched, so the digest does not change. A test
// compares it with NewState field by field, so a new field cannot be forgotten.
func (w *World) Revive(s *State) {
	t := NewState(w)
	reviveMap(&s.Entities, t.Entities)
	reviveMap(&s.Facts, t.Facts)
	reviveMap(&s.Beliefs, t.Beliefs)
	reviveSlice(&s.Events, t.Events)
	reviveSlice(&s.Schedules, t.Schedules)
	reviveMap(&s.Arcs, t.Arcs)
	reviveMap(&s.Quests, t.Quests)
	reviveMap(&s.Declined, t.Declined)
	reviveMap(&s.Decisions, t.Decisions)
	reviveMap(&s.Cooldowns, t.Cooldowns)
	reviveMap(&s.Receipts, t.Receipts)
	reviveMap(&s.Relations, t.Relations)
	reviveMap(&s.Styles, t.Styles)
	reviveMap(&s.Skills, t.Skills)
	reviveMap(&s.Deeds, t.Deeds)
	reviveSlice(&s.Marks, t.Marks)
	reviveMap(&s.Lineages, t.Lineages)
	reviveMap(&s.Looks, t.Looks)
	reviveMap(&s.Genomes, t.Genomes)
	reviveMap(&s.Delves, t.Delves)
	reviveMap(&s.Pops, t.Pops)
	reviveMap(&s.Ledger, t.Ledger)
	reviveMap(&s.Conflicts, t.Conflicts)
	reviveMap(&s.NPCs, t.NPCs)
	reviveMap(&s.Helps, t.Helps)
	reviveMap(&s.Memories, t.Memories)
	reviveMap(&s.Reserved, t.Reserved)
}

func reviveMap[K comparable, V any](have *map[K]V, want map[K]V) {
	if *have == nil && want != nil {
		*have = map[K]V{}
	}
}

func reviveSlice[E any](have *[]E, want []E) {
	if *have == nil && want != nil {
		*have = []E{}
	}
}
