package authority

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// This fixture uses real PostgreSQL. A minimal auth.users fixture is explicitly NOT Supabase Auth.
// It refuses remote hosts and creates/drops only its randomly named disposable database.
func testDatabase(t *testing.T) (context.Context, *Store, *pgx.Conn, string, string) {
	t.Helper()
	raw := os.Getenv("TEST_DATABASE_URL")
	if raw == "" {
		t.Skip("TEST_DATABASE_URL absent; real PostgreSQL integration not executed")
	}
	u, e := url.Parse(raw)
	if e != nil || u.Scheme != "postgres" && u.Scheme != "postgresql" || u.Hostname() != "127.0.0.1" || u.Path != "/postgres" || u.Port() == "" {
		t.Fatal("test fixture only accepts loopback /postgres admin connection")
	}
	ctx := context.Background()
	admin, e := pgx.Connect(ctx, raw)
	if e != nil {
		t.Fatal("local PostgreSQL unavailable")
	}
	suffix := strings.ReplaceAll(uuid.NewString(), "-", "")
	database := "mmorpg_test_" + suffix
	login := "mmorpg_test_role_" + suffix
	if _, e = admin.Exec(ctx, `create database `+pgx.Identifier{database}.Sanitize()); e != nil {
		admin.Close(ctx)
		t.Fatal("cannot create disposable database")
	}
	admin.Close(ctx)
	u.Path = "/" + database
	admin, e = pgx.Connect(ctx, u.String())
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() {
		admin.Close(ctx)
		maintenance, _ := pgx.Connect(ctx, raw)
		if maintenance != nil {
			defer maintenance.Close(ctx)
			_, _ = maintenance.Exec(ctx, `drop database `+pgx.Identifier{database}.Sanitize()+` with(force)`)
			_, _ = maintenance.Exec(ctx, `drop role if exists `+pgx.Identifier{login}.Sanitize())
		}
	})
	bootstrap := `do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if; if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if; if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if; end $$; create schema auth; create table auth.users(id uuid primary key);`
	if _, e = admin.Exec(ctx, bootstrap); e != nil {
		t.Fatal(e)
	}
	migrations, e := filepath.Glob("../../supabase/migrations/*.sql")
	if e != nil || len(migrations) == 0 {
		t.Fatal("no migrations")
	}
	for _, path := range migrations {
		b, e := os.ReadFile(path)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = admin.Exec(ctx, string(b)); e != nil {
			t.Fatalf("migration %s: %v", filepath.Base(path), e)
		}
	}
	seed, e := os.ReadFile("../../supabase/seed.sql")
	if e != nil {
		t.Fatal(e)
	}
	for i := 0; i < 2; i++ {
		if _, e = admin.Exec(ctx, string(seed)); e != nil {
			t.Fatal(e)
		}
	}
	a, b := uuid.NewString(), uuid.NewString()
	if _, e = admin.Exec(ctx, `insert into auth.users(id) values($1),($2)`, a, b); e != nil {
		t.Fatal(e)
	}
	if _, e = admin.Exec(ctx, `create role `+pgx.Identifier{login}.Sanitize()+` login noinherit nosuperuser nocreaterole nocreatedb nobypassrls; grant game_backend to `+pgx.Identifier{login}.Sanitize()); e != nil {
		t.Fatal(e)
	}
	cfg, e := pgxpool.ParseConfig(u.String())
	if e != nil {
		t.Fatal(e)
	}
	cfg.ConnConfig.User = login
	cfg.ConnConfig.Password = ""
	pool, e := pgxpool.NewWithConfig(ctx, cfg)
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(pool.Close)
	s := &Store{Pool: pool, EnableDevImport: true}
	if s.CheckRole(ctx) != nil {
		t.Fatal("limited backend role check failed")
	}
	return ctx, s, admin, a, b
}
func create(t *testing.T, ctx context.Context, s *Store, user string) Character {
	t.Helper()
	c, e := s.Create(ctx, user, CreateCharacter{Version: 1, WorldID: "marco05-dev", Name: "test"})
	if e != nil {
		t.Fatal(e)
	}
	return c
}
func intent(t *testing.T, ctx context.Context, s *Store, user string, c Character, kind, target string) Character {
	t.Helper()
	n, e := s.Apply(ctx, user, c.ID, Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: c.Revision, Kind: kind, TargetID: target})
	if e != nil {
		t.Fatalf("%s: %v", kind, e)
	}
	return n
}
func defeat(t *testing.T, ctx context.Context, s *Store, user string, c Character) Character {
	t.Helper()
	c = intent(t, ctx, s, user, c, "start-encounter", "corrupted-wolf")
	for i := 0; i < 3; i++ {
		c = intent(t, ctx, s, user, c, "attack", c.Encounter.ID)
		if i < 2 {
			c = intent(t, ctx, s, user, c, "dodge", c.Encounter.ID)
		}
	}
	return c
}

func TestPostgresIsolationTransactionsAndReplay(t *testing.T) {
	ctx, s, admin, a, b := testDatabase(t)
	ca, cb := create(t, ctx, s, a), create(t, ctx, s, b)
	t.Run("owner-isolation", func(t *testing.T) {
		if _, e := s.Read(ctx, b, ca.ID); e != ErrNotFound {
			t.Fatal("other character disclosed")
		}
		if _, e := s.Apply(ctx, b, ca.ID, Intent{Version: 1, RequestID: uuid.NewString(), Kind: "tick"}); e != ErrNotFound {
			t.Fatal("other character changed")
		}
		ids, e := s.List(ctx, b)
		if e != nil || len(ids) != 1 || ids[0] != cb.ID {
			t.Fatal("list leaked")
		}
	})
	t.Run("data-api-denied", func(t *testing.T) {
		var tables []string
		rows, e := admin.Query(ctx, `select tablename from pg_tables where schemaname='game' order by tablename`)
		if e != nil {
			t.Fatal(e)
		}
		for rows.Next() {
			var name string
			_ = rows.Scan(&name)
			tables = append(tables, name)
		}
		rows.Close()
		for _, role := range []string{"anon", "authenticated", "service_role"} {
			for _, table := range tables {
				tx, e := admin.Begin(ctx)
				if e != nil {
					t.Fatal(e)
				}
				_, e = tx.Exec(ctx, `set local role `+pgx.Identifier{role}.Sanitize())
				if e == nil {
					_, e = tx.Exec(ctx, `select * from game.`+pgx.Identifier{table}.Sanitize())
				}
				_ = tx.Rollback(ctx)
				var denied *pgconn.PgError
				if !errors.As(e, &denied) || denied.Code != "42501" {
					t.Fatalf("expected permission denial: %s read %s: %v", role, table, e)
				}
			}
		}
	})
	t.Run("rls-defense-in-depth", func(t *testing.T) {
		tx, e := s.begin(ctx, b)
		if e != nil {
			t.Fatal(e)
		}
		defer tx.Rollback(ctx)
		var n int
		if e = tx.QueryRow(ctx, `select count(*) from game.characters where id=$1`, ca.ID).Scan(&n); e != nil || n != 0 {
			t.Fatal("RLS leak")
		}
		if _, e = tx.Exec(ctx, `insert into game.character_inventory(character_id,item_id,quantity) values($1,'corruption-sample',1)`, ca.ID); e == nil {
			t.Fatal("cross owner inventory write")
		}
	})
	t.Run("client-defeat-rejected", func(t *testing.T) {
		if _, e := s.Apply(ctx, a, ca.ID, Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: ca.Revision, Kind: "CreatureDefeated", TargetID: "corrupted-wolf"}); e != ErrInvalid {
			t.Fatal("untrusted reward accepted")
		}
	})
	ca = defeat(t, ctx, s, a, ca)
	ca = intent(t, ctx, s, a, ca, "collect", ca.Encounter.ID)
	t.Run("integrity-constraints", func(t *testing.T) {
		for _, q := range []string{`update game.character_inventory set quantity=-1 where character_id=$1`, `insert into game.character_inventory(character_id,item_id,quantity) values($1,'unknown',1)`, `insert into game.character_abilities(character_id,ability_id,source_fact_id) values($1,'unknown',gen_random_uuid())`} {
			tx, e := s.begin(ctx, a)
			if e != nil {
				t.Fatal(e)
			}
			_, e = tx.Exec(ctx, q, ca.ID)
			tx.Rollback(ctx)
			if e == nil {
				t.Fatal("invalid projection accepted")
			}
		}
	})
	t.Run("rollback-all-consequences", func(t *testing.T) {
		before, e := s.Read(ctx, a, ca.ID)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = admin.Exec(ctx, `create function game.test_fail_ability() returns trigger language plpgsql as $$begin raise exception 'injected test failure'; end$$; create trigger fail_ability before insert on game.character_abilities for each row execute function game.test_fail_ability()`); e != nil {
			t.Fatal(e)
		}
		_, e = s.Apply(ctx, a, ca.ID, Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: ca.Revision, Kind: "deliver-mira", TargetID: "mira"})
		if e == nil {
			t.Fatal("injected storage failure ignored")
		}
		after, e := s.Read(ctx, a, ca.ID)
		if e != nil || !reflect.DeepEqual(before, after) {
			t.Fatal("partial transaction committed")
		}
		_, e = admin.Exec(ctx, `drop trigger fail_ability on game.character_abilities; drop function game.test_fail_ability()`)
		if e != nil {
			t.Fatal(e)
		}
	})
	request := Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: ca.Revision, Kind: "deliver-mira", TargetID: "mira"}
	var err error
	ca, err = s.Apply(ctx, a, ca.ID, request)
	if err != nil {
		t.Fatal(err)
	}
	t.Run("persisted-replay-and-conflict", func(t *testing.T) {
		restart := &Store{Pool: s.Pool}
		again, e := restart.Apply(ctx, a, ca.ID, request)
		if e != nil || !reflect.DeepEqual(ca, again) {
			t.Fatal("replay changed")
		}
		changed := request
		changed.Kind = "collect"
		if _, e = s.Apply(ctx, a, ca.ID, changed); e != ErrConflict {
			t.Fatal("changed request accepted")
		}
		if ca.Inventory["corruption-sample"] != 0 || len(ca.Abilities) != 1 || ca.Relationships["mira"] != 1 || ca.Opportunities["forest-sample"] != "completed" {
			t.Fatal("incomplete projection")
		}
		other, e := s.Read(ctx, b, cb.ID)
		if e != nil || len(other.Facts) != 0 || len(other.Inventory) != 0 || len(other.Knowledge) != 0 {
			t.Fatal("private state leaked")
		}
	})
	t.Run("shared-region-unique-schedule", func(t *testing.T) {
		cb = defeat(t, ctx, s, b, cb)
		cb = intent(t, ctx, s, b, cb, "collect", cb.Encounter.ID)
		cb = intent(t, ctx, s, b, cb, "deliver-mira", "mira")
		if _, e := admin.Exec(ctx, `update game.scheduled_consequences set due_at=now()-interval '1 second'`); e != nil {
			t.Fatal(e)
		}
		var wg sync.WaitGroup
		errs := make(chan error, 2)
		for _, p := range []struct {
			user string
			c    Character
		}{{a, ca}, {b, cb}} {
			wg.Add(1)
			go func(user string, c Character) {
				defer wg.Done()
				_, e := s.Apply(ctx, user, c.ID, Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: c.Revision, Kind: "tick"})
				errs <- e
			}(p.user, p.c)
		}
		wg.Wait()
		close(errs)
		for e := range errs {
			if e != nil {
				t.Fatal(e)
			}
		}
		ra, e := s.ReadRegion(ctx, a, "marco05-dev", "gray-forest")
		rb, e2 := s.ReadRegion(ctx, b, "marco05-dev", "gray-forest")
		if e != nil || e2 != nil || !ra.NoticePublished || ra != rb {
			t.Fatal("shared projection")
		}
		var n int
		_ = admin.QueryRow(ctx, `select count(*) from game.world_events`).Scan(&n)
		if n != 1 {
			t.Fatal("duplicate historical event")
		}
		_ = admin.QueryRow(ctx, `select count(*) from game.scheduled_consequences where status='executed'`).Scan(&n)
		if n != 2 {
			t.Fatal("schedule not recorded")
		}
	})
	t.Run("concurrent-command-once", func(t *testing.T) {
		current, e := s.Read(ctx, a, ca.ID)
		if e != nil {
			t.Fatal(e)
		}
		req := Intent{Version: 1, RequestID: uuid.NewString(), ExpectedRevision: current.Revision, Kind: "tick"}
		results := make(chan Character, 8)
		errs := make(chan error, 8)
		var wg sync.WaitGroup
		for i := 0; i < 8; i++ {
			wg.Add(1)
			go func() { defer wg.Done(); c, e := s.Apply(ctx, a, current.ID, req); results <- c; errs <- e }()
		}
		wg.Wait()
		close(results)
		close(errs)
		for e := range errs {
			if e != nil {
				t.Fatal(e)
			}
		}
		for c := range results {
			if c.Revision != current.Revision+1 {
				t.Fatal("duplicated application")
			}
		}
	})
	t.Run("outbox-idempotence", func(t *testing.T) {
		var facts, outbox int
		_ = admin.QueryRow(ctx, `select count(*) from game.character_facts`).Scan(&facts)
		_ = admin.QueryRow(ctx, `select count(*) from game.event_outbox`).Scan(&outbox)
		if facts != outbox {
			t.Fatal("missing/duplicate outbox")
		}
	})
}
func TestPostgresAlternativeJourneyAndExplicitDevelopmentImport(t *testing.T) {
	ctx, s, admin, a, _ := testDatabase(t)
	c := create(t, ctx, s, a)
	c = intent(t, ctx, s, a, c, "examine-tracks", "corrupted-tracks")
	c = intent(t, ctx, s, a, c, "brief-orin", "orin")
	c = defeat(t, ctx, s, a, c)
	if len(c.Abilities) != 1 || c.Relationships["orin"] != 1 || c.Opportunities["forest-observation"] != "completed" || len(c.Inventory) != 0 {
		t.Fatal("alternative route requires delivery")
	}
	in := DevelopmentImport{Version: 1, WorldID: "marco05-dev", Name: "import", SourceVersion: 3, SourceActor: "player", SourceWorld: "offline-clearing", SourceChecksum: base64.StdEncoding.EncodeToString(make([]byte, 32)), Facts: []ImportFact{{ID: "trace", Kind: "TraceExamined", Payload: json.RawMessage(`{"version":1}`)}}, Knowledge: []ImportKnowledge{{NPCID: "orin", FactID: "trace"}}, Abilities: []string{"weakness-reading"}, Inventory: map[string]int{"corruption-sample": 1}, Relationships: map[string]int{"orin": 1}, Opportunities: map[string]string{"forest-observation": "completed"}}
	imported, e := s.Import(ctx, a, in)
	if e != nil {
		t.Fatal(e)
	}
	if imported.Provenance != "offline-import" || imported.Inventory["corruption-sample"] != 1 || len(imported.Abilities) != 1 || len(imported.Knowledge) != 1 {
		t.Fatal("lost import state")
	}
	again, e := s.Import(ctx, a, in)
	if e != nil || !reflect.DeepEqual(imported, again) {
		t.Fatal("duplicate import")
	}
	changed := in
	changed.Name = "different"
	if _, e = s.Import(ctx, a, changed); e != ErrConflict {
		t.Fatal("import replacement accepted")
	}
	disabled := &Store{Pool: s.Pool}
	if _, e = disabled.Import(ctx, a, in); e != ErrNotFound {
		t.Fatal("implicit import")
	}
	_, e = admin.Exec(ctx, `insert into game.worlds(id,name,is_test) values('trusted','trusted',false);insert into game.world_regions(world_id,id,name) values('trusted','gray-forest','forest')`)
	if e != nil {
		t.Fatal(e)
	}
	in.WorldID = "trusted"
	if _, e = s.Import(ctx, a, in); e != ErrInvalid {
		t.Fatal("offline data promoted to trusted world")
	}
}

func TestPostgresUnityExportFixtures(t *testing.T) {
	root := os.Getenv("UNITY_IMPORT_FIXTURES")
	if root == "" {
		t.Skip("Editor-generated v1/v2/v3 fixture exports not supplied")
	}
	ctx, s, _, user, _ := testDatabase(t)
	for version := 1; version <= 3; version++ {
		t.Run(fmt.Sprintf("v%d", version), func(t *testing.T) {
			b, e := os.ReadFile(filepath.Join(root, fmt.Sprintf("v%d-import.json", version)))
			if e != nil {
				t.Fatal(e)
			}
			var in DevelopmentImport
			d := json.NewDecoder(bytes.NewReader(b))
			d.DisallowUnknownFields()
			if d.Decode(&in) != nil || in.SourceVersion != version {
				t.Fatal("C# export contract mismatch")
			}
			c, e := s.Import(ctx, user, in)
			if e != nil {
				t.Fatal(e)
			}
			if len(c.Abilities) != 1 || c.Relationships["mira"] != 1 || c.Opportunities["forest-sample"] != "completed" || c.Provenance != "offline-import" {
				t.Fatal("C# export projection lost")
			}
			if len(c.Facts) != len(in.Facts)+1 {
				t.Fatal("lost archive records")
			}
		})
	}
}
