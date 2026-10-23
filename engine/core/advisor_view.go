package core

import (
	"slices"
	"strconv"
)

// What the advisor (Jev) is doing for this player, for a debug panel: the decisions waiting for an answer and the last decisions that
// were taken (who answered, how long it took, what it cost). Nothing here reveals the world's truth: it is the player's own decisions
// (their mutations, class, body, route...) and how they were resolved.

// AdvisorRow is one decision that was taken for the observer.
type AdvisorRow struct {
	Tick       Tick    `json:"tick"`
	Kind       string  `json:"kind"`   // evolution, evolution-slot, lineage, ability, appearance, design, rota, dungeon, offer...
	Detail     string  `json:"detail"` // for a design, the trait; for a slot, its number
	Choice     string  `json:"choice"`
	Default    string  `json:"default"`
	Provider   string  `json:"provider"` // jev, deterministic, default (the deadline), test
	Model      string  `json:"model,omitempty"`
	LatencyMS  int64   `json:"latencyMs,omitempty"`
	Cost       float64 `json:"cost,omitempty"`
	Confidence float64 `json:"confidence,omitempty"`
}

// AdvisorPending is a decision waiting for an answer.
type AdvisorPending struct {
	Kind    string `json:"kind"`
	Detail  string `json:"detail"`
	Options int    `json:"options"`
	Default string `json:"default"`
	DueIn   Tick   `json:"dueIn"` // ticks left before the default applies
}

// AdvisorView is the observer's window on the advisor.
type AdvisorView struct {
	Recent  []AdvisorRow     `json:"recent"`
	Pending []AdvisorPending `json:"pending"`
}

const advisorRecent = 60

// detailOf is the part of a decision id that says what exactly was decided (the trait of a design, the slot of an offer).
func detailOf(kind, id string) string {
	parts := splitID(id)
	switch kind {
	case "design", kindSlot:
		if len(parts) >= 2 {
			return parts[1]
		}
	}
	return ""
}

func splitID(id string) []string {
	var out []string
	cur := ""
	for _, r := range id {
		if r == ':' {
			out = append(out, cur)
			cur = ""
			continue
		}
		cur += string(r)
	}
	return append(out, cur)
}

func (w *World) advisorView(s *State, observer ID) *AdvisorView {
	v := &AdvisorView{Recent: []AdvisorRow{}, Pending: []AdvisorPending{}}
	for i := len(s.Events) - 1; i >= 0 && len(v.Recent) < advisorRecent; i-- {
		e := s.Events[i]
		if e.Kind != "decision" || e.Data["subject"] != string(observer) {
			continue
		}
		row := AdvisorRow{Tick: e.At, Kind: e.Data["kind"], Detail: detailOf(e.Data["kind"], e.Data["decision"]), Choice: e.Data["choice"], Default: e.Data["default"], Provider: e.Data["provider"], Model: e.Data["model"]}
		row.LatencyMS, _ = strconv.ParseInt(e.Data["latencyMs"], 10, 64)
		row.Cost, _ = strconv.ParseFloat(e.Data["cost"], 64)
		row.Confidence, _ = strconv.ParseFloat(e.Data["confidence"], 64)
		v.Recent = append(v.Recent, row)
	}
	for _, id := range sortedKeys(s.Decisions) {
		d := s.Decisions[id]
		if d.Subject != string(observer) {
			continue
		}
		v.Pending = append(v.Pending, AdvisorPending{Kind: d.Kind, Detail: detailOf(d.Kind, d.ID), Options: len(d.Options), Default: d.Default, DueIn: max(d.Due-s.Tick, 0)})
	}
	slices.SortStableFunc(v.Pending, func(a, b AdvisorPending) int { return int(a.DueIn - b.DueIn) })
	return v
}
