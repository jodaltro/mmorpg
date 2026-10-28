package core

import (
	"maps"
	"strings"
)

// PopulationDef is a cohort: many anonymous workers of one role in one place,
// kept as a headcount instead of one entity per member. A cohort works by
// moving numbers between entities (carry oxygen, clear a pathogen load), dies
// off slowly and is replaced by spending a reserve. Nothing here knows biology:
// the universe names the roles, the places and the numbers.
type PopulationDef struct {
	ID     string `json:"id"`
	Role   string `json:"role"`
	Region ID     `json:"region"`
	Count  int64  `json:"count"`         // headcount at tick 0
	Max    int64  `json:"max,omitempty"` // capacity; 0 means Count
	// Mortality is the permille of the headcount lost every MortalityEvery ticks.
	Mortality      int64       `json:"mortality,omitempty"`
	MortalityEvery Tick        `json:"mortalityEvery,omitempty"`
	Recruit        *RecruitDef `json:"recruit,omitempty"`
	Work           []WorkDef   `json:"work,omitempty"`
}

// RecruitDef replaces members from a reserve: each new member costs Cost units
// of Key taken from entity From, at most PerCycle members every Every ticks.
type RecruitDef struct {
	From     ID     `json:"from"`
	K        string `json:"k"`
	Cost     int64  `json:"cost"`
	PerCycle int64  `json:"perCycle"`
	Every    Tick   `json:"every,omitempty"`
}

// WorkDef is one job of a cohort. Every Every ticks the cohort moves
// Count*Rate/1000 units of K from From to To. A quantity never appears from
// nowhere: an empty From is an exogenous source and an empty To a sink, both
// written to the ledger so conservation can be audited. The amount is limited
// by what From holds and by the room left in To (ToMax). Loss (permille) of
// what leaves From is lost on the way and goes to the sink ledger.
type WorkDef struct {
	ID    string `json:"id"`
	K     string `json:"k"`
	From  ID     `json:"from,omitempty"`
	To    ID     `json:"to,omitempty"`
	ToK   string `json:"toK,omitempty"` // key at the destination (default K)
	Rate  int64  `json:"rate"`          // milli-units per member per cycle
	Every Tick   `json:"every,omitempty"`
	Loss  int64  `json:"loss,omitempty"`
	ToMax *int64 `json:"toMax,omitempty"`
	When  *Cond  `json:"when,omitempty"`
}

// PopCmp compares a cohort's headcount.
type PopCmp struct {
	ID string `json:"id"`
	Op string `json:"op"`
	V  int64  `json:"v"`
}

// PopState is the persisted state of one cohort. Acc keeps the fractions of a
// unit (milli) so slow work is not rounded away, and is part of the digest.
type PopState struct {
	Count int64            `json:"count"`
	Acc   map[string]int64 `json:"acc,omitempty"`
}

// Ledger keys: "source:<key>" and "sink:<key>" for quantities, "born:<pop>" and
// "died:<pop>" for headcounts.
func ledgerKey(kind, name string) string { return kind + ":" + name }

func (w *World) compilePopulations(ents map[ID]string) error {
	w.pops = map[string]PopulationDef{}
	for _, p := range w.U.Populations {
		if p.ID == "" || w.pops[p.ID].ID != "" || strings.ContainsAny(p.ID, " |") || p.Role == "" {
			return invalid("population %q: empty/duplicate id or role", p.ID)
		}
		if !w.regions[ents[p.Region]] {
			return invalid("population %s: region %q is not a place", p.ID, p.Region)
		}
		if p.Count < 0 || p.Max < 0 || p.Max > 0 && p.Max < p.Count || p.Mortality < 0 || p.Mortality > 1000 || p.MortalityEvery < 0 {
			return invalid("population %s: numbers", p.ID)
		}
		if r := p.Recruit; r != nil {
			if ents[r.From] == "" || r.K == "" || r.Cost < 1 || r.PerCycle < 1 || r.Every < 0 {
				return invalid("population %s: recruit", p.ID)
			}
		}
		seen := map[string]bool{}
		for _, wk := range p.Work {
			if wk.ID == "" || seen[wk.ID] || wk.K == "" || wk.Rate < 1 || wk.Every < 0 || wk.Loss < 0 || wk.Loss > 1000 {
				return invalid("population %s work %q", p.ID, wk.ID)
			}
			seen[wk.ID] = true
			if wk.From != "" && ents[wk.From] == "" || wk.To != "" && ents[wk.To] == "" || wk.ToMax != nil && wk.To == "" {
				return invalid("population %s work %s: unknown entity", p.ID, wk.ID)
			}
		}
		w.pops[p.ID] = p
	}
	return nil
}

// validatePopulationConds checks the optional conditions of every job once the
// condition validator exists.
func (w *World) validatePopulationConds(v *validator) error {
	for _, p := range w.U.Populations {
		for _, wk := range p.Work {
			if wk.When != nil {
				if e := v.cond(*wk.When, map[string]bool{}, "population "+p.ID+" work "+wk.ID); e != nil {
					return e
				}
			}
		}
	}
	return nil
}

func (w *World) initPopulations(s *State) {
	s.Pops = map[string]PopState{}
	for _, p := range w.U.Populations {
		s.Pops[p.ID] = PopState{Count: p.Count, Acc: map[string]int64{}}
	}
}

func (p PopulationDef) capacity() int64 {
	if p.Max > 0 {
		return p.Max
	}
	return p.Count
}

// populationTick runs every cohort once, in id order. It is called from tick,
// so it needs no player, no advisor and no clock.
func (w *World) populationTick(s *State) {
	for _, id := range sortedKeys(w.pops) {
		def := w.pops[id]
		st := s.Pops[id]
		if st.Acc == nil {
			st.Acc = map[string]int64{}
		}
		if def.Mortality > 0 && st.Count > 0 {
			every := max(def.MortalityEvery, 1)
			if s.Tick%every == 0 {
				st.Acc["death"] += st.Count * def.Mortality
				dead := min(st.Acc["death"]/1000, st.Count)
				st.Acc["death"] -= st.Acc["death"] / 1000 * 1000
				st.Count -= dead
				s.Ledger[ledgerKey("died", id)] += dead
			}
		}
		if r := def.Recruit; r != nil && st.Count < def.capacity() && s.Tick%max(r.Every, 1) == 0 {
			from := s.Entities[r.From]
			n := min(r.PerCycle, def.capacity()-st.Count, from.Num[r.K]/r.Cost)
			if n > 0 {
				from.Num[r.K] -= n * r.Cost
				s.Entities[r.From] = from
				s.Ledger[ledgerKey("sink", r.K)] += n * r.Cost // spent to build new members
				st.Count += n
				s.Ledger[ledgerKey("born", id)] += n
			}
		}
		for _, wk := range def.Work {
			if s.Tick%max(wk.Every, 1) != 0 || st.Count == 0 {
				continue
			}
			if wk.When != nil && !w.Holds(s, *wk.When, Bind{}) {
				continue
			}
			st.Acc[wk.ID] += st.Count * wk.Rate
			want := st.Acc[wk.ID] / 1000
			if want == 0 {
				continue
			}
			moved := w.moveWork(s, wk, want)
			// Keep the fraction of what could not be done only while the job
			// was limited by nothing; a blocked job does not hoard work.
			if moved == want {
				st.Acc[wk.ID] -= want * 1000
			} else {
				st.Acc[wk.ID] = 0
			}
		}
		s.Pops[id] = st
	}
}

// moveWork moves up to want units for one job and returns how many left From.
func (w *World) moveWork(s *State, wk WorkDef, want int64) int64 {
	taken := want
	if wk.From != "" {
		src, ok := s.Entities[wk.From]
		if !ok {
			return 0
		}
		taken = min(taken, max(src.Num[wk.K], 0))
	}
	toK := wk.ToK
	if toK == "" {
		toK = wk.K
	}
	if wk.To != "" && wk.ToMax != nil {
		dst := s.Entities[wk.To]
		taken = min(taken, max(*wk.ToMax-dst.Num[toK], 0))
	}
	if taken <= 0 {
		return 0
	}
	lost := taken * wk.Loss / 1000
	if wk.From != "" {
		src := s.Entities[wk.From]
		src.Num[wk.K] -= taken
		s.Entities[wk.From] = src
	} else {
		s.Ledger[ledgerKey("source", wk.K)] += taken
	}
	if wk.To != "" {
		dst := s.Entities[wk.To]
		dst.Num[toK] += taken - lost
		s.Entities[wk.To] = dst
		if lost > 0 {
			s.Ledger[ledgerKey("sink", wk.K)] += lost
		}
	} else {
		s.Ledger[ledgerKey("sink", wk.K)] += taken
	}
	return taken
}

// PopulationView is a cohort as an observer sees it. Headcounts are public:
// they are what the body can feel (how many guards are left).
type PopulationView struct {
	ID     string `json:"id"`
	Role   string `json:"role"`
	Region ID     `json:"region"`
	Count  int64  `json:"count"`
	Max    int64  `json:"max"`
}

func (w *World) populationsView(s *State) []PopulationView {
	out := []PopulationView{}
	for _, id := range sortedKeys(w.pops) {
		d := w.pops[id]
		out = append(out, PopulationView{ID: id, Role: d.Role, Region: d.Region, Count: s.Pops[id].Count, Max: d.capacity()})
	}
	return out
}

func clonePops(m map[string]PopState) map[string]PopState {
	c := make(map[string]PopState, len(m))
	for k, v := range m {
		v.Acc = maps.Clone(v.Acc)
		c[k] = v
	}
	return c
}
