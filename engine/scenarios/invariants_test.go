package scenarios

import (
	"encoding/json"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
	"github.com/jodaltro/mmorpg/engine/universe"
)

func scripted(t *testing.T) *harness {
	h := load(t, "valdoria")
	h.join("p1", "p2")
	h.tick(6)
	h.mustAct("player", "p1", "examinar-poco", nil)
	h.move("p1", "estrada")
	h.tick(1)
	q := h.steer("p1", "cenario-origem")
	h.accept("p1", q)
	h.move("p1", "floresta")
	h.mustAct("adapter", "p1", "seguir-rastro", nil)
	h.tick(40)
	return h
}

// Replaying the command log from tick 0 reproduces the exact state.
func TestReplayIsDeterministic(t *testing.T) {
	a := scripted(t)
	b := load(t, "valdoria")
	for _, c := range a.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay rejected %+v: %v", c, err)
		}
	}
	if a.s.Digest() != b.s.Digest() {
		t.Fatal("replay digest differs")
	}
	if a.s.Digest() != scripted(t).s.Digest() {
		t.Fatal("two identical runs differ")
	}
}

func TestIdempotencyAndRevisionGuard(t *testing.T) {
	h := load(t, "valdoria")
	h.join("p1")
	c := core.Command{RequestID: "same", Kind: "act", Origin: "player", Actor: "p1", Action: "examinar-poco"}
	h.do(c)
	before := h.s.Digest()
	if d := h.do(c); !d.Duplicate {
		t.Fatal("duplicate request must be a no-op")
	}
	if h.s.Digest() != before {
		t.Fatal("duplicate changed state")
	}
	stale := h.s.Revision - 1
	if _, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "examinar-poco", ExpectedRevision: &stale}); !isRejected(err) {
		t.Fatal("stale revision must be rejected")
	}
	if _, err := h.try(core.Command{Kind: "tick", Origin: "system", RequestID: "tick:9"}); !isRejected(err) {
		t.Fatal("ticks must be sequential")
	}
	if _, err := h.try(core.Command{Kind: "act", Origin: "player", Actor: "p1", Action: "seguir-rastro"}); !isRejected(err) {
		t.Fatal("players cannot submit adapter-only occurrences")
	}
	if _, err := h.try(core.Command{Kind: "act", Origin: "agent", Actor: "mira", Action: "colher-ervas"}); !isRejected(err) {
		t.Fatal("agent commands cannot come from outside")
	}
}

func TestSecondUniverseRunsOnSameCore(t *testing.T) {
	h := load(t, "orbital")
	h.join("x1", "x2")
	h.tick(40)
	if s := h.events("sealed"); len(s) == 0 || s[0].Actor != "ines" {
		t.Fatalf("crew should seal leaks autonomously, sealed by %+v", s)
	}
	h.move("x1", "antena")
	h.move("x2", "antena")
	h.tick(1)
	q1 := h.steer("x1", "contato")
	q2 := h.steer("x2", "contato")
	h.accept("x1", q1)
	h.accept("x2", q2)
	h.mustAct("adapter", "x2", "registrar-sinal", nil)
	if b := h.s.Arcs["sinal"].Beats["contato"]; b.State != "claimed" || b.By[0] != "x2" {
		t.Fatalf("x2 should claim first contact: %+v", b)
	}
	if h.s.Entities["x1"].Num["merit"] < 1 {
		t.Fatal("rival effect missing")
	}
}

func TestValidatorRejectsBrokenUniverses(t *testing.T) {
	raw, err := os.ReadFile("../../universes/valdoria/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	cases := map[string]func(u *core.Universe){
		"unknown predicate":  func(u *core.Universe) { u.Rules[1].When.Fact.P = "nope" },
		"unbound variable":   func(u *core.Universe) { u.Actions[0].Effects[0].Fact.S = "$ghost" },
		"unknown entity":     func(u *core.Universe) { u.Actions[0].Effects[0].Fact.S = "atlantis" },
		"story cycle":        func(u *core.Universe) { u.Arcs[0].Beats[3].Next = []string{"origem"} },
		"unreachable beat":   func(u *core.Universe) { u.Arcs[0].Beats[0].Next = []string{"restaurar"} },
		"unknown op":         func(u *core.Universe) { u.Rules[1].Effects[0].Op = "teleport" },
		"agent player-only":  func(u *core.Universe) { u.Agents[0].Goals[0].Action = "consultar-anciao" },
		"two-operator node":  func(u *core.Universe) { u.Rules[1].When.Num = &core.NumCmp{E: "vila", K: "health", Op: "<", V: 1} },
		"quest on bad beat":  func(u *core.Universe) { u.Quests[2].Beat = "missing" },
		"unknown field kind": func(u *core.Universe) { u.Entities[0].Kind = "dragon" },
		"luck in skill learn": func(u *core.Universe) {
			u.Skills[0].Learn = &core.Cond{All: []core.Cond{*u.Skills[0].Learn, {Chance: &core.ChanceCmp{Seed: "x", Permille: 5}}}}
		},
		"grant unknown skill": func(u *core.Universe) {
			u.Actions[0].Effects = append(u.Actions[0].Effects, core.Effect{Op: "grant", V: "fly"})
		},
		"bad rarity": func(u *core.Universe) { u.Skills[0].Rarity = "mythic" },
	}
	for name, mutate := range cases {
		var u core.Universe
		if err := json.Unmarshal(raw, &u); err != nil {
			t.Fatal(err)
		}
		mutate(&u)
		if _, err := core.Compile(u); err == nil {
			t.Errorf("%s: expected rejection", name)
		}
	}
	if _, err := universe.Parse([]byte(strings.Replace(string(raw), `"version": 1`, `"version": 1, "cheat": true`, 1))); err == nil {
		t.Error("unknown JSON fields must be rejected")
	}
}

// The kernel must stay engine-, network- and storage-agnostic.
func TestCoreHasNoInfrastructureImports(t *testing.T) {
	allowed := map[string]bool{"crypto/sha256": true, "encoding/hex": true, "encoding/json": true, "errors": true, "fmt": true,
		"hash/fnv": true, "maps": true, "slices": true, "strconv": true, "strings": true}
	files, _ := filepath.Glob("../core/*.go")
	if len(files) == 0 {
		t.Fatal("no core files")
	}
	for _, f := range files {
		ast, err := parser.ParseFile(token.NewFileSet(), f, nil, parser.ImportsOnly)
		if err != nil {
			t.Fatal(err)
		}
		for _, imp := range ast.Imports {
			p, _ := strconv.Unquote(imp.Path.Value)
			if !allowed[p] {
				t.Errorf("%s imports %s", f, p)
			}
		}
	}
}
