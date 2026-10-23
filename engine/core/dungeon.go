package core

import (
	"hash/fnv"
	"slices"
	"strconv"
	"strings"
)

// Dungeons: places a player enters on purpose, made of rooms to clear one after another and a final one with a boss.
// The universe says what a dungeon is (rooms, modifiers, rewards); the engine keeps the run per player, decides nothing
// about combat and trusts only confirmed happenings: the game server tells it a room was cleared, or that the run
// failed. The modifiers of a run (for example "in a fever") are chosen by the advisor from the ones that apply to this
// player, revalidated, with a deterministic default at the deadline. The seed of the run comes from the engine, so
// everyone in the same run sees the same dungeon.

const (
	actEnterDungeon = "entrar-masmorra"    // player; args: dungeon
	actClearRoom    = "sala-limpa"         // adapter: the current room was cleared
	actFailDungeon  = "falhar-masmorra"    // adapter: the run failed (the cell died)
	actLeaveDungeon = "abandonar-masmorra" // player: leaves a run
)

// DungeonDef is a kind of dungeon.
type DungeonDef struct {
	ID         string        `json:"id"`
	Name       string        `json:"name"`
	Desc       string        `json:"desc"`
	Region     string        `json:"region"`             // where its entrance is
	Eligible   *Cond         `json:"eligible,omitempty"` // $self is the player
	Rooms      []RoomDef     `json:"rooms"`
	Pool       []RoomDef     `json:"pool,omitempty"`  // procedural dungeon: the first of Rooms opens it, the last closes it (the boss) and a run draws the rooms between them from here
	Depth      []int         `json:"depth,omitempty"` // with a pool: [min, max] rooms drawn between the opening and the boss
	Modifiers  []ModifierDef `json:"modifiers,omitempty"`
	Rewards    []Effect      `json:"rewards,omitempty"`    // every clear, $self is the player
	FirstClear []Effect      `json:"firstClear,omitempty"` // only the first clear in the world: a unique scenario
	FirstText  string        `json:"firstText,omitempty"`  // public chronicle line for it
	Retry      Tick          `json:"retry,omitempty"`      // ticks before the same player may enter again
}

// RoomDef is one room: kind is a hint for the game server (guard, wall, core, boss).
type RoomDef struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Desc string `json:"desc,omitempty"`
	Kind string `json:"kind,omitempty"`
}

// ModifierDef changes a run (the game server reads its id). Tags are the play style it suits.
type ModifierDef struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Desc     string   `json:"desc"`
	Tags     []string `json:"tags,omitempty"`
	Eligible *Cond    `json:"eligible,omitempty"`
}

// Delve is a player's run: preparing (the modifier is being decided), active, cleared or failed.
type Delve struct {
	Dungeon  string    `json:"dungeon"`
	State    string    `json:"state"`
	Seed     int64     `json:"seed"`
	Modifier string    `json:"modifier,omitempty"`
	Room     int       `json:"room"`
	Started  Tick      `json:"started"`
	Rooms    []RoomDef `json:"rooms,omitempty"` // the rooms of this run when the dungeon is procedural (drawn from the seed)
}

// DungeonView is what a player sees of the dungeons.
type DungeonView struct {
	Available []DungeonOption `json:"available"`
	Run       *RunView        `json:"run,omitempty"`
}

type DungeonOption struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Desc     string `json:"desc"`
	Region   string `json:"region"`
	Rooms    int    `json:"rooms"`
	Eligible bool   `json:"eligible"` // true when this player may enter now
}

type RunView struct {
	Dungeon  string     `json:"dungeon"`
	Name     string     `json:"name"`
	State    string     `json:"state"`
	Seed     int64      `json:"seed"`
	Modifier *RunMod    `json:"modifier,omitempty"`
	Room     int        `json:"room"`
	Rooms    []RoomView `json:"rooms"`
}

type RunMod struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Desc string `json:"desc"`
}

type RoomView struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Desc string `json:"desc,omitempty"`
	Kind string `json:"kind,omitempty"`
}

func (w *World) dungeon(id string) (DungeonDef, bool) {
	i := slices.IndexFunc(w.U.Dungeons, func(d DungeonDef) bool { return d.ID == id })
	if i < 0 {
		return DungeonDef{}, false
	}
	return w.U.Dungeons[i], true
}

func (w *World) compileDungeons(v *validator) error {
	seen := map[string]bool{}
	for _, d := range w.U.Dungeons {
		if !validID(d.ID) || seen[d.ID] || d.Name == "" || !w.regions[v.ents[ID(d.Region)]] || len(d.Rooms) == 0 || d.Retry < 0 {
			return invalid("dungeon %q", d.ID)
		}
		seen[d.ID] = true
		rooms := map[string]bool{}
		if len(d.Pool) > 0 {
			if len(d.Rooms) < 2 || len(d.Depth) != 2 || d.Depth[0] < 1 || d.Depth[1] < d.Depth[0] || d.Depth[1] > len(d.Pool) {
				return invalid("dungeon %s: a pool needs an opening and a boss in rooms, and depth [min, max] within the pool", d.ID)
			}
		}
		for _, r := range append(slices.Clone(d.Rooms), d.Pool...) {
			if !validID(r.ID) || r.Name == "" || rooms[r.ID] {
				return invalid("dungeon %s: room %q", d.ID, r.ID)
			}
			rooms[r.ID] = true
		}
		mods := map[string]bool{}
		for _, m := range d.Modifiers {
			if !validID(m.ID) || m.Name == "" || mods[m.ID] {
				return invalid("dungeon %s: modifier %q", d.ID, m.ID)
			}
			mods[m.ID] = true
			if m.Eligible != nil {
				if e := v.cond(*m.Eligible, map[string]bool{"self": true}, "dungeon "+d.ID+" modifier "+m.ID); e != nil {
					return e
				}
			}
		}
		if d.Eligible != nil {
			if e := v.cond(*d.Eligible, map[string]bool{"self": true}, "dungeon "+d.ID); e != nil {
				return e
			}
		}
		if e := v.effects(d.Rewards, map[string]bool{"self": true}, "dungeon "+d.ID+" rewards"); e != nil {
			return e
		}
		if e := v.effects(d.FirstClear, map[string]bool{"self": true}, "dungeon "+d.ID+" first clear"); e != nil {
			return e
		}
	}
	if len(w.U.Dungeons) > 0 {
		for _, reserved := range []string{actEnterDungeon, actClearRoom, actFailDungeon, actLeaveDungeon} {
			if _, taken := w.actions[reserved]; taken {
				return invalid("action id %q is reserved by the engine", reserved)
			}
		}
	}
	return nil
}

// composeRooms is the sequence of rooms of one run. A fixed dungeon is always the same rooms; a procedural one opens with its first room,
// closes with its last (the boss) and draws between them, from the seed of the run, a number of rooms of its pool: two runs differ in
// length, in which rooms they have and in what order, and everyone who shares the seed shares the dungeon.
func composeRooms(def DungeonDef, seed int64) []RoomDef {
	if len(def.Pool) == 0 {
		return slices.Clone(def.Rooms)
	}
	state := uint64(seed)*2862933555777941757 + 3037000493
	next := func(n int) int { // a small deterministic generator: the engine never depends on a library's sequence
		state ^= state << 13
		state ^= state >> 7
		state ^= state << 17
		return int((state >> 11) % uint64(n))
	}
	pool := slices.Clone(def.Pool)
	n := def.Depth[0] + next(def.Depth[1]-def.Depth[0]+1)
	out := []RoomDef{def.Rooms[0]}
	for i := 0; i < n; i++ {
		k := next(len(pool))
		out = append(out, pool[k])
		pool = slices.Delete(pool, k, k+1)
	}
	return append(out, def.Rooms[len(def.Rooms)-1])
}

func (w *World) seedOf(s *State, p ID, dungeon string) int64 {
	h := fnv.New64a()
	h.Write([]byte(string(p) + "|" + dungeon + "|" + strconv.FormatInt(int64(s.Tick), 10)))
	return int64(h.Sum64() >> 1)
}

// runModifiers are the modifiers that may apply to this player's next run.
func (w *World) runModifiers(s *State, p ID, d DungeonDef) []ModifierDef {
	out := []ModifierDef{}
	for _, m := range d.Modifiers {
		if m.Eligible == nil || w.Holds(s, *m.Eligible, Bind{"self": p}) {
			out = append(out, m)
		}
	}
	return out
}

func (w *World) mayEnter(s *State, p ID, d DungeonDef) bool {
	e, ok := s.Entities[p]
	if !ok || e.Kind != w.U.PlayerKind || string(e.Region) != d.Region {
		return false
	}
	if run, has := s.Delves[p]; has && (run.State == "preparing" || run.State == "active") {
		return false
	}
	if end, has := s.Receipts["delve-end|"+string(p)]; has && s.Tick < Tick(end)+d.Retry {
		return false
	}
	return d.Eligible == nil || w.Holds(s, *d.Eligible, Bind{"self": p})
}

// enterDungeon is the player's intention to go in. The run prepares while the advisor picks its modifier.
func (w *World) enterDungeon(s *State, origin string, p ID, args map[string]ID, cause string) error {
	d, ok := w.dungeon(string(args["dungeon"]))
	if origin != "player" || !ok || !w.mayEnter(s, p, d) {
		return reject("dungeon")
	}
	if s.Delves == nil {
		s.Delves = map[ID]Delve{}
	}
	s.Delves[p] = Delve{Dungeon: d.ID, State: "preparing", Seed: w.seedOf(s, p, d.ID), Started: s.Tick}
	w.count(s, p, actEnterDungeon)
	mods := w.runModifiers(s, p, d)
	switch len(mods) {
	case 0:
		w.beginRun(s, p, "", cause)
	case 1:
		w.beginRun(s, p, mods[0].ID, cause)
	default:
		opts := make([]Option, 0, len(mods))
		for _, m := range mods {
			desc := m.Desc
			if len(m.Tags) > 0 {
				desc += " [suits: " + strings.Join(m.Tags, ", ") + "]"
			}
			opts = append(opts, Option{ID: m.ID, Title: m.Name, Desc: desc})
		}
		id := "dungeon:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
		ctx := w.profile(s, p)
		ctx = append(ctx, "entering "+d.Name+": "+d.Desc)
		if w.U.Evolution != nil {
			ctx = append(ctx, w.genomeText(s, p))
		}
		s.Decisions[id] = Decision{ID: id, Kind: "dungeon", Subject: string(p), Options: opts, Default: mods[0].ID,
			Created: s.Tick, Due: s.Tick + 1, Context: ctx}
		w.emit(s, Event{Kind: "dungeon-preparing", Holder: p, Text: d.Name, Cause: cause, Data: map[string]string{"dungeon": d.ID}})
	}
	return nil
}

// decideDungeon starts the run with the advisor's modifier after revalidating it.
func (w *World) decideDungeon(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	run, has := s.Delves[p]
	def, ok := w.dungeon(run.Dungeon)
	if !has || !ok || run.State != "preparing" || !slices.ContainsFunc(w.runModifiers(s, p, def), func(m ModifierDef) bool { return m.ID == choice }) {
		return reject("choice no longer valid")
	}
	delete(s.Decisions, d.ID)
	w.beginRun(s, p, choice, cause)
	return nil
}

func (w *World) beginRun(s *State, p ID, modifier, cause string) {
	run := s.Delves[p]
	def, _ := w.dungeon(run.Dungeon)
	run.State, run.Modifier, run.Room = "active", modifier, 0
	run.Rooms = composeRooms(def, run.Seed)
	s.Delves[p] = run
	w.emit(s, Event{Kind: "dungeon-started", Holder: p, Text: def.Name, Cause: cause,
		Data: map[string]string{"dungeon": run.Dungeon, "seed": strconv.FormatInt(run.Seed, 10), "modifier": modifier, "rooms": strconv.Itoa(len(run.Rooms))}})
}

// dungeonTick starts any run whose decision vanished (a default that was no longer valid) with the first valid modifier.
func (w *World) dungeonTick(s *State, cause string) {
	for _, p := range sortedIDs(s.Entities) {
		run, has := s.Delves[p]
		if !has || run.State != "preparing" {
			continue
		}
		if slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == "dungeon" && s.Decisions[k].Subject == string(p)
		}) {
			continue
		}
		def, _ := w.dungeon(run.Dungeon)
		mods := w.runModifiers(s, p, def)
		first := ""
		if len(mods) > 0 {
			first = mods[0].ID
		}
		w.beginRun(s, p, first, cause)
	}
}

// clearRoom is the game server confirming the current room was cleared. The last one completes the dungeon.
func (w *World) clearRoom(s *State, origin string, p ID, cause string) error {
	run, has := s.Delves[p]
	def, ok := w.dungeon(run.Dungeon)
	if origin != "adapter" || !has || !ok || run.State != "active" {
		return reject("room")
	}
	if len(run.Rooms) == 0 {
		run.Rooms = def.Rooms // a run saved before rooms were drawn per run
	}
	run.Room++
	s.Delves[p] = run
	w.emit(s, Event{Kind: "dungeon-room", Holder: p, Text: run.Rooms[run.Room-1].Name, Cause: cause,
		Data: map[string]string{"dungeon": def.ID, "room": strconv.Itoa(run.Room), "of": strconv.Itoa(len(run.Rooms))}})
	if run.Room < len(run.Rooms) {
		return nil
	}
	run.State = "cleared"
	s.Delves[p] = run
	s.Receipts["delve-end|"+string(p)] = int64(s.Tick)
	w.count(s, p, actClearRoom)
	b := Bind{"self": p}
	w.apply(s, def.Rewards, b, cause)
	if first := "dungeon-first|" + def.ID; s.Receipts[first] == 0 {
		s.Receipts[first] = 1
		w.apply(s, def.FirstClear, b, cause)
		if def.FirstText != "" {
			w.emit(s, Event{Kind: "dungeon-first", Actor: p, Holder: p, Public: true, Text: s.Entities[p].Name + " " + def.FirstText, Cause: cause, Data: map[string]string{"dungeon": def.ID}})
		}
	}
	w.emit(s, Event{Kind: "dungeon-cleared", Holder: p, Text: def.Name, Cause: cause, Data: map[string]string{"dungeon": def.ID}})
	w.discover(s, p, cause)
	return nil
}

// failRun is the game server confirming that the cell fell in the dungeon.
func (w *World) failRun(s *State, origin string, p ID, cause string) error {
	run, has := s.Delves[p]
	def, ok := w.dungeon(run.Dungeon)
	if origin != "adapter" || !has || !ok || run.State != "active" {
		return reject("run")
	}
	run.State = "failed"
	s.Delves[p] = run
	s.Receipts["delve-end|"+string(p)] = int64(s.Tick)
	w.emit(s, Event{Kind: "dungeon-failed", Holder: p, Text: def.Name, Cause: cause, Data: map[string]string{"dungeon": def.ID, "room": strconv.Itoa(run.Room)}})
	return nil
}

// leaveRun is the player giving up a run.
func (w *World) leaveRun(s *State, origin string, p ID, cause string) error {
	run, has := s.Delves[p]
	if origin != "player" || !has || (run.State != "active" && run.State != "preparing") {
		return reject("run")
	}
	for k, d := range s.Decisions {
		if d.Kind == "dungeon" && d.Subject == string(p) {
			delete(s.Decisions, k)
		}
	}
	run.State = "failed"
	s.Delves[p] = run
	def, _ := w.dungeon(run.Dungeon)
	w.emit(s, Event{Kind: "dungeon-left", Holder: p, Text: def.Name, Cause: cause, Data: map[string]string{"dungeon": def.ID}})
	return nil
}

func (w *World) dungeonView(s *State, p ID) *DungeonView {
	if len(w.U.Dungeons) == 0 || s.Entities[p].Kind != w.U.PlayerKind {
		return nil
	}
	v := &DungeonView{Available: []DungeonOption{}}
	for _, d := range w.U.Dungeons {
		v.Available = append(v.Available, DungeonOption{ID: d.ID, Name: d.Name, Desc: d.Desc, Region: d.Region, Rooms: len(d.Rooms) + maxDepth(d), Eligible: w.mayEnter(s, p, d)})
	}
	if run, has := s.Delves[p]; has {
		def, _ := w.dungeon(run.Dungeon)
		rv := &RunView{Dungeon: run.Dungeon, Name: def.Name, State: run.State, Seed: run.Seed, Room: run.Room, Rooms: []RoomView{}}
		if len(run.Rooms) == 0 {
			run.Rooms = def.Rooms
		}
		for _, r := range run.Rooms {
			rv.Rooms = append(rv.Rooms, RoomView{ID: r.ID, Name: r.Name, Desc: r.Desc, Kind: r.Kind})
		}
		if i := slices.IndexFunc(def.Modifiers, func(m ModifierDef) bool { return m.ID == run.Modifier }); i >= 0 {
			m := def.Modifiers[i]
			rv.Modifier = &RunMod{ID: m.ID, Name: m.Name, Desc: m.Desc}
		}
		v.Run = rv
	}
	return v
}

// maxDepth is how many rooms a run of d can have between its opening and its boss (0 for a fixed dungeon).
func maxDepth(d DungeonDef) int {
	if len(d.Pool) == 0 {
		return 0
	}
	return d.Depth[1]
}
