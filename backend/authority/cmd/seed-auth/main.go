// Development-only Auth database fixtures; no email is sent and no existing account is changed.
// Tokens/sessions must still be issued and cryptographically verified through the real Supabase Auth Server.
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"net/mail"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
	authority "mmorpg/authority"
)

func stop(code string) {
	_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"success": false, "error": code})
	os.Exit(1)
}
func main() {
	file := flag.String("env-file", ".env", "Explicit configured test users")
	migration := flag.String("migration-env", ".env.migrations", "Admin connection only")
	apply := flag.Bool("apply", false, "Explicit development provisioning authorization")
	generate := flag.Bool("generate-test-passwords", false, "Generate valid passwords only for NEW test accounts when supplied passwords are invalid; store them only in the local ignored env file")
	flag.Parse()
	if !*apply {
		stop("explicit_apply_required")
	}
	if authority.LoadEnvironmentFile(*file) != nil {
		stop("configuration_unavailable")
	}
	contents, e := os.ReadFile(*migration)
	if e != nil {
		stop("administrator_config_unavailable")
	}
	raw := ""
	for _, line := range strings.Split(string(contents), "\n") {
		if strings.HasPrefix(line, "DATABASE_URL=") {
			raw = strings.TrimSpace(strings.TrimPrefix(line, "DATABASE_URL="))
		}
	}
	cfg, e := pgx.ParseConfig(raw)
	if e != nil || cfg.TLSConfig == nil || cfg.TLSConfig.InsecureSkipVerify {
		stop("verified_tls_required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	conn, e := pgx.ConnectConfig(ctx, cfg)
	if e != nil {
		stop("database_unavailable")
	}
	defer conn.Close(ctx)
	var testWorld bool
	if conn.QueryRow(ctx, `select is_test from game.worlds where id='marco05-dev'`).Scan(&testWorld) != nil || !testWorld {
		stop("isolated_development_world_required")
	}
	tx, e := conn.Begin(ctx)
	if e != nil {
		stop("transaction_unavailable")
	}
	defer tx.Rollback(ctx)
	// Inspect the live Auth schema first; do not assume optional token columns across Auth versions.
	rows, e := tx.Query(ctx, `select column_name from information_schema.columns where table_schema='auth' and table_name='users'`)
	if e != nil {
		stop("auth_schema_inspection_failed")
	}
	columns := map[string]bool{}
	for rows.Next() {
		var name string
		if rows.Scan(&name) != nil {
			stop("auth_schema_inspection_failed")
		}
		columns[name] = true
	}
	rows.Close()
	created, preserved := 0, 0
	updatedPasswords := map[string]string{}
	emails := map[string]bool{}
	for _, label := range []string{"A", "B"} {
		email, password := os.Getenv("SUPABASE_TEST_EMAIL_"+label), os.Getenv("SUPABASE_TEST_PASSWORD_"+label)
		address, e := mail.ParseAddress(email)
		if e != nil || address.Address != email {
			stop("invalid_development_email_" + label)
		}
		if emails[strings.ToLower(email)] {
			stop("development_users_must_have_different_emails")
		}
		emails[strings.ToLower(email)] = true
		var existing string
		e = tx.QueryRow(ctx, `select id::text from auth.users where email=$1`, email).Scan(&existing)
		if e == nil {
			preserved++
			continue
		}
		if !errors.Is(e, pgx.ErrNoRows) {
			stop("existing_user_inspection_failed")
		}
		if len(password) < 6 || len([]byte(password)) > 72 {
			if !*generate {
				stop("invalid_development_password_" + label)
			}
			random := make([]byte, 24)
			if _, e = rand.Read(random); e != nil {
				stop("test_password_generation_failed")
			}
			password = hex.EncodeToString(random)
			updatedPasswords["SUPABASE_TEST_PASSWORD_"+label] = password
		}
		encrypted, e := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		if e != nil {
			stop("password_hash_failed")
		}
		id := uuid.NewString()
		names := []string{"id", "instance_id", "aud", "role", "email", "encrypted_password", "email_confirmed_at", "created_at", "updated_at", "raw_app_meta_data", "raw_user_meta_data"}
		values := []any{id, uuid.Nil.String(), "authenticated", "authenticated", email, string(encrypted), time.Now().UTC(), time.Now().UTC(), time.Now().UTC(), []byte(`{"provider":"email","providers":["email"]}`), []byte(`{"development_test":true,"milestone":"05A"}`)}
		for _, name := range []string{"confirmation_token", "recovery_token", "email_change_token_new", "email_change_token_current", "email_change", "phone_change", "phone_change_token", "reauthentication_token"} {
			if columns[name] {
				names = append(names, name)
				values = append(values, "")
			}
		}
		quoted := []string{}
		placeholders := []string{}
		for i, name := range names {
			if !columns[name] {
				stop("unsupported_auth_schema")
			}
			quoted = append(quoted, pgx.Identifier{name}.Sanitize())
			placeholders = append(placeholders, "$"+strconv.Itoa(i+1))
		}
		if _, e = tx.Exec(ctx, "insert into auth.users("+strings.Join(quoted, ",")+") values("+strings.Join(placeholders, ",")+")", values...); e != nil {
			var pe *pgconn.PgError
			if errors.As(e, &pe) {
				stop("auth_seed_postgres_" + pe.Code)
			}
			stop("auth_user_seed_failed")
		}
		identity, _ := json.Marshal(map[string]any{"sub": id, "email": email, "email_verified": true, "phone_verified": false})
		if _, e = tx.Exec(ctx, `insert into auth.identities(id,user_id,provider,provider_id,identity_data,created_at,updated_at) values($1::uuid,$2::uuid,'email',($2::uuid)::text,$3,now(),now())`, uuid.NewString(), id, identity); e != nil {
			var pe *pgconn.PgError
			if errors.As(e, &pe) {
				stop("identity_seed_postgres_" + pe.Code)
			}
			stop("auth_identity_seed_failed")
		}
		created++
	}
	if e = tx.Commit(ctx); e != nil {
		stop("auth_seed_commit_failed")
	}
	if len(updatedPasswords) > 0 {
		data, e := os.ReadFile(*file)
		if e != nil {
			stop("local_password_storage_failed")
		}
		lines := strings.Split(string(data), "\n")
		for i, line := range lines {
			name, _, ok := strings.Cut(strings.TrimSpace(line), "=")
			if ok {
				if password, changed := updatedPasswords[name]; changed {
					lines[i] = name + "=" + password
				}
			}
		}
		if os.WriteFile(*file, []byte(strings.Join(lines, "\n")), 0600) != nil {
			stop("local_password_storage_failed")
		}
	}
	_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"success": true, "developmentUsersCreated": created, "existingUsersPreserved": preserved, "emailsSent": 0, "credentialsPrinted": false})
}
