package core

// VitalDef names a number of the world that every observer may read: the body's
// temperature, the oxygen of a place, a hormone. It is public by design (what a
// player could feel or measure), so the universe lists exactly which numbers are
// shown. The rules that move them are ordinary rules and happenings.
type VitalDef struct {
	ID     string `json:"id"`
	Label  string `json:"label"`
	Entity ID     `json:"e"`
	Key    string `json:"k"`
	Min    int64  `json:"min"`
	Max    int64  `json:"max"`
	// Low and High bound the healthy range (both zero: no range is shown).
	Low  int64 `json:"low,omitempty"`
	High int64 `json:"high,omitempty"`
}

// VitalView is one vital as an observer sees it.
type VitalView struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Value int64  `json:"value"`
	Min   int64  `json:"min"`
	Max   int64  `json:"max"`
	Low   int64  `json:"low,omitempty"`
	High  int64  `json:"high,omitempty"`
}

func (w *World) vitalsView(s *State) []VitalView {
	out := []VitalView{}
	for _, d := range w.U.Vitals {
		e, ok := s.Entities[d.Entity]
		if !ok {
			continue
		}
		out = append(out, VitalView{ID: d.ID, Label: d.Label, Value: e.Num[d.Key], Min: d.Min, Max: d.Max, Low: d.Low, High: d.High})
	}
	return out
}

func (w *World) compileVitals(ents map[ID]string) error {
	seen := map[string]bool{}
	for _, d := range w.U.Vitals {
		if d.ID == "" || seen[d.ID] {
			return invalid("vital %q: empty or duplicate id", d.ID)
		}
		seen[d.ID] = true
		if ents[d.Entity] == "" || d.Key == "" {
			return invalid("vital %s: unknown entity %q or empty key", d.ID, d.Entity)
		}
		if d.Max <= d.Min {
			return invalid("vital %s: max must be above min", d.ID)
		}
	}
	return nil
}
