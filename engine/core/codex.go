package core

import (
	"slices"
	"strconv"
	"strings"
)

// The second half of exploration (E2): the codex fills in as the cell sees and does things, secrets show only while the body is in a
// certain state, living in a place adapts the cell to it, and the advisor (Jev) points each player to the next place worth finding
// (the `rota` decision). Everything is deterministic state moved by commands, so the log replays it.

const (
	decisionRota = "rota"
	tagRota      = "rota"
	tagAdapted   = "adaptado:"
	numHabitat   = "habitat:"
)

// ExploringDef tunes the pace of exploration. Zero values turn a part off.
type ExploringDef struct {
	// AdaptAfter is how many ticks of living in a region adapt the cell to it.
	AdaptAfter Tick `json:"adaptAfter,omitempty"`
	// RotaEvery is how often (ticks) each player is pointed to a place worth finding.
	RotaEvery Tick `json:"rotaEvery,omitempty"`
}

// CodexDef is an entry of the codex of the body: it unlocks, per player, the first time its condition holds.
type CodexDef struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	// Kind groups entries in the panel: regiao, patogeno, celula, corpo or segredo.
	Kind string `json:"kind"`
	Text string `json:"text"`
	When Cond   `json:"when"`
}

// CodexView is an entry as a player sees it: locked ones show nothing but their kind.
type CodexView struct {
	ID       string `json:"id"`
	Kind     string `json:"kind"`
	Title    string `json:"title"`
	Unlocked bool   `json:"unlocked"`
	Text     string `json:"text,omitempty"`
}

func codexDeed(id string) string { return "codice:" + id }

// codexTick unlocks what the cell now qualifies for.
func (w *World) codexTick(s *State, p ID, cause string) {
	if s.Entities[p].Kind != w.U.PlayerKind {
		return
	}
	for _, c := range w.U.Codex {
		if s.Deeds[p][codexDeed(c.ID)] > 0 || !w.Holds(s, c.When, Bind{"self": p}) {
			continue
		}
		if s.Deeds[p] == nil {
			s.Deeds[p] = map[string]int64{}
		}
		s.Deeds[p][codexDeed(c.ID)] = 1
		w.emit(s, Event{Kind: "codice", Actor: p, Holder: p, Text: c.Title, Cause: cause, Data: map[string]string{"entry": c.ID, "kind": c.Kind}})
	}
}

func (w *World) codexView(s *State, p ID) []CodexView {
	out := []CodexView{}
	for _, c := range w.U.Codex {
		v := CodexView{ID: c.ID, Kind: c.Kind, Title: "???"}
		if s.Deeds[p][codexDeed(c.ID)] > 0 {
			v.Unlocked, v.Title, v.Text = true, c.Title, c.Text
		}
		out = append(out, v)
	}
	return out
}

// adaptTick counts the ticks each player lives in its region and adapts it when the time is long enough.
func (w *World) adaptTick(s *State, cause string) {
	ex := w.U.Exploring
	if ex == nil || ex.AdaptAfter == 0 {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		e := s.Entities[p]
		if e.Kind != w.U.PlayerKind || e.Region == "" {
			continue
		}
		if e.Num == nil {
			e.Num = map[string]int64{}
		}
		if e.Tag == nil {
			e.Tag = map[string]string{}
		}
		key := numHabitat + string(e.Region)
		e.Num[key]++
		if e.Num[key] >= int64(ex.AdaptAfter) && e.Tag[tagAdapted+string(e.Region)] == "" {
			e.Tag[tagAdapted+string(e.Region)] = "1"
			s.Entities[p] = e
			w.emit(s, Event{Kind: "adaptou", Actor: p, Holder: p, Text: "Seu corpo se adapta a " + s.Entities[e.Region].Name + ".", Cause: cause, Data: map[string]string{"region": string(e.Region)}})
			continue
		}
		s.Entities[p] = e
	}
}

// adaptedRegions lists the regions the player's body has adapted to.
func adaptedRegions(e Entity) []string {
	out := []string{}
	for k := range e.Tag {
		if strings.HasPrefix(k, tagAdapted) {
			out = append(out, strings.TrimPrefix(k, tagAdapted))
		}
	}
	slices.Sort(out)
	return out
}

// reachable lists the regions a player can walk to from its own through open passages, nearest first (ties by id).
func (w *World) reachable(s *State, p ID) map[ID]int {
	from := s.Entities[p].Region
	hops := map[ID]int{from: 0}
	queue := []ID{from}
	for len(queue) > 0 {
		at := queue[0]
		queue = queue[1:]
		for _, ps := range w.U.Passages {
			next := ID("")
			switch at {
			case ps.From:
				next = ps.To
			case ps.To:
				next = ps.From
			}
			if next == "" || !w.passageOpen(s, p, ps) {
				continue
			}
			if _, seen := hops[next]; !seen {
				hops[next] = hops[at] + 1
				queue = append(queue, next)
			}
		}
	}
	return hops
}

// nicheVisible is whether the observer may be told of a niche now: not found, whispered, its secret condition (if any) holding.
func (w *World) nicheVisible(s *State, p ID, n NicheDef) bool {
	if n.When != nil && !w.Holds(s, *n.When, Bind{"self": p}) {
		return false
	}
	return s.Deeds[p][nicheDeed(n.ID)] == 0 && w.whispers(s, p, n.Region)
}

// rotaOptions are the places worth pointing a player to: hidden niches it can reach, nearest first.
func (w *World) rotaOptions(s *State, p ID) []Option {
	hops := w.reachable(s, p)
	type cand struct {
		n    NicheDef
		hops int
	}
	var cands []cand
	for _, n := range w.U.Niches {
		h, ok := hops[n.Region]
		if ok && w.nicheVisible(s, p, n) {
			cands = append(cands, cand{n, h})
		}
	}
	slices.SortFunc(cands, func(a, b cand) int {
		if a.hops != b.hops {
			return a.hops - b.hops
		}
		return strings.Compare(a.n.ID, b.n.ID)
	})
	opts := make([]Option, 0, len(cands))
	for _, c := range cands {
		where := string(c.n.Region)
		if r, ok := s.Entities[c.n.Region]; ok {
			where = r.Name
		}
		opts = append(opts, Option{ID: c.n.ID, Title: "A hidden place in " + where, Desc: c.n.Hint + " [" + strconv.Itoa(c.hops) + " passages away]"})
	}
	return opts
}

func hasOption(opts []Option, id string) bool {
	return slices.ContainsFunc(opts, func(o Option) bool { return o.ID == id })
}

// rotaTick keeps every player pointed at a place worth finding. With one place the answer is plain; with several the advisor picks.
func (w *World) rotaTick(s *State, cause string) {
	ex := w.U.Exploring
	if ex == nil || ex.RotaEvery == 0 || len(w.U.Niches) == 0 || s.Tick%ex.RotaEvery != 0 {
		return
	}
	for _, p := range sortedIDs(s.Entities) {
		e := s.Entities[p]
		if e.Kind != w.U.PlayerKind {
			continue
		}
		pending := slices.ContainsFunc(sortedKeys(s.Decisions), func(k string) bool {
			return s.Decisions[k].Kind == decisionRota && s.Decisions[k].Subject == string(p)
		})
		opts := w.rotaOptions(s, p)
		if pending || (e.Tag[tagRota] != "" && hasOption(opts, e.Tag[tagRota])) {
			continue
		}
		if e.Tag == nil {
			e.Tag = map[string]string{}
		}
		switch len(opts) {
		case 0:
			delete(e.Tag, tagRota)
			s.Entities[p] = e
		case 1:
			e.Tag[tagRota] = opts[0].ID
			s.Entities[p] = e
		default:
			id := decisionRota + ":" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
			ctx := w.profile(s, p)
			ctx = append(ctx, "explored regions: "+strconv.Itoa(len(adaptedRegions(e)))+" adapted; body temperature "+strconv.FormatInt(s.Entities["corpo"].Num["temperatura"], 10)+" (tenths of a degree)")
			if w.U.Evolution != nil {
				ctx = append(ctx, w.genomeText(s, p))
			}
			s.Decisions[id] = Decision{ID: id, Kind: decisionRota, Subject: string(p), Options: opts, Default: opts[0].ID, Created: s.Tick, Due: s.Tick + 2, Context: ctx}
		}
	}
}

// decideRota points the player to the chosen place after revalidating it.
func (w *World) decideRota(s *State, d Decision, choice, cause string) error {
	p := ID(d.Subject)
	if !hasOption(w.rotaOptions(s, p), choice) {
		return reject("choice no longer valid")
	}
	e := s.Entities[p]
	if e.Tag == nil {
		e.Tag = map[string]string{}
	}
	e.Tag[tagRota] = choice
	s.Entities[p] = e
	delete(s.Decisions, d.ID)
	w.emit(s, Event{Kind: "rota", Actor: p, Holder: p, Cause: cause, Data: map[string]string{"niche": choice}})
	return nil
}

func (w *World) compileCodex(v *validator) error {
	seen := map[string]bool{}
	for _, c := range w.U.Codex {
		if c.ID == "" || seen[c.ID] || c.Title == "" {
			return invalid("codex entry %q: needs a unique id and a title", c.ID)
		}
		seen[c.ID] = true
		if err := v.cond(c.When, map[string]bool{"self": true}, "codex "+c.ID); err != nil {
			return err
		}
	}
	for _, n := range w.U.Niches {
		if n.When != nil {
			if err := v.cond(*n.When, map[string]bool{"self": true}, "niche "+n.ID); err != nil {
				return err
			}
		}
	}
	return nil
}
