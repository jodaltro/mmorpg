// Explicit development migrations using the separate administrator file; no resets, secret argv or role changes.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"github.com/jackc/pgx/v5"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func fail(code string) {
	json.NewEncoder(os.Stdout).Encode(map[string]any{"success": false, "error": code, "credentialsPrinted": false})
	os.Exit(1)
}
func main() {
	env := flag.String("migration-env", ".env.migrations", "Explicit administrative file")
	cli := flag.String("supabase-cli", "supabase", "Existing CLI")
	repo := flag.String("repo", "../..", "Reviewed project")
	apply := flag.Bool("apply", false, "Apply to the configured existing development world")
	flag.Parse()
	if !*apply {
		fail("explicit_apply_required")
	}
	b, e := os.ReadFile(*env)
	if e != nil {
		fail("configuration_unavailable")
	}
	raw := ""
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "DATABASE_URL=") {
			raw = strings.TrimSpace(strings.TrimPrefix(line, "DATABASE_URL="))
		}
	}
	cfg, e := pgx.ParseConfig(raw)
	if e != nil || cfg.TLSConfig == nil || cfg.TLSConfig.InsecureSkipVerify {
		fail("verified_tls_required")
	}
	for _, f := range cfg.Fallbacks {
		if f.TLSConfig == nil || f.TLSConfig.InsecureSkipVerify {
			fail("tls_downgrade_forbidden")
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	conn, e := pgx.ConnectConfig(ctx, cfg)
	if e != nil {
		fail("connection_unavailable")
	}
	defer conn.Close(context.Background())
	var dev bool
	if conn.QueryRow(ctx, `select is_test from game.worlds where id='marco05-dev'`).Scan(&dev) != nil || !dev {
		fail("existing_development_world_required")
	}
	noPassword, e := url.Parse(raw)
	if e != nil {
		fail("invalid_configuration")
	}
	noPassword.User = url.User(cfg.User)
	cmd := exec.CommandContext(ctx, *cli, "migration", "up", "--db-url", noPassword.String(), "--output-format", "json")
	cmd.Dir = *repo
	cmd.Env = append(os.Environ(), "PGPASSWORD="+cfg.Password)
	if _, e = cmd.CombinedOutput(); e != nil {
		fail("migration_failed")
	}
	seed, e := os.ReadFile(filepath.Join(*repo, "supabase", "seed.sql"))
	if e != nil {
		fail("seed_unavailable")
	}
	tx, e := conn.Begin(ctx)
	if e != nil {
		fail("transaction_unavailable")
	}
	defer tx.Rollback(context.Background())
	if _, e = tx.Exec(ctx, string(seed)); e != nil {
		fail("seed_failed")
	}
	if e = tx.Commit(ctx); e != nil {
		fail("seed_commit_failed")
	}
	var tables, forced, migrations int
	conn.QueryRow(ctx, `select count(*),count(*) filter(where relrowsecurity and relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and c.relkind='r'`).Scan(&tables, &forced)
	conn.QueryRow(ctx, `select count(*) from supabase_migrations.schema_migrations`).Scan(&migrations)
	json.NewEncoder(os.Stdout).Encode(map[string]any{"success": true, "migrationsAppliedViaCLI": true, "migrationHistoryCount": migrations, "internalTables": tables, "forcedRLSTables": forced, "seedApplied": true, "resetPerformed": false, "credentialsPrinted": false})
}
