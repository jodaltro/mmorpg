// Package universe loads universe definitions from JSON.
package universe

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"

	"github.com/jodaltro/mmorpg/engine/core"
)

const maxBytes = 4 << 20

// Parse decodes strictly: unknown fields are errors, so a typo in content
// never silently disables a rule.
func Parse(data []byte) (*core.World, error) {
	if len(data) > maxBytes {
		return nil, fmt.Errorf("%w: file too large", core.ErrUniverse)
	}
	dec := json.NewDecoder(bytes.NewReader(bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf})))
	dec.DisallowUnknownFields()
	var u core.Universe
	if err := dec.Decode(&u); err != nil {
		return nil, fmt.Errorf("%w: %v", core.ErrUniverse, err)
	}
	if dec.More() {
		return nil, fmt.Errorf("%w: trailing data", core.ErrUniverse)
	}
	return core.Compile(u)
}

func Load(path string) (*core.World, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return Parse(data)
}
