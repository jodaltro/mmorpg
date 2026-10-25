package core

import "slices"

// View is what one observer may see. World truth is never exposed directly:
// a player sees their own entity, their private facts, their beliefs, their
// quests and the events visible to them. Two players in the same world see
// different worlds because they know different things.
type View struct {
	Universe  string           `json:"universe"`
	Tick      Tick             `json:"tick"`
	Hour      int64            `json:"hour"` // in-game hour, -1 without days
	Revision  int64            `json:"revision"`
	Self      Entity           `json:"self"`
	Style     map[string]int64 `json:"style,omitempty"` // what the world learned about this player
	Skills    []SkillView      `json:"skills"`
	Others    []Seen           `json:"others"`
	Facts     []Fact           `json:"facts"`
	Beliefs   []Belief         `json:"beliefs"`
	Quests    []Quest          `json:"quests"`
	Events    []Event          `json:"events"`
	Story     []StoryView      `json:"story"`
	Signs     []SignView       `json:"signs"` // traces of hidden things the observer can make out here
	Marks     []MarkView       `json:"marks"`
	Evolution *EvolutionView   `json:"evolution,omitempty"` // the observer's own genome and mutation offer
	Lineage   *LineageView     `json:"lineage,omitempty"`   // the observer's lineage, offer and progress
	Look      *LookView        `json:"look,omitempty"`      // the observer's own procedural body
	Dungeon   *DungeonView     `json:"dungeon,omitempty"`   // the dungeons the observer may enter and their current run
	Vitals    []VitalView      `json:"vitals,omitempty"`    // the public numbers of the body
	Explore   *ExploreView     `json:"explore,omitempty"`   // passages (open or closed) and niches
	Codex     []CodexView      `json:"codex,omitempty"`     // the codex of the body
	Advisor   *AdvisorView     `json:"advisor,omitempty"`   // what the advisor decided for this player (debug)
}

type Seen struct {
	ID     ID     `json:"id"`
	Kind   string `json:"kind"`
	Name   string `json:"name"`
	Region ID     `json:"region,omitempty"`
	Spot   string `json:"spot,omitempty"`  // where in the region (a universe spot)
	Doing  string `json:"doing,omitempty"` // what they are up to, from their routine
	// KnowsYou is true when this person believes it knows the observer: they
	// saw them act nearby or heard of them. The observer can tell from how
	// they are greeted, so it is not a secret.
	KnowsYou bool `json:"knowsYou,omitempty"`
	// Title is the public recognition a player earned (a unique chapter claimed).
	Title string `json:"title,omitempty"`
	// Marks are visible signs of what this person carries (see Universe.VisibleMarks).
	Marks []string `json:"marks,omitempty"`
	// Look is the person's procedural body (players only), so everyone sees who they are.
	Look *LookView `json:"look,omitempty"`
}

// StoryView shows the public chronicle of an arc: which chapters were
// claimed, by whom. Open unique scenarios stay hidden unless the observer
// is pursuing one.
type StoryView struct {
	Arc       string    `json:"arc"`
	Title     string    `json:"title"`
	Done      bool      `json:"done"`
	Chronicle []Chapter `json:"chronicle"`
	Pursuing  *Chapter  `json:"pursuing,omitempty"`
}

type Chapter struct {
	Beat  string   `json:"beat"`
	Title string   `json:"title"`
	By    []string `json:"by,omitempty"`
	At    Tick     `json:"at,omitempty"`
}

func (w *World) View(s *State, observer ID, limit int) (View, bool) {
	self, ok := s.Entities[observer]
	if !ok {
		return View{}, false
	}
	v := View{Universe: s.Universe, Tick: s.Tick, Hour: w.Hour(s), Style: s.Styles[observer], Skills: w.skillsOf(s, observer), Revision: s.Revision, Self: self, Others: []Seen{}, Facts: []Fact{},
		Beliefs: []Belief{}, Quests: []Quest{}, Events: []Event{}, Story: []StoryView{}, Signs: w.Signs(s, observer), Marks: w.MarksHere(s, observer), Evolution: w.evolutionView(s, observer), Look: w.lookOf(s, observer), Lineage: w.lineageViewOf(s, observer), Dungeon: w.dungeonView(s, observer), Vitals: w.vitalsView(s), Explore: w.exploreView(s, observer), Codex: w.codexView(s, observer), Advisor: w.advisorView(s, observer)}
	for _, id := range sortedIDs(s.Entities) {
		if id != observer {
			e := s.Entities[id]
			marks := w.marksOf(s, id, e.Kind)
			v.Others = append(v.Others, Seen{ID: id, Kind: e.Kind, Name: e.Name, Region: e.Region, Spot: e.Tag["spot"], Doing: e.Tag["doing"], KnowsYou: w.U.Acquaintance != "" && e.Kind != w.U.PlayerKind && w.knowsOf(s, id, observer), Marks: marks, Title: titleOf(w, e), Look: w.lookOf(s, id)})
		}
	}
	for _, k := range sortedKeys(s.Facts) {
		if f := s.Facts[k]; f.Holder == observer {
			v.Facts = append(v.Facts, f)
		}
	}
	for _, k := range sortedKeys(s.Beliefs[observer]) {
		v.Beliefs = append(v.Beliefs, s.Beliefs[observer][k])
	}
	for _, k := range sortedKeys(s.Quests) {
		if q := s.Quests[k]; q.Holder == observer {
			q.RewardDetails = w.rewardInfo(s, observer, w.quests[q.Def].Rewards)
			v.Quests = append(v.Quests, q)
		}
	}
	for _, e := range s.Events {
		if e.Public || e.Holder == observer {
			v.Events = append(v.Events, e)
		}
	}
	if limit > 0 && len(v.Events) > limit {
		v.Events = v.Events[len(v.Events)-limit:]
	}
	for _, a := range w.U.Arcs {
		sv := w.storyView(s, a)
		for _, q := range v.Quests {
			d := w.quests[q.Def]
			if d.Arc == a.ID && (q.State == "offered" || q.State == "active") {
				b := w.beats[a.ID][d.Beat]
				sv.Pursuing = &Chapter{Beat: b.ID, Title: b.Title}
			}
		}
		v.Story = append(v.Story, sv)
	}
	return v, true
}

func (w *World) storyView(s *State, a ArcDef) StoryView {
	st := s.Arcs[a.ID]
	sv := StoryView{Arc: a.ID, Title: a.Title, Done: st.Done, Chronicle: []Chapter{}}
	for _, id := range st.Path {
		bs := st.Beats[id]
		if len(bs.By) == 0 {
			continue
		}
		c := Chapter{Beat: id, Title: w.beats[a.ID][id].Title, At: bs.At}
		for _, by := range bs.By {
			c.By = append(c.By, s.Entities[by].Name)
		}
		sv.Chronicle = append(sv.Chronicle, c)
	}
	return sv
}

// Chronicle is the public face of the world, for spectators and lobbies.
type Chronicle struct {
	Universe string      `json:"universe"`
	Tick     Tick        `json:"tick"`
	Revision int64       `json:"revision"`
	Events   []Event     `json:"events"`
	Story    []StoryView `json:"story"`
}

func (w *World) Chronicle(s *State, limit int) Chronicle {
	c := Chronicle{Universe: s.Universe, Tick: s.Tick, Revision: s.Revision, Events: []Event{}, Story: []StoryView{}}
	for _, e := range s.Events {
		if e.Public {
			c.Events = append(c.Events, e)
		}
	}
	if limit > 0 && len(c.Events) > limit {
		c.Events = c.Events[len(c.Events)-limit:]
	}
	for _, a := range w.U.Arcs {
		c.Story = append(c.Story, w.storyView(s, a))
	}
	return c
}

// Universe returns the compiled definition (read-only by convention).
func (w *World) Universe() Universe { return w.U }

// marksOf lists the visible marks a person carries (private facts about
// themselves whose predicate the universe says shows).
func (w *World) marksOf(s *State, id ID, kind string) []string {
	if len(w.U.VisibleMarks) == 0 || kind != w.U.PlayerKind {
		return nil
	}
	var out []string
	for _, m := range w.U.VisibleMarks {
		for _, f := range s.Facts {
			if f.P == m && f.S == id && f.Holder == id {
				out = append(out, m)
				break
			}
		}
	}
	slices.Sort(out)
	return out
}
