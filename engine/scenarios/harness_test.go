package scenarios

import (
	"errors"
	"fmt"
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

// steer resolves the pending offer of p toward a quest def, as an advisor would.
func (h *harness) steer(p core.ID, def string) core.Quest {
	h.t.Helper()
	if q, ok := h.quest(p, def); ok && q.State == "offered" {
		return q
	}
	d, ok := h.offerDecision(p)
	if !ok {
		h.t.Fatalf("no offer decision for %s; quests %+v", p, h.s.Quests)
	}
	for _, o := range d.Options {
		if strings.HasPrefix(o.ID, def+"|") {
			h.do(core.Command{Kind: "resolve", Origin: "advisor", Decision: d.ID, Choice: o.ID, Provider: "test"})
			q, _ := h.quest(p, def)
			return q
		}
	}
	h.t.Fatalf("decision for %s has no %s option: %+v", p, def, d.Options)
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
