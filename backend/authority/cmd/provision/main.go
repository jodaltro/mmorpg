// Explicit, non-destructive development provisioning; secrets never enter CLI arguments or logs.
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	authority "mmorpg/authority"
)

func fail(code string) {
	_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"success": false, "error": code})
	os.Exit(1)
}
func main() {
	file := flag.String("env-file", ".env", "Explicit existing configuration")
	cert := flag.String("root-ca", "certs/supabase-prod-ca-2021.crt", "Official provider CA PEM")
	cli := flag.String("supabase-cli", "supabase", "Existing Supabase CLI executable")
	repo := flag.String("repo", "../..", "Project root containing reviewed migrations")
	apply := flag.Bool("apply", false, "Explicit authorization to apply additive development migrations and provision a NEW restricted role")
	flag.Parse()
	if !*apply {
		fail("explicit_apply_required")
	}
	envPath, e := filepath.Abs(*file)
	if e != nil || authority.LoadEnvironmentFile(envPath) != nil {
		fail("configuration_unavailable")
	}
	databaseURL, e := authority.DirectSupabaseDatabaseURL(os.Getenv("DATABASE_URL"), os.Getenv("SUPABASE_URL"), *cert)
	if e != nil {
		fail("invalid_direct_database_configuration")
	}
	cfg, e := pgx.ParseConfig(databaseURL)
	if e != nil || cfg.TLSConfig == nil || cfg.TLSConfig.InsecureSkipVerify {
		fail("verified_tls_required")
	}
	cfg.ConnectTimeout = 8 * time.Second
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	conn, e := pgx.ConnectConfig(ctx, cfg)
	if e != nil {
		fail("database_connection_failed")
	}
	defer conn.Close(context.Background())
	var roleExists bool
	if conn.QueryRow(ctx, `select exists(select 1 from pg_roles where rolname='mmorpg_server')`).Scan(&roleExists) != nil {
		fail("role_inspection_failed")
	}
	if roleExists {
		fail("existing_runtime_role_preserved_use_existing_configuration")
	}
	migrationConfig := filepath.Join(filepath.Dir(envPath), ".env.migrations")
	if _, e = os.Stat(migrationConfig); e == nil {
		fail("existing_migration_config_preserved")
	}
	adminBytes := []byte("# Database administrator; explicit migration tooling only. Never load in Unity.\nDATABASE_URL=" + databaseURL + "\n")
	f, e := os.OpenFile(migrationConfig, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if e != nil {
		fail("cannot_preserve_administrator_config")
	}
	_, e = f.Write(adminBytes)
	closeError := f.Close()
	if e != nil || closeError != nil {
		fail("cannot_preserve_administrator_config")
	}
	// Keep the password in the child's environment, not argv; keep CLI output private/sanitized.
	noPassword, _ := url.Parse(databaseURL)
	noPassword.User = url.User(cfg.User)
	command := exec.CommandContext(ctx, *cli, "migration", "up", "--db-url", noPassword.String(), "--output-format", "json")
	command.Dir = *repo
	command.Env = append(os.Environ(), "PGPASSWORD="+cfg.Password)
	if _, e = command.CombinedOutput(); e != nil {
		fail("supabase_cli_migration_failed")
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
		fail("development_seed_failed")
	}
	var testWorld bool
	if tx.QueryRow(ctx, `select is_test from game.worlds where id='marco05-dev'`).Scan(&testWorld) != nil || !testWorld {
		fail("test_world_required")
	}
	random := make([]byte, 32)
	if _, e = rand.Read(random); e != nil {
		fail("random_generation_failed")
	}
	password := hex.EncodeToString(random)
	// Hex secret cannot contain SQL quotes. No existing role is modified; failure rolls back role + seed.
	statement := fmt.Sprintf("create role mmorpg_server login noinherit nosuperuser nocreatedb nocreaterole nobypassrls password '%s'; grant game_backend to mmorpg_server", password)
	if _, e = tx.Exec(ctx, statement); e != nil {
		fail("restricted_role_provision_failed")
	}
	if e = tx.Commit(ctx); e != nil {
		fail("provision_commit_failed")
	}
	runtimeURL, _ := url.Parse(databaseURL)
	runtimeURL.User = url.UserPassword("mmorpg_server", password)
	content, e := os.ReadFile(envPath)
	if e != nil {
		fail("runtime_config_read_failed")
	}
	lines := strings.Split(string(content), "\n")
	replaced := false
	for i, line := range lines {
		if strings.HasPrefix(strings.TrimSpace(line), "DATABASE_URL=") {
			lines[i] = "DATABASE_URL=" + runtimeURL.String()
			replaced = true
		}
	}
	if !replaced {
		fail("runtime_database_entry_missing")
	}
	if e = os.WriteFile(envPath, []byte(strings.Join(lines, "\n")), 0600); e != nil {
		fail("runtime_configuration_write_failed")
	}
	_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"success": true, "connection": "direct_ipv6_verified_tls", "migrations": "applied_via_supabase_cli", "seedWorld": "marco05-dev", "runtimeRole": "mmorpg_server", "administratorConfigurationSeparated": true, "resetPerformed": false})
}
