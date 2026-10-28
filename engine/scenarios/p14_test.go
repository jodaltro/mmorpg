package scenarios

import (
	"encoding/json"
	"reflect"
	"testing"

	"github.com/jodaltro/mmorpg/engine/core"
)

// P14: a state that went through JSON must be revived to what NewState makes,
// field by field. If a field is added to State and allocated in NewState but
// not in Revive, this names it before the world breaks on a restart.
func TestReviveAllocatesWhatNewStateAllocates(t *testing.T) {
	for _, name := range []string{"hospedeiro", "valdoria", "orbital"} {
		h := load(t, name)
		fresh := core.NewState(h.w)
		raw, err := json.Marshal(fresh)
		if err != nil {
			t.Fatal(err)
		}
		var back core.State
		if err := json.Unmarshal(raw, &back); err != nil {
			t.Fatal(err)
		}
		h.w.Revive(&back)
		a, b := reflect.ValueOf(fresh), reflect.ValueOf(back)
		for i := 0; i < a.NumField(); i++ {
			switch a.Field(i).Kind() {
			case reflect.Map, reflect.Slice:
				if a.Field(i).IsNil() != b.Field(i).IsNil() {
					t.Errorf("%s: State.%s is nil=%v in a new world but nil=%v after a restore", name, a.Type().Field(i).Name, a.Field(i).IsNil(), b.Field(i).IsNil())
				}
			}
		}
		if back.Digest() != fresh.Digest() {
			t.Errorf("%s: reviving must not change the digest", name)
		}
	}
}
