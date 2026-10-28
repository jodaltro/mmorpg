package scenarios

import (
	"encoding/json"
	"testing"
)

func TestZZDebug(t *testing.T) {
	h := load(t, "hospedeiro")
	for _, at := range []int{800, 1600, 2400} {
		h.tick(at - int(h.s.Tick))
		b, _ := json.Marshal(h.s.Facts)
		t.Logf("t=%d infl=%d carga_sangue=%d carga_pulmao=%d facts=%s", h.s.Tick, h.s.Entities["corpo"].Num["inflamacao"], h.s.Entities["sangue"].Num["carga"], h.s.Entities["pulmao"].Num["carga"], string(b))
	}
}
