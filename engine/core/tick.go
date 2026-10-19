package core

import (
	"maps"
	"slices"
)

// tick advances world time. Nothing here depends on a player being online:
// schedules fire, rules run, stories open, NPCs act and quests are offered.
func (w *World) tick(s *State, cause string) {
	s.Tick++
	for len(s.Schedules) > 0 && s.Schedules[0].Due <= s.Tick {
		sc := s.Schedules[0]
		s.Schedules = s.Schedules[1:]
		r := w.rules[sc.Rule]
		b := maps.Clone(sc.Bind)
		if b == nil {
			b = Bind{}
		}
		if w.Holds(s, r.When, b) {
			w.apply(s, r.Effects, b, "rule:"+r.ID)
		}
	}
	for _, r := range w.U.Rules {
		if r.Every == 0 || s.Tick%r.Every != 0 {
			continue
		}
		if r.ForEach == "" {
			if w.Holds(s, r.When, Bind{}) {
				w.apply(s, r.Effects, Bind{}, "rule:"+r.ID)
			}
			continue
		}
		for _, id := range sortedIDs(s.Entities) {
			if s.Entities[id].Kind == r.ForEach {
				b := Bind{"it": id}
				if w.Holds(s, r.When, b) {
					w.apply(s, r.Effects, b, "rule:"+r.ID)
				}
			}
		}
	}
	w.stories(s, cause)
	w.direct(s)
	for _, id := range sortedKeys(s.Decisions) {
		if d := s.Decisions[id]; d.Due <= s.Tick {
			w.decideDefault(s, d, cause)
		}
	}
	w.think(s)
	w.questTick(s, cause)
}

func (w *World) stories(s *State, cause string) {
	for _, a := range w.U.Arcs {
		st := s.Arcs[a.ID]
		if st.Done || st.Choosing || st.Current == "" {
			continue
		}
		beat := w.beats[a.ID][st.Current]
		bs := st.Beats[beat.ID]
		if bs.State == "locked" && w.Holds(s, beat.Opens, Bind{}) {
			bs.State, bs.At = "open", s.Tick
			st.Beats[beat.ID] = bs
			s.Arcs[a.ID] = st
			// Unique scenarios open silently: players discover them through
			// the quests offered to them, not through a global announcement.
			w.emit(s, Event{Kind: "beat-open", Cause: cause, Data: map[string]string{"arc": a.ID, "beat": beat.ID}})
		}
		if bs.State == "open" && beat.AdvanceWhen != nil && w.Holds(s, *beat.AdvanceWhen, Bind{}) {
			w.advance(s, a.ID, beat, nil, cause)
		}
	}
}

// advance moves an arc past a beat. With several possible continuations a
// story decision is created; the advisor may pick, the default never waits.
func (w *World) advance(s *State, arc string, beat BeatDef, claimant *ID, cause string) {
	for _, k := range sortedKeys(s.Quests) {
		q := s.Quests[k]
		def := w.quests[q.Def]
		claimed := slices.Contains(s.Arcs[arc].Beats[beat.ID].By, q.Holder)
		if def.Arc == arc && def.Beat == beat.ID && !claimed && (q.State == "offered" || q.State == "active") {
			q.State = "superseded"
			s.Quests[k] = q
			w.emit(s, Event{Kind: "quest-superseded", Holder: q.Holder, Text: q.Title, Cause: cause})
		}
	}
	st := s.Arcs[arc]
	switch len(beat.Next) {
	case 0:
		st.Done, st.Current = true, ""
		s.Arcs[arc] = st
		w.emit(s, Event{Kind: "arc-done", Public: true, Text: w.arcs[arc].Title, Cause: cause, Data: map[string]string{"arc": arc}})
		return
	case 1:
		s.Arcs[arc] = st
		w.setBeat(s, arc, beat.Next[0])
		return
	}
	opts := []Option{}
	def := ""
	for _, n := range beat.Next {
		nb := w.beats[arc][n]
		opts = append(opts, Option{ID: n, Title: nb.Title, Desc: nb.Desc})
		if def == "" && w.Holds(s, nb.Opens, Bind{}) {
			def = n
		}
	}
	if def == "" {
		def = beat.Next[0]
	}
	ctx := []string{"arc: " + w.arcs[arc].Title, "just concluded: " + beat.Title}
	if claimant != nil {
		ctx = append(ctx, "concluded by:")
		ctx = append(ctx, w.profile(s, *claimant)...)
	}
	ctx = append(ctx, w.storySoFar(s)...)
	ctx = append(ctx, w.recentPublic(s, 6)...)
	st.Choosing = true
	s.Arcs[arc] = st
	id := "story:" + arc + ":" + beat.ID
	s.Decisions[id] = Decision{ID: id, Kind: "story", Subject: arc, Options: opts, Default: def,
		Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
}

func (w *World) setBeat(s *State, arc, beat string) {
	st := s.Arcs[arc]
	st.Current, st.Choosing = beat, false
	st.Path = append(st.Path, beat)
	s.Arcs[arc] = st
}

func (w *World) recentPublic(s *State, n int) []string {
	out := []string{}
	for i := len(s.Events) - 1; i >= 0 && len(out) < n; i-- {
		if s.Events[i].Public {
			out = append(out, "event: "+s.Events[i].Text)
		}
	}
	slices.Reverse(out)
	return out
}

// think runs NPC agents. An agent acts on what it believes; the authority
// checks the truth. A failed attempt teaches the agent the facts it misread.
func (w *World) think(s *State) {
	for _, id := range sortedIDs(w.agents) {
		a := w.agents[id]
		if _, alive := s.Entities[id]; !alive {
			continue
		}
		if a.Think > 1 && s.Tick%a.Think != 0 {
			continue
		}
		goals := slices.Clone(a.Goals)
		slices.SortStableFunc(goals, func(x, y GoalDef) int { return y.Priority - x.Priority })
		for _, g := range goals {
			key := string(id) + "|" + g.ID
			if s.Cooldowns[key] > s.Tick {
				continue
			}
			b := Bind{"self": id}
			if !w.Holds(s, g.When, b) {
				continue
			}
			args := map[string]ID{}
			for name, ref := range g.Args {
				args[name] = resolve(ref, b)
				b[name] = args[name]
			}
			if g.Cooldown > 0 {
				s.Cooldowns[key] = s.Tick + g.Cooldown
			}
			cause := "agent:" + string(id) + ":" + g.ID
			if err := w.act(s, "agent", id, g.Action, args, cause); err != nil {
				var ps []Pattern
				patterns(w.actions[g.Action].Requires, &ps)
				for _, p := range ps {
					if bel, ok := w.belief(s, &p, b, "observation", ""); ok {
						s.believe(id, bel)
					}
				}
				w.emit(s, Event{Kind: "agent-failed", Actor: id, Cause: cause, Data: map[string]string{"goal": g.ID}})
			} else {
				w.completeAll(s, cause)
			}
			break
		}
	}
}
