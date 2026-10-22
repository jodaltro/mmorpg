package core

import (
	"slices"
	"strings"
)

// Reserved action ids: the engine's own verbs for learning about the world.
const (
	actExamine = "examinar" // args: sign
	actTell    = "contar"   // args: npc, p, s[, o]
)

// SignDef is a physical trace of something hidden: murky water, gnawed
// carrots, a light at night. It shows the effect, never the cause. A sign
// exists while When holds; only those who can Perceive it see it, and
// examining it gives the observer an observation or a private clue.
type SignDef struct {
	ID       string   `json:"id"`
	Region   ID       `json:"region"`
	Spot     string   `json:"spot,omitempty"`
	Title    string   `json:"title"`          // the prompt: "Examinar a agua do poco"
	Look     string   `json:"look"`           // what anyone who can perceive it sees from afar
	Text     string   `json:"text"`           // what examining it reveals, in words
	When     *Cond    `json:"when,omitempty"` // $self is the observer; empty = always there
	Perceive *Cond    `json:"perceive,omitempty"`
	Examine  []Effect `json:"examine,omitempty"`
	// FarFrom lists other regions from which the sign can still be made out
	// (a tower, a column of smoke, a glow at night). From there it is only a
	// landmark: examining needs being where it is.
	FarFrom []ID `json:"farFrom,omitempty"`
}

// SignView is what the observer is shown of a sign.
type SignView struct {
	ID     string `json:"id"`
	Region ID     `json:"region"`
	Spot   string `json:"spot,omitempty"`
	Title  string `json:"title"`
	Look   string `json:"look"`
	Far    bool   `json:"far,omitempty"` // seen from another region: a landmark, not yet examinable
}

// Reaction is how people answer when told what the teller believes. Tell
// someone what they already know, something that is no longer true, or news.
type Reaction struct {
	P       string   `json:"p"`
	S       string   `json:"s,omitempty"`   // empty = any subject
	Who     []ID     `json:"who,omitempty"` // empty = anyone who perceives
	Told    string   `json:"told"`          // news: the listener now believes it
	Known   string   `json:"known"`         // they already believed it
	Stale   string   `json:"stale"`         // it is not true any more: they do not take it in
	Effects []Effect `json:"effects,omitempty"`
}

func (w *World) signByID(id string) (SignDef, bool) {
	for _, sg := range w.U.Signs {
		if sg.ID == id {
			return sg, true
		}
	}
	return SignDef{}, false
}

// visibleSign: the sign exists now and the observer can make it out.
func (w *World) visibleSign(s *State, sg SignDef, observer ID) bool {
	b := Bind{"self": observer}
	if sg.When != nil && !w.Holds(s, *sg.When, b) {
		return false
	}
	return sg.Perceive == nil || w.Holds(s, *sg.Perceive, b)
}

// Signs lists what the observer can make out where they are.
func (w *World) Signs(s *State, observer ID) []SignView {
	out := []SignView{}
	ent, ok := s.Entities[observer]
	if !ok {
		return out
	}
	for _, sg := range w.U.Signs {
		near := sg.Region == ent.Region
		if (near || slices.Contains(sg.FarFrom, ent.Region)) && w.visibleSign(s, sg, observer) {
			out = append(out, SignView{ID: sg.ID, Region: sg.Region, Spot: sg.Spot, Title: sg.Title, Look: sg.Look, Far: !near})
		}
	}
	return out
}

func (w *World) examine(s *State, origin string, actor ID, args map[string]ID, cause string) error {
	ent, ok := s.Entities[actor]
	if origin != "player" || !ok || ent.Kind != w.U.PlayerKind || len(args) != 1 {
		return reject("examine")
	}
	sg, ok := w.signByID(string(args["sign"]))
	if !ok || sg.Region != ent.Region || !w.visibleSign(s, sg, actor) {
		return reject("sign")
	}
	w.count(s, actor, actExamine)
	w.count(s, actor, actExamine+":"+sg.ID)
	w.emit(s, Event{Kind: "examined", Actor: actor, Holder: actor, Text: sg.Text, Cause: cause, Data: map[string]string{"sign": sg.ID}})
	w.apply(s, sg.Examine, Bind{"self": actor}, cause)
	w.learn(s, actor, []string{"explore"}, 1)
	return nil
}

func (w *World) reactionFor(p string, subject, npc ID) (Reaction, bool) {
	for _, r := range w.U.Reactions {
		if r.P == p && (r.S == "" || ID(r.S) == subject) && (len(r.Who) == 0 || slices.Contains(r.Who, npc)) {
			return r, true
		}
	}
	return Reaction{}, false
}

// tellBelief passes on something the teller believes to someone in the same place.
// The listener takes it in as heard from the teller, unless it no longer
// matches the truth or they already believed it.
func (w *World) tellBelief(s *State, origin string, actor ID, args map[string]ID, cause string) error {
	ent, ok := s.Entities[actor]
	if origin != "player" || !ok || ent.Kind != w.U.PlayerKind || len(args) < 3 || len(args) > 4 {
		return reject("tell")
	}
	npc, ok := s.Entities[args["npc"]]
	toPlayer := ok && npc.Kind == w.U.PlayerKind
	if !ok || npc.ID == actor || npc.Region != ent.Region || !toPlayer && !slices.Contains(w.U.Perceivers, npc.Kind) {
		return reject("listener")
	}
	p, subject, object := string(args["p"]), args["s"], args["o"]
	if !w.preds[p] {
		return reject("belief")
	}
	key := factKey("", p, subject, object)
	mine, ok := s.Beliefs[actor][key]
	if !ok {
		return reject("belief") // you cannot tell what you do not believe
	}
	text := func(t string) string {
		return strings.NewReplacer("{self}", ent.Name, "{npc}", npc.Name).Replace(t)
	}
	r, covered := w.reactionFor(p, subject, npc.ID)
	_, truth := s.Facts[key]
	w.count(s, actor, actTell)
	switch theirs, knew := s.Beliefs[npc.ID][key]; {
	case mine.Holds != truth: // what you believe is out of date
		msg := "{npc} ouve, mas nao parece convencido."
		if covered && r.Stale != "" {
			msg = r.Stale
		}
		w.emit(s, Event{Kind: "told", Actor: actor, Holder: actor, Text: text(msg), Cause: cause})
	case knew && theirs.Holds == mine.Holds:
		msg := "{npc} ja sabia disso."
		if covered && r.Known != "" {
			msg = r.Known
		}
		w.emit(s, Event{Kind: "told", Actor: actor, Holder: actor, Text: text(msg), Cause: cause})
	default:
		heard := mine
		heard.Source, heard.From, heard.At = "communication", actor, s.Tick
		s.believe(npc.ID, heard)
		if toPlayer { // a secret passed between players: the listener is told too
			w.emit(s, Event{Kind: "told", Actor: actor, Holder: npc.ID, Text: ent.Name + " lhe conta algo que sabe.", Cause: cause, Data: map[string]string{"p": p}})
		}
		msg := "{npc} escuta com atencao."
		if covered && r.Told != "" {
			msg = r.Told
		}
		w.emit(s, Event{Kind: "told", Actor: actor, Holder: actor, Text: text(msg), Cause: cause})
		if covered {
			w.apply(s, r.Effects, Bind{"self": actor, "npc": npc.ID}, cause)
		}
	}
	w.learn(s, actor, []string{"social"}, 1)
	return nil
}

// signAffordances: examining what the observer can see, telling what they
// believe to people who would react to it.
func (w *World) signAffordances(s *State, p ID, self Entity) []Affordance {
	out := []Affordance{}
	for _, sg := range w.U.Signs {
		if sg.Region == self.Region && w.visibleSign(s, sg, p) {
			out = append(out, Affordance{Action: actExamine, Title: sg.Title, Origin: "player", Args: map[string]ID{"sign": ID(sg.ID)}, Region: self.Region, Tags: []string{"explore"}})
		}
	}
	for _, npc := range sortedIDs(s.Entities) {
		e := s.Entities[npc]
		if npc == p || e.Region != self.Region || !(e.Kind == w.U.PlayerKind || slices.Contains(w.U.Perceivers, e.Kind)) {
			continue
		}
		for _, k := range sortedKeys(s.Beliefs[p]) {
			b := s.Beliefs[p][k]
			if e.Kind == w.U.PlayerKind { // another player: pass on what they do not already believe
				if theirs, has := s.Beliefs[npc][k]; has && theirs.Holds == b.Holds {
					continue
				}
			} else if _, ok := w.reactionFor(b.P, b.S, npc); !ok {
				continue
			}
			args := map[string]ID{"npc": npc, "p": ID(b.P), "s": b.S}
			if b.O != "" {
				args["o"] = b.O
			}
			out = append(out, Affordance{Action: actTell, Title: "Contar a " + e.Name, Origin: "player", Args: args, With: npc, Region: self.Region, Tags: []string{"social"}})
		}
	}
	return out
}

func (v *validator) signs() error {
	w := v.w
	u := w.U
	spots := map[string]ID{}
	for _, sp := range u.Spots {
		spots[sp.ID] = sp.Region
	}
	seen := map[string]bool{}
	for _, sg := range u.Signs {
		if sg.ID == "" || seen[sg.ID] || sg.Title == "" || sg.Look == "" || sg.Text == "" || !w.regions[v.ents[sg.Region]] {
			return invalid("sign %q", sg.ID)
		}
		seen[sg.ID] = true
		if sg.Spot != "" && spots[sg.Spot] != sg.Region {
			return invalid("sign %s: spot %q is not in %s", sg.ID, sg.Spot, sg.Region)
		}
		for _, far := range sg.FarFrom {
			if !w.regions[v.ents[far]] || far == sg.Region {
				return invalid("sign %s: farFrom %q", sg.ID, far)
			}
		}
		vars := map[string]bool{"self": true}
		for _, c := range []*Cond{sg.When, sg.Perceive} {
			if c != nil {
				if err := v.cond(*c, vars, "sign "+sg.ID); err != nil {
					return err
				}
			}
		}
		if err := v.effects(sg.Examine, vars, "sign "+sg.ID); err != nil {
			return err
		}
	}
	for _, r := range u.Reactions {
		if !w.preds[r.P] || r.S != "" && v.ents[ID(r.S)] == "" || r.Told == "" {
			return invalid("reaction %q %q", r.P, r.S)
		}
		for _, id := range r.Who {
			if v.ents[id] == "" || !slices.Contains(u.Perceivers, v.ents[id]) {
				return invalid("reaction %s: listener %q", r.P, id)
			}
		}
		if err := v.effects(r.Effects, map[string]bool{"self": true, "npc": true}, "reaction "+r.P); err != nil {
			return err
		}
	}
	for _, reserved := range []string{actExamine, actTell} {
		if _, taken := w.actions[reserved]; taken {
			return invalid("action id %q is reserved by the engine", reserved)
		}
	}
	return nil
}
