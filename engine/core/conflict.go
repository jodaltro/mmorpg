package core

import (
	"maps"
	"slices"
	"strconv"
)

// ConflictDef declares a persistent crisis of the shared world. The engine
// knows nothing about diseases: a universe names the cause (Trigger), the
// number that measures how bad it is (Severity), and when it is held back
// (Contain) or over (Resolve). A conflict never ends because someone logged
// out or a timer expired: it moves only when the world's own numbers move,
// and only after the condition has held for a sustained number of ticks.
type ConflictDef struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Desc   string `json:"desc,omitempty"`
	Region ID     `json:"region"` // primary place
	// Trigger is the material cause. While an instance of this definition is
	// alive no second one opens, so one cause never becomes many conflicts.
	Trigger Cond `json:"trigger"`
	// Severity is the official measure: higher is worse.
	Severity ConflictMetric `json:"severity"`
	// Critical and CriticalExit give the hysteresis of the critical phase.
	// Needs are the roles this crisis wants and how many players each; see calling.go.
	Needs        []NeedDef `json:"needs,omitempty"`
	Critical     int64     `json:"critical"`
	CriticalExit int64     `json:"criticalExit"`
	Contain      Cond      `json:"contain"` // the threat is held back
	Resolve      Cond      `json:"resolve"` // the world is stable again
	// Sustain is how many consecutive ticks Contain must hold to be contained,
	// and Resolve to start recovering. Recovery is how long Resolve must keep
	// holding while recovering before the conflict is resolved.
	Sustain  Tick `json:"sustain"`
	Recovery Tick `json:"recovery"`
	// Cooldown keeps a resolved definition from reopening for this many ticks.
	Cooldown Tick             `json:"cooldown,omitempty"`
	Metrics  []ConflictMetric `json:"metrics,omitempty"`
	Fronts   []ConflictFront  `json:"fronts,omitempty"`
	// Effects applied on each transition, with no $self.
	OnStart    []Effect `json:"onStart,omitempty"`
	OnEscalate []Effect `json:"onEscalate,omitempty"`
	OnContain  []Effect `json:"onContain,omitempty"`
	OnReopen   []Effect `json:"onReopen,omitempty"`
	OnRecover  []Effect `json:"onRecover,omitempty"`
	OnResolve  []Effect `json:"onResolve,omitempty"`
	// Rewards are paid once, when an instance resolves, to every player whose
	// validated contribution reaches RewardMinCredit (default 3). $self is that
	// player. Nobody who only watched is paid, and a reopened conflict pays
	// only when it finally resolves.
	Rewards         []Effect `json:"rewards,omitempty"`
	RewardMinCredit int64    `json:"rewardMinCredit,omitempty"`
	// WhileRecovering runs every tick of the recovery phase: the cleanup is
	// real work, not a celebration.
	WhileRecovering []Effect `json:"whileRecovering,omitempty"`
	// Responses are the ways the body can answer when this starts or escalates;
	// the first is the deterministic default. See deliberation.go.
	Responses []ResponseDef `json:"responses,omitempty"`
}

// ConflictMetric is one official indicator: a number of an entity.
type ConflictMetric struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	E     ID     `json:"e"`
	K     string `json:"k"`
	// Of inverts the reading: the metric is Of minus the stored number, for a
	// quantity where less is worse (a microbiota at 20 of 100 is a severity of 80).
	Of int64 `json:"of,omitempty"`
}

// ConflictFront is another place the same conflict reaches. It does not copy
// the conflict: it only marks that the cause has spread, once.
type ConflictFront struct {
	ID     string `json:"id"`
	Region ID     `json:"region"`
	When   Cond   `json:"when"`
}

// Conflict phases.
const (
	PhaseActive     = "active"
	PhaseCritical   = "critical"
	PhaseContained  = "contained"
	PhaseRecovering = "recovering"
	PhaseResolved   = "resolved"
)

// ConflictState is one instance of a crisis. Revision grows with every
// semantic transition (never with a metric change), so a client announces a
// transition once and can drop anything older after a reconnect.
type ConflictState struct {
	ID       string           `json:"id"`
	Def      string           `json:"def"`
	Phase    string           `json:"phase"`
	Onset    Tick             `json:"onset"`
	Since    Tick             `json:"since"`
	Revision int64            `json:"revision"`
	Region   ID               `json:"region"`
	Fronts   []string         `json:"fronts,omitempty"`
	Held     Tick             `json:"held,omitempty"` // tick since which the current exit condition holds; 0 = not holding
	Peak     int64            `json:"peak"`
	Reopened int64            `json:"reopened,omitempty"`
	Credit   map[string]int64 `json:"credit,omitempty"` // "actor|kind" -> validated contribution
}

// maxCredit caps what one confirmed deed may add, so a forged or farmed
// magnitude cannot dominate the record.
const maxCredit = 10

func (w *World) compileConflicts(v *validator, ents map[ID]string) error {
	seen := map[string]bool{}
	for _, c := range w.U.Conflicts {
		where := "conflict " + c.ID
		if c.ID == "" || seen[c.ID] || !validID(c.ID) || c.Title == "" || !w.regions[ents[c.Region]] {
			return invalid("%s: id, title or region", where)
		}
		if ents[c.Severity.E] == "" || c.Severity.K == "" || c.Critical < 1 || c.CriticalExit < 0 || c.CriticalExit >= c.Critical || c.Sustain < 1 || c.Recovery < 1 || c.Cooldown < 0 {
			return invalid("%s: severity and thresholds", where)
		}
		for _, m := range append(slices.Clone(c.Metrics), c.Severity) {
			if m.ID == "" || m.Label == "" || ents[m.E] == "" || m.K == "" {
				return invalid("%s: metric %q", where, m.ID)
			}
		}
		vars := map[string]bool{}
		for _, cond := range []Cond{c.Trigger, c.Contain, c.Resolve} {
			if e := v.cond(cond, vars, where); e != nil {
				return e
			}
		}
		fronts := map[string]bool{}
		for _, f := range c.Fronts {
			if f.ID == "" || fronts[f.ID] || !w.regions[ents[f.Region]] {
				return invalid("%s: front %q", where, f.ID)
			}
			fronts[f.ID] = true
			if e := v.cond(f.When, vars, where+" front "+f.ID); e != nil {
				return e
			}
		}
		if e := v.effects(c.Rewards, map[string]bool{"self": true}, where+" rewards"); e != nil {
			return e
		}
		if c.RewardMinCredit < 0 {
			return invalid("%s: rewardMinCredit", where)
		}
		for _, list := range [][]Effect{c.OnStart, c.OnEscalate, c.OnContain, c.OnReopen, c.OnRecover, c.OnResolve, c.WhileRecovering} {
			if e := v.effects(list, vars, where); e != nil {
				return e
			}
		}
		seen[c.ID] = true
	}
	return nil
}

// conflictTick runs after everything else in a tick, so the numbers it reads
// already include this tick's rules, cohorts and agents. At most one phase
// transition per instance per tick. Order is by definition, then instance id.
func (w *World) conflictTick(s *State, cause string) {
	if len(w.U.Conflicts) == 0 {
		return
	}
	type waiting struct {
		def  ConflictDef
		last Tick
		at   int
	}
	var queue []waiting
	alive := 0
	for i, def := range w.U.Conflicts {
		live := ""
		var last Tick = -1 << 62
		for _, id := range sortedKeys(s.Conflicts) {
			c := s.Conflicts[id]
			if c.Def != def.ID {
				continue
			}
			if c.Phase != PhaseResolved {
				live = id
			} else if c.Since > last {
				last = c.Since
			}
		}
		if live == "" {
			if (last < 0 || s.Tick-last >= def.Cooldown) && w.Holds(s, def.Trigger, Bind{}) {
				queue = append(queue, waiting{def, last, i})
			}
			continue
		}
		w.advanceConflict(s, def, live, cause)
		if w.takesAPlace(s, s.Conflicts[live]) {
			alive++
		}
	}
	// The ones whose cause holds open in order of how long they have waited
	// (never opened first, then the least recently ended), while there is room.
	limit := w.U.Limits.MaxLiveConflicts
	if limit > 0 { // without a cap everything opens in the universe's order, as always
		slices.SortStableFunc(queue, func(a, b waiting) int {
			if a.last != b.last {
				if a.last < b.last {
					return -1
				}
				return 1
			}
			return a.at - b.at
		})
	}
	for _, q := range queue {
		if limit > 0 && alive >= limit {
			break
		}
		w.openConflict(s, q.def, cause)
		alive++
	}
	w.attentionTick(s)
}

// takesAPlace says whether a live conflict counts against the cap: it must be
// asking for attention (active or critical) and not have kept the place past
// the universe's patience.
func (w *World) takesAPlace(s *State, c ConflictState) bool {
	if c.Phase != PhaseActive && c.Phase != PhaseCritical {
		return false
	}
	p := w.U.Limits.LiveConflictPatience
	return p == 0 || s.Tick-c.Onset < p
}

func (w *World) openConflict(s *State, def ConflictDef, cause string) {
	s.ConflictSeq++
	id := "conflict:" + def.ID + ":" + string(def.Region) + ":" + strconv.FormatInt(s.ConflictSeq, 10)
	c := ConflictState{ID: id, Def: def.ID, Phase: PhaseActive, Onset: s.Tick, Since: s.Tick, Revision: 1, Region: def.Region}
	c.Peak = w.metric(s, def.Severity)
	s.Conflicts[id] = c
	w.apply(s, def.OnStart, Bind{}, cause)
	w.emitConflict(s, c, def, "conflict-started", def.Title+": o conflito começou.", cause)
	w.openResponses(s, def, c)
}

func (w *World) metric(s *State, m ConflictMetric) int64 {
	v := s.Entities[m.E].Num[m.K]
	if m.Of != 0 {
		return m.Of - v
	}
	return v
}

func (w *World) advanceConflict(s *State, def ConflictDef, id, cause string) {
	c := s.Conflicts[id]
	sev := w.metric(s, def.Severity)
	c.Peak = max(c.Peak, sev)
	hold := func(cond Cond) bool {
		if !w.Holds(s, cond, Bind{}) {
			c.Held = 0
			return false
		}
		if c.Held == 0 {
			c.Held = s.Tick
		}
		return true
	}
	held := func(n Tick) bool { return c.Held != 0 && s.Tick-c.Held >= n-1 }
	transition := func(phase, kind, text string, fx []Effect) {
		c.Phase, c.Since, c.Held = phase, s.Tick, 0
		c.Revision++
		s.Conflicts[id] = c
		w.apply(s, fx, Bind{}, cause)
		w.emitConflict(s, c, def, kind, text, cause)
		if phase == PhaseCritical {
			w.openResponses(s, def, c)
		}
	}
	defer func() {
		// Fronts open once, whatever phase the conflict is in.
		cur := s.Conflicts[id]
		if cur.Phase == PhaseResolved {
			return
		}
		for _, f := range def.Fronts {
			if !slices.Contains(cur.Fronts, f.ID) && w.Holds(s, f.When, Bind{}) {
				cur.Fronts = append(slices.Clone(cur.Fronts), f.ID)
				cur.Revision++
				s.Conflicts[id] = cur
				w.emitConflict(s, cur, def, "conflict-front-opened", def.Title+": nova frente em "+string(f.Region)+".", cause, "front", f.ID)
			}
		}
	}()
	s.Conflicts[id] = c
	switch c.Phase {
	case PhaseActive:
		if sev >= def.Critical {
			transition(PhaseCritical, "conflict-escalated", def.Title+": situação crítica.", def.OnEscalate)
		} else if hold(def.Contain) && held(def.Sustain) {
			transition(PhaseContained, "conflict-contained", def.Title+": contido.", def.OnContain)
		}
	case PhaseCritical:
		if sev < def.CriticalExit {
			transition(PhaseActive, "conflict-eased", def.Title+": a crise crítica recuou.", nil)
		}
	case PhaseContained:
		if sev >= def.Critical {
			c.Reopened++
			transition(PhaseCritical, "conflict-reopened", def.Title+": voltou a se agravar.", def.OnReopen)
		} else if !w.Holds(s, def.Contain, Bind{}) {
			c.Reopened++
			transition(PhaseActive, "conflict-reopened", def.Title+": voltou a se agravar.", def.OnReopen)
		} else if hold(def.Resolve) && held(def.Sustain) {
			transition(PhaseRecovering, "conflict-recovering", def.Title+": em recuperação.", def.OnRecover)
		}
	case PhaseRecovering:
		if !w.Holds(s, def.Resolve, Bind{}) {
			c.Reopened++
			transition(PhaseActive, "conflict-reopened", def.Title+": a recuperação falhou.", def.OnReopen)
		} else {
			w.apply(s, def.WhileRecovering, Bind{}, cause)
			if hold(def.Resolve) && held(def.Recovery) {
				transition(PhaseResolved, "conflict-resolved", def.Title+": resolvido.", def.OnResolve)
				w.payConflictRewards(s, def, s.Conflicts[id], cause)
			}
		}
	}
	if cur := s.Conflicts[id]; cur.Held != c.Held || cur.Peak != c.Peak {
		cur.Held, cur.Peak = c.Held, c.Peak
		s.Conflicts[id] = cur
	}
}

// payConflictRewards gives the rewards of a resolved conflict to the players
// who contributed enough. Credit comes only from confirmed deeds, so this is
// the one place where taking part in a crisis becomes progression.
func (w *World) payConflictRewards(s *State, def ConflictDef, c ConflictState, cause string) {
	if len(def.Rewards) == 0 {
		return
	}
	need := def.RewardMinCredit
	if need == 0 {
		need = 3
	}
	total := map[string]int64{}
	for k, n := range c.Credit {
		if actor, _, ok := splitCredit(k); ok {
			total[actor] += n
		}
	}
	for _, name := range sortedKeys(total) {
		actor := ID(name)
		if total[name] < need || s.Entities[actor].Kind != w.U.PlayerKind {
			continue
		}
		w.apply(s, def.Rewards, Bind{"self": actor}, cause)
		w.emit(s, Event{Kind: "conflict-reward", Holder: actor, Public: false, Text: def.Title, Cause: cause, Data: map[string]string{"conflict": c.ID, "def": def.ID}})
	}
}

func (w *World) emitConflict(s *State, c ConflictState, def ConflictDef, kind, text, cause string, extra ...string) {
	d := map[string]string{"conflict": c.ID, "def": def.ID, "revision": strconv.FormatInt(c.Revision, 10), "phase": c.Phase, "region": string(c.Region)}
	for i := 0; i+1 < len(extra); i += 2 {
		d[extra[i]] = extra[i+1]
	}
	w.emit(s, Event{Kind: kind, Public: true, Text: text, Cause: cause, Data: d})
}

// contribute credits the actor of a confirmed deed to every live conflict of
// the definition. It runs from an action effect, so it only happens through a
// command the boundary already authorised and deduplicated by request id; the
// magnitude is the universe's, capped, never the client's.
func (w *World) contribute(s *State, def string, actor ID, kind string, amount int64) {
	if actor == "" || amount < 1 {
		return
	}
	for _, id := range sortedKeys(s.Conflicts) {
		c := s.Conflicts[id]
		if c.Def != def || c.Phase == PhaseResolved {
			continue
		}
		c.Credit = maps.Clone(c.Credit)
		if c.Credit == nil {
			c.Credit = map[string]int64{}
		}
		c.Credit[string(actor)+"|"+kind] += min(amount, maxCredit)
		if r, ok := s.Roles[actor]; ok && r.Gap && r.Conflict == id { // whoever fills the role nobody covered is worth a little more
			c.Credit[string(actor)+"|lacuna"]++
		}
		s.Conflicts[id] = c
	}
}

// ConflictView is the same for every observer of the world: the official
// numbers of every crisis, the one to show first and what changed.
type ConflictView struct {
	Revision int64              `json:"revision"` // grows with any transition
	Focus    string             `json:"focus,omitempty"`
	Active   []ConflictItemView `json:"active"`
	Recent   []ConflictItemView `json:"recent,omitempty"` // resolved, newest first
}

type ConflictItemView struct {
	ID       string       `json:"id"`
	Def      string       `json:"def"`
	Title    string       `json:"title"`
	Desc     string       `json:"desc,omitempty"`
	Phase    string       `json:"phase"`
	Region   ID           `json:"region"`
	Onset    Tick         `json:"onset"`
	Since    Tick         `json:"since"`
	Revision int64        `json:"revision"`
	Severity int64        `json:"severity"`
	Peak     int64        `json:"peak"`
	Metrics  []MetricView `json:"metrics"`
	Fronts   []string     `json:"fronts,omitempty"`
	// FrontRegions maps each opened front to the region it reached, so a client
	// shows the spread only where and when the engine opened it.
	FrontRegions map[string]ID    `json:"frontRegions,omitempty"`
	Reopened     int64            `json:"reopened,omitempty"`
	Mine         map[string]int64 `json:"mine,omitempty"` // the observer's own validated credit by kind
}

type MetricView struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Value int64  `json:"value"`
}

var phaseRank = map[string]int{PhaseCritical: 5, PhaseActive: 4, PhaseContained: 3, PhaseRecovering: 2, PhaseResolved: 0}

func (w *World) conflictView(s *State, observer ID) *ConflictView {
	if len(w.U.Conflicts) == 0 {
		return nil
	}
	v := &ConflictView{Active: []ConflictItemView{}}
	var recent []ConflictItemView
	for _, id := range sortedKeys(s.Conflicts) {
		c := s.Conflicts[id]
		def := w.conflicts[c.Def]
		it := ConflictItemView{ID: c.ID, Def: c.Def, Title: def.Title, Desc: def.Desc, Phase: c.Phase, Region: c.Region, Onset: c.Onset, Since: c.Since,
			Revision: c.Revision, Severity: w.metric(s, def.Severity), Peak: c.Peak, Metrics: []MetricView{}, Fronts: c.Fronts, Reopened: c.Reopened}
		for _, f := range def.Fronts {
			if slices.Contains(c.Fronts, f.ID) {
				if it.FrontRegions == nil {
					it.FrontRegions = map[string]ID{}
				}
				it.FrontRegions[f.ID] = f.Region
			}
		}
		for _, m := range def.Metrics {
			it.Metrics = append(it.Metrics, MetricView{ID: m.ID, Label: m.Label, Value: w.metric(s, m)})
		}
		for k, n := range c.Credit {
			if actor, kind, ok := splitCredit(k); ok && actor == string(observer) {
				if it.Mine == nil {
					it.Mine = map[string]int64{}
				}
				it.Mine[kind] += n
			}
		}
		v.Revision += c.Revision
		if c.Phase == PhaseResolved {
			recent = append(recent, it)
			continue
		}
		v.Active = append(v.Active, it)
	}
	slices.SortStableFunc(v.Active, func(a, b ConflictItemView) int {
		if ra, rb := phaseRank[a.Phase], phaseRank[b.Phase]; ra != rb {
			return rb - ra
		}
		if a.Severity != b.Severity {
			return int(b.Severity - a.Severity)
		}
		return int(a.Onset - b.Onset)
	})
	if len(v.Active) > 0 {
		v.Focus = v.Active[0].ID
	}
	for _, it := range v.Active { // the body's chosen attention is the recommended focus
		if it.ID == s.Attention {
			v.Focus = it.ID
		}
	}
	slices.SortStableFunc(recent, func(a, b ConflictItemView) int { return int(b.Since - a.Since) })
	v.Recent = recent[:min(len(recent), 3)]
	return v
}

func splitCredit(k string) (actor, kind string, ok bool) {
	for i := len(k) - 1; i >= 0; i-- {
		if k[i] == '|' {
			return k[:i], k[i+1:], true
		}
	}
	return "", "", false
}

func cloneConflicts(m map[string]ConflictState) map[string]ConflictState {
	c := make(map[string]ConflictState, len(m))
	for k, v := range m {
		v.Fronts = slices.Clone(v.Fronts)
		v.Credit = maps.Clone(v.Credit)
		c[k] = v
	}
	return c
}
