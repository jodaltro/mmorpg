package core

import "slices"

// Exploration (E2): the body is explored, not only crossed. Passages join two
// regions and may need a key (an expressed gene), so growing opens the body;
// niches are hidden pockets that hand a gene to whoever finds them, once per
// player or, for the unique ones, once per world (the first finder keeps the
// scenario, the others find it already claimed). All of it is deterministic
// state changed by commands, so the log replays it.

const actFindNiche = "achar-nicho" // adapter: the cell reached a niche; args: niche

// PassageDef is a way between two regions. Without Gene it is always open.
type PassageDef struct {
	ID   string `json:"id"`
	From ID     `json:"from"`
	To   ID     `json:"to"`
	Name string `json:"name"`
	// Gene is the key: the gene a cell must express to go through.
	Gene string `json:"gene,omitempty"`
	// Hint says, in words, what the passage asks for (shown while it is closed).
	Hint string `json:"hint,omitempty"`
}

// NicheDef is a hidden pocket of a region with a gene as its reward.
type NicheDef struct {
	ID     string `json:"id"`
	Region ID     `json:"region"`
	Name   string `json:"name"`
	// Hint is a whisper of where to look, given once the region is known.
	Hint string `json:"hint,omitempty"`
	// Text is what the finder reads on finding it.
	Text string `json:"text"`
	Gene string `json:"gene"`
	// Unique niches reward only the first player to find them.
	Unique bool `json:"unique,omitempty"`
	// When makes it a secret: the niche exists for a player only while this holds (a niche that shows only in fever, only in sleep).
	When *Cond `json:"when,omitempty"`
}

// PassageView and NicheView are what an observer may see of them.
type PassageView struct {
	ID   string `json:"id"`
	From ID     `json:"from"`
	To   ID     `json:"to"`
	Name string `json:"name"`
	Open bool   `json:"open"`
	Hint string `json:"hint,omitempty"`
}

type NicheView struct {
	ID      string `json:"id"`
	Region  ID     `json:"region"`
	Name    string `json:"name"`
	Hint    string `json:"hint,omitempty"`
	Found   bool   `json:"found"`
	Claimed bool   `json:"claimed,omitempty"` // a unique niche somebody else already took
}

// ExploreView is the observer's map of what can be explored.
type ExploreView struct {
	Passages []PassageView `json:"passages"`
	Niches   []NicheView   `json:"niches"`
	Adapted  []string      `json:"adapted"`
	Route    string        `json:"route,omitempty"` // the niche the advisor pointed this player to
}

const worldKey ID = "mundo" // the deeds of the world itself (who claimed a unique niche)

func nicheDeed(id string) string { return "nicho:" + id }

func (w *World) passageBetween(a, b ID) (PassageDef, bool) {
	for _, p := range w.U.Passages {
		if p.From == a && p.To == b || p.From == b && p.To == a {
			return p, true
		}
	}
	return PassageDef{}, false
}

// passageOpen is whether the player's genome carries the passage's key.
func (w *World) passageOpen(s *State, who ID, p PassageDef) bool {
	return p.Gene == "" || slices.Contains(s.Genomes[who].Genes, p.Gene)
}

func (w *World) niche(id string) (NicheDef, bool) {
	i := slices.IndexFunc(w.U.Niches, func(n NicheDef) bool { return n.ID == id })
	if i < 0 {
		return NicheDef{}, false
	}
	return w.U.Niches[i], true
}

// findNiche is the game server confirming that a cell reached a niche.
func (w *World) findNiche(s *State, origin string, p ID, args map[string]ID, cause string) error {
	n, ok := w.niche(string(args["niche"]))
	e := s.Entities[p]
	if origin != "adapter" || !ok || e.Kind != w.U.PlayerKind || e.Region != n.Region || n.When != nil && !w.Holds(s, *n.When, Bind{"self": p}) {
		return reject("niche")
	}
	if s.Deeds[p][nicheDeed(n.ID)] > 0 {
		return nil // already found: nothing changes
	}
	if s.Deeds[p] == nil {
		s.Deeds[p] = map[string]int64{}
	}
	s.Deeds[p][nicheDeed(n.ID)] = 1
	claimed := s.Deeds[worldKey][nicheDeed(n.ID)] > 0
	if n.Unique && claimed {
		w.emit(s, Event{Kind: "nicho-vazio", Actor: p, Holder: p, Text: n.Name + ": alguém chegou aqui antes de você.", Cause: cause, Data: map[string]string{"niche": n.ID}})
		return nil
	}
	if n.Unique {
		if s.Deeds[worldKey] == nil {
			s.Deeds[worldKey] = map[string]int64{}
		}
		s.Deeds[worldKey][nicheDeed(n.ID)] = 1
	}
	g := s.Genomes[p]
	data := map[string]string{"niche": n.ID, "gene": n.Gene}
	if !slices.Contains(g.Genes, n.Gene) {
		g.Genes = append(slices.Clone(g.Genes), n.Gene)
		if len(g.Genes) > w.geneSlots() {
			data["replaced"], g.Genes = g.Genes[0], g.Genes[1:]
		}
		s.Genomes[p] = g
		if m, ok := w.mutation(n.Gene); ok {
			w.learn(s, p, m.Tags, 1)
		}
	}
	w.emit(s, Event{Kind: "nicho", Actor: p, Holder: p, Text: n.Text, Cause: cause, Data: data})
	if n.Unique {
		w.emit(s, Event{Kind: "nicho-reivindicado", Actor: p, Public: true, Text: n.Name + " foi encontrado pela primeira vez.", Cause: cause, Data: map[string]string{"niche": n.ID}})
	}
	w.discover(s, p, cause)
	w.codexTick(s, p, cause)
	return nil
}

func (w *World) exploreView(s *State, p ID) *ExploreView {
	if len(w.U.Passages) == 0 && len(w.U.Niches) == 0 {
		return nil
	}
	pe := s.Entities[p]
	v := &ExploreView{Passages: []PassageView{}, Niches: []NicheView{}, Adapted: adaptedRegions(pe)}
	if r := pe.Tag[tagRota]; r != "" && hasOption(w.rotaOptions(s, p), r) {
		v.Route = r
	}
	for _, ps := range w.U.Passages {
		open := w.passageOpen(s, p, ps)
		pv := PassageView{ID: ps.ID, From: ps.From, To: ps.To, Name: ps.Name, Open: open}
		if !open {
			pv.Hint = ps.Hint
		}
		v.Passages = append(v.Passages, pv)
	}
	for _, n := range w.U.Niches {
		found := s.Deeds[p][nicheDeed(n.ID)] > 0
		if !found && n.When != nil && !w.Holds(s, *n.When, Bind{"self": p}) {
			continue // a secret the body is not showing now
		}
		nv := NicheView{ID: n.ID, Region: n.Region, Name: "?", Found: found, Claimed: n.Unique && !found && s.Deeds[worldKey][nicheDeed(n.ID)] > 0}
		if found {
			nv.Name = n.Name
		} else if w.whispers(s, p, n.Region) {
			nv.Hint = n.Hint
		}
		v.Niches = append(v.Niches, nv)
	}
	return v
}

// whispers is whether the observer may be told something of a region: it has been there or a passage leads to it from a place it knows.
func (w *World) whispers(s *State, p, place ID) bool {
	if w.discoveredPlace(s, p, place) {
		return true
	}
	for _, ps := range w.U.Passages {
		if ps.From == place && w.discoveredPlace(s, p, ps.To) || ps.To == place && w.discoveredPlace(s, p, ps.From) {
			return true
		}
	}
	return false
}

func (w *World) discoveredPlace(s *State, p, place ID) bool {
	if w.U.Discovered == "" {
		return true
	}
	_, ok := s.Facts[factKey(p, w.U.Discovered, p, place)]
	return ok
}

func (w *World) compileExploration(ents map[ID]string) error {
	ids := map[string]bool{}
	for _, p := range w.U.Passages {
		if p.ID == "" || ids[p.ID] || !w.regions[ents[p.From]] || !w.regions[ents[p.To]] {
			return invalid("passage %q: needs a unique id and two regions", p.ID)
		}
		ids[p.ID] = true
		if _, ok := w.mutation(p.Gene); p.Gene != "" && !ok {
			return invalid("passage %s: unknown gene %q", p.ID, p.Gene)
		}
	}
	for _, n := range w.U.Niches {
		if n.ID == "" || ids[n.ID] || !w.regions[ents[n.Region]] {
			return invalid("niche %q: needs a unique id and a region", n.ID)
		}
		ids[n.ID] = true
		if _, ok := w.mutation(n.Gene); !ok {
			return invalid("niche %s: unknown gene %q", n.ID, n.Gene)
		}
	}
	return nil
}
