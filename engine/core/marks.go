package core

import (
	"slices"
	"strconv"
)

// Reserved verbs of the shared world.
const (
	actMark  = "marcar"    // args: glyph, spot
	actAgree = "concordar" // args: mark
)

// GlyphDef is one of the fixed symbols a traveller can leave in a place.
// There is no free text: a small vocabulary is enough to warn, point and
// reassure, and nothing needs moderating.
type GlyphDef struct {
	ID    string `json:"id"`
	Title string `json:"title"` // "Perigo adiante"
}

// TravelerMarks sets how many marks one person may keep and for how long.
type TravelerMarks struct {
	PerAuthor  int  `json:"perAuthor"`  // the oldest goes when exceeded
	Life       Tick `json:"life"`       // ticks a mark lasts
	AgreeBonus Tick `json:"agreeBonus"` // ticks each agreement adds
}

// Mark is a symbol someone left at a spot. Others who pass can agree with it,
// which keeps it alive longer: a mark many people confirm stays.
type Mark struct {
	ID      string `json:"id"`
	Author  ID     `json:"author"`
	Glyph   string `json:"glyph"`
	Region  ID     `json:"region"`
	Spot    string `json:"spot"`
	At      Tick   `json:"at"`
	Expires Tick   `json:"expires"`
	Agree   []ID   `json:"agree,omitempty"`
}

// MarkView is what one observer sees of a mark in their place.
type MarkView struct {
	ID         string `json:"id"`
	Author     ID     `json:"author"`
	AuthorName string `json:"authorName"`
	Glyph      string `json:"glyph"`
	Title      string `json:"title"`
	Region     ID     `json:"region"`
	Spot       string `json:"spot"`
	Agree      int    `json:"agree"`
	Mine       bool   `json:"mine,omitempty"`
	Agreed     bool   `json:"agreed,omitempty"` // the observer already confirmed it
}

func (w *World) glyph(id string) (GlyphDef, bool) {
	for _, g := range w.U.Glyphs {
		if g.ID == id {
			return g, true
		}
	}
	return GlyphDef{}, false
}

func (w *World) markRules() TravelerMarks {
	r := TravelerMarks{PerAuthor: 3, Life: 200, AgreeBonus: 60}
	if w.U.Travelers != nil {
		r = *w.U.Travelers
	}
	return r
}

// MarksHere lists the marks in the observer's place.
func (w *World) MarksHere(s *State, observer ID) []MarkView {
	out := []MarkView{}
	ent, ok := s.Entities[observer]
	if !ok {
		return out
	}
	for _, m := range s.Marks {
		if m.Region != ent.Region {
			continue
		}
		g, _ := w.glyph(m.Glyph)
		out = append(out, MarkView{ID: m.ID, Author: m.Author, AuthorName: s.Entities[m.Author].Name, Glyph: m.Glyph, Title: g.Title,
			Region: m.Region, Spot: m.Spot, Agree: len(m.Agree), Mine: m.Author == observer, Agreed: slices.Contains(m.Agree, observer)})
	}
	return out
}

func (w *World) leaveMark(s *State, origin string, actor ID, args map[string]ID, cause string) error {
	ent, ok := s.Entities[actor]
	if origin != "player" || !ok || ent.Kind != w.U.PlayerKind || len(args) != 2 {
		return reject("mark")
	}
	g, ok := w.glyph(string(args["glyph"]))
	if !ok {
		return reject("glyph")
	}
	spot := string(args["spot"])
	var region ID
	for _, sp := range w.U.Spots {
		if sp.ID == spot {
			region = sp.Region
		}
	}
	if region == "" || region != ent.Region {
		return reject("spot") // you can only mark where you are
	}
	r := w.markRules()
	mine, oldest := 0, -1
	for i, m := range s.Marks {
		if m.Author == actor {
			mine++
			if oldest < 0 || m.At < s.Marks[oldest].At {
				oldest = i
			}
		}
	}
	if mine >= r.PerAuthor && oldest >= 0 {
		s.Marks = slices.Delete(s.Marks, oldest, oldest+1)
	}
	s.Seq++
	id := "m" + strconv.FormatInt(s.Seq, 10)
	s.Marks = append(s.Marks, Mark{ID: id, Author: actor, Glyph: g.ID, Region: region, Spot: spot, At: s.Tick, Expires: s.Tick + r.Life})
	w.count(s, actor, actMark)
	w.emit(s, Event{Kind: "marked", Actor: actor, Holder: actor, Text: "Voce deixa uma marca: " + g.Title + ".", Cause: cause, Data: map[string]string{"mark": id}})
	return nil
}

func (w *World) agreeMark(s *State, origin string, actor ID, args map[string]ID, cause string) error {
	ent, ok := s.Entities[actor]
	if origin != "player" || !ok || ent.Kind != w.U.PlayerKind || len(args) != 1 {
		return reject("agree")
	}
	for i, m := range s.Marks {
		if string(args["mark"]) != m.ID {
			continue
		}
		if m.Region != ent.Region || m.Author == actor || slices.Contains(m.Agree, actor) {
			return reject("agree")
		}
		s.Marks[i].Agree = append(s.Marks[i].Agree, actor)
		s.Marks[i].Expires += w.markRules().AgreeBonus
		w.count(s, actor, actAgree)
		g, _ := w.glyph(m.Glyph)
		w.emit(s, Event{Kind: "agreed", Actor: actor, Holder: actor, Text: "Voce confirma a marca: " + g.Title + ".", Cause: cause})
		w.emit(s, Event{Kind: "agreed", Actor: actor, Holder: m.Author, Text: ent.Name + " confirma a sua marca: " + g.Title + ".", Cause: cause})
		return nil
	}
	return reject("mark")
}

func (w *World) expireMarks(s *State) {
	if len(s.Marks) == 0 {
		return
	}
	s.Marks = slices.DeleteFunc(s.Marks, func(m Mark) bool { return m.Expires <= s.Tick })
}

// markAffordances: agree with the marks other travellers left here.
func (w *World) markAffordances(s *State, p ID, self Entity) []Affordance {
	out := []Affordance{}
	for _, m := range s.Marks {
		if m.Region != self.Region || m.Author == p || slices.Contains(m.Agree, p) {
			continue
		}
		g, _ := w.glyph(m.Glyph)
		out = append(out, Affordance{Action: actAgree, Title: "Concordar com a marca: " + g.Title, Origin: "player", Args: map[string]ID{"mark": ID(m.ID)}, Region: self.Region, Tags: []string{"social"}})
	}
	return out
}

func titleOf(w *World, e Entity) string {
	if e.Kind != w.U.PlayerKind {
		return ""
	}
	return e.Tag["title"]
}

func (v *validator) glyphs() error {
	seen := map[string]bool{}
	for _, g := range v.w.U.Glyphs {
		if g.ID == "" || g.Title == "" || seen[g.ID] {
			return invalid("glyph %q", g.ID)
		}
		seen[g.ID] = true
	}
	if t := v.w.U.Travelers; t != nil && (t.PerAuthor < 1 || t.Life < 1 || t.AgreeBonus < 0) {
		return invalid("travelerMarks")
	}
	for _, reserved := range []string{actMark, actAgree} {
		if _, taken := v.w.actions[reserved]; taken {
			return invalid("action id %q is reserved by the engine", reserved)
		}
	}
	return nil
}
