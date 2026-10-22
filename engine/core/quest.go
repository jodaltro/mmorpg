package core

import (
	"hash/fnv"
	"maps"
	"slices"
	"strconv"
	"strings"
)

type candidate struct {
	key  string
	def  QuestDef
	bind Bind
}

func questKey(def string, holder ID, params []QuestParam, b Bind) string {
	parts := []string{def, string(holder)}
	for _, p := range params {
		parts = append(parts, string(b[p.Name]))
	}
	return strings.Join(parts, "|")
}

func pick(seed string, n int) int {
	h := fnv.New64a()
	h.Write([]byte(seed))
	return int(h.Sum64() % uint64(n))
}

// local reports whether the quest can be offered to p now. Offers are not
// gated by distance: the giver reaches the player wherever they are (the
// client decides how: walking up, a messenger, a call). Coherence comes
// from eligibility, the situation of the world and the advisor. Only a
// quest that explicitly declares a Region is limited to that place.
func (w *World) local(s *State, def QuestDef, b Bind) bool {
	if def.Giver != "" {
		if _, ok := s.Entities[resolve(def.Giver, b)]; !ok {
			return false
		}
	}
	return def.Region == "" || s.Entities[b["self"]].Region == resolve(def.Region, b)
}

// refreshOffers withdraws pending offers that stopped making sense:
// ineligible, already achieved, or the player walked away from the giver.
func (w *World) refreshOffers(s *State, p ID, cause string) {
	for _, k := range sortedKeys(s.Quests) {
		q := s.Quests[k]
		if q.State != "offered" || p != "" && q.Holder != p {
			continue
		}
		def := w.quests[q.Def]
		b := maps.Clone(q.Bind)
		if b == nil {
			b = Bind{}
		}
		b["self"] = q.Holder
		if !w.Holds(s, def.Eligible, Bind{"self": q.Holder}) || w.Holds(s, def.Goal, b) || !w.local(s, def, b) {
			q.State = "withdrawn"
			s.Quests[k] = q
			w.emit(s, Event{Kind: "quest-withdrawn", Holder: q.Holder, Text: q.Title, Cause: cause, Data: map[string]string{"quest": k}})
		}
	}
}

// rest marks the end of a quest for p: the next offer waits QuestGap ticks.
func (w *World) rest(s *State, p ID) {
	if w.U.Limits.QuestGap > 0 {
		s.Cooldowns["next-offer|"+string(p)] = s.Tick + w.U.Limits.QuestGap
	}
}

func (w *World) questTick(s *State, cause string) {
	l := w.U.Limits
	for _, k := range sortedKeys(s.Quests) {
		q := s.Quests[k]
		if q.State == "active" {
			// Failure and turns of events come first: a quest that someone
			// else resolved fails, it does not just become pointless.
			w.evolve(s, k, cause)
			q = s.Quests[k]
		}
		if q.State == "active" && w.quests[q.Def].Arc == "" && !w.Holds(s, w.quests[q.Def].Eligible, Bind{"self": q.Holder}) {
			// The world moved on (the caravan left, the well is clean):
			// the quest no longer makes sense and frees the active slot.
			q.State = "obsolete"
			s.Quests[k] = q
			w.rest(s, q.Holder)
			w.emit(s, Event{Kind: "quest-obsolete", Holder: q.Holder, Text: q.Title, Cause: cause})
			continue
		}
		if q.State == "offered" && s.Tick-q.At >= l.OfferExpiry {
			q.State = "expired"
			s.Quests[k] = q
			s.Declined[k] = s.Tick
			w.emit(s, Event{Kind: "quest-expired", Holder: q.Holder, Text: q.Title, Cause: cause})
		}
	}
	w.refreshOffers(s, "", cause)
	w.completeAll(s, cause)
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind == w.U.PlayerKind {
			w.offer(s, p, cause)
		}
	}
}

func (w *World) completeAll(s *State, cause string) {
	for _, p := range sortedIDs(s.Entities) {
		if s.Entities[p].Kind == w.U.PlayerKind {
			w.completeFor(s, p, cause)
		}
	}
}

func (w *World) completeFor(s *State, holder ID, cause string) {
	w.discover(s, holder, cause)
	w.claimStories(s, holder, cause)
	for _, k := range sortedKeys(s.Quests) {
		if q := s.Quests[k]; q.Holder == holder && q.State == "active" {
			w.evolve(s, k, cause)
			if s.Quests[k].State == "active" {
				w.tryComplete(s, k, cause)
			}
		}
	}
}

func questBind(q Quest) Bind {
	b := maps.Clone(q.Bind)
	if b == nil {
		b = Bind{}
	}
	b["self"] = q.Holder
	return b
}

// evolve lets an accepted quest react to the world: it can fail (by
// condition or timeout) or move to a later stage, which rewrites its title,
// objective, rank and goal, like a system window updating mid-quest.
func (w *World) evolve(s *State, key, cause string) {
	q := s.Quests[key]
	def := w.quests[q.Def]
	b := questBind(q)
	if q.Deadline > 0 && s.Tick >= q.Deadline || def.Fail != nil && w.Holds(s, *def.Fail, b) {
		q.State = "failed"
		s.Quests[key] = q
		w.apply(s, def.FailEffects, b, cause)
		w.rest(s, q.Holder)
		w.emit(s, Event{Kind: "quest-failed", Holder: q.Holder, Text: q.Title, Cause: cause, Data: map[string]string{"quest": key}})
		return
	}
	from := slices.IndexFunc(def.Stages, func(st QuestStage) bool { return st.ID == q.Stage })
	for i := from + 1; i < len(def.Stages); i++ {
		st := def.Stages[i]
		if !w.Holds(s, st.When, b) {
			continue
		}
		q.Stage = st.ID
		if st.Title != "" {
			q.Title = w.render(s, st.Title, b)
		}
		if st.Desc != "" {
			q.Desc = w.render(s, st.Desc, b)
		}
		if st.Objective != "" {
			q.Objective = w.render(s, st.Objective, b)
		}
		old := q.Rank
		if st.Rank != "" {
			q.Rank = st.Rank
		}
		s.Quests[key] = q
		w.apply(s, st.Effects, b, cause)
		data := map[string]string{"quest": key, "stage": st.ID, "rank": q.Rank}
		if old != q.Rank {
			data["rankFrom"] = old
		}
		w.emit(s, Event{Kind: "quest-updated", Holder: q.Holder, Text: q.Title, Cause: cause, Data: data})
		return
	}
}

// goalOf is the goal of the current stage, else the quest goal.
func (w *World) goalOf(q Quest) Cond {
	def := w.quests[q.Def]
	if i := slices.IndexFunc(def.Stages, func(st QuestStage) bool { return st.ID == q.Stage }); i >= 0 && def.Stages[i].Goal != nil {
		return *def.Stages[i].Goal
	}
	return def.Goal
}

func (w *World) tryComplete(s *State, key string, cause string) {
	q := s.Quests[key]
	def := w.quests[q.Def]
	b := questBind(q)
	if !w.Holds(s, w.goalOf(q), b) {
		return
	}
	if def.Arc != "" && !slices.Contains(s.Arcs[def.Arc].Beats[def.Beat].By, q.Holder) && !w.claim(s, def.Arc, def.Beat, q.Holder, cause) {
		return
	}
	q = s.Quests[key]
	q.State = "done"
	s.Quests[key] = q
	w.rest(s, q.Holder)
	w.learn(s, q.Holder, def.Tags, 2)
	w.count(s, q.Holder, "quest")
	w.apply(s, def.Rewards, b, cause)
	w.emit(s, Event{Kind: "quest-done", Holder: q.Holder, Text: q.Title, Cause: cause, Data: map[string]string{"quest": key}})
}

// claimStories lets a player claim any open chapter whose goal they meet,
// with or without the guiding quest: unique scenarios trigger on deeds.
func (w *World) claimStories(s *State, holder ID, cause string) {
	if s.Entities[holder].Kind != w.U.PlayerKind {
		return
	}
	for _, a := range w.U.Arcs {
		if st := s.Arcs[a.ID]; st.Current != "" && !st.Choosing && st.Beats[st.Current].State == "open" {
			w.claim(s, a.ID, st.Current, holder, cause)
		}
	}
}

// claim completes a story beat for holder. For a unique beat the first
// claimant wins atomically; every other contender is superseded and gets
// the Rival effects, which open a different personal continuation.
func (w *World) claim(s *State, arc, beatID string, holder ID, cause string) bool {
	def := QuestDef{Arc: arc, Beat: beatID}
	st := s.Arcs[def.Arc]
	beat := w.beats[def.Arc][def.Beat]
	bs := st.Beats[beat.ID]
	if st.Current != beat.ID || st.Choosing || bs.State != "open" || slices.Contains(bs.By, holder) {
		return false
	}
	b := Bind{"self": holder}
	if !w.Holds(s, beat.Goal, b) {
		return false
	}
	bs.By = append(bs.By, holder)
	bs.At = s.Tick
	if beat.Unique {
		bs.State = "claimed"
	}
	st.Beats[beat.ID] = bs
	s.Arcs[def.Arc] = st
	w.apply(s, beat.Claim, b, cause)
	w.emit(s, Event{Kind: "story", Actor: holder, Public: true, Text: beat.Title + ": " + s.Entities[holder].Name, Cause: cause,
		Data: map[string]string{"arc": def.Arc, "beat": beat.ID, "unique": boolText(beat.Unique)}})
	if !beat.Unique {
		return true
	}
	rivals := map[ID]bool{}
	for _, k := range sortedKeys(s.Quests) {
		r := s.Quests[k]
		rd := w.quests[r.Def]
		if r.Holder == holder || rd.Arc != def.Arc || rd.Beat != beat.ID || r.State != "offered" && r.State != "active" {
			continue
		}
		r.State = "superseded"
		s.Quests[k] = r
		rivals[r.Holder] = true
	}
	if beat.Contender != nil {
		for _, p := range sortedIDs(s.Entities) {
			if p != holder && s.Entities[p].Kind == w.U.PlayerKind && w.Holds(s, *beat.Contender, Bind{"self": p}) {
				rivals[p] = true
			}
		}
	}
	for _, p := range sortedIDs(rivals) {
		w.apply(s, beat.Rival, Bind{"self": p, "claimant": holder}, cause)
		w.emit(s, Event{Kind: "beat-lost", Holder: p, Text: beat.Title, Cause: cause,
			Data: map[string]string{"arc": def.Arc, "beat": beat.ID, "claimant": string(holder)}})
	}
	claimant := holder
	w.advance(s, def.Arc, beat, &claimant, cause)
	return true
}

func boolText(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

const maxCandidates = 64

// candidates lists the quests a player could be offered now. The same
// templates yield different quests per player because eligibility and
// bindings depend on what that player did and knows.
func (w *World) candidates(s *State, p ID) []candidate {
	out := []candidate{}
	for _, def := range w.U.Quests {
		if def.Arc != "" {
			st := s.Arcs[def.Arc]
			if st.Current != def.Beat || st.Choosing || st.Beats[def.Beat].State != "open" || slices.Contains(st.Beats[def.Beat].By, p) {
				continue
			}
		}
		if !w.Holds(s, def.Eligible, Bind{"self": p}) {
			continue
		}
		var bindings []Bind
		var expand func(i int, b Bind)
		expand = func(i int, b Bind) {
			if len(bindings) >= maxCandidates {
				return
			}
			if i == len(def.Params) {
				bindings = append(bindings, maps.Clone(b))
				return
			}
			qp := def.Params[i]
			for _, id := range sortedIDs(s.Entities) {
				if s.Entities[id].Kind != qp.Kind || id == p {
					continue
				}
				b["it"] = id
				if w.Holds(s, qp.Where, b) {
					delete(b, "it")
					b[qp.Name] = id
					expand(i+1, b)
					delete(b, qp.Name)
				}
				delete(b, "it")
			}
		}
		expand(0, Bind{"self": p})
		for _, b := range bindings {
			if w.U.Acquaintance != "" && def.Giver != "" && !w.knowsOf(s, resolve(def.Giver, b), p) {
				continue // nobody reaches out on behalf of a stranger
			}
			key := questKey(def.ID, p, def.Params, b)
			if q, seen := s.Quests[key]; seen {
				switch q.State {
				case "offered", "active", "superseded":
					continue
				case "done":
					if !def.Repeat {
						continue
					}
				default:
					if s.Tick-s.Declined[key] < w.U.Limits.DeclineCooldown {
						continue
					}
				}
			}
			if w.Holds(s, def.Goal, b) || !w.local(s, def, b) {
				continue
			}
			delete(b, "self")
			out = append(out, candidate{key: key, def: def, bind: b})
		}
	}
	return out
}

func (w *World) offer(s *State, p ID, cause string) {
	active := 0
	for _, q := range s.Quests {
		if q.Holder == p && q.State == "offered" {
			return // GameVision: at most one pending proposal
		}
		if q.Holder == p && q.State == "active" {
			active++
		}
	}
	if active >= w.U.Limits.MaxActiveQuests || s.Cooldowns["next-offer|"+string(p)] > s.Tick {
		return
	}
	if w.U.Limits.FirstDeedFirst && !w.hasActed(s, p) {
		return
	}
	for _, d := range s.Decisions {
		if d.Kind == "offer" && d.Subject == string(p) {
			return
		}
	}
	cands := w.candidates(s, p)
	switch len(cands) {
	case 0:
		return
	case 1:
		w.createOffer(s, p, cands[0], cause)
		return
	}
	opts := make([]Option, 0, len(cands))
	for _, c := range cands {
		b := maps.Clone(c.bind)
		b["self"] = p
		desc := w.render(s, c.def.Desc, b)
		if c.def.Giver != "" {
			desc = "Offered by " + w.name(s, resolve(c.def.Giver, b)) + ". " + desc
		}
		if c.def.Rank != "" {
			desc = "Rank " + c.def.Rank + ". " + desc
		}
		if len(c.def.Tags) > 0 {
			desc += " [style: " + strings.Join(c.def.Tags, ", ") + "]"
		}
		desc += " [fit " + strconv.FormatInt(w.salience(s, p, c), 10) + "]"
		opts = append(opts, Option{ID: c.key, Title: w.render(s, c.def.Title, b), Desc: desc})
	}
	id := "offer:" + string(p) + ":" + strconv.FormatInt(int64(s.Tick), 10)
	ctx := w.profile(s, p)
	ctx = append(ctx, w.storySoFar(s)...)
	ctx = append(ctx, w.offeredToOthers(s, p, 5)...)
	ctx = append(ctx, w.recentPublic(s, 4)...)
	s.Decisions[id] = Decision{ID: id, Kind: "offer", Subject: string(p), Options: opts,
		Default: w.best(s, p, cands, id).key, Created: s.Tick, Due: s.Tick + w.U.Limits.DecisionTimeout, Context: ctx}
}

func (w *World) createOffer(s *State, p ID, c candidate, cause string) {
	b := maps.Clone(c.bind)
	b["self"] = p
	q := Quest{Key: c.key, Def: c.def.ID, Holder: p, Bind: c.bind, State: "offered", At: s.Tick,
		Title: w.render(s, c.def.Title, b), Desc: w.render(s, c.def.Desc, b), Region: s.Entities[p].Region,
		Rank: c.def.Rank, Objective: w.render(s, c.def.Objective, b), Reward: w.render(s, c.def.Reward, b), Penalty: w.render(s, c.def.Penalty, b)}
	data := map[string]string{"quest": c.key}
	if q.Rank != "" {
		data["rank"] = q.Rank
	}
	if c.def.Giver != "" {
		q.Giver = resolve(c.def.Giver, b)
		data["giver"] = string(q.Giver)
	}
	if q.Region != "" {
		data["region"] = string(q.Region)
	}
	s.Quests[c.key] = q
	// The client turns this into presentation: the giver walks up to the
	// player and calls them. The engine only says who, where and what.
	w.emit(s, Event{Kind: "quest-offered", Actor: q.Giver, Holder: p, Text: q.Title, Cause: cause, Data: data})
}

func (w *World) questCommand(s *State, c Command, cause string) error {
	q, ok := s.Quests[c.Quest]
	if !ok || q.Holder != c.Actor {
		return reject("quest")
	}
	switch c.Kind {
	case "accept":
		if q.State != "offered" {
			return reject("quest state")
		}
		q.State = "active"
		if lim := w.quests[q.Def].TimeLimit; lim > 0 {
			q.Deadline = s.Tick + lim
		}
		w.count(s, q.Holder, "accept")
	case "decline":
		if q.State != "offered" {
			return reject("quest state")
		}
		q.State = "declined"
		s.Declined[q.Key] = s.Tick
		w.apply(s, w.quests[q.Def].OnDecline, questBind(q), cause)
		w.learn(s, q.Holder, w.quests[q.Def].Tags, -1)
		w.count(s, q.Holder, "decline")
	case "abandon":
		if !w.U.Limits.AllowAbandon {
			return reject("this world requires finishing the accepted quest")
		}
		if q.State != "active" {
			return reject("quest state")
		}
		w.rest(s, q.Holder)
		q.State = "abandoned"
		s.Declined[q.Key] = s.Tick
	}
	q.At = s.Tick
	s.Quests[q.Key] = q
	w.emit(s, Event{Kind: "quest-" + q.State, Holder: q.Holder, Text: q.Title, Cause: cause, Data: map[string]string{"quest": q.Key}})
	if q.State == "active" {
		w.evolve(s, q.Key, cause)
		if s.Quests[q.Key].State == "active" {
			w.tryComplete(s, q.Key, cause)
		}
	}
	return nil
}

// decide applies an advisor choice. The choice must be one of the options
// AND still valid now; otherwise it is rejected and the default will apply.
func (w *World) decide(s *State, d Decision, choice string, meta map[string]string, cause string) error {
	if !slices.ContainsFunc(d.Options, func(o Option) bool { return o.ID == choice }) {
		return reject("choice")
	}
	switch d.Kind {
	case "offer":
		p := ID(d.Subject)
		var found *candidate
		for _, c := range w.candidates(s, p) {
			if c.key == choice {
				found = &c
				break
			}
		}
		if found == nil {
			return reject("choice no longer valid")
		}
		delete(s.Decisions, d.ID)
		w.createOffer(s, p, *found, cause)
	case "story":
		st := s.Arcs[d.Subject]
		if !st.Choosing {
			return reject("story not choosing")
		}
		delete(s.Decisions, d.ID)
		w.setBeat(s, d.Subject, choice)
	case "world":
		if err := w.occur(s, choice, cause); err != nil {
			return err
		}
		delete(s.Decisions, d.ID)
	case "evolution":
		if err := w.decideMutation(s, d, choice, cause); err != nil {
			return err
		}
	}
	data := map[string]string{"decision": d.ID, "kind": d.Kind, "subject": d.Subject, "choice": choice, "default": d.Default}
	for k, v := range meta {
		data[k] = v
	}
	w.emit(s, Event{Kind: "decision", Cause: cause, Data: data})
	return nil
}

// decideDefault runs at the deadline. If even the default became invalid,
// an offer decision is dropped (the next tick recomputes candidates).
func (w *World) decideDefault(s *State, d Decision, cause string) {
	if w.decide(s, d, d.Default, map[string]string{"provider": "default"}, cause) == nil {
		return
	}
	delete(s.Decisions, d.ID)
	if d.Kind == "story" {
		w.setBeat(s, d.Subject, d.Options[0].ID)
		return
	}
	if d.Kind == "world" || d.Kind == "evolution" {
		return // nothing still valid: tried again on a later tick
	}
	// The world moved on while the decision was pending: offer the first
	// option that is still valid, else any current candidate, so a fast
	// changing world never starves a player of proposals.
	p := ID(d.Subject)
	cands := w.candidates(s, p)
	if len(cands) == 0 {
		return
	}
	still := []candidate{}
	for _, c := range cands {
		if slices.ContainsFunc(d.Options, func(o Option) bool { return o.ID == c.key }) {
			still = append(still, c)
		}
	}
	if len(still) == 0 {
		still = cands
	}
	w.createOffer(s, p, w.best(s, p, still, d.ID), cause)
}
