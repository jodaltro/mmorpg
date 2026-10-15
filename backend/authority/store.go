package authority

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	Pool            *pgxpool.Pool
	EnableDevImport bool
}

func (s *Store) CheckRole(ctx context.Context) error {
	var role string
	var privileged, member bool
	err := s.Pool.QueryRow(ctx, `select current_user, rolsuper or rolbypassrls or rolcreaterole or rolcreatedb, pg_has_role(current_user,'game_backend','member') from pg_roles where rolname=current_user`).Scan(&role, &privileged, &member)
	if err != nil || privileged || !member || role == "authenticator" || role == "service_role" {
		return errors.New("unsafe_database_role")
	}
	return nil
}
func (s *Store) begin(ctx context.Context, user string) (pgx.Tx, error) {
	id, e := uuid.Parse(user)
	if e != nil || id == uuid.Nil {
		return nil, ErrUnauthorized
	}
	tx, e := s.Pool.Begin(ctx)
	if e != nil {
		return nil, e
	}
	if _, e = tx.Exec(ctx, `set local role game_backend`); e == nil {
		_, e = tx.Exec(ctx, `select set_config('app.user_id',$1,true)`, id.String())
	}
	if e != nil {
		tx.Rollback(ctx)
		return nil, e
	}
	return tx, nil
}
func (s *Store) Create(ctx context.Context, user string, in CreateCharacter) (Character, error) {
	if in.Version != 1 || len(in.WorldID) > 80 || strings.TrimSpace(in.Name) != in.Name || len([]rune(in.Name)) < 1 || len([]rune(in.Name)) > 40 || strings.ContainsAny(in.Name, "\r\n\t") {
		return Character{}, ErrInvalid
	}
	tx, e := s.begin(ctx, user)
	if e != nil {
		return Character{}, e
	}
	defer tx.Rollback(ctx)
	var region string
	if tx.QueryRow(ctx, `select id from game.world_regions where world_id=$1 order by case when id='valdoria' then 0 else 1 end,id limit 1`, in.WorldID).Scan(&region) != nil {
		return Character{}, ErrInvalid
	}
	var id string
	if e = tx.QueryRow(ctx, `insert into game.characters(owner_id,world_id,region_id,name) values($1,$2,$3,$4) returning id::text`, user, in.WorldID, region, in.Name).Scan(&id); e != nil {
		return Character{}, e
	}
	var ruleset string
	if e = tx.QueryRow(ctx, `select ruleset from game.worlds where id=$1`, in.WorldID).Scan(&ruleset); e != nil {
		return Character{}, e
	}
	if ruleset == "expanded-v1" {
		if _, e = tx.Exec(ctx, `insert into game.journey_runtime(character_id) values($1)`, id); e != nil {
			return Character{}, e
		}
		if _, e = addFact(ctx, tx, Character{ID: id}, "journey-fact", "j:visited:valdoria"); e != nil {
			return Character{}, e
		}
	}
	c, e := loadCharacter(ctx, tx, id, false)
	if e != nil {
		return Character{}, e
	}
	if e = tx.Commit(ctx); e != nil {
		return Character{}, e
	}
	return c, nil
}
func (s *Store) Read(ctx context.Context, user, id string) (Character, error) {
	if _, e := uuid.Parse(id); e != nil {
		return Character{}, ErrNotFound
	}
	tx, e := s.begin(ctx, user)
	if e != nil {
		return Character{}, e
	}
	defer tx.Rollback(ctx)
	c, e := loadCharacter(ctx, tx, id, false)
	if e != nil {
		return Character{}, e
	}
	return c, tx.Commit(ctx)
}
func (s *Store) List(ctx context.Context, user string) ([]string, error) {
	tx, e := s.begin(ctx, user)
	if e != nil {
		return nil, e
	}
	defer tx.Rollback(ctx)
	rows, e := tx.Query(ctx, `select id::text from game.characters order by created_at,id`)
	if e != nil {
		return nil, e
	}
	defer rows.Close()
	ids := []string{}
	for rows.Next() {
		var id string
		if e = rows.Scan(&id); e != nil {
			return nil, e
		}
		ids = append(ids, id)
	}
	if e = rows.Err(); e != nil {
		return nil, e
	}
	rows.Close()
	return ids, tx.Commit(ctx)
}
func (s *Store) ReadRegion(ctx context.Context, user, world, region string) (Region, error) {
	tx, e := s.begin(ctx, user)
	if e != nil {
		return Region{}, e
	}
	defer tx.Rollback(ctx)
	r := Region{WorldID: world, ID: region}
	e = tx.QueryRow(ctx, `select version,threat,notice_published from game.world_regions where world_id=$1 and id=$2`, world, region).Scan(&r.Version, &r.Threat, &r.NoticePublished)
	if errors.Is(e, pgx.ErrNoRows) {
		return Region{}, ErrNotFound
	}
	if e != nil {
		return Region{}, e
	}
	return r, tx.Commit(ctx)
}
func (s *Store) Apply(ctx context.Context, user, id string, in Intent) (Character, error) {
	if in.Version != 1 || in.ExpectedRevision < 0 || len(in.TargetID) > 128 {
		return Character{}, ErrInvalid
	}
	rid, e := uuid.Parse(in.RequestID)
	if e != nil || rid == uuid.Nil {
		return Character{}, ErrInvalid
	}
	if _, e = uuid.Parse(id); e != nil {
		return Character{}, ErrNotFound
	}
	bytes, _ := json.Marshal(in)
	h := sha256.Sum256(bytes)
	fingerprint := hex.EncodeToString(h[:])
	tx, e := s.begin(ctx, user)
	if e != nil {
		return Character{}, e
	}
	defer tx.Rollback(ctx)
	c, e := loadCharacter(ctx, tx, id, true)
	if e != nil {
		return Character{}, e
	}
	var savedFingerprint string
	var saved []byte
	e = tx.QueryRow(ctx, `select fingerprint,response from game.command_receipts where character_id=$1 and request_id=$2`, id, rid.String()).Scan(&savedFingerprint, &saved)
	if e == nil {
		if savedFingerprint != fingerprint {
			return Character{}, ErrConflict
		}
		var result Character
		if json.Unmarshal(saved, &result) != nil {
			return Character{}, ErrUnavailable
		}
		result.Ruleset = c.Ruleset
		return result, tx.Commit(ctx)
	}
	if !errors.Is(e, pgx.ErrNoRows) {
		return Character{}, e
	}
	if c.Revision != in.ExpectedRevision {
		return Character{}, ErrConflict
	}
	if c.Journey != nil {
		e = applyExpanded(ctx, tx, &c, in)
	} else {
		e = applyIntent(ctx, tx, &c, in)
		if e == nil {
			e = processDue(ctx, tx, c)
		}
	}
	if e != nil {
		return Character{}, e
	}
	if _, e = tx.Exec(ctx, `update game.characters set hp=$2,region_id=$3,revision=revision+1 where id=$1`, id, c.HP, c.RegionID); e != nil {
		return Character{}, e
	}
	c, e = loadCharacter(ctx, tx, id, false)
	if e != nil {
		return Character{}, e
	}
	response, e := json.Marshal(c)
	if e != nil {
		return Character{}, e
	}
	if _, e = tx.Exec(ctx, `insert into game.command_receipts(character_id,request_id,fingerprint,response) values($1,$2,$3,$4)`, id, rid.String(), fingerprint, response); e != nil {
		return Character{}, e
	}
	return c, tx.Commit(ctx)
}
func loadCharacter(ctx context.Context, tx pgx.Tx, id string, lock bool) (Character, error) {
	c := Character{Version: 1, Inventory: map[string]int{}, Abilities: []string{}, Facts: []Fact{}, Opportunities: map[string]string{}, Relationships: map[string]int{}, Knowledge: []Knowledge{}}
	q := `select c.id::text,c.world_id,c.region_id,c.name,c.revision,c.hp,c.provenance,w.ruleset from game.characters c join game.worlds w on w.id=c.world_id where c.id=$1`
	if lock {
		q += ` for update of c`
	}
	e := tx.QueryRow(ctx, q, id).Scan(&c.ID, &c.WorldID, &c.RegionID, &c.Name, &c.Revision, &c.HP, &c.Provenance, &c.Ruleset)
	if errors.Is(e, pgx.ErrNoRows) {
		return Character{}, ErrNotFound
	}
	if e != nil {
		return Character{}, e
	}
	queries := []struct {
		q    string
		scan func(pgx.Rows) error
	}{
		{`select item_id,quantity from game.character_inventory where character_id=$1 order by item_id`, func(r pgx.Rows) error {
			var k string
			var n int
			if e := r.Scan(&k, &n); e != nil {
				return e
			}
			c.Inventory[k] = n
			return nil
		}},
		{`select ability_id from game.character_abilities where character_id=$1 order by ability_id`, func(r pgx.Rows) error {
			var k string
			if e := r.Scan(&k); e != nil {
				return e
			}
			c.Abilities = append(c.Abilities, k)
			return nil
		}},
		{`select id::text,version,kind,semantic_key from game.character_facts where character_id=$1 order by created_at,id`, func(r pgx.Rows) error {
			var f Fact
			if e := r.Scan(&f.ID, &f.Version, &f.Kind, &f.SemanticKey); e != nil {
				return e
			}
			c.Facts = append(c.Facts, f)
			return nil
		}},
		{`select opportunity_id,status from game.character_opportunities where character_id=$1 order by opportunity_id`, func(r pgx.Rows) error {
			var k, v string
			if e := r.Scan(&k, &v); e != nil {
				return e
			}
			c.Opportunities[k] = v
			return nil
		}},
		{`select npc_id,trust from game.npc_relationships where character_id=$1 order by npc_id`, func(r pgx.Rows) error {
			var k string
			var v int
			if e := r.Scan(&k, &v); e != nil {
				return e
			}
			c.Relationships[k] = v
			return nil
		}},
		{`select npc_id,fact_id::text,source from game.npc_knowledge where character_id=$1 order by npc_id,fact_id`, func(r pgx.Rows) error {
			var k Knowledge
			if e := r.Scan(&k.NPCID, &k.FactID, &k.Source); e != nil {
				return e
			}
			c.Knowledge = append(c.Knowledge, k)
			return nil
		}},
	}
	for _, q := range queries {
		r, e := tx.Query(ctx, q.q, id)
		if e != nil {
			return Character{}, e
		}
		for r.Next() {
			if e = q.scan(r); e != nil {
				r.Close()
				return Character{}, e
			}
		}
		e = r.Err()
		r.Close()
		if e != nil {
			return Character{}, e
		}
	}
	encounter := Encounter{}
	e = tx.QueryRow(ctx, `select id::text,hp,turn,phase,collected from game.encounters where character_id=$1`, id).Scan(&encounter.ID, &encounter.HP, &encounter.Turn, &encounter.Phase, &encounter.Collected)
	if e == nil {
		c.Encounter = &encounter
	} else if !errors.Is(e, pgx.ErrNoRows) {
		return Character{}, e
	}
	if e = loadExpanded(ctx, tx, &c); e != nil {
		return Character{}, e
	}
	return c, nil
}
func has(c Character, kind string) bool {
	for _, f := range c.Facts {
		if f.Kind == kind {
			return true
		}
	}
	return false
}
func factID(c Character, key string) string {
	return uuid.NewSHA1(uuid.NameSpaceOID, []byte(c.ID+":"+key)).String()
}
func addFact(ctx context.Context, tx pgx.Tx, c Character, kind, key string) (string, error) {
	id := factID(c, key)
	_, e := tx.Exec(ctx, `insert into game.character_facts(id,character_id,kind,semantic_key) values($1,$2,$3,$4) on conflict(character_id,semantic_key) do nothing`, id, c.ID, kind, key)
	if e != nil {
		return "", e
	}
	_, e = tx.Exec(ctx, `insert into game.event_outbox(character_id,fact_id,topic,payload) values($1::uuid,$2::uuid,'character-fact',jsonb_build_object('factId',$2::uuid,'kind',$3::text)) on conflict(fact_id) do nothing`, c.ID, id, kind)
	return id, e
}
func know(ctx context.Context, tx pgx.Tx, c Character, npc, id, source string) error {
	_, e := tx.Exec(ctx, `insert into game.npc_knowledge(character_id,npc_id,fact_id,source) values($1,$2,$3,$4) on conflict do nothing`, c.ID, npc, id, source)
	return e
}
func completeRoute(ctx context.Context, tx pgx.Tx, c Character, route, npc, source string) error {
	_, e := tx.Exec(ctx, `insert into game.character_opportunities(character_id,opportunity_id,status,source_fact_id) values($1,$2,'completed',$3) on conflict(character_id,opportunity_id) do update set status='completed',version=game.character_opportunities.version+1 where game.character_opportunities.status!='completed'`, c.ID, route, source)
	if e != nil {
		return e
	}
	if _, e = tx.Exec(ctx, `insert into game.character_abilities(character_id,ability_id,source_fact_id) values($1,'weakness-reading',$2) on conflict do nothing`, c.ID, source); e != nil {
		return e
	}
	if _, e = tx.Exec(ctx, `insert into game.npc_relationships(character_id,npc_id,trust) values($1,$2,1) on conflict(character_id,npc_id) do update set trust=least(100,game.npc_relationships.trust+1),version=game.npc_relationships.version+1`, c.ID, npc); e != nil {
		return e
	}
	return know(ctx, tx, c, npc, source, "observation")
}
func applyIntent(ctx context.Context, tx pgx.Tx, c *Character, in Intent) error {
	switch in.Kind {
	case "examine-tracks":
		if c.HP <= 0 || in.TargetID != "corrupted-tracks" || has(*c, "tracking-confirmed") {
			return ErrInvalid
		}
		_, e := addFact(ctx, tx, *c, "tracking-confirmed", "corrupted-tracks")
		return e
	case "brief-orin":
		if c.HP <= 0 || in.TargetID != "orin" || !has(*c, "tracking-confirmed") || has(*c, "orin-briefed") {
			return ErrInvalid
		}
		id, e := addFact(ctx, tx, *c, "orin-briefed", "orin-briefed")
		if e != nil {
			return e
		}
		_ = id
		return know(ctx, tx, *c, "orin", factID(*c, "corrupted-tracks"), "conversation")
	case "start-encounter":
		if c.HP <= 0 || in.TargetID != "corrupted-wolf" || c.Encounter != nil {
			return ErrInvalid
		}
		if _, e := tx.Exec(ctx, `insert into game.encounters(character_id) values($1)`, c.ID); e != nil {
			return e
		}
		_, e := addFact(ctx, tx, *c, "encounter-started", "wolf-encounter")
		return e
	case "attack", "dodge":
		if c.Encounter == nil || in.TargetID != c.Encounter.ID {
			return ErrInvalid
		}
		weakness := false
		for _, a := range c.Abilities {
			if a == "weakness-reading" {
				weakness = true
			}
		}
		encounter, hp, defeated, e := ResolveEncounter(*c.Encounter, c.HP, in.Kind, weakness)
		if e != nil {
			return e
		}
		c.HP = hp
		if _, e = tx.Exec(ctx, `update game.encounters set hp=$2,turn=$3,phase=$4,version=version+1 where id=$1`, encounter.ID, encounter.HP, encounter.Turn, encounter.Phase); e != nil {
			return e
		}
		if _, e = addFact(ctx, tx, *c, "combat-turn-verified", encounter.ID+":"+in.RequestID); e != nil {
			return e
		}
		if defeated {
			source, e := addFact(ctx, tx, *c, "wolf-defeated", "wolf-defeated")
			if e != nil {
				return e
			}
			if has(*c, "orin-briefed") {
				return completeRoute(ctx, tx, *c, "forest-observation", "orin", source)
			}
		}
		return nil
	case "collect":
		if c.HP <= 0 || c.Encounter == nil || in.TargetID != c.Encounter.ID || c.Encounter.Phase != "defeated" || c.Encounter.Collected {
			return ErrInvalid
		}
		if _, e := tx.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,'corruption-sample',1)`, c.ID); e != nil {
			return e
		}
		if _, e := tx.Exec(ctx, `update game.encounters set collected=true,version=version+1 where id=$1`, c.Encounter.ID); e != nil {
			return e
		}
		source, e := addFact(ctx, tx, *c, "evidence-collected", "corruption-sample-collected")
		if e != nil {
			return e
		}
		_, e = tx.Exec(ctx, `insert into game.character_opportunities(character_id,opportunity_id,status,source_fact_id) values($1,'forest-sample','available',$2)`, c.ID, source)
		return e
	case "deliver-mira":
		if c.HP <= 0 || in.TargetID != "mira" || c.Inventory["corruption-sample"] != 1 || has(*c, "investigation-confirmed") {
			return ErrInvalid
		}
		if _, e := tx.Exec(ctx, `delete from game.character_inventory where character_id=$1 and item_id='corruption-sample'`, c.ID); e != nil {
			return e
		}
		source, e := addFact(ctx, tx, *c, "investigation-confirmed", "corruption-sample-delivered")
		if e != nil {
			return e
		}
		if e = know(ctx, tx, *c, "mira", source, "delivery"); e != nil {
			return e
		}
		if e = completeRoute(ctx, tx, *c, "forest-sample", "mira", source); e != nil {
			return e
		}
		if _, e = tx.Exec(ctx, `insert into game.scheduled_consequences(character_id,world_id,region_id,action_id,source_fact_id,due_at) values($1,$2,$3,'forest-alert',$4,now()+interval '15 seconds') on conflict do nothing`, c.ID, c.WorldID, c.RegionID, source); e != nil {
			return e
		}
		_, e = tx.Exec(ctx, `insert into game.decision_records(character_id,evaluation_id,revision,policy_id,selected_id,candidates,provider) values($1,$2,$3,'server-forest-v1','forest-alert','["forest-alert","none"]','deterministic')`, c.ID, source, c.Revision)
		return e
	case "tick":
		if in.TargetID != "" {
			return ErrInvalid
		}
		return nil
	default:
		return ErrInvalid
	}
}
func processDue(ctx context.Context, tx pgx.Tx, c Character) error {
	// Locks the shared projection before revalidation; concurrent authors publish a single unique world event.
	var threat bool
	if e := tx.QueryRow(ctx, `select threat from game.world_regions where world_id=$1 and id=$2 for update`, c.WorldID, c.RegionID).Scan(&threat); e != nil {
		return e
	}
	var schedule, source string
	e := tx.QueryRow(ctx, `select id::text,source_fact_id::text from game.scheduled_consequences where character_id=$1 and status='pending' and due_at<=now() and action_id='forest-alert' for update`, c.ID).Scan(&schedule, &source)
	if errors.Is(e, pgx.ErrNoRows) {
		return nil
	}
	if e != nil {
		return e
	}
	var known bool
	if e = tx.QueryRow(ctx, `select exists(select 1 from game.npc_knowledge k join game.character_facts f on f.id=k.fact_id where k.character_id=$1 and k.npc_id='mira' and f.id=$2 and f.kind='investigation-confirmed')`, c.ID, source).Scan(&known); e != nil {
		return e
	}
	status := "cancelled"
	if threat && known {
		if _, e = tx.Exec(ctx, `insert into game.world_events(world_id,region_id,definition_id,author_character_id) values($1,$2,'forest-alert',$3) on conflict(world_id,definition_id) do nothing`, c.WorldID, c.RegionID, c.ID); e != nil {
			return e
		}
		if _, e = tx.Exec(ctx, `update game.world_regions set notice_published=true,version=version+1 where world_id=$1 and id=$2 and not notice_published`, c.WorldID, c.RegionID); e != nil {
			return e
		}
		if _, e = addFact(ctx, tx, c, "notice-published", "notice-published"); e != nil {
			return e
		}
		status = "executed"
	}
	_, e = tx.Exec(ctx, `update game.scheduled_consequences set status=$2,version=version+1 where id=$1`, schedule, status)
	return e
}
