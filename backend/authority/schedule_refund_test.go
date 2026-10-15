package authority

import (
	"github.com/google/uuid"
	"mmorpg/authority/journey"
	"testing"
)

func TestPostgresSharedScheduleRefundIsTransactionalAndIdempotent(t *testing.T) {
	ctx, s, admin, a, b := testDatabase(t)
	cat, e := journey.Load()
	if e != nil {
		t.Fatal(e)
	}
	o, _ := cat.Opportunity("mines-awakening")
	chars := []Character{}
	for _, user := range []string{a, b} {
		c, e := s.Create(ctx, user, CreateCharacter{Version: 1, WorldID: "marco05-expanded", Name: "Scheduled"})
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
		c, e = s.Read(ctx, user, c.ID)
		if e != nil {
			t.Fatal(e)
		}
		c = intent(t, ctx, s, user, c, "complete", o.ID)
		chars = append(chars, c)
	}
	first := intent(t, ctx, s, a, chars[0], "tick", "")
	first = intent(t, ctx, s, a, first, "tick", "")
	if first.Journey.Opportunities[o.ID] != "completed" {
		t.Fatal("first author did not execute schedule")
	}
	second := intent(t, ctx, s, b, chars[1], "tick", "")
	in := Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: second.Revision, Kind: "tick"}
	second, e = s.Apply(ctx, b, second.ID, in)
	if e != nil || second.Journey.Opportunities[o.ID] != "cancelled" {
		t.Fatal("losing schedule not cancelled", e)
	}
	for k, n := range o.Costs {
		if second.Inventory[k] != n {
			t.Fatal("reservation not refunded atomically")
		}
	}
	replay, e := s.Apply(ctx, b, second.ID, in)
	if e != nil || replay.Inventory["stone-core"] != 1 {
		t.Fatal("refund repeated on receipt replay")
	}
	second = intent(t, ctx, s, b, second, "tick", "")
	if second.Inventory["stone-core"] != 1 {
		t.Fatal("refund repeated on later tick")
	}
}
