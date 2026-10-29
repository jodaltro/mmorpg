package core

import (
	"slices"
	"strings"
)

// Organs: every part of the body always has work to do, crisis or not. An organ (a region) has a health read from its own numbers
// (the same the crises use, plus a wear that grows with time), the roles its routine work asks for, and a calling offered to whoever
// enters it. A crisis is an event on top: while one is live in the organ the offer follows the crisis, otherwise the organ. What a
// player does there (confirmed deeds in the organ) is shown back to them. Pure: it reads the state and never changes it.

const organContext = "organ:" // the calling context of an organ without a live crisis

// OrganMetricDef is one number of the organ that counts for its health.
type OrganMetricDef struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	E     string `json:"e,omitempty"` // entity (default: the organ)
	K     string `json:"k"`
	Good  string `json:"good"` // "low" or "high"
	Of    int64  `json:"of,omitempty"`
}

// OrganDef describes one organ.
type OrganDef struct {
	ID     string           `json:"id"` // the region (a tissue entity)
	Name   string           `json:"name,omitempty"`
	Needs  []NeedDef        `json:"needs"`
	Health []OrganMetricDef `json:"health"`
}

type OrganMetricView struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Value int64  `json:"value"` // 0..100, 100 is as good as it gets
	Raw   int64  `json:"raw"`
}

type OrganNeedView struct {
	Role    string `json:"role"`
	Weight  int64  `json:"weight"`
	Covered int64  `json:"covered"` // players holding that role in the organ now
}

type OrganDeedView struct {
	Action string `json:"action"`
	Title  string `json:"title"`
	Count  int64  `json:"count"`
}

// OrganView is the state of one organ for an observer.
type OrganView struct {
	ID      ID                `json:"id"`
	Name    string            `json:"name"`
	Health  int64             `json:"health"` // 0..100
	Metrics []OrganMetricView `json:"metrics"`
	Needs   []OrganNeedView   `json:"needs"`
	Crisis  string            `json:"crisis,omitempty"` // the live crisis here (its def)
	Here    int64             `json:"here"`             // players in the organ
	Mine    int64             `json:"mine"`             // the observer's confirmed deeds in this organ
	Deeds   []OrganDeedView   `json:"deeds,omitempty"`  // which ones (only for the organ the observer stands in)
}

func (w *World) compileOrgans(ents map[ID]string) error {
	w.organs = map[string]OrganDef{}
	roles := map[string]bool{}
	for _, c := range w.U.Callings {
		roles[c.Role] = true
	}
	for _, o := range w.U.Organs {
		if !w.regions[ents[ID(o.ID)]] || w.organs[o.ID].ID != "" {
			return invalid("organ %q", o.ID)
		}
		for _, n := range o.Needs {
			if !roles[n.Role] || n.Weight < 1 {
				return invalid("organ %s: need %q", o.ID, n.Role)
			}
		}
		for _, m := range o.Health {
			e := m.E
			if e == "" {
				e = o.ID
			}
			if m.ID == "" || m.K == "" || (m.Good != "low" && m.Good != "high") || ents[ID(e)] == "" || m.Of < 0 {
				return invalid("organ %s: metric %q", o.ID, m.ID)
			}
		}
		w.organs[o.ID] = o
	}
	return nil
}

// organHealth is the mean of what the organ's numbers say, 0..100.
func (w *World) organHealth(s *State, o OrganDef) (int64, []OrganMetricView) {
	out := make([]OrganMetricView, 0, len(o.Health))
	var sum int64
	for _, m := range o.Health {
		e := m.E
		if e == "" {
			e = o.ID
		}
		of := m.Of
		if of == 0 {
			of = 100
		}
		raw := s.Entities[ID(e)].Num[m.K]
		v := min(max(raw, 0), of) * 100 / of
		if m.Good == "low" {
			v = 100 - v
		}
		out = append(out, OrganMetricView{ID: m.ID, Label: m.Label, Value: v, Raw: raw})
		sum += v
	}
	if len(out) == 0 {
		return 100, out
	}
	return sum / int64(len(out)), out
}

// condRegion is the region an action's condition asks the actor to be in, or "".
func condRegion(c Cond) string {
	if c.In != nil {
		return c.In.Region
	}
	for _, sub := range c.All {
		if r := condRegion(sub); r != "" {
			return r
		}
	}
	return ""
}

// organDeeds counts what the observer did in each organ: their confirmed deeds of actions that help and happen in it.
func (w *World) organDeeds(s *State, observer ID, region string) (total int64, list []OrganDeedView) {
	for _, a := range w.U.Actions {
		if !slices.Contains(a.Tags, "help") || condRegion(a.Requires) != region {
			continue
		}
		if n := s.Deeds[observer][a.ID]; n > 0 {
			total += n
			list = append(list, OrganDeedView{Action: a.ID, Title: a.Title, Count: n})
		}
	}
	slices.SortStableFunc(list, func(a, b OrganDeedView) int {
		if a.Count != b.Count {
			return int(b.Count - a.Count)
		}
		return strings.Compare(a.Action, b.Action)
	})
	if len(list) > 6 {
		list = list[:6]
	}
	return
}

func (w *World) organsView(s *State, observer ID) []OrganView {
	if len(w.U.Organs) == 0 {
		return nil
	}
	here := s.Entities[observer].Region
	out := make([]OrganView, 0, len(w.U.Organs))
	for _, o := range w.U.Organs {
		health, metrics := w.organHealth(s, o)
		name := o.Name
		if name == "" {
			name = s.Entities[ID(o.ID)].Name
		}
		v := OrganView{ID: ID(o.ID), Name: name, Health: health, Metrics: metrics, Needs: []OrganNeedView{}}
		crisis := ""
		for _, id := range sortedKeys(s.Conflicts) {
			c := s.Conflicts[id]
			if c.Region == ID(o.ID) && c.Phase != PhaseResolved && (c.Phase == PhaseActive || c.Phase == PhaseCritical) {
				crisis = c.Def
				break
			}
		}
		v.Crisis = crisis
		byRole := map[string]int64{}
		for _, p := range sortedIDs(s.Roles) {
			if s.Entities[p].Region == ID(o.ID) {
				byRole[s.Roles[p].Role]++
			}
		}
		for _, p := range sortedIDs(s.Entities) {
			if s.Entities[p].Kind == w.U.PlayerKind && s.Entities[p].Region == ID(o.ID) {
				v.Here++
			}
		}
		for _, n := range o.Needs {
			v.Needs = append(v.Needs, OrganNeedView{Role: n.Role, Weight: n.Weight, Covered: byRole[n.Role]})
		}
		total, list := w.organDeeds(s, observer, o.ID)
		v.Mine = total
		if ID(o.ID) == here {
			v.Deeds = list
		}
		out = append(out, v)
	}
	return out
}
