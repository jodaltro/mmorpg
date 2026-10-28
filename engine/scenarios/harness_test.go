package scenarios

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"slices"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/universe"
)

type harness struct {
	t   *testing.T
	w   *core.World
	s   core.State
	n   int
	log []core.Command
}

func load(t *testing.T, name string) *harness {
	t.Helper()
	w, err := universe.Load("../../universes/" + name + "/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	return &harness{t: t, w: w, s: core.NewState(w)}
}

// loadWithoutPops loads a universe with some cohorts taken out, to study an
// organ chain bare. The variant world is compiled normally and replays on its own.
func loadWithoutPops(t *testing.T, name string, ids ...string) *harness {
	t.Helper()
	data, err := os.ReadFile("../../universes/" + name + "/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	dec := json.NewDecoder(bytes.NewReader(bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf})))
	var u core.Universe
	if err := dec.Decode(&u); err != nil {
		t.Fatal(err)
	}
	// ids prefixed "npc:" remove that NPC and its tasks.
	u.Tasks = slices.DeleteFunc(u.Tasks, func(t core.TaskDef) bool { return slices.Contains(ids, "npc:"+string(t.NPC)) })
	u.Populations = slices.DeleteFunc(u.Populations, func(p core.PopulationDef) bool { return slices.Contains(ids, p.ID) })
	for i := range u.Conflicts { // responses that would muster a removed cohort go with it
		u.Conflicts[i].Responses = slices.DeleteFunc(u.Conflicts[i].Responses, func(r core.ResponseDef) bool {
			return slices.ContainsFunc(r.Effects, func(e core.Effect) bool { return e.Op == "muster" && slices.Contains(ids, e.Rule) })
		})
		if len(u.Conflicts[i].Responses) < 2 {
			u.Conflicts[i].Responses = nil
		}
	}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	return &harness{t: t, w: w, s: core.NewState(w)}
}

func (h *harness) try(c core.Command) (core.Delta, error) {
	c.Version = 1
	if c.RequestID == "" {
		h.n++
		c.RequestID = fmt.Sprintf("r%d", h.n)
	}
	s, d, err := h.w.Step(h.s, c)
	if err == nil {
		h.s = s
		h.log = append(h.log, c)
	}
	return d, err
}

func (h *harness) do(c core.Command) core.Delta {
	h.t.Helper()
	d, err := h.try(c)
	if err != nil {
		h.t.Fatalf("%s %s %s: %v", c.Kind, c.Actor, c.Action, err)
	}
	return d
}

func (h *harness) tick(n int) {
	h.t.Helper()
	for i := 0; i < n; i++ {
		h.do(core.Command{Kind: "tick", Origin: "system", RequestID: fmt.Sprintf("tick:%d", h.s.Tick+1)})
	}
}

func (h *harness) join(ids ...core.ID) {
	for _, id := range ids {
		h.do(core.Command{Kind: "join", Origin: "adapter", Actor: id, Name: strings.ToUpper(string(id))})
	}
}

func (h *harness) act(origin string, actor core.ID, action string, args map[string]core.ID) error {
	_, err := h.try(core.Command{Kind: "act", Origin: origin, Actor: actor, Action: action, Args: args})
	return err
}

func (h *harness) mustAct(origin string, actor core.ID, action string, args map[string]core.ID) {
	h.t.Helper()
	if err := h.act(origin, actor, action, args); err != nil {
		h.t.Fatalf("%s by %s: %v", action, actor, err)
	}
}

// quest returns the quest of holder built from def, in any state.
func (h *harness) quest(holder core.ID, def string) (core.Quest, bool) {
	for _, q := range h.s.Quests {
		if q.Holder == holder && q.Def == def {
			return q, true
		}
	}
	return core.Quest{}, false
}

// offerDecision finds the pending offer decision for a player.
func (h *harness) offerDecision(p core.ID) (core.Decision, bool) {
	for _, d := range h.s.Decisions {
		if d.Kind == "offer" && d.Subject == string(p) {
			return d, true
		}
	}
	return core.Decision{}, false
}

// steer gets quest def offered to p, as a player who declines other
// offers and an advisor who picks def would. Ticks the world as needed.
func (h *harness) steer(p core.ID, def string) core.Quest {
	h.t.Helper()
	for i := 0; i < 40; i++ {
		if q, ok := h.quest(p, def); ok && q.State == "offered" {
			return q
		}
		if d, ok := h.offerDecision(p); ok {
			for _, o := range d.Options {
				if strings.HasPrefix(o.ID, def+"|") {
					h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: o.ID, Provider: "test"})
					break
				}
			}
		}
		for _, q := range h.s.Quests {
			if q.Holder == p && q.State == "offered" && q.Def != def {
				h.do(core.Command{Kind: "decline", Origin: "player", Actor: p, Quest: q.Key})
			}
		}
		if q, ok := h.quest(p, def); ok && q.State == "offered" {
			return q
		}
		h.tick(1)
	}
	h.t.Fatalf("%s was never offered %s: %+v", p, def, h.s.Quests)
	return core.Quest{}
}

func (h *harness) accept(p core.ID, q core.Quest) {
	h.t.Helper()
	h.do(core.Command{Kind: "accept", Origin: "player", Actor: p, Quest: q.Key})
}

func (h *harness) fact(holder core.ID, p string, s, o core.ID) bool {
	_, ok := h.s.Facts[string(holder)+"|"+p+"|"+string(s)+"|"+string(o)]
	return ok
}

func (h *harness) believes(who core.ID, p string, s core.ID) (bool, bool) {
	b, ok := h.s.Beliefs[who]["|"+p+"|"+string(s)+"|"]
	return b.Holds, ok
}

// meet introduces p where npc lives: p talks to npc there, so everyone in
// that region now knows p (they witnessed it).
func (h *harness) meet(p, npc core.ID) {
	h.t.Helper()
	if region := h.s.Entities[npc].Region; h.s.Entities[p].Region != region {
		h.move(p, region)
	}
	h.mustAct("player", p, "conversar", map[string]core.ID{"npc": npc})
}

// introduce makes ps known wherever NPCs live, as if they had been around:
// they talk to someone in each such region and come back. Tests about other
// mechanics use it so givers know the players they call.
func (h *harness) introduce(ps ...core.ID) {
	h.t.Helper()
	regions := map[core.ID]core.ID{} // region -> first NPC there
	for _, id := range sortedKeys(h.s.Entities) {
		if e := h.s.Entities[id]; e.Kind == "npc" && e.Region != "" {
			if _, ok := regions[e.Region]; !ok {
				regions[e.Region] = id
			}
		}
	}
	for _, p := range ps {
		start := h.s.Entities[p].Region
		for _, r := range sortedKeys(regions) {
			h.meet(p, regions[r])
		}
		if h.s.Entities[p].Region != start {
			h.move(p, start)
		}
	}
}

// knowsOf: who believes it knows p (met p or heard of p).
func (h *harness) knowsOf(who, p core.ID) bool {
	for _, b := range h.s.Beliefs[who] {
		if b.P == "met" && b.O == p && b.Holds {
			return true
		}
	}
	return false
}

func (h *harness) events(kind string) []core.Event {
	out := []core.Event{}
	for _, e := range h.s.Events {
		if e.Kind == kind {
			out = append(out, e)
		}
	}
	return out
}

func isRejected(err error) bool { return errors.Is(err, core.ErrRejected) }

// move reports, as the game server would, that actor entered a region.
func (h *harness) move(actor, region core.ID) {
	h.t.Helper()
	h.do(core.Command{Kind: "move", Origin: "adapter", Actor: actor, Region: region})
}

func sortedKeys[V any](m map[core.ID]V) []core.ID {
	out := make([]core.ID, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	slices.Sort(out)
	return out
}

// legacyDungeons is the Hospedeiro as it was while it still had dungeon runs.
// The generic dungeon service stays in the core (no other universe uses it
// today), so its scenarios run on this frozen fixture and not on the live
// universe, which no longer has dungeons.
const legacyDungeons = "../engine/scenarios/testdata/legacy-dungeons"
