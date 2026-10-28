package core

import (
	"slices"
	"strconv"
	"strings"
)

// DeliberationDef turns on the cognitive scheduler. Without it every NPC takes
// the deterministic best task at once. With it, an NPC that faces a real choice
// (two or more tasks it could start) and a conflict that starts or escalates
// become decisions an advisor may answer; the default always applies at the
// deadline, so an absent or slow advisor changes nothing about the world's
// ability to go on.
//
// Importance, not frames, drives it: Every is the quiet time between two
// deliberations of the same NPC and MaxOpen bounds how many NPC decisions can
// be waiting at once (the AI budget). The rest of the body never asks.
type DeliberationDef struct {
	Every   Tick `json:"every"`
	MaxOpen int  `json:"maxOpen"`
	// AttentionEvery turns on the macro layer: with two or more live conflicts,
	// every this many ticks the advisor chooses which one the body concentrates
	// on. The choice has a material effect (see TaskDef.Conflict) and is the
	// focus clients show first. Zero: off.
	AttentionEvery Tick `json:"attentionEvery,omitempty"`
}

// ResponseDef is one way the body can answer a conflict. Its effects are
// ordinary validated effects; the advisor only chooses between them.
type ResponseDef struct {
	ID      string   `json:"id"`
	Title   string   `json:"title"`
	Desc    string   `json:"desc,omitempty"`
	Effects []Effect `json:"effects,omitempty"`
}

// Decision kinds added by the deliberation layer.
const (
	DecisionNPC       = "npc"
	DecisionConflict  = "conflict"
	DecisionAttention = "attention"
	// WaitChoice is the option that keeps the routine: do nothing new.
	WaitChoice = "esperar"
)

func (w *World) compileDeliberation(v *validator) error {
	if d := w.U.Deliberation; d != nil && (d.Every < 1 || d.MaxOpen < 1) {
		return invalid("deliberation: every and maxOpen must be positive")
	}
	for _, c := range w.U.Conflicts {
		seen := map[string]bool{}
		if len(c.Responses) == 1 || len(c.Responses) > 0 && w.U.Deliberation == nil {
			return invalid("conflict %s: responses need deliberation and at least two options", c.ID)
		}
		for _, r := range c.Responses {
			if r.ID == "" || seen[r.ID] || r.Title == "" || strings.ContainsAny(r.ID, " |") {
				return invalid("conflict %s: response %q", c.ID, r.ID)
			}
			seen[r.ID] = true
			if e := v.effects(r.Effects, map[string]bool{}, "conflict "+c.ID+" response "+r.ID); e != nil {
				return e
			}
		}
	}
	return nil
}

func (w *World) openDecisions(s *State, kind string) int {
	n := 0
	for _, d := range s.Decisions {
		if d.Kind == kind {
			n++
		}
	}
	return n
}

// npcContext is what an advisor may know about one NPC's choice: its own place,
// its own beliefs and memory, and the public numbers of the conflict. Nothing
// about other NPCs' minds or players' private facts goes out.
func (w *World) npcContext(s *State, id ID, eligible []TaskDef) []string {
	e := s.Entities[id]
	out := []string{"npc: " + e.Name + " in " + w.name(s, e.Region), "tick: " + strconv.FormatInt(int64(s.Tick), 10)}
	st := s.NPCs[id]
	out = append(out, "finished tasks: "+strconv.FormatInt(st.Done, 10)+", failed: "+strconv.FormatInt(st.Failed, 10))
	for _, k := range sortedKeys(s.Beliefs[id]) {
		b := s.Beliefs[id][k]
		verb := "believes"
		if !b.Holds {
			verb = "believes NOT"
		}
		out = append(out, verb+" "+b.P+" at "+w.name(s, b.S)+" (source "+b.Source+", "+strconv.FormatInt(int64(s.Tick-b.At), 10)+" ticks ago)")
	}
	for _, m := range s.TopMemories(id, "", 3) {
		out = append(out, "remembers "+m.Kind+" "+strconv.FormatInt(int64(s.Tick-m.Tick), 10)+" ticks ago")
	}
	for _, cid := range sortedKeys(s.Conflicts) {
		if c := s.Conflicts[cid]; c.Phase != PhaseResolved {
			def := w.conflicts[c.Def]
			out = append(out, "public conflict: "+def.Title+" is "+c.Phase+", severity "+strconv.FormatInt(w.metric(s, def.Severity), 10))
		}
	}
	for _, t := range eligible {
		out = append(out, "could do: "+t.Title+" (priority "+strconv.Itoa(t.Priority)+")")
	}
	return out
}

// deliberate opens a decision for an idle NPC with a real choice. It returns
// false when the scheduler says to just act (no budget, too soon, no choice).
func (w *World) deliberate(s *State, id ID, st *NPCState, eligible []TaskDef) bool {
	d := w.U.Deliberation
	if d == nil || len(eligible) < 2 || s.Cooldowns["deliberate|"+string(id)] > s.Tick || w.openDecisions(s, DecisionNPC) >= d.MaxOpen {
		return false
	}
	dec := Decision{ID: "npc:" + string(id) + ":" + strconv.FormatInt(int64(s.Tick), 10), Kind: DecisionNPC, Subject: string(id), Default: eligible[0].ID,
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: w.npcContext(s, id, eligible)}
	for _, t := range eligible {
		dec.Options = append(dec.Options, Option{ID: t.ID, Title: t.Title, Desc: "priority " + strconv.Itoa(t.Priority)})
	}
	dec.Options = append(dec.Options, Option{ID: WaitChoice, Title: "Keep the routine and wait", Desc: "do nothing new for now"})
	s.Decisions[dec.ID] = dec
	s.Cooldowns["deliberate|"+string(id)] = s.Tick + d.Every
	st.Phase, st.Decision, st.Since = NPCDeciding, dec.ID, s.Tick
	return true
}

func (w *World) decideNPC(s *State, d Decision, choice, cause string) error {
	id := ID(d.Subject)
	st, ok := s.NPCs[id]
	if !ok || st.Phase != NPCDeciding || st.Decision != d.ID {
		delete(s.Decisions, d.ID)
		return reject("npc decision is stale")
	}
	if choice == WaitChoice {
		delete(s.Decisions, d.ID)
		s.Cooldowns["wait|"+string(id)] = s.Tick + 4
		st.Phase, st.Decision, st.Since = NPCIdle, "", s.Tick
		s.NPCs[id] = st
		return nil
	}
	t, known := w.tasks[choice]
	if !known || t.NPC != id || !w.eligible(s, id, t) {
		return reject("task no longer valid")
	}
	delete(s.Decisions, d.ID)
	st.Decision = ""
	w.beginTask(s, id, &st, t, cause)
	s.NPCs[id] = st
	return nil
}

// eligible says whether the NPC may start t right now.
func (w *World) eligible(s *State, id ID, t TaskDef) bool {
	if s.Cooldowns["task|"+string(id)+"|"+t.ID] > s.Tick || !w.Holds(s, t.When, Bind{"self": id}) {
		return false
	}
	holder, taken := s.Reserved[t.Reserve]
	return t.Reserve == "" || !taken || holder == id
}

// openResponses asks which response the body gives to a conflict that has just
// started or escalated. One decision per instance revision.
func (w *World) openResponses(s *State, def ConflictDef, c ConflictState) {
	if len(def.Responses) < 2 || w.U.Deliberation == nil {
		return
	}
	dec := Decision{ID: "conflict:" + c.ID + ":r" + strconv.FormatInt(c.Revision, 10), Kind: DecisionConflict, Subject: c.ID, Default: def.Responses[0].ID,
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout}
	dec.Context = []string{"conflict: " + def.Title + " (" + c.Phase + ")", "severity: " + strconv.FormatInt(w.metric(s, def.Severity), 10) + ", peak " + strconv.FormatInt(c.Peak, 10),
		"reopened: " + strconv.FormatInt(c.Reopened, 10) + " times"}
	for _, m := range def.Metrics {
		dec.Context = append(dec.Context, m.Label+": "+strconv.FormatInt(w.metric(s, m), 10))
	}
	for _, id := range sortedKeys(w.pops) {
		if p := w.pops[id]; p.Region == c.Region {
			dec.Context = append(dec.Context, "cohort "+p.Role+": "+strconv.FormatInt(s.Pops[id].Count, 10)+" of "+strconv.FormatInt(p.capacity(), 10))
		}
	}
	for _, r := range def.Responses {
		dec.Options = append(dec.Options, Option{ID: r.ID, Title: r.Title, Desc: r.Desc})
	}
	s.Decisions[dec.ID] = dec
}

func (w *World) decideConflict(s *State, d Decision, choice, cause string) error {
	c, ok := s.Conflicts[d.Subject]
	if !ok || c.Phase == PhaseResolved || !strings.HasSuffix(d.ID, ":r"+strconv.FormatInt(c.Revision, 10)) {
		delete(s.Decisions, d.ID)
		return reject("conflict decision is stale")
	}
	def := w.conflicts[c.Def]
	i := slices.IndexFunc(def.Responses, func(r ResponseDef) bool { return r.ID == choice })
	if i < 0 {
		return reject("response")
	}
	delete(s.Decisions, d.ID)
	w.apply(s, def.Responses[i].Effects, Bind{}, cause)
	w.emit(s, Event{Kind: "conflict-response", Public: true, Cause: cause, Text: def.Title + ": " + def.Responses[i].Title + ".",
		Data: map[string]string{"conflict": c.ID, "revision": strconv.FormatInt(c.Revision, 10), "response": choice}})
	return nil
}

// muster brings up to n members of a cohort at once, paying the cohort's own
// recruit cost from its reserve and respecting its capacity.
func (w *World) muster(s *State, pop string, n int64) {
	def, ok := w.pops[pop]
	r := def.Recruit
	if !ok || r == nil || n < 1 {
		return
	}
	st := s.Pops[pop]
	from := s.Entities[r.From]
	k := min(n, def.capacity()-st.Count, from.Num[r.K]/r.Cost)
	if k <= 0 {
		return
	}
	from.Num[r.K] -= k * r.Cost
	s.Entities[r.From] = from
	s.Ledger[ledgerKey("sink", r.K)] += k * r.Cost
	s.Ledger[ledgerKey("born", pop)] += k
	st.Count += k
	s.Pops[pop] = st
}

// attentionBonus is how much a task that serves the conflict holding the
// body's attention is preferred when an NPC picks its default.
const attentionBonus = 3

func (w *World) liveConflicts(s *State) []string {
	var ids []string
	for _, id := range sortedKeys(s.Conflicts) {
		if s.Conflicts[id].Phase != PhaseResolved {
			ids = append(ids, id)
		}
	}
	slices.SortStableFunc(ids, func(a, b string) int {
		ca, cb := s.Conflicts[a], s.Conflicts[b]
		if ra, rb := phaseRank[ca.Phase], phaseRank[cb.Phase]; ra != rb {
			return rb - ra
		}
		if sa, sb := w.metric(s, w.conflicts[ca.Def].Severity), w.metric(s, w.conflicts[cb.Def].Severity); sa != sb {
			return int(sb - sa)
		}
		return strings.Compare(a, b)
	})
	return ids
}

// attentionTick opens the macro question when several crises are alive.
func (w *World) attentionTick(s *State) {
	d := w.U.Deliberation
	if d == nil || d.AttentionEvery < 1 || w.openDecisions(s, DecisionAttention) > 0 {
		return
	}
	live := w.liveConflicts(s)
	if len(live) < 2 || s.AttentionAt != 0 && s.Tick-s.AttentionAt < d.AttentionEvery {
		return
	}
	dec := Decision{ID: "attention:" + strconv.FormatInt(int64(s.Tick), 10), Kind: DecisionAttention, Subject: "world", Default: live[0],
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout}
	dec.Context = []string{"several crises are alive at once and the body's cohorts are finite", "tick: " + strconv.FormatInt(int64(s.Tick), 10)}
	for _, id := range live[:min(len(live), 8)] {
		c := s.Conflicts[id]
		def := w.conflicts[c.Def]
		dec.Options = append(dec.Options, Option{ID: id, Title: def.Title, Desc: c.Phase + ", severity " + strconv.FormatInt(w.metric(s, def.Severity), 10) + ", peak " + strconv.FormatInt(c.Peak, 10) + ", reopened " + strconv.FormatInt(c.Reopened, 10)})
		dec.Context = append(dec.Context, def.Title+" is "+c.Phase+", severity "+strconv.FormatInt(w.metric(s, def.Severity), 10)+" for "+strconv.FormatInt(int64(s.Tick-c.Onset), 10)+" ticks")
	}
	if len(dec.Options) < 2 {
		return
	}
	s.Decisions[dec.ID] = dec
}

func (w *World) decideAttention(s *State, d Decision, choice, cause string) error {
	c, ok := s.Conflicts[choice]
	if !ok || c.Phase == PhaseResolved {
		delete(s.Decisions, d.ID)
		return reject("attention target is no longer alive")
	}
	delete(s.Decisions, d.ID)
	s.Attention, s.AttentionAt = choice, s.Tick
	w.emit(s, Event{Kind: "conflict-attention", Public: true, Cause: cause, Text: "O corpo concentra a atenção em: " + w.conflicts[c.Def].Title + ".",
		Data: map[string]string{"conflict": choice, "def": c.Def, "revision": strconv.FormatInt(c.Revision, 10)}})
	return nil
}

// attentionDef is the definition id of the conflict holding attention, if alive.
func (w *World) attentionDef(s *State) string {
	if c, ok := s.Conflicts[s.Attention]; ok && c.Phase != PhaseResolved {
		return c.Def
	}
	return ""
}
