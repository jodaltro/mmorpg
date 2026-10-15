// Admin diagnostics restricted to the two explicitly configured test users and rollback-only SQL assertions.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
	authority "mmorpg/authority"
)

func main() {
	runtime := flag.String("env-file", ".env", "Runtime config")
	migration := flag.String("migration-env", ".env.migrations", "Explicit admin config")
	flag.Parse()
	out := map[string]any{"credentialsPrinted": false}
	emit := func() { _ = json.NewEncoder(os.Stdout).Encode(out) }
	if authority.LoadEnvironmentFile(*runtime) != nil {
		out["error"] = "runtime_configuration_unavailable"
		emit()
		return
	}
	contents, e := os.ReadFile(*migration)
	if e != nil {
		out["error"] = "admin_configuration_unavailable"
		emit()
		return
	}
	raw := ""
	for _, line := range strings.Split(string(contents), "\n") {
		if strings.HasPrefix(line, "DATABASE_URL=") {
			raw = strings.TrimSpace(strings.TrimPrefix(line, "DATABASE_URL="))
		}
	}
	cfg, e := pgx.ParseConfig(raw)
	if e != nil || cfg.TLSConfig == nil || cfg.TLSConfig.InsecureSkipVerify {
		out["error"] = "verified_admin_tls_required"
		emit()
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	conn, e := pgx.ConnectConfig(ctx, cfg)
	if e != nil {
		out["error"] = "admin_connection_unavailable"
		emit()
		return
	}
	defer conn.Close(ctx)
	users := []map[string]any{}
	var canInsertUsers, canInsertIdentities bool
	if conn.QueryRow(ctx, `select has_table_privilege(current_user,'auth.users','INSERT'),has_table_privilege(current_user,'auth.identities','INSERT')`).Scan(&canInsertUsers, &canInsertIdentities) == nil {
		out["authUsersInsertPermitted"] = canInsertUsers
		out["authIdentitiesInsertPermitted"] = canInsertIdentities
	}
	for _, label := range []string{"A", "B"} {
		entry := map[string]any{"label": label}
		var encrypted string
		var confirmed bool
		e = conn.QueryRow(ctx, `select coalesce(encrypted_password,''),email_confirmed_at is not null from auth.users where email=$1`, os.Getenv("SUPABASE_TEST_EMAIL_"+label)).Scan(&encrypted, &confirmed)
		entry["exists"] = e == nil
		if e != nil && !errors.Is(e, pgx.ErrNoRows) {
			var pgError *pgconn.PgError
			if errors.As(e, &pgError) {
				entry["lookupErrorCode"] = pgError.Code
			} else {
				entry["lookupErrorCode"] = "unavailable"
			}
		}
		if e == nil {
			entry["emailConfirmed"] = confirmed
			entry["passwordConfigured"] = encrypted != ""
			entry["passwordMatchesLocalConfiguration"] = encrypted != "" && bcrypt.CompareHashAndPassword([]byte(encrypted), []byte(os.Getenv("SUPABASE_TEST_PASSWORD_"+label))) == nil
		}
		users = append(users, entry)
	}
	out["testUsers"] = users
	var tables, rls, denied int
	if conn.QueryRow(ctx, `select count(*),count(*) filter(where c.relrowsecurity and c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and c.relkind='r'`).Scan(&tables, &rls) == nil {
		out["internalTables"] = tables
		out["forcedRLSTables"] = rls
	}
	if conn.QueryRow(ctx, `select count(*) from pg_roles r where r.rolname in ('anon','authenticated','service_role') and not has_schema_privilege(r.rolname,'game','USAGE')`).Scan(&denied) == nil {
		out["dataAPIRolesDeniedSchema"] = denied
	}
	tx, e := conn.Begin(ctx)
	if e != nil {
		out["sqlTests"] = "unavailable"
		emit()
		return
	}
	defer tx.Rollback(ctx)
	sql := `create extension if not exists pgtap with schema extensions;set local search_path=extensions,public;`
	if _, e = tx.Exec(ctx, sql); e != nil {
		out["pgTAP"] = "extension_unavailable"
		emit()
		return
	}
	rows, e := tx.Query(ctx, `select plan(8);`)
	if e != nil {
		out["pgTAP"] = "plan_failed"
		emit()
		return
	}
	rows.Close()
	assertions := []string{
		`not has_schema_privilege('anon','game','USAGE')`,
		`not has_schema_privilege('authenticated','game','USAGE')`,
		`not has_schema_privilege('service_role','game','USAGE')`,
		`not has_table_privilege('authenticated','game.character_inventory','UPDATE')`,
		`not has_table_privilege('authenticated','game.character_abilities','INSERT')`,
		`not has_table_privilege('authenticated','game.world_events','INSERT')`,
		`not has_table_privilege('authenticated','game.npc_relationships','UPDATE')`,
		`(select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and c.relkind='r')`,
	}
	passed := 0
	for _, condition := range assertions {
		var result string
		if tx.QueryRow(ctx, "select ok("+condition+")").Scan(&result) == nil && strings.HasPrefix(result, "ok ") {
			passed++
		}
	}
	out["pgTAPAssertionsPassed"] = passed
	out["pgTAPAssertionsTotal"] = len(assertions)
	out["sqlAssertionsRolledBack"] = true
	_ = tx.Rollback(ctx)
	emit()
}
