package scenarios

import (
	"slices"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

func TestFirstDiveAwardsPermanentGeneWithoutReplacingBuildAndReplays(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1", "p2")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	q := h.steer("p1", "primeiro-mergulho")
	h.accept("p1", q)
	h.move("p1", "sangue")
	h.tick(2)
	g := h.s.Genomes["p1"]
	if !slices.Contains(g.Library, "nucleo-reativo") || len(g.Genes) != 0 {
		t.Fatalf("reward must enter library, without altering expression: %+v", g)
	}
	view, _ := h.w.View(&h.s, "p2", 0)
	for _, e := range view.Events {
		if e.Kind == "gene-acquired" && e.Actor == "p1" {
			t.Fatal("a private gene reward leaked to another player")
		}
	}
	h.mustAct("player", "p1", "expressar", map[string]core.ID{"gene": "nucleo-reativo"})
	if !slices.Contains(h.s.Genomes["p1"].Genes, "nucleo-reativo") {
		t.Fatal("the permanent reward cannot be expressed")
	}
	b := load(t, "hospedeiro")
	for _, c := range h.log {
		var err error
		if b.s, _, err = b.w.Step(b.s, c); err != nil {
			t.Fatalf("replay: %v", err)
		}
	}
	if b.s.Digest() != h.s.Digest() {
		t.Fatal("gene rewards changed deterministic replay")
	}
}

func TestGeneRewardIsIdempotentAndOnlyAuthorityCanGrantIt(t *testing.T) {
	h := load(t, "hospedeiro")
	u := h.w.U
	u.Actions = append(slices.Clone(u.Actions), core.ActionDef{ID: "award-test", By: []string{"adapter"}, Effects: []core.Effect{{Op: "acquire-gene", E: "$self", V: "vesicula-toxica"}}})
	var err error
	h.w, err = core.Compile(u)
	if err != nil {
		t.Fatal(err)
	}
	h.join("p1")
	if h.act("player", "p1", "award-test", nil) == nil {
		t.Fatal("client granted itself a gene")
	}
	h.mustAct("adapter", "p1", "award-test", nil)
	h.mustAct("adapter", "p1", "award-test", nil)
	if !slices.Equal(h.s.Genomes["p1"].Library, []string{"vesicula-toxica"}) {
		t.Fatal("duplicate gene reward")
	}
	count := 0
	for _, e := range h.s.Events {
		if e.Kind == "gene-acquired" {
			count++
		}
	}
	if count != 1 {
		t.Fatalf("expected one reward notice, got %d", count)
	}
	u.Actions[len(u.Actions)-1].Effects[0].V = "unknown-gene"
	if _, err := core.Compile(u); err == nil {
		t.Fatal("unknown gene reward compiled")
	}
}

func TestSlowerEvolutionAndEveryDungeonHasConcreteGeneReward(t *testing.T) {
	h := load(t, "hospedeiro")
	if h.w.U.Evolution.Threshold != 120 || !slices.Equal(h.w.U.Differentiation.Tiers, []int64{168, 480}) {
		t.Fatal("progression no longer follows the calibrated fourfold cadence")
	}
	for _, dungeon := range h.w.U.Dungeons {
		found := false
		for _, reward := range dungeon.Rewards {
			found = found || reward.Op == "acquire-gene"
		}
		if !found {
			t.Fatalf("%s lacks a permanent combat reward", dungeon.ID)
		}
	}
}

func TestClassProofCountsPracticeAfterDifferentiation(t *testing.T) {
	h := load(t, "hospedeiro")
	h.join("p1")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.move("p1", "sangue")
	h.mustAct("adapter", "p1", "absorver-nutriente", nil)
	h.tick(8)
	h.becomeClass("p1", "mieloide", "eosinofilo")
	q := h.steer("p1", "prova-eosinofilo")
	h.accept("p1", q)
	h.tick(1)
	if got, _ := h.quest("p1", q.Def); got.State != "active" {
		t.Fatal("kills before differentiation prematurely completed the proof")
	}
	if h.s.Entities["p1"].Num["prova-eosinofilo-feitos"] != 0 {
		t.Fatal("practice from another class was counted")
	}
	h.mustAct("adapter", "p1", "derrotar-virus", nil)
	if h.s.Entities["p1"].Num["prova-eosinofilo-feitos"] != 1 {
		t.Fatal("a confirmed deed after differentiation was not counted")
	}
}
