package core

import (
	"maps"
	"slices"
	"strconv"
)

// TaskDef is a job a named NPC does on its own. The NPC starts it when its
// need holds (When, with $self bound to the NPC), walks the route region by
// region (each leg takes Ticks), applies the step's effects on arrival and
// finishes with Success. A task is never decoration: its steps are effects on
// the world, so it only matters if the world changes.
type TaskDef struct {
	ID       string    `json:"id"`
	NPC      ID        `json:"npc"`
	Title    string    `json:"title"`
	Priority int       `json:"priority"`
	When     Cond      `json:"when"` // the real need, with $self = the NPC
	Route    []StepDef `json:"route"`
	// Reserve makes the task exclusive: while another NPC holds the key, this
	// one replans to something else instead of crowding the same job.
	Reserve string `json:"reserve,omitempty"`
	// Conflict names the conflict definition this task serves, so the body's
	// attention can favour it.
	Conflict string    `json:"conflict,omitempty"`
	Block    *BlockDef `json:"block,omitempty"`
	Cooldown Tick      `json:"cooldown,omitempty"`
	Success  []Effect  `json:"success,omitempty"`
}

// StepDef is one leg: go to Region (Ticks long), then apply Do.
type StepDef struct {
	Region ID       `json:"region"`
	Ticks  Tick     `json:"ticks,omitempty"`
	Doing  string   `json:"doing,omitempty"` // shown while on the way and working
	Do     []Effect `json:"do,omitempty"`
}

// BlockDef is an obstruction: before the NPC enters Via, if When holds the way
// is shut. It tries Detour first; with none (or when that is blocked too) it
// waits, asks for help after HelpAfter ticks and gives up after GiveUpAfter.
type BlockDef struct {
	Via         ID        `json:"via"`
	When        Cond      `json:"when"`
	Detour      []StepDef `json:"detour,omitempty"`
	HelpAfter   Tick      `json:"helpAfter"`
	GiveUpAfter Tick      `json:"giveUpAfter"`
	// Need is a short code of what is wrong and Say the line the NPC says,
	// built from the confirmed state ({self}); nothing else is invented.
	Need         string `json:"need"`
	Say          string `json:"say"`
	HelpCooldown Tick   `json:"helpCooldown,omitempty"`
}

// NPC phases.
const (
	NPCIdle     = "idle"
	NPCTravel   = "travel"
	NPCBlocked  = "blocked"
	NPCSeekHelp = "seek_help"
	NPCDeciding = "deciding" // waiting for the advisor or the default
)

// NPCState is the persisted mind of a named NPC: what it is doing, where in the
// route, since when. Everything else it "knows" lives in beliefs and memory.
type NPCState struct {
	Task     string `json:"task,omitempty"`
	Step     int    `json:"step"`
	Phase    string `json:"phase"`
	Since    Tick   `json:"since"`
	Arrive   Tick   `json:"arrive,omitempty"`
	Detour   bool   `json:"detour,omitempty"`
	Blocked  Tick   `json:"blocked,omitempty"`
	Help     string `json:"help,omitempty"`     // open help request id
	Decision string `json:"decision,omitempty"` // pending deliberation
	Done     int64  `json:"done"`
	Failed   int64  `json:"failed"`
	Replans  int64  `json:"replans"`
}

// HelpRequest is a real need an NPC could not meet by itself. It exists only
// while the cause does; it is not a quest and nobody has to accept it.
type HelpRequest struct {
	ID     string `json:"id"`
	NPC    ID     `json:"npc"`
	Task   string `json:"task"`
	Need   string `json:"need"`
	Region ID     `json:"region"`
	Text   string `json:"text"`
	Open   Tick   `json:"open"`
	Status string `json:"status"` // open answered resolved expired
	By     ID     `json:"by,omitempty"`
	Closed Tick   `json:"closed,omitempty"`
}

// MemoryEpisode is one thing an NPC lived through, with where it came from.
type MemoryEpisode struct {
	Kind     string `json:"kind"` // ajuda-recebida rota-interrompida
	Subject  ID     `json:"subject,omitempty"`
	Tick     Tick   `json:"tick"`
	Seq      int64  `json:"seq"` // the event that proves it
	Salience int64  `json:"salience"`
	Region   ID     `json:"region,omitempty"`
}

const maxMemories = 16

func (w *World) compileTasks(v *validator, ents map[ID]string) error {
	w.tasks = map[string]TaskDef{}
	w.npcTasks = map[ID][]TaskDef{}
	for _, t := range w.U.Tasks {
		where := "task " + t.ID
		if t.ID == "" || w.tasks[t.ID].ID != "" || !validID(t.ID) || t.Title == "" || len(t.Route) == 0 || ents[t.NPC] == "" || ents[t.NPC] == w.U.PlayerKind || t.Cooldown < 0 {
			return invalid("%s: id, npc, title or route", where)
		}
		vars := map[string]bool{"self": true}
		if e := v.cond(t.When, vars, where); e != nil {
			return e
		}
		steps := slices.Clone(t.Route)
		if t.Conflict != "" {
			if _, known := w.conflicts[t.Conflict]; !known {
				return invalid("%s: unknown conflict %q", where, t.Conflict)
			}
		}
		if b := t.Block; b != nil {
			if !w.regions[ents[b.Via]] || b.HelpAfter < 1 || b.GiveUpAfter <= b.HelpAfter || b.Need == "" || b.Say == "" || b.HelpCooldown < 0 {
				return invalid("%s: block", where)
			}
			if e := v.cond(b.When, vars, where+" block"); e != nil {
				return e
			}
			steps = append(steps, b.Detour...)
		}
		for i, st := range steps {
			if !w.regions[ents[st.Region]] || st.Ticks < 0 {
				return invalid("%s: step %d region/ticks", where, i)
			}
			if e := v.effects(st.Do, vars, where); e != nil {
				return e
			}
		}
		if e := v.effects(t.Success, vars, where); e != nil {
			return e
		}
		w.tasks[t.ID] = t
		w.npcTasks[t.NPC] = append(w.npcTasks[t.NPC], t)
	}
	for id, list := range w.npcTasks {
		slices.SortStableFunc(list, func(a, b TaskDef) int { return b.Priority - a.Priority })
		w.npcTasks[id] = list
	}
	return nil
}

// npcTick advances every NPC with tasks, in id order, once per tick. It needs
// no player, no advisor and no clock.
func (w *World) npcTick(s *State, cause string) {
	if len(w.npcTasks) == 0 {
		return
	}
	ids := make([]ID, 0, len(w.npcTasks))
	for id := range w.npcTasks {
		ids = append(ids, id)
	}
	slices.Sort(ids)
	for _, id := range ids {
		if _, alive := s.Entities[id]; !alive {
			continue
		}
		st := s.NPCs[id]
		if st.Phase == "" {
			st.Phase, st.Since = NPCIdle, s.Tick
		}
		w.npcStep(s, id, &st, cause)
		s.NPCs[id] = st
	}
}

func (w *World) npcStep(s *State, id ID, st *NPCState, cause string) {
	switch st.Phase {
	case NPCIdle:
		w.startTask(s, id, st, cause)
	case NPCDeciding:
		if _, open := s.Decisions[st.Decision]; !open { // answered elsewhere or dropped
			st.Phase, st.Decision, st.Since = NPCIdle, "", s.Tick
		}
	case NPCTravel:
		for st.Phase == NPCTravel && s.Tick >= st.Arrive {
			w.arrive(s, id, st, cause)
		}
	case NPCBlocked, NPCSeekHelp:
		w.waitBlocked(s, id, st, cause)
	}
}

func (w *World) startTask(s *State, id ID, st *NPCState, cause string) {
	if s.Cooldowns["wait|"+string(id)] > s.Tick {
		return
	}
	var ok []TaskDef
	for _, t := range w.npcTasks[id] {
		if w.eligible(s, id, t) {
			ok = append(ok, t)
		} else if t.Reserve != "" && s.Reserved[t.Reserve] != "" && s.Reserved[t.Reserve] != id && s.Cooldowns["task|"+string(id)+"|"+t.ID] <= s.Tick && w.Holds(s, t.When, Bind{"self": id}) {
			st.Replans++ // someone else is on it: replan instead of crowding
		}
	}
	if att := w.attentionDef(s); att != "" {
		slices.SortStableFunc(ok, func(a, b TaskDef) int { return w.effectivePriority(b, att) - w.effectivePriority(a, att) })
	}
	if len(ok) == 0 || w.deliberate(s, id, st, ok) {
		return
	}
	w.beginTask(s, id, st, ok[0], cause)
}

func (w *World) effectivePriority(t TaskDef, attention string) int {
	if attention != "" && t.Conflict == attention {
		return t.Priority + attentionBonus
	}
	return t.Priority
}

func (w *World) beginTask(s *State, id ID, st *NPCState, t TaskDef, cause string) {
	if t.Reserve != "" {
		s.Reserved[t.Reserve] = id
	}
	st.Task, st.Step, st.Detour, st.Phase, st.Since, st.Blocked = t.ID, 0, false, NPCTravel, s.Tick, 0
	w.depart(s, id, st, cause)
	for st.Phase == NPCTravel && s.Tick >= st.Arrive {
		w.arrive(s, id, st, cause)
	}
}

func (st *NPCState) route(t TaskDef) []StepDef {
	if st.Detour && t.Block != nil {
		return t.Block.Detour
	}
	return t.Route
}

// depart starts the leg st.Step, or turns the NPC around when the way is shut.
func (w *World) depart(s *State, id ID, st *NPCState, cause string) {
	t := w.tasks[st.Task]
	step := st.route(t)[st.Step]
	if b := t.Block; b != nil && step.Region == b.Via && w.Holds(s, b.When, Bind{"self": id}) {
		if !st.Detour && len(b.Detour) > 0 {
			st.Detour, st.Step, st.Replans = true, 0, st.Replans+1
			w.depart(s, id, st, cause)
			return
		}
		st.Phase, st.Blocked, st.Since = NPCBlocked, s.Tick, s.Tick
		return
	}
	ent := s.Entities[id]
	ent.Tag = maps.Clone(ent.Tag)
	ent.Tag["doing"] = step.Doing
	s.Entities[id] = ent
	st.Phase, st.Arrive, st.Since = NPCTravel, s.Tick+step.Ticks, s.Tick
}

func (w *World) arrive(s *State, id ID, st *NPCState, cause string) {
	t := w.tasks[st.Task]
	route := st.route(t)
	step := route[st.Step]
	ent := s.Entities[id]
	ent.Region = step.Region
	s.Entities[id] = ent
	w.apply(s, step.Do, Bind{"self": id}, "task:"+t.ID)
	st.Step++
	if st.Step >= len(route) {
		w.apply(s, t.Success, Bind{"self": id}, "task:"+t.ID)
		st.Done++
		w.finish(s, id, st, t)
		return
	}
	// A more urgent need pre-empts at a stop, never mid-leg.
	for _, o := range w.npcTasks[id] {
		if o.Priority <= t.Priority {
			break
		}
		if o.ID != t.ID && s.Cooldowns["task|"+string(id)+"|"+o.ID] <= s.Tick && w.Holds(s, o.When, Bind{"self": id}) && (o.Reserve == "" || s.Reserved[o.Reserve] == "" || s.Reserved[o.Reserve] == id) {
			st.Replans++
			w.finish(s, id, st, t)
			return
		}
	}
	w.depart(s, id, st, cause)
}

func (w *World) finish(s *State, id ID, st *NPCState, t TaskDef) {
	if t.Reserve != "" && s.Reserved[t.Reserve] == id {
		delete(s.Reserved, t.Reserve)
	}
	s.Cooldowns["task|"+string(id)+"|"+t.ID] = s.Tick + t.Cooldown
	ent := s.Entities[id]
	ent.Tag = maps.Clone(ent.Tag)
	delete(ent.Tag, "doing")
	s.Entities[id] = ent
	st.Task, st.Step, st.Detour, st.Phase, st.Since, st.Blocked, st.Help = "", 0, false, NPCIdle, s.Tick, 0, ""
}

func (w *World) waitBlocked(s *State, id ID, st *NPCState, cause string) {
	t := w.tasks[st.Task]
	b := t.Block
	if !w.Holds(s, b.When, Bind{"self": id}) {
		w.closeHelp(s, st, "resolved", cause)
		st.Phase = NPCTravel
		w.depart(s, id, st, cause)
		for st.Phase == NPCTravel && s.Tick >= st.Arrive {
			w.arrive(s, id, st, cause)
		}
		return
	}
	waited := s.Tick - st.Blocked
	if waited >= b.GiveUpAfter {
		w.closeHelp(s, st, "expired", cause)
		st.Failed++
		w.remember(s, id, MemoryEpisode{Kind: "rota-interrompida", Region: b.Via, Salience: 2})
		w.finish(s, id, st, t)
		return
	}
	if waited >= b.HelpAfter && st.Help == "" && s.Cooldowns["help|"+string(id)] <= s.Tick {
		s.HelpSeq++
		req := HelpRequest{ID: "help:" + string(id) + ":" + strconv.FormatInt(s.HelpSeq, 10), NPC: id, Task: t.ID, Need: b.Need, Region: s.Entities[id].Region,
			Text: w.render(s, b.Say, Bind{"self": id}), Open: s.Tick, Status: "open"}
		s.Helps[req.ID] = req
		st.Help, st.Phase = req.ID, NPCSeekHelp
		w.emit(s, Event{Kind: "help-requested", Actor: id, Public: true, Text: req.Text, Cause: cause, Data: map[string]string{"request": req.ID, "npc": string(id), "need": b.Need, "region": string(req.Region)}})
	}
}

// closeHelp ends the NPC's open request. A request that was answered by an
// actor and resolved leaves a memory and a warmer relation; one that simply
// expired leaves only the memory of the interrupted route.
func (w *World) closeHelp(s *State, st *NPCState, status, cause string) {
	if st.Help == "" {
		return
	}
	req := s.Helps[st.Help]
	req.Status, req.Closed = status, s.Tick
	s.Helps[req.ID] = req
	t := w.tasks[req.Task]
	cd := Tick(20)
	if t.Block != nil && t.Block.HelpCooldown > 0 {
		cd = t.Block.HelpCooldown
	}
	s.Cooldowns["help|"+string(req.NPC)] = s.Tick + cd
	if status == "resolved" && req.By != "" {
		k := relKey(req.NPC, req.By)
		s.Relations[k] = min(s.Relations[k]+3, 10)
		w.emit(s, Event{Kind: "help-resolved", Actor: req.By, Public: true, Cause: cause,
			Text: w.name(s, req.NPC) + " foi socorrida por " + w.name(s, req.By) + ".", Data: map[string]string{"request": req.ID, "npc": string(req.NPC), "by": string(req.By)}})
		w.remember(s, req.NPC, MemoryEpisode{Kind: "ajuda-recebida", Subject: req.By, Salience: 5, Region: req.Region})
	} else if status == "resolved" {
		w.emit(s, Event{Kind: "help-resolved", Public: true, Cause: cause, Text: "O caminho de " + w.name(s, req.NPC) + " se abriu sozinho.", Data: map[string]string{"request": req.ID, "npc": string(req.NPC)}})
	}
	st.Help = ""
}

// assist is the effect an already-confirmed deed uses to answer an NPC's open
// request: the first confirmed helper is the one the NPC will remember. A deed
// that did not clear the cause earns nothing, because the request only closes
// as resolved when the world itself changes.
func (w *World) assist(s *State, helper, npc ID) {
	if helper == "" {
		return
	}
	st, ok := s.NPCs[npc]
	if !ok || st.Help == "" {
		return
	}
	req := s.Helps[st.Help]
	if req.Status != "open" {
		return
	}
	req.Status, req.By = "answered", helper
	s.Helps[req.ID] = req
}

func (w *World) remember(s *State, npc ID, m MemoryEpisode) {
	m.Tick, m.Seq = s.Tick, s.Seq
	mem := append(slices.Clone(s.Memories[npc]), m)
	if len(mem) > maxMemories { // forget the least salient, oldest first
		drop := 0
		for i, x := range mem {
			if x.Salience < mem[drop].Salience {
				drop = i
			}
		}
		mem = slices.Delete(mem, drop, drop+1)
	}
	s.Memories[npc] = mem
}

// TopMemories returns what npc remembers about subject, most salient and most
// recent first. An NPC only ever reports its own memory.
func (s *State) TopMemories(npc, subject ID, n int) []MemoryEpisode {
	var out []MemoryEpisode
	for _, m := range s.Memories[npc] {
		if subject == "" || m.Subject == subject {
			out = append(out, m)
		}
	}
	slices.SortStableFunc(out, func(a, b MemoryEpisode) int {
		if a.Salience != b.Salience {
			return int(b.Salience - a.Salience)
		}
		return int(b.Tick - a.Tick)
	})
	return out[:min(len(out), n)]
}

// SocietyView lists the named NPCs: where they are, what they do and what they
// remember about the observer (never about anyone else).
type SocietyView struct {
	ID       ID              `json:"id"`
	Name     string          `json:"name"`
	Region   ID              `json:"region"`
	Phase    string          `json:"phase"`
	Task     string          `json:"task,omitempty"`
	Doing    string          `json:"doing,omitempty"`
	Done     int64           `json:"done"`
	Failed   int64           `json:"failed"`
	Dest     ID              `json:"dest,omitempty"` // region of the leg in progress: where the NPC is heading
	Step     int             `json:"step"`           // 0-based leg of the route
	Steps    int             `json:"steps"`          // legs in the route
	Since    Tick            `json:"since"`          // tick the current phase began
	Arrive   Tick            `json:"arrive,omitempty"`
	Help     *HelpView       `json:"help,omitempty"`
	Memories []MemoryEpisode `json:"memories,omitempty"`
}

type HelpView struct {
	ID     string `json:"id"`
	Need   string `json:"need"`
	Text   string `json:"text"`
	Region ID     `json:"region"`
	Open   Tick   `json:"open"`
	Status string `json:"status"`
}

func (w *World) societyView(s *State, observer ID) []SocietyView {
	if len(w.npcTasks) == 0 {
		return nil
	}
	out := []SocietyView{}
	for _, id := range sortedIDs(s.NPCs) {
		ent, ok := s.Entities[id]
		if !ok {
			continue
		}
		st := s.NPCs[id]
		v := SocietyView{ID: id, Name: ent.Name, Region: ent.Region, Phase: st.Phase, Task: st.Task, Doing: ent.Tag["doing"], Done: st.Done, Failed: st.Failed,
			Memories: s.TopMemories(id, observer, 3)}
		if t, ok := w.tasks[st.Task]; ok && st.Task != "" {
			route := st.route(t)
			v.Steps, v.Since = len(route), st.Since
			if st.Step < len(route) {
				v.Dest = route[st.Step].Region
			}
			if st.Phase == NPCTravel {
				v.Arrive = st.Arrive
			}
		}
		if st.Help != "" {
			r := s.Helps[st.Help]
			v.Help = &HelpView{ID: r.ID, Need: r.Need, Text: r.Text, Region: r.Region, Open: r.Open, Status: r.Status}
		}
		out = append(out, v)
	}
	return out
}

func cloneNPCs(m map[ID]NPCState) map[ID]NPCState { return maps.Clone(m) }

func cloneMemories(m map[ID][]MemoryEpisode) map[ID][]MemoryEpisode {
	c := make(map[ID][]MemoryEpisode, len(m))
	for k, v := range m {
		c[k] = slices.Clone(v)
	}
	return c
}
