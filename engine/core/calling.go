package core

import (
	"slices"
	"strconv"
)

// Callings: a class is not something a player collects but what the body needs
// from them where they stand. A crisis lists the roles it needs (ConflictDef.Needs,
// with how many players each should have); a player who stands in the crisis is
// offered a few callings that answer it, ordered by what is missing, and chooses
// one. When others already cover a role, the offer moves to the roles that are
// not covered, so the same class is not always the answer. A calling lasts while
// the player stays in the crisis; leaving it, or the crisis ending, releases it.
// The calling is a tag on the player ("calling", "role", "form"), so conditions
// and the client can read it. The offer is a pure function of the state: it is
// recomputed whenever it is asked for and revalidated when it is chosen.

const actAssume = "assumir" // args: calling

// CallingDef is one situational class. Role is what it does for a crisis; Form is the
// lineage whose body and abilities the client shows while the player holds the calling.
type CallingDef struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Desc string `json:"desc"`
	Role string `json:"role"`
	Form string `json:"form,omitempty"`
}

// NeedDef says how many players a crisis wants in one role.
type NeedDef struct {
	Role   string `json:"role"`
	Weight int64  `json:"weight"`
}

// RoleState is the calling a player holds right now.
type RoleState struct {
	Conflict string `json:"conflict"`
	Calling  string `json:"calling"`
	Role     string `json:"role"`
	Since    Tick   `json:"since"`
	Gap      bool   `json:"gap,omitempty"` // it was chosen to fill a role nobody else covered
}

// CallingOption is a calling as the player sees it in an offer.
type CallingOption struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Desc    string `json:"desc"`
	Role    string `json:"role"`
	Form    string `json:"form,omitempty"`
	Missing int64  `json:"missing"` // players still needed in this role
	Covered int64  `json:"covered"` // players already in this role
	Gap     bool   `json:"gap,omitempty"`
}

// CallingView is the observer's own calling and, when they stand in a crisis, what they could take.
type CallingView struct {
	Conflict string          `json:"conflict,omitempty"` // the crisis where they stand
	Current  string          `json:"current,omitempty"`
	Role     string          `json:"role,omitempty"`
	Offer    []CallingOption `json:"offer"`
}

func (w *World) callingDef(id string) (CallingDef, bool) {
	i := slices.IndexFunc(w.U.Callings, func(c CallingDef) bool { return c.ID == id })
	if i < 0 {
		return CallingDef{}, false
	}
	return w.U.Callings[i], true
}

func (w *World) compileCallings() error {
	if len(w.U.Callings) == 0 {
		for _, c := range w.U.Conflicts {
			if len(c.Needs) > 0 {
				return invalid("conflict %s has needs but the universe has no callings", c.ID)
			}
		}
		return nil
	}
	if _, taken := w.actions[actAssume]; taken {
		return invalid("action id %q is reserved by the engine", actAssume)
	}
	seen := map[string]bool{}
	roles := map[string]bool{}
	for _, c := range w.U.Callings {
		if !validID(c.ID) || c.Name == "" || c.Role == "" || seen[c.ID] {
			return invalid("calling %q", c.ID)
		}
		if c.Form != "" {
			if _, ok := w.lineageDef(c.Form); !ok {
				return invalid("calling %s: unknown form %q", c.ID, c.Form)
			}
		}
		seen[c.ID] = true
		roles[c.Role] = true
	}
	for _, c := range w.U.Conflicts {
		for _, n := range c.Needs {
			if !roles[n.Role] || n.Weight < 1 {
				return invalid("conflict %s: need %q", c.ID, n.Role)
			}
		}
	}
	return nil
}

// callingConflict is the live crisis the player stands in (its place or a front it opened), or "".
func (w *World) callingConflict(s *State, p ID) string {
	here := s.Entities[p].Region
	for _, id := range sortedKeys(s.Conflicts) {
		c := s.Conflicts[id]
		if c.Phase == PhaseResolved || len(w.conflicts[c.Def].Needs) == 0 {
			continue
		}
		if c.Region == here {
			return id
		}
		for _, f := range w.conflicts[c.Def].Fronts {
			if f.Region == here && slices.Contains(c.Fronts, f.ID) {
				return id
			}
		}
	}
	return ""
}

// coverage counts the players, other than `except`, holding each role and each calling in a crisis.
func (w *World) coverage(s *State, conflict string, except ID) (byRole, byCalling map[string]int64) {
	byRole, byCalling = map[string]int64{}, map[string]int64{}
	for _, p := range sortedIDs(s.Roles) {
		r := s.Roles[p]
		if r.Conflict == conflict && p != except {
			byRole[r.Role]++
			byCalling[r.Calling]++
		}
	}
	return
}

// callingOffer is what the player may take in the crisis: at most three callings, from different
// roles, the role with the most missing players first; inside a role, the calling fewer people hold.
func (w *World) callingOffer(s *State, p ID, conflict string) []CallingOption {
	c, ok := s.Conflicts[conflict]
	if !ok {
		return nil
	}
	needs := w.conflicts[c.Def].Needs
	byRole, byCalling := w.coverage(s, conflict, p)
	type scored struct {
		need    NeedDef
		missing int64
		ratio   int64 // covered per 1000 of wanted, for when nothing is missing any more
	}
	var roles []scored
	for _, n := range needs {
		covered := byRole[n.Role]
		roles = append(roles, scored{n, n.Weight - covered, covered * 1000 / n.Weight})
	}
	slices.SortStableFunc(roles, func(a, b scored) int {
		if a.missing != b.missing {
			return int(b.missing - a.missing)
		}
		return int(a.ratio - b.ratio)
	})
	var out []CallingOption
	for _, r := range roles {
		best := -1
		for i, cd := range w.U.Callings {
			if cd.Role != r.need.Role {
				continue
			}
			if best < 0 || byCalling[cd.ID] < byCalling[w.U.Callings[best].ID] {
				best = i
			}
		}
		if best < 0 {
			continue
		}
		cd := w.U.Callings[best]
		out = append(out, CallingOption{ID: cd.ID, Name: cd.Name, Desc: cd.Desc, Role: cd.Role, Form: cd.Form,
			Missing: max(r.missing, 0), Covered: byRole[cd.Role], Gap: r.missing > 0})
		if len(out) == 3 {
			break
		}
	}
	return out
}

// assume is the player's choice: take one calling of the offer where they stand.
func (w *World) assume(s *State, origin string, p ID, args map[string]ID, cause string) error {
	id := string(args["calling"])
	if origin != "player" || s.Entities[p].Kind != w.U.PlayerKind || len(w.U.Callings) == 0 {
		return reject("calling")
	}
	conflict := w.callingConflict(s, p)
	if conflict == "" {
		return reject("calling: no crisis here")
	}
	i := slices.IndexFunc(w.callingOffer(s, p, conflict), func(o CallingOption) bool { return o.ID == id })
	if i < 0 {
		return reject("calling: not offered")
	}
	opt := w.callingOffer(s, p, conflict)[i]
	cd, _ := w.callingDef(id)
	if s.Roles == nil {
		s.Roles = map[ID]RoleState{}
	}
	s.Roles[p] = RoleState{Conflict: conflict, Calling: id, Role: cd.Role, Since: s.Tick, Gap: opt.Gap}
	w.setCallingTags(s, p, cd.ID, cd.Role, cd.Form)
	w.count(s, p, actAssume)
	w.emit(s, Event{Kind: "calling-assumed", Actor: p, Holder: p, Public: true, Cause: cause,
		Text: s.Entities[p].Name + " assume o chamado de " + cd.Name + ".",
		Data: map[string]string{"calling": id, "role": cd.Role, "conflict": conflict, "gap": strconv.FormatBool(opt.Gap)}})
	return nil
}

func (w *World) setCallingTags(s *State, p ID, calling, role, form string) {
	e := s.Entities[p]
	tags := map[string]string{}
	for k, v := range e.Tag {
		tags[k] = v
	}
	if calling == "" {
		delete(tags, "calling")
		delete(tags, "role")
		delete(tags, "form")
	} else {
		tags["calling"], tags["role"] = calling, role
		if form != "" {
			tags["form"] = form
		} else {
			delete(tags, "form")
		}
	}
	e.Tag = tags
	s.Entities[p] = e
}

// callingTick releases the calling of a player who left the crisis or whose crisis ended.
func (w *World) callingTick(s *State, cause string) {
	for _, p := range sortedIDs(s.Roles) {
		r := s.Roles[p]
		if c, ok := s.Conflicts[r.Conflict]; ok && c.Phase != PhaseResolved && w.callingConflict(s, p) == r.Conflict {
			continue
		}
		delete(s.Roles, p)
		w.setCallingTags(s, p, "", "", "")
		w.emit(s, Event{Kind: "calling-released", Actor: p, Holder: p, Cause: cause, Text: s.Entities[p].Name + " volta à forma base.",
			Data: map[string]string{"calling": r.Calling, "conflict": r.Conflict}})
	}
}

func (w *World) callingViewOf(s *State, p ID) *CallingView {
	if len(w.U.Callings) == 0 || s.Entities[p].Kind != w.U.PlayerKind {
		return nil
	}
	v := &CallingView{Offer: []CallingOption{}}
	if r, ok := s.Roles[p]; ok {
		v.Current, v.Role = r.Calling, r.Role
	}
	if conflict := w.callingConflict(s, p); conflict != "" {
		v.Conflict = conflict
		if o := w.callingOffer(s, p, conflict); o != nil {
			v.Offer = o
		}
	}
	return v
}
