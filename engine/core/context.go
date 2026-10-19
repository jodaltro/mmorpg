package core

import (
	"strconv"
	"strings"
)

// Decision context is what an advisor (Jev) reads to choose well. It is
// internal: it may mention hidden story state, but never reaches clients.

func (w *World) name(s *State, id ID) string {
	if e, ok := s.Entities[id]; ok {
		return e.Name
	}
	return string(id)
}

func (w *World) profile(s *State, p ID) []string {
	e := s.Entities[p]
	out := []string{"player: " + e.Name}
	if t := e.Tag["title"]; t != "" {
		out = append(out, "title: "+t)
	}
	nums := []string{}
	for _, k := range sortedKeys(e.Num) {
		nums = append(nums, k+"="+strconv.FormatInt(e.Num[k], 10))
	}
	if len(nums) > 0 {
		out = append(out, "stats: "+strings.Join(nums, ", "))
	}
	done, lost := []string{}, []string{}
	for _, k := range sortedKeys(s.Quests) {
		q := s.Quests[k]
		if q.Holder != p {
			continue
		}
		switch q.State {
		case "done":
			done = append(done, q.Title)
		case "superseded":
			lost = append(lost, q.Title)
		}
	}
	if len(done) > 0 {
		out = append(out, "completed: "+strings.Join(last(done, 5), "; "))
	}
	if len(lost) > 0 {
		out = append(out, "arrived too late for: "+strings.Join(last(lost, 3), "; "))
	}
	for _, k := range sortedKeys(s.Beliefs[p]) {
		b := s.Beliefs[p][k]
		line := "believes " + w.name(s, b.S) + " " + b.P
		if b.O != "" {
			line += " " + w.name(s, b.O)
		}
		line += " = " + boolText(b.Holds) + " (" + b.Source
		if b.From != "" {
			line += " from " + w.name(s, b.From)
		}
		out = append(out, line+")")
	}
	n := 0
	for i := len(s.Events) - 1; i >= 0 && n < 4; i-- {
		if ev := s.Events[i]; ev.Holder == p && ev.Text != "" {
			out = append(out, "recently: "+ev.Text)
			n++
		}
	}
	return out
}

func (w *World) storySoFar(s *State) []string {
	out := []string{}
	for _, a := range w.U.Arcs {
		st := s.Arcs[a.ID]
		parts := []string{}
		for _, id := range st.Path {
			b := st.Beats[id]
			title := w.beats[a.ID][id].Title
			if len(b.By) > 0 {
				names := []string{}
				for _, by := range b.By {
					names = append(names, w.name(s, by))
				}
				parts = append(parts, title+" (by "+strings.Join(last(names, 3), ", ")+")")
			} else if id == st.Current {
				parts = append(parts, title+" ("+b.State+")")
			}
		}
		state := "ongoing"
		if st.Done {
			state = "finished"
		}
		out = append(out, "story "+a.Title+" ["+state+"]: "+strings.Join(parts, " -> "))
	}
	return out
}

func (w *World) offeredToOthers(s *State, p ID, n int) []string {
	seen := map[string]bool{}
	titles := []string{}
	for i := len(s.Events) - 1; i >= 0 && len(titles) < n; i-- {
		if ev := s.Events[i]; ev.Kind == "quest-offered" && ev.Holder != p && !seen[ev.Text] {
			seen[ev.Text] = true
			titles = append(titles, ev.Text)
		}
	}
	if len(titles) == 0 {
		return nil
	}
	return []string{"recently offered to other players: " + strings.Join(titles, "; ")}
}

func last(xs []string, n int) []string {
	if len(xs) > n {
		return xs[len(xs)-n:]
	}
	return xs
}
