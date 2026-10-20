// Package core is the engine-agnostic world simulation kernel.
//
// It knows nothing about rendering, networking, storage, combat or any game
// genre. A universe declares kinds, predicates, actions, rules, agents, story
// arcs and quest templates; core executes them deterministically:
// Step(world, state, command) -> (state', delta).
//
// Ground truth (world facts) is separate from what each entity believes.
// Agents decide from their beliefs; the authority validates against the truth.
package core

// ID identifies an entity (player, NPC, place, object...).
type ID string

// Tick is world time. The world advances one tick per "tick" command,
// independently of any player session.
type Tick int64

// Bind maps template variables ("$self", "$npc"...) to entity IDs.
type Bind map[string]ID

// Universe is the declarative definition of a world. It is plain data so it
// can be loaded from JSON and validated before anything runs.
type Universe struct {
	Version     int          `json:"version"`
	ID          string       `json:"id"`
	Name        string       `json:"name"`
	Description string       `json:"description,omitempty"`
	Kinds       []string     `json:"kinds"`
	Predicates  []string     `json:"predicates"`
	PlayerKind  string       `json:"playerKind"`
	RegionKinds []string     `json:"regionKinds,omitempty"` // kinds whose entities are places
	Player      EntitySeed   `json:"player"`
	Perceivers  []string     `json:"perceivers"`
	Entities    []EntitySeed `json:"entities"`
	Facts       []FactSeed   `json:"facts,omitempty"`
	Beliefs     []BeliefSeed `json:"beliefs,omitempty"`
	Schedules   []Schedule   `json:"schedules,omitempty"`
	Actions     []ActionDef  `json:"actions"`
	Rules       []RuleDef    `json:"rules,omitempty"`
	Agents      []AgentDef   `json:"agents,omitempty"`
	Arcs        []ArcDef     `json:"arcs,omitempty"`
	Quests      []QuestDef   `json:"quests,omitempty"`
	Happenings  []Happening  `json:"happenings,omitempty"`
	Director    *Director    `json:"director,omitempty"`
	Limits      Limits       `json:"limits"`
}

// Happening is an optional world event. The director periodically gathers
// the happenings that make sense now and asks the advisor (Jev) which one
// occurs, keeping the shared world moving between and after story arcs.
type Happening struct {
	ID       string   `json:"id"`
	Title    string   `json:"title"`
	Desc     string   `json:"desc,omitempty"`
	When     Cond     `json:"when"`
	Effects  []Effect `json:"effects"`
	Cooldown Tick     `json:"cooldown,omitempty"`
}

// Director paces happenings. AllowNone lets the advisor keep things quiet.
type Director struct {
	Every     Tick `json:"every"`
	AllowNone bool `json:"allowNone,omitempty"`
}

type EntitySeed struct {
	ID     ID                `json:"id"`
	Kind   string            `json:"kind"`
	Name   string            `json:"name"`
	Region ID                `json:"region,omitempty"` // where it is; players start here
	Num    map[string]int64  `json:"num,omitempty"`
	Tag    map[string]string `json:"tag,omitempty"`
}

type FactSeed struct {
	Holder ID     `json:"holder,omitempty"`
	P      string `json:"p"`
	S      ID     `json:"s"`
	O      ID     `json:"o,omitempty"`
}

type BeliefSeed struct {
	Who   ID     `json:"who"`
	P     string `json:"p"`
	S     ID     `json:"s"`
	O     ID     `json:"o,omitempty"`
	False bool   `json:"false,omitempty"`
}

// Schedule runs a rule at an absolute tick (initial world events).
type Schedule struct {
	Rule string `json:"rule"`
	At   Tick   `json:"at"`
}

// Limits encode the product rules that keep the world readable for players.
type Limits struct {
	MaxActiveQuests int  `json:"maxActiveQuests"`        // per player; GameVision: 1
	DecisionTimeout Tick `json:"decisionTimeout"`        // ticks before the deterministic default applies
	DeclineCooldown Tick `json:"declineCooldown"`        // a declined offer is not proposed again before this
	OfferExpiry     Tick `json:"offerExpiry"`            // an ignored offer expires
	MaxEvents       int  `json:"maxEvents"`              // chronicle retention
	AllowAbandon    bool `json:"allowAbandon,omitempty"` // false: an accepted quest must be finished
	QuestGap        Tick `json:"questGap,omitempty"`     // quiet ticks after a quest ends before the next offer
}

// Pattern addresses a fact. Private facts belong to $self.
type Pattern struct {
	P       string `json:"p"`
	S       string `json:"s"`
	O       string `json:"o,omitempty"`
	Private bool   `json:"private,omitempty"`
}

// Cond is a condition tree. Exactly one field is set per node; the zero
// value is "always true".
type Cond struct {
	All   []Cond   `json:"all,omitempty"`
	Any   []Cond   `json:"any,omitempty"`
	Not   *Cond    `json:"not,omitempty"`
	Fact  *Pattern `json:"fact,omitempty"`
	Knows *Knows   `json:"knows,omitempty"`
	Num   *NumCmp  `json:"num,omitempty"`
	Tag   *TagCmp  `json:"tag,omitempty"`
	Beat  *BeatCmp `json:"beat,omitempty"`
	In    *InCmp   `json:"in,omitempty"`
	Near  *NearCmp `json:"near,omitempty"`
}

// InCmp holds when entity E is in region Region.
type InCmp struct {
	E      string `json:"e"`
	Region string `json:"region"`
}

// NearCmp holds when A is in the same region as B, or inside B when B is a region.
type NearCmp struct {
	A string `json:"a"`
	B string `json:"b"`
}

// Knows holds when Who (default $self) believes the world fact holds.
// False=true asks for a belief that the fact does NOT hold.
type Knows struct {
	Who   string `json:"who,omitempty"`
	P     string `json:"p"`
	S     string `json:"s"`
	O     string `json:"o,omitempty"`
	False bool   `json:"false,omitempty"`
}

type NumCmp struct {
	E  string `json:"e"`
	K  string `json:"k"`
	Op string `json:"op"`
	V  int64  `json:"v"`
}

type TagCmp struct {
	E string `json:"e"`
	K string `json:"k"`
	V string `json:"v"`
}

type BeatCmp struct {
	Arc   string `json:"arc"`
	Beat  string `json:"beat"`
	State string `json:"state"` // locked | open | claimed
}

// Effect is one of a closed set of operations. Universes cannot inject code.
type Effect struct {
	Op      string   `json:"op"` // assert retract adjust set observe inform schedule emit relocate
	Fact    *Pattern `json:"fact,omitempty"`
	E       string   `json:"e,omitempty"`
	K       string   `json:"k,omitempty"`
	D       int64    `json:"d,omitempty"`
	Min     *int64   `json:"min,omitempty"`
	Max     *int64   `json:"max,omitempty"`
	V       string   `json:"v,omitempty"`
	To      string   `json:"to,omitempty"`
	Rule    string   `json:"rule,omitempty"`
	After   Tick     `json:"after,omitempty"`
	Event   string   `json:"event,omitempty"`
	Text    string   `json:"text,omitempty"`
	Public  bool     `json:"public,omitempty"`
	Reveals *Pattern `json:"reveals,omitempty"`
	If      *Cond    `json:"if,omitempty"` // apply only when this holds
}

type Param struct {
	Name string `json:"name"`
	Kind string `json:"kind"`
}

// ActionDef is something an actor may attempt. By lists who may submit it:
// "player" (a client intention), "agent" (an NPC), "adapter" (a trusted game
// server confirming an occurrence such as a defeated creature).
type ActionDef struct {
	ID       string   `json:"id"`
	By       []string `json:"by"`
	Params   []Param  `json:"params,omitempty"`
	Requires Cond     `json:"requires"`
	Effects  []Effect `json:"effects"`
	Desc     string   `json:"desc,omitempty"`
}

// RuleDef is autonomous world dynamics: periodic (Every) and/or scheduled.
type RuleDef struct {
	ID      string   `json:"id"`
	Every   Tick     `json:"every,omitempty"`
	ForEach string   `json:"forEach,omitempty"` // kind; binds $it
	When    Cond     `json:"when"`
	Effects []Effect `json:"effects"`
	Desc    string   `json:"desc,omitempty"`
}

type AgentDef struct {
	Entity ID        `json:"entity"`
	Think  Tick      `json:"think,omitempty"`
	Goals  []GoalDef `json:"goals"`
}

// GoalDef: when When holds (usually through the beliefs of the agent), try Action.
type GoalDef struct {
	ID       string            `json:"id"`
	Priority int               `json:"priority"`
	When     Cond              `json:"when"`
	Action   string            `json:"action"`
	Args     map[string]string `json:"args,omitempty"`
	Cooldown Tick              `json:"cooldown,omitempty"`
}

// ArcDef is a world story: a DAG of beats. The world has one canonical
// history; which branch comes next is decided when a beat is claimed.
type ArcDef struct {
	ID    string    `json:"id"`
	Title string    `json:"title"`
	Start string    `json:"start"`
	Beats []BeatDef `json:"beats"`
}

// BeatDef is a chapter of a world story. A Unique beat is a "unique
// scenario": many players may pursue it in parallel, but only the first to
// satisfy Goal claims it. Every other contender receives Rival effects so
// their story continues differently instead of being erased.
// A shared (non-unique) beat can be completed by everyone; the arc advances
// when AdvanceWhen holds.
type BeatDef struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Desc        string   `json:"desc,omitempty"`
	Unique      bool     `json:"unique,omitempty"`
	Opens       Cond     `json:"opens"`
	Goal        Cond     `json:"goal"`
	Claim       []Effect `json:"claim,omitempty"`
	Rival       []Effect `json:"rival,omitempty"`
	Contender   *Cond    `json:"contender,omitempty"` // players pursuing it without the quest also become rivals
	Next        []string `json:"next,omitempty"`
	AdvanceWhen *Cond    `json:"advanceWhen,omitempty"`
}

type QuestParam struct {
	Name  string `json:"name"`
	Kind  string `json:"kind"`
	Where Cond   `json:"where"` // $it is the candidate
}

// QuestDef is a template for personal opportunities. Bindings make the same
// template produce different quests for different players.
type QuestDef struct {
	ID       string       `json:"id"`
	Title    string       `json:"title"`
	Desc     string       `json:"desc,omitempty"`
	Arc      string       `json:"arc,omitempty"` // with Beat: this quest pursues a story beat
	Beat     string       `json:"beat,omitempty"`
	Giver    string       `json:"giver,omitempty"`  // NPC who reaches out to the player, wherever they are
	Region   string       `json:"region,omitempty"` // optional: offered only while the player is in this region
	Eligible Cond         `json:"eligible"`
	Params   []QuestParam `json:"params,omitempty"`
	Goal     Cond         `json:"goal"`
	Rewards  []Effect     `json:"rewards,omitempty"`
	Repeat   bool         `json:"repeat,omitempty"`

	// What the system window shows (all rendered with the bindings).
	Rank      string `json:"rank,omitempty"`      // e.g. F..S, SS, SSS
	Objective string `json:"objective,omitempty"` // what to do
	Reward    string `json:"reward,omitempty"`    // what you get
	Penalty   string `json:"penalty,omitempty"`   // failure or refusal consequence

	// A living quest: stages replace title, objective, rank and goal when
	// the world changes while it is active (forward only, first match wins).
	Stages      []QuestStage `json:"stages,omitempty"`
	Fail        *Cond        `json:"fail,omitempty"`        // the quest fails when this holds
	FailEffects []Effect     `json:"failEffects,omitempty"` // applied on failure or timeout
	OnDecline   []Effect     `json:"onDecline,omitempty"`   // refusing has consequences
	TimeLimit   Tick         `json:"timeLimit,omitempty"`   // ticks after acceptance
}

// QuestStage is a turn of events inside an accepted quest.
type QuestStage struct {
	ID        string   `json:"id"`
	When      Cond     `json:"when"`
	Title     string   `json:"title,omitempty"`
	Desc      string   `json:"desc,omitempty"`
	Objective string   `json:"objective,omitempty"`
	Rank      string   `json:"rank,omitempty"`
	Goal      *Cond    `json:"goal,omitempty"`
	Effects   []Effect `json:"effects,omitempty"`
}
