package authority

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
)

type ImportFact struct {
	ID      string          `json:"id"`
	Kind    string          `json:"kind"`
	Payload json.RawMessage `json:"payload"`
}
type ImportKnowledge struct {
	NPCID  string `json:"npcId"`
	FactID string `json:"factId"`
}
type DevelopmentImport struct {
	Version        int               `json:"version"`
	WorldID        string            `json:"worldId"`
	Name           string            `json:"name"`
	SourceVersion  int               `json:"sourceVersion"`
	SourceActor    string            `json:"sourceActor"`
	SourceWorld    string            `json:"sourceWorld"`
	SourceChecksum string            `json:"sourceChecksum"`
	Facts          []ImportFact      `json:"facts"`
	Abilities      []string          `json:"abilities"`
	Inventory      map[string]int    `json:"inventory"`
	Opportunities  map[string]string `json:"opportunities"`
	Relationships  map[string]int    `json:"relationships"`
	Knowledge      []ImportKnowledge `json:"knowledge"`
}

func (in DevelopmentImport) Validate() error {
	checksum, e := base64.StdEncoding.DecodeString(in.SourceChecksum)
	if in.Version != 1 || in.SourceVersion < 1 || in.SourceVersion > 3 || len(in.SourceActor) == 0 || len(in.SourceActor) > 128 || len(in.SourceWorld) == 0 || len(in.SourceWorld) > 128 || e != nil || len(checksum) != 32 || len(in.Facts) > 16384 || len(in.Abilities) > 1 || len(in.Inventory) > 1 || len(in.Opportunities) > 5 || len(in.Relationships) > 2 || len(in.Knowledge) > 16384 {
		return ErrInvalid
	}
	seen := map[string]bool{}
	for _, f := range in.Facts {
		if f.ID == "" || len(f.ID) > 256 || f.Kind == "" || len(f.Kind) > 80 || seen[f.ID] || len(f.Payload) > 16384 {
			return ErrInvalid
		}
		var p map[string]any
		if json.Unmarshal(f.Payload, &p) != nil || p == nil {
			return ErrInvalid
		}
		seen[f.ID] = true
	}
	for _, a := range in.Abilities {
		if a != "weakness-reading" {
			return ErrInvalid
		}
	}
	for i, n := range in.Inventory {
		if i != "corruption-sample" || n != 1 {
			return ErrInvalid
		}
	}
	for k, n := range in.Relationships {
		if k != "mira" && k != "orin" || n < 0 || n > 100 {
			return ErrInvalid
		}
	}
	for id, status := range in.Opportunities {
		if id != "forest-sample" && id != "forest-observation" && id != "forest-alert" && id != "new-threat-tracks" && id != "hunter-training" {
			return ErrInvalid
		}
		if status != "available" && status != "started" && status != "completed" && status != "expired" && status != "closed" {
			return ErrInvalid
		}
	}
	for _, k := range in.Knowledge {
		if k.NPCID != "mira" && k.NPCID != "orin" || !seen[k.FactID] {
			return ErrInvalid
		}
	}
	return nil
}
func (s *Store) Import(ctx context.Context, user string, in DevelopmentImport) (Character, error) {
	if !s.EnableDevImport {
		return Character{}, ErrNotFound
	}
	if in.Validate() != nil || len([]rune(in.Name)) < 1 || len([]rune(in.Name)) > 40 || strings.TrimSpace(in.Name) != in.Name || strings.ContainsAny(in.Name, "\r\n\t") {
		return Character{}, ErrInvalid
	}
	tx, e := s.begin(ctx, user)
	if e != nil {
		return Character{}, e
	}
	defer tx.Rollback(ctx)
	var region string
	var ruleset string
	var isTest bool
	if e = tx.QueryRow(ctx, `select r.id,w.is_test,w.ruleset from game.worlds w join game.world_regions r on r.world_id=w.id where w.id=$1 order by r.id limit 1`, in.WorldID).Scan(&region, &isTest,&ruleset); e != nil || !isTest || ruleset!="forest-demo-v1" {
		return Character{}, ErrInvalid
	}
	id := uuid.NewSHA1(uuid.NameSpaceOID, []byte(user+":"+in.WorldID+":"+in.SourceChecksum)).String()
	encoded, _ := json.Marshal(in)
	digest := sha256.Sum256(encoded)
	fingerprint := hex.EncodeToString(digest[:])
	if _, e = tx.Exec(ctx, `select pg_advisory_xact_lock(hashtextextended($1,0))`, id); e != nil {
		return Character{}, e
	}
	// Deterministic destination ID allows retry after network loss without duplicating the imported character.
	var existing string
	if tx.QueryRow(ctx, `select id::text from game.characters where id=$1`, id).Scan(&existing) == nil {
		var original string
		if tx.QueryRow(ctx, `select manifest_fingerprint from game.development_imports where character_id=$1`, id).Scan(&original) != nil || original != fingerprint {
			return Character{}, ErrConflict
		}
		c, e := loadCharacter(ctx, tx, id, false)
		if e != nil {
			return Character{}, e
		}
		return c, tx.Commit(ctx)
	}
	if _, e = tx.Exec(ctx, `insert into game.characters(id,owner_id,world_id,region_id,name,provenance) values($1,$2,$3,$4,$5,'offline-import')`, id, user, in.WorldID, region, in.Name); e != nil {
		return Character{}, e
	}
	c := Character{ID: id, WorldID: in.WorldID, RegionID: region}
	root, e := addFact(ctx, tx, c, "offline-import", "offline-import")
	if e != nil {
		return Character{}, e
	}
	for _, f := range in.Facts {
		fid := factID(c, "offline:"+f.ID)
		if _, e = tx.Exec(ctx, `insert into game.character_facts(id,character_id,kind,semantic_key,payload) values($1,$2,$3,$4,$5)`, fid, id, "offline:"+f.Kind, "offline:"+f.ID, []byte(f.Payload)); e != nil {
			return Character{}, e
		}
		if _, e = tx.Exec(ctx, `insert into game.character_memories(character_id,id,fact_id,description) values($1,$2,$3,$4)`, id, "offline:"+f.ID, fid, f.Kind); e != nil {
			return Character{}, e
		}
	}
	for _, a := range in.Abilities {
		if _, e = tx.Exec(ctx, `insert into game.character_abilities(character_id,ability_id,source_fact_id) values($1,$2,$3)`, id, a, root); e != nil {
			return Character{}, e
		}
	}
	for item, n := range in.Inventory {
		if _, e = tx.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,$2,$3)`, id, item, n); e != nil {
			return Character{}, e
		}
	}
	for opportunity, status := range in.Opportunities {
		if _, e = tx.Exec(ctx, `insert into game.character_opportunities(character_id,opportunity_id,status,source_fact_id) values($1,$2,$3,$4)`, id, opportunity, status, root); e != nil {
			return Character{}, e
		}
	}
	for npc, trust := range in.Relationships {
		if _, e = tx.Exec(ctx, `insert into game.npc_relationships(character_id,npc_id,trust) values($1,$2,$3)`, id, npc, trust); e != nil {
			return Character{}, e
		}
	}
	for _, k := range in.Knowledge {
		if e = know(ctx, tx, c, k.NPCID, factID(c, "offline:"+k.FactID), "offline-import"); e != nil {
			return Character{}, e
		}
	}
	if _, e = tx.Exec(ctx, `insert into game.development_imports(character_id,source_version,source_checksum,source_actor,source_world,manifest_fingerprint) values($1,$2,$3,$4,$5,$6)`, id, in.SourceVersion, in.SourceChecksum, in.SourceActor, in.SourceWorld, fingerprint); e != nil {
		return Character{}, e
	}
	c, e = loadCharacter(ctx, tx, id, false)
	if e != nil {
		return Character{}, e
	}
	return c, tx.Commit(ctx)
}
