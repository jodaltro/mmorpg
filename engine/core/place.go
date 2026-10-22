package core

import "slices"

// SpotDef is a named place inside a region (the well, the forge). The core
// never positions anything: a client maps spot ids to coordinates.
type SpotDef struct {
	ID     string `json:"id"`
	Region ID     `json:"region"`
	Name   string `json:"name"`
	// Near lists spots close enough that whoever is there sees what happens here
	// (the plaza and the well). A spot always sees itself.
	Near []string `json:"near,omitempty"`
}

// Routine says where an NPC is through the day. The first Override whose
// condition holds wins (an outbreak keeps the healer at the patients); else
// the Slot covering the current hour. Slots may wrap midnight (From > To).
type Routine struct {
	NPC       ID            `json:"npc"`
	Slots     []RoutineSlot `json:"slots"`
	Overrides []RoutineSlot `json:"overrides,omitempty"`
}

type RoutineSlot struct {
	From   int64  `json:"from,omitempty"` // in-game hour, inclusive
	To     int64  `json:"to,omitempty"`   // exclusive
	Region ID     `json:"region"`
	Spot   string `json:"spot"`
	Doing  string `json:"doing,omitempty"`
	When   *Cond  `json:"when,omitempty"` // overrides only; $self is the NPC
}

// Chatter is a conversation people overhear. It happens only when every
// speaker is at its spot and the condition holds, so what is said follows
// what the speakers believe, not what is true. Listeners are the players in
// the region; Hear runs for each with $self = listener, $speaker = first
// speaker.
type Chatter struct {
	ID       string        `json:"id"`
	Spot     string        `json:"spot"`
	Speakers []ID          `json:"speakers"`
	When     *Cond         `json:"when,omitempty"` // $self is the first speaker
	Lines    []ChatterLine `json:"lines"`
	Hear     []Effect      `json:"hear,omitempty"`
}

type ChatterLine struct {
	Who  ID     `json:"who"`
	Text string `json:"text"`
}

func (v *validator) places() error {
	w := v.w
	u := w.U
	if u.ChatterEvery < 0 {
		return invalid("chatterEvery")
	}
	spots := map[string]ID{}
	for _, sp := range u.Spots {
		if sp.ID == "" || sp.Name == "" || spots[sp.ID] != "" || !w.regions[v.ents[sp.Region]] {
			return invalid("spot %q", sp.ID)
		}
		spots[sp.ID] = sp.Region
	}
	for _, sp := range u.Spots {
		for _, n := range sp.Near {
			if spots[n] != sp.Region || n == sp.ID {
				return invalid("spot %s: near %q", sp.ID, n)
			}
		}
	}
	slot := func(sl RoutineSlot, who string, override bool) error {
		if spots[sl.Spot] != sl.Region || sl.From < 0 || sl.From > 23 || sl.To < 0 || sl.To > 24 {
			return invalid("routine %s: slot %s/%s", who, sl.Region, sl.Spot)
		}
		if override != (sl.When != nil) {
			return invalid("routine %s: only overrides have a condition", who)
		}
		if sl.When != nil {
			return v.cond(*sl.When, map[string]bool{"self": true}, "routine "+who)
		}
		return nil
	}
	seen := map[ID]bool{}
	for _, r := range u.Routines {
		if v.ents[r.NPC] == "" || seen[r.NPC] || len(r.Slots) == 0 || !w.perceives[v.ents[r.NPC]] && v.ents[r.NPC] == u.PlayerKind {
			return invalid("routine %q", r.NPC)
		}
		seen[r.NPC] = true
		for _, sl := range r.Slots {
			if err := slot(sl, string(r.NPC), false); err != nil {
				return err
			}
		}
		for _, sl := range r.Overrides {
			if err := slot(sl, string(r.NPC), true); err != nil {
				return err
			}
		}
	}
	ids := map[string]bool{}
	for _, c := range u.Chatter {
		if c.ID == "" || ids[c.ID] || spots[c.Spot] == "" || len(c.Speakers) == 0 || len(c.Lines) == 0 {
			return invalid("chatter %q", c.ID)
		}
		ids[c.ID] = true
		for _, sp := range c.Speakers {
			if v.ents[sp] == "" {
				return invalid("chatter %s: speaker %q", c.ID, sp)
			}
		}
		for _, l := range c.Lines {
			if l.Text == "" || !slices.Contains(c.Speakers, l.Who) {
				return invalid("chatter %s: line by %q", c.ID, l.Who)
			}
		}
		if c.When != nil {
			if err := v.cond(*c.When, map[string]bool{"self": true}, "chatter "+c.ID); err != nil {
				return err
			}
		}
		if err := v.effects(c.Hear, map[string]bool{"self": true, "speaker": true}, "chatter "+c.ID); err != nil {
			return err
		}
	}
	return nil
}

func (sl RoutineSlot) covers(hour int64) bool {
	if sl.From <= sl.To {
		return hour >= sl.From && hour < sl.To
	}
	return hour >= sl.From || hour < sl.To
}

// routines puts each NPC where its day says, every tick, in ID order. It
// needs days: without them an NPC just stays put.
func (w *World) routines(s *State) {
	hour := w.Hour(s)
	if hour < 0 {
		return
	}
	for _, r := range w.U.Routines {
		ent, ok := s.Entities[r.NPC]
		if !ok {
			continue
		}
		var want *RoutineSlot
		for i := range r.Overrides {
			if w.Holds(s, *r.Overrides[i].When, Bind{"self": r.NPC}) {
				want = &r.Overrides[i]
				break
			}
		}
		if want == nil {
			for i := range r.Slots {
				if r.Slots[i].covers(hour) {
					want = &r.Slots[i]
					break
				}
			}
		}
		if want == nil || ent.Region == want.Region && ent.Tag["spot"] == want.Spot && ent.Tag["doing"] == want.Doing {
			continue
		}
		ent.Region = want.Region
		ent.Tag["spot"], ent.Tag["doing"] = want.Spot, want.Doing
		s.Entities[r.NPC] = ent
	}
}

// chatter makes one overheard conversation per spot every ChatterEvery
// ticks, rotating through the ones that make sense now.
func (w *World) chatter(s *State) {
	every := w.U.ChatterEvery
	if every == 0 {
		every = 3
	}
	if len(w.U.Chatter) == 0 || s.Tick%every != 0 {
		return
	}
	bySpot := map[string][]Chatter{}
	var order []string
	for _, c := range w.U.Chatter {
		if !w.chatterReady(s, c) {
			continue
		}
		if _, ok := bySpot[c.Spot]; !ok {
			order = append(order, c.Spot)
		}
		bySpot[c.Spot] = append(bySpot[c.Spot], c)
	}
	for _, spot := range order {
		list := bySpot[spot]
		c := list[int(s.Tick/every)%len(list)]
		region := s.Entities[c.Speakers[0]].Region
		for _, l := range c.Lines {
			w.emit(s, Event{Kind: "chatter", Actor: l.Who, Public: true, Text: l.Text, Cause: "chatter:" + c.ID,
				Data: map[string]string{"region": string(region), "spot": spot, "chatter": c.ID}})
		}
		for _, id := range sortedIDs(s.Entities) {
			if e := s.Entities[id]; e.Kind == w.U.PlayerKind && e.Region == region {
				w.apply(s, c.Hear, Bind{"self": id, "speaker": c.Speakers[0]}, "chatter:"+c.ID)
			}
		}
	}
}

func (w *World) chatterReady(s *State, c Chatter) bool {
	for _, sp := range c.Speakers {
		e, ok := s.Entities[sp]
		if !ok || e.Tag["spot"] != c.Spot {
			return false
		}
	}
	return c.When == nil || w.Holds(s, *c.When, Bind{"self": c.Speakers[0]})
}
