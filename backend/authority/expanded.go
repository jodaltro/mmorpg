package authority

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
	"strings"

	"github.com/jackc/pgx/v5"
	"mmorpg/authority/journey"
)

func expandedWorld(ctx context.Context, tx pgx.Tx, world string, catalog journey.Catalog) (journey.World, error) {
	w := journey.NewWorld()
	rows, e := tx.Query(ctx, `select definition_id,author_character_id::text from game.world_events where world_id=$1`, world)
	if e != nil {
		return w, e
	}
	defer rows.Close()
	for rows.Next() {
		var id, author string
		if e = rows.Scan(&id, &author); e != nil {
			return w, e
		}
		if o, ok := catalog.Opportunity(id); ok && o.Shared {
			w.Facts[o.Fact] = true
			w.Authors[o.Fact] = author
		}
	}
	return w, rows.Err()
}
func loadExpanded(ctx context.Context, tx pgx.Tx, c *Character) error {
	s := journey.NewState()
	s.Region = c.RegionID
	s.HP = c.HP
	var equipment, cooldowns, pending, encounter []byte
	e := tx.QueryRow(ctx, `select r.step,r.poison,
  coalesce((select jsonb_object_agg(slot,item_id) from game.character_equipment where character_id=r.character_id),'{}'),
  coalesce((select jsonb_object_agg(ability_id,due_step) from game.journey_cooldowns where character_id=r.character_id),'{}'),
  coalesce((select jsonb_object_agg(opportunity_id,due_step) from game.journey_schedules where character_id=r.character_id),'{}'),
  (select to_jsonb(e)-'character_id' from game.journey_encounters e where character_id=r.character_id)
  from game.journey_runtime r where character_id=$1`, c.ID).Scan(&s.Step, &s.Poison, &equipment, &cooldowns, &pending, &encounter)
	if errors.Is(e, pgx.ErrNoRows) {
		if c.Ruleset == "expanded-v1" {
			return ErrUnavailable
		}
		return nil
	}
	if e != nil {
		return e
	}
	for _, v := range []struct {
		b   []byte
		dst any
	}{{equipment, &s.Equipment}, {cooldowns, &s.Cooldowns}, {pending, &s.Pending}} {
		if e = json.Unmarshal(v.b, v.dst); e != nil {
			return e
		}
	}
	if len(encounter) > 0 {
		if e = json.Unmarshal(encounter, &s.Encounter); e != nil {
			return e
		}
	}
	s.Inventory = map[string]int{}
	for k, v := range c.Inventory {
		s.Inventory[k] = v
	}
	for _, a := range c.Abilities {
		s.Abilities[a] = true
	}
	idKeys := map[string]string{}
	s.Facts = map[string]bool{}
	for _, f := range c.Facts {
		if strings.HasPrefix(f.SemanticKey, "j:") {
			key := strings.TrimPrefix(f.SemanticKey, "j:")
			s.Facts[key] = true
			idKeys[f.ID] = key
		}
	}
	for _, k := range c.Knowledge {
		if key := idKeys[k.FactID]; key != "" {
			s.Knowledge[k.NPCID] = append(s.Knowledge[k.NPCID], key)
		}
	}
	for k, v := range c.Relationships {
		s.Relationships[k] = v
	}
	for k, v := range c.Opportunities {
		s.Opportunities[k] = v
	}
	catalog, e := journey.Load()
	if e != nil {
		return e
	}
	w, e := expandedWorld(ctx, tx, c.WorldID, catalog)
	if e != nil {
		return e
	}
	catalog.Refresh(&s, w)
	c.Journey = &s
	c.Actions = catalog.LegalActions(s, w)
	return nil
}
func applyExpanded(ctx context.Context, tx pgx.Tx, c *Character, in Intent) error {
	catalog, e := journey.Load()
	if e != nil {
		return e
	}
	// Test-world prototype serializes world consequences across characters/processes.
	// Lock + UNIQUE prevents a simultaneous ritual from consuming a losing actor's materials.
	if _, e = tx.Exec(ctx, `select pg_advisory_xact_lock(hashtextextended($1,0))`, c.WorldID); e != nil {
		return e
	}
	w, e := expandedWorld(ctx, tx, c.WorldID, catalog)
	if e != nil {
		return e
	}
	change, e := catalog.Step(*c.Journey, w, c.ID, journey.Action{Kind: in.Kind, Target: in.TargetID})
	if e != nil {
		if errors.Is(e, journey.ErrIntent) {
			return ErrInvalid
		}
		return e
	}
	n := change.State
	source, e := addFact(ctx, tx, *c, "journey-command", "command:"+in.RequestID)
	if e != nil {
		return e
	}
	for _, key := range change.NewFacts {
		if _, e = addFact(ctx, tx, *c, "journey-fact", "j:"+key); e != nil {
			return e
		}
	}
	// Normalize projections. Historical facts/outbox/decisions remain append-only.
	for k := range c.Inventory {
		if n.Inventory[k] == 0 {
			if _, e = tx.Exec(ctx, `delete from game.character_inventory where character_id=$1 and item_id=$2`, c.ID, k); e != nil {
				return e
			}
		}
	}
	for k, v := range n.Inventory {
		if c.Inventory[k] == v {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,$2,$3) on conflict(character_id,item_id) do update set quantity=excluded.quantity,version=game.character_inventory.version+1`, c.ID, k, v); e != nil {
			return e
		}
	}
	for k := range n.Abilities {
		if slices.Contains(c.Abilities, k) {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.character_abilities(character_id,ability_id,source_fact_id) values($1,$2,$3) on conflict do nothing`, c.ID, k, source); e != nil {
			return e
		}
	}
	for slot, item := range n.Equipment {
		if c.Journey.Equipment[slot] == item {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.character_equipment(character_id,slot,item_id) values($1,$2,$3) on conflict(character_id,slot) do update set item_id=excluded.item_id,version=game.character_equipment.version+1`, c.ID, slot, item); e != nil {
			return e
		}
	}
	for k, v := range c.Opportunities {
		if v == "available" && n.Opportunities[k] == "" {
			if _, e = tx.Exec(ctx, `update game.character_opportunities set status='closed',version=version+1 where character_id=$1 and opportunity_id=$2`, c.ID, k); e != nil {
				return e
			}
		}
	}
	for k, v := range n.Opportunities {
		if c.Opportunities[k] == v {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.character_opportunities(character_id,opportunity_id,status,source_fact_id) values($1,$2,$3,$4) on conflict(character_id,opportunity_id) do update set status=excluded.status,version=game.character_opportunities.version+1`, c.ID, k, v, source); e != nil {
			return e
		}
	}
	for npc, v := range n.Relationships {
		if c.Relationships[npc] == v {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.npc_relationships(character_id,npc_id,trust) values($1,$2,$3) on conflict(character_id,npc_id) do update set trust=excluded.trust,version=game.npc_relationships.version+1`, c.ID, npc, v); e != nil {
			return e
		}
	}
	for npc, keys := range n.Knowledge {
		for _, key := range keys {
			if slices.Contains(c.Journey.Knowledge[npc], key) {
				continue
			}
			if e = know(ctx, tx, *c, npc, factID(*c, "j:"+key), "conversation"); e != nil {
				return e
			}
		}
	}
	if _, e = tx.Exec(ctx, `update game.journey_runtime set step=$2,poison=$3,version=version+1 where character_id=$1`, c.ID, n.Step, n.Poison); e != nil {
		return e
	}
	for id, due := range n.Cooldowns {
		if c.Journey.Cooldowns[id] == due {
			continue
		}
		if _, e = tx.Exec(ctx, `insert into game.journey_cooldowns(character_id,ability_id,due_step) values($1,$2,$3) on conflict(character_id,ability_id) do update set due_step=excluded.due_step`, c.ID, id, due); e != nil {
			return e
		}
	}
	for id := range c.Journey.Pending {
		if n.Pending[id] == 0 {
			if _, e = tx.Exec(ctx, `delete from game.journey_schedules where character_id=$1 and opportunity_id=$2`, c.ID, id); e != nil {
				return e
			}
		}
	}
	for id, due := range n.Pending {
		if _, e = tx.Exec(ctx, `insert into game.journey_schedules(character_id,opportunity_id,due_step) values($1,$2,$3) on conflict do nothing`, c.ID, id, due); e != nil {
			return e
		}
	}
	if x := n.Encounter; x != nil {
		if _, e = tx.Exec(ctx, `insert into game.journey_encounters(character_id,creature,hp,turn,phase,range,fractured,marked,burn,defended,collected) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) on conflict(character_id) do update set creature=excluded.creature,hp=excluded.hp,turn=excluded.turn,phase=excluded.phase,range=excluded.range,fractured=excluded.fractured,marked=excluded.marked,burn=excluded.burn,defended=excluded.defended,collected=excluded.collected`, c.ID, x.Creature, x.HP, x.Turn, x.Phase, x.Range, x.Fractured, x.Marked, x.Burn, x.Defended, x.Collected); e != nil {
			return e
		}
	}
	for _, id := range change.NewEvents {
		o, _ := catalog.Opportunity(id)
		if _, e = tx.Exec(ctx, `insert into game.world_events(world_id,region_id,definition_id,author_character_id,payload) values($1,$2,$3,$4,jsonb_build_object('fact',$5::text))`, c.WorldID, o.Region, id, c.ID, o.Fact); e != nil {
			return e
		}
		if _, e = tx.Exec(ctx, `update game.world_regions set version=version+1,notice_published=true,threat=false where world_id=$1 and id=$2`, c.WorldID, o.Region); e != nil {
			return e
		}
	}
	candidates, _ := json.Marshal(change.Candidates)
	if _, e = tx.Exec(ctx, `insert into game.decision_records(character_id,evaluation_id,revision,policy_id,selected_id,candidates,provider) values($1,$2,$3,'expanded-world-v1',$4,$5,'deterministic')`, c.ID, in.RequestID, c.Revision, in.Kind+":"+in.TargetID, candidates); e != nil {
		return e
	}
	c.RegionID = n.Region
	c.HP = n.HP
	c.Journey = &n
	return nil
}
