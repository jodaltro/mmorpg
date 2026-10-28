package scenarios

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"slices"
	"strconv"
	"testing"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
)

// scaled is the Hospedeiro with every named cell that has tasks repeated until
// there are about n of them. The copies share the same organs, so they compete
// for the same work; that is the point, it is the load a crowd puts on a tick.
func scaled(t *testing.T, n int) (*harness, int) {
	t.Helper()
	data, err := os.ReadFile("../../universes/hospedeiro/universe.json")
	if err != nil {
		t.Fatal(err)
	}
	var u core.Universe
	if err := json.NewDecoder(bytes.NewReader(bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf}))).Decode(&u); err != nil {
		t.Fatal(err)
	}
	named := map[core.ID]bool{}
	for _, task := range u.Tasks {
		named[task.NPC] = true
	}
	var seeds []core.EntitySeed
	for _, e := range u.Entities {
		if named[e.ID] {
			seeds = append(seeds, e)
		}
	}
	base := slices.Clone(u.Tasks)
	count := len(seeds)
	for copy := 2; count < n; copy++ {
		for _, e := range seeds {
			if count >= n {
				break
			}
			id := core.ID(string(e.ID) + "-" + strconv.Itoa(copy))
			c := e
			c.ID, c.Name = id, e.Name+" "+strconv.Itoa(copy)
			u.Entities = append(u.Entities, c)
			for _, task := range base {
				if task.NPC == e.ID {
					task.NPC, task.ID = id, task.ID+"-"+strconv.Itoa(copy)
					u.Tasks = append(u.Tasks, task)
				}
			}
			count++
		}
	}
	w, err := core.Compile(u)
	if err != nil {
		t.Fatalf("a world with %d named cells must compile: %v", n, err)
	}
	return &harness{t: t, w: w, s: core.NewState(w)}, count
}

type tickCost struct{ mean, p99, max time.Duration }

// cost ticks the world and times every Step on its own.
func cost(h *harness, warm, n int) tickCost {
	h.tick(warm)
	ds := make([]time.Duration, 0, n)
	for i := 0; i < n; i++ {
		began := time.Now()
		h.tick(1)
		ds = append(ds, time.Since(began))
	}
	slices.Sort(ds)
	var sum time.Duration
	for _, d := range ds {
		sum += d
	}
	return tickCost{sum / time.Duration(n), ds[n*99/100], ds[n-1]}
}

// P14.3: budgets for 10, 100 and 500 named cells. The tick of the Hospedeiro is
// 4 s, so a tick has 4000 ms to fit in; the limits asserted here are far
// tighter than that and are recorded, not promised: they are where this
// machine was, and the point is to notice when they move.
func TestTickBudgetForTenHundredAndFiveHundredNamedCells(t *testing.T) {
	if testing.Short() {
		t.Skip("scale")
	}
	limits := map[int]time.Duration{14: 10 * time.Millisecond, 100: 40 * time.Millisecond, 500: 250 * time.Millisecond}
	for _, want := range []int{14, 100, 500} {
		h, got := scaled(t, want)
		h.join("p1")
		c := cost(h, 200, 300)
		st, _ := json.Marshal(h.s)
		working := 0
		for _, n := range h.s.NPCs {
			if n.Task != "" {
				working++
			}
		}
		line := fmt.Sprintf("%3d named cells: tick mean %6.2f ms, p99 %6.2f ms, max %6.2f ms; state %4d KB; %d working at tick %d",
			got, ms(c.mean), ms(c.p99), ms(c.max), len(st)/1024, working, h.s.Tick)
		t.Log(line)
		if got < want {
			t.Fatalf("asked for %d, built %d", want, got)
		}
		if c.mean > limits[want] {
			t.Fatalf("%s: mean over the %v budget", line, limits[want])
		}
		if working == 0 {
			t.Fatalf("%d named cells and none working: the load is not real", got)
		}
	}
}

func ms(d time.Duration) float64 { return float64(d.Microseconds()) / 1000 }
