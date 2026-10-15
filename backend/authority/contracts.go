package authority

import (
	"errors"
	"mmorpg/authority/journey"
)

var (
	ErrInvalid     = errors.New("invalid_intent")
	ErrNotFound    = errors.New("not_found")
	ErrConflict    = errors.New("revision_or_request_conflict")
	ErrUnavailable = errors.New("storage_unavailable")
)

type CreateCharacter struct {
	Version int    `json:"version"`
	WorldID string `json:"worldId"`
	Name    string `json:"name"`
}
type Intent struct {
	Version          int    `json:"version"`
	RequestID        string `json:"requestId"`
	ExpectedRevision int64  `json:"expectedRevision"`
	Kind             string `json:"kind"`
	TargetID         string `json:"targetId"`
}
type Character struct {
	Version       int               `json:"version"`
	ID            string            `json:"id"`
	WorldID       string            `json:"worldId"`
	Ruleset       string            `json:"-"`
	RegionID      string            `json:"regionId"`
	Name          string            `json:"name"`
	Revision      int64             `json:"revision"`
	HP            int               `json:"hp"`
	Provenance    string            `json:"provenance"`
	Inventory     map[string]int    `json:"inventory"`
	Abilities     []string          `json:"abilities"`
	Facts         []Fact            `json:"facts"`
	Opportunities map[string]string `json:"opportunities"`
	Relationships map[string]int    `json:"relationships"`
	Knowledge     []Knowledge       `json:"knowledge"`
	Encounter     *Encounter        `json:"encounter,omitempty"`
	Journey       *journey.State    `json:"journey,omitempty"`
	Actions       []journey.Action  `json:"actions,omitempty"`
}
type Fact struct {
	ID          string `json:"id"`
	Version     int    `json:"version"`
	Kind        string `json:"kind"`
	SemanticKey string `json:"semanticKey"`
}
type Knowledge struct {
	NPCID  string `json:"npcId"`
	FactID string `json:"factId"`
	Source string `json:"source"`
}
type Encounter struct {
	ID        string `json:"id"`
	HP        int    `json:"hp"`
	Turn      int    `json:"turn"`
	Phase     string `json:"phase"`
	Collected bool   `json:"collected"`
}
type Region struct {
	Version         int    `json:"version"`
	WorldID         string `json:"worldId"`
	ID              string `json:"id"`
	Threat          bool   `json:"threat"`
	NoticePublished bool   `json:"noticePublished"`
}

// The demonstration encounter is turn-based. It never accepts damage/hits/deaths from a client.
func ResolveEncounter(e Encounter, hp int, kind string, weakness bool) (Encounter, int, bool, error) {
	if hp <= 0 || e.Phase == "defeated" {
		return e, hp, false, ErrInvalid
	}
	defeated := false
	switch kind {
	case "attack":
		if e.Phase == "preparing" {
			hp -= 15
			e.Phase = "ready"
		} else {
			damage := 20
			if e.Phase == "exposed" && weakness {
				damage += 10
			}
			e.HP -= damage
			if e.HP <= 0 {
				e.HP = 0
				e.Phase = "defeated"
				defeated = true
			} else {
				e.Phase = "preparing"
			}
		}
	case "dodge":
		if e.Phase != "preparing" {
			return e, hp, false, ErrInvalid
		}
		e.Phase = "exposed"
	default:
		return e, hp, false, ErrInvalid
	}
	if hp < 0 {
		hp = 0
	}
	e.Turn++
	return e, hp, defeated, nil
}
