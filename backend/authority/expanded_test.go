package authority

import (
	"errors"
	"github.com/google/uuid"
	"mmorpg/authority/journey"
	"sync"
	"testing"
)

func TestExpandedPersistentDiscoveryEquipmentAndIsolation(t *testing.T) {
	ctx, s, admin, a, b := testDatabase(t)
	ca, e := s.Create(ctx, a, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Explorer"})
	if e != nil || ca.Journey == nil {
		t.Fatalf("expanded creation: %v", e)
	}
	cb, e := s.Create(ctx, b, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Collector"})
	if e != nil {
		t.Fatal(e)
	}
	ca = intent(t, ctx, s, a, ca, "travel", "gray-forest")
	ca = intent(t, ctx, s, a, ca, "gather", "forest-tracks")
	ca = intent(t, ctx, s, a, ca, "talk", "orin")
	ca = intent(t, ctx, s, a, ca, "complete", "hunter-mark-training")
	if !ca.Journey.Abilities["hunter-mark"] || ca.Relationships["orin"] != 2 {
		t.Fatal("ability/relationship not persisted")
	}
	ca = intent(t, ctx, s, a, ca, "travel", "echo-marsh")
	ca = intent(t, ctx, s, a, ca, "gather", "marsh-memory")
	ca = intent(t, ctx, s, a, ca, "talk", "ivo")
	ca = intent(t, ctx, s, a, ca, "complete", "silent-marsh-route")
	ca = intent(t, ctx, s, a, ca, "travel", "asterion")
	ca = intent(t, ctx, s, a, ca, "gather", "ruins-inscription")
	ca = intent(t, ctx, s, a, ca, "talk", "enya")
	ca = intent(t, ctx, s, a, ca, "complete", "ancestral-study")
	ca = intent(t, ctx, s, a, ca, "gather", "ancestral-glyph")
	ca = intent(t, ctx, s, a, ca, "travel", "kharum")
	ca = intent(t, ctx, s, a, ca, "talk", "dorin")
	ca = intent(t, ctx, s, a, ca, "complete", "mining-tools")
	ca = intent(t, ctx, s, a, ca, "equip", "mining-pick")
	ca = intent(t, ctx, s, a, ca, "gather", "iron-vein")
	ca = intent(t, ctx, s, a, ca, "complete", "fracture-training")
	reloaded, e := s.Read(ctx, a, ca.ID)
	if e != nil || reloaded.Journey.Equipment["tool"] != "mining-pick" || !reloaded.Journey.Abilities["ancestral-sense"] || reloaded.Inventory["asterion-glyph"] != 2 || reloaded.Inventory["iron-ore"] != 5 {
		t.Fatalf("normalized state not durable: %v", e)
	}
	if _, e = s.Read(ctx, b, ca.ID); !errors.Is(e, ErrNotFound) {
		t.Fatal("cross-owner read accepted")
	}
	other, e := s.Read(ctx, b, cb.ID)
	if e != nil || len(other.Abilities) > 0 || len(other.Inventory) > 0 || len(other.Knowledge) > 0 {
		t.Fatal("expanded privacy leaked")
	}
	tx, e := s.begin(ctx, b)
	if e != nil {
		t.Fatal(e)
	}
	defer tx.Rollback(ctx)
	var rows int
	if tx.QueryRow(ctx, `select count(*) from game.journey_runtime where character_id=$1`, ca.ID).Scan(&rows) != nil || rows != 0 {
		t.Fatal("new-table RLS bypass")
	}
	var protected int
	if admin.QueryRow(ctx, `select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and relkind='r' and relrowsecurity and relforcerowsecurity`).Scan(&protected) != nil || protected != 23 {
		t.Fatal("new tables not protected")
	}
}
func TestExpandedHistoricalRaceRollbackAndReplay(t *testing.T) {
	ctx, s, admin, a, b := testDatabase(t)
	cat, e := journey.Load()
	if e != nil {
		t.Fatal(e)
	}
	o, _ := cat.Opportunity("asterion-beacon")
	chars := []Character{}
	for _, user := range []string{a, b} {
		c, e := s.Create(ctx, user, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Ritual"})
		if e != nil {
			t.Fatal(e)
		}
		if _, e = admin.Exec(ctx, `update game.characters set region_id='asterion' where id=$1`, c.ID); e != nil {
			t.Fatal(e)
		}
		for _, f := range o.Requires {
			if _, e = admin.Exec(ctx, `insert into game.character_facts(id,character_id,kind,semantic_key) values($1,$2,'journey-fact',$3) on conflict do nothing`, factID(c, "j:"+f), c.ID, "j:"+f); e != nil {
				t.Fatal(e)
			}
		}
		for k, n := range o.Costs {
			if _, e = admin.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,$2,$3)`, c.ID, k, n); e != nil {
				t.Fatal(e)
			}
		}
		c, e = s.Read(ctx, user, c.ID)
		if e != nil {
			t.Fatal(e)
		}
		chars = append(chars, c)
	}
	inputs := []Intent{{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: 0, Kind: "complete", TargetID: o.ID}, {Version: 1, RequestID: uuid.NewString(), ExpectedRevision: 0, Kind: "complete", TargetID: o.ID}}
	results := make([]Character, 2)
	errs := make([]error, 2)
	var wg sync.WaitGroup
	for i, user := range []string{a, b} {
		wg.Add(1)
		go func(i int, user string) {
			defer wg.Done()
			results[i], errs[i] = s.Apply(ctx, user, chars[i].ID, inputs[i])
		}(i, user)
	}
	wg.Wait()
	winner, loser := -1, -1
	for i, e := range errs {
		if e == nil {
			winner = i
		} else if errors.Is(e, ErrInvalid) {
			loser = i
		} else {
			t.Fatalf("unexpected race result: %v", e)
		}
	}
	if winner < 0 || loser < 0 {
		t.Fatal("ritual must have exactly one author")
	}
	users := []string{a, b}
	replay, e := s.Apply(ctx, users[winner], chars[winner].ID, inputs[winner])
	if e != nil || replay.Revision != results[winner].Revision {
		t.Fatal("historical receipt replay failed")
	}
	after, e := s.Read(ctx, users[loser], chars[loser].ID)
	if e != nil || after.Revision != 0 || after.Inventory["asterion-glyph"] != 1 {
		t.Fatal("loser resources consumed")
	}
	var count int
	var author string
	if admin.QueryRow(ctx, `select count(*),min(author_character_id::text) from game.world_events where world_id='marco05-expanded' and definition_id='asterion-beacon'`).Scan(&count, &author) != nil || count != 1 || author != chars[winner].ID {
		t.Fatal("unique world authorship violated")
	}
	// Shared beacon opens a route for the other character, without copying private discoveries.
	after = intent(t, ctx, s, users[loser], after, "talk", "enya")
	after = intent(t, ctx, s, users[loser], after, "complete", "beacon-attunement")
	if !after.Journey.Abilities["ancestral-sense"] {
		t.Fatal("shared historical consequence unavailable")
	}
}
func TestExpandedScheduleFollowsSourcedRegionAfterTravel(t *testing.T) {
	ctx, s, admin, a, b := testDatabase(t)
	cat, e := journey.Load()
	if e != nil {
		t.Fatal(e)
	}
	o, _ := cat.Opportunity("mines-awakening")
	c, e := s.Create(ctx, a, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Miner"})
	if e != nil {
		t.Fatal(e)
	}
	if _, e = admin.Exec(ctx, `update game.characters set region_id='kharum' where id=$1`, c.ID); e != nil {
		t.Fatal(e)
	}
	for _, f := range o.Requires {
		if _, e = admin.Exec(ctx, `insert into game.character_facts(id,character_id,kind,semantic_key) values($1,$2,'journey-fact',$3)`, factID(c, "j:"+f), c.ID, "j:"+f); e != nil {
			t.Fatal(e)
		}
	}
	for k, n := range o.Costs {
		if _, e = admin.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,$2,$3)`, c.ID, k, n); e != nil {
			t.Fatal(e)
		}
	}
	c, e = s.Read(ctx, a, c.ID)
	if e != nil {
		t.Fatal(e)
	}
	c = intent(t, ctx, s, a, c, "complete", o.ID)
	c = intent(t, ctx, s, a, c, "travel", "valdoria")
	c = intent(t, ctx, s, a, c, "tick", "")
	if c.Journey.Opportunities[o.ID] != "completed" {
		t.Fatal("schedule did not persist")
	}
	region, e := s.ReadRegion(ctx, b, c.WorldID, "kharum")
	if e != nil || region.Threat || !region.NoticePublished {
		t.Fatal("sourced regional projection did not follow schedule")
	}
	other, e := s.Create(ctx, b, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Private"})
	if e != nil {
		t.Fatal(e)
	}
	tx, e := s.begin(ctx, b)
	if e != nil {
		t.Fatal(e)
	}
	defer tx.Rollback(ctx)
	tag, e := tx.Exec(ctx, `update game.world_regions set threat=true where world_id=$1 and id='asterion'`, other.WorldID)
	if e != nil || tag.RowsAffected() != 0 {
		t.Fatal("unrelated regional update permitted")
	}
}
func TestExpandedMissingRuntimeFailsClosed(t *testing.T) {
	ctx, s, admin, a, _ := testDatabase(t)
	c, e := s.Create(ctx, a, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Integrity"})
	if e != nil {
		t.Fatal(e)
	}
	if _, e = admin.Exec(ctx, `delete from game.journey_runtime where character_id=$1`, c.ID); e != nil {
		t.Fatal(e)
	}
	if _, e = s.Read(ctx, a, c.ID); !errors.Is(e, ErrUnavailable) {
		t.Fatal("corrupt expansion silently fell back to old authority")
	}
}
