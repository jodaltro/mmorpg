// Read-only readiness probe. Never logs connection strings, passwords, API keys or upstream bodies.
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	authority "mmorpg/authority"
)

func main() {
	envFile := flag.String("env-file", "", "Explicit local configuration file")
	connection := flag.String("connection", "configured", "configured or direct; probe only, leaves file unchanged")
	rootCA := flag.String("root-ca", "", "Explicit provider CA PEM")
	flag.Parse()
	result := map[string]any{"readOnly": true}
	emit := func() { _ = json.NewEncoder(os.Stdout).Encode(result) }
	if authority.LoadEnvironmentFile(*envFile) != nil {
		result["configuration"] = "invalid_environment_file"
		emit()
		return
	}
	mode := os.Getenv("AUTH_MODE")
	a, e := authority.NewSupabaseAuth(os.Getenv("SUPABASE_URL"), os.Getenv("SUPABASE_PUBLISHABLE_KEY"), mode, "authenticated", os.Getenv("ALLOW_LOCAL_AUTH") == "true")
	if e != nil {
		result["authConfiguration"] = "invalid"
	} else {
		result["authConfiguration"] = "valid"
		result["authMode"] = mode
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		req, _ := http.NewRequestWithContext(ctx, "GET", a.URL+"/auth/v1/settings", nil)
		req.Header.Set("apikey", a.PublishableKey)
		res, e := a.Client.Do(req)
		if e != nil {
			result["authSettings"] = "unreachable"
		} else {
			result["authSettingsStatus"] = res.StatusCode
			_ = res.Body.Close()
		}
		req, _ = http.NewRequestWithContext(ctx, "GET", a.URL+"/auth/v1/.well-known/jwks.json", nil)
		res, e = a.Client.Do(req)
		if e != nil {
			result["jwks"] = "unreachable"
		} else {
			result["jwksStatus"] = res.StatusCode
			var doc struct {
				Keys []struct {
					Alg string `json:"alg"`
				} `json:"keys"`
			}
			if res.StatusCode == 200 && json.NewDecoder(io.LimitReader(res.Body, 65536)).Decode(&doc) == nil {
				algorithms := []string{}
				for _, k := range doc.Keys {
					if k.Alg == "RS256" || k.Alg == "ES256" {
						algorithms = append(algorithms, k.Alg)
					}
				}
				result["supportedSigningAlgorithms"] = algorithms
				result["jwksKeyCount"] = len(doc.Keys)
			}
			_ = res.Body.Close()
		}
		cancel()
	}
	rawDatabase := os.Getenv("DATABASE_URL")
	if *connection == "direct" {
		authURL, ae := url.Parse(os.Getenv("SUPABASE_URL"))
		dbURL, de := url.Parse(rawDatabase)
		if ae != nil || de != nil || !strings.HasSuffix(authURL.Hostname(), ".supabase.co") || dbURL.User == nil {
			result["database"] = "direct_configuration_requires_project_url_and_postgres_uri"
			emit()
			return
		}
		ref := strings.TrimSuffix(authURL.Hostname(), ".supabase.co")
		user := dbURL.User.Username()
		if strings.HasSuffix(user, "."+ref) {
			user = strings.TrimSuffix(user, "."+ref)
		} else if strings.HasSuffix(dbURL.Hostname(), ".pooler.supabase.com") {
			result["database"] = "project_identity_mismatch"
			emit()
			return
		}
		password, ok := dbURL.User.Password()
		if !ok {
			result["database"] = "password_missing"
			emit()
			return
		}
		dbURL.Host = "db." + ref + ".supabase.co:5432"
		dbURL.User = url.UserPassword(user, password)
		query := dbURL.Query()
		query.Set("sslmode", "verify-full")
		dbURL.RawQuery = query.Encode()
		rawDatabase = dbURL.String()
		result["directConfigurationDerivedInMemory"] = true
	} else if *connection != "configured" {
		result["configuration"] = "invalid_connection_option"
		emit()
		return
	}
	cfg, e := pgx.ParseConfig(rawDatabase)
	if e != nil || os.Getenv("DATABASE_URL") == "" {
		result["database"] = "invalid_connection_configuration"
		result["postgresURIPrefix"] = strings.HasPrefix(rawDatabase, "postgres://") || strings.HasPrefix(rawDatabase, "postgresql://")
		result["containsUnreplacedPasswordPlaceholder"] = strings.Contains(rawDatabase, "[YOUR-PASSWORD]") || strings.Contains(rawDatabase, "[SUA-SENHA]")
		if parsed, parseErr := url.Parse(rawDatabase); parseErr == nil {
			result["hostPresent"] = parsed.Hostname() != ""
			result["hasUnexpectedFragment"] = parsed.Fragment != ""
			result["userInfoPresent"] = parsed.User != nil
		} else {
			result["urlSyntaxValid"] = false
		}
		if e != nil {
			cause := "unrecognized_format"
			for _, c := range []string{"invalid URL escape", "invalid port", "invalid sslmode", "invalid userinfo", "invalid DSN", "invalid keyword/value"} {
				if strings.Contains(e.Error(), c) {
					cause = c
					break
				}
			}
			result["databaseFormatIssue"] = cause
		}
		emit()
		return
	}
	remote := cfg.Host != "127.0.0.1" && cfg.Host != "localhost"
	result["databaseTLSConfiguredForBackend"] = !remote || (cfg.TLSConfig != nil && !cfg.TLSConfig.InsecureSkipVerify && len(cfg.Fallbacks) == 0)
	method := "other"
	if strings.HasSuffix(cfg.Host, ".pooler.supabase.com") {
		if cfg.Port == 5432 {
			method = "session_pooler"
		} else if cfg.Port == 6543 {
			method = "transaction_pooler"
		}
	} else if strings.HasPrefix(cfg.Host, "db.") && strings.HasSuffix(cfg.Host, ".supabase.co") {
		method = "direct"
	}
	result["databaseConnectionMethod"] = method
	// A pasted Connect URI commonly defaults to sslmode=prefer. This probe strengthens TLS in memory only.
	// It never permits plaintext fallback and leaves the user's file unchanged.
	if remote {
		if cfg.TLSConfig != nil {
			cfg.TLSConfig = cfg.TLSConfig.Clone()
		} else {
			cfg.TLSConfig = &tls.Config{}
		}
		cfg.TLSConfig.ServerName = cfg.Host
		cfg.TLSConfig.MinVersion = tls.VersionTLS12
		cfg.TLSConfig.InsecureSkipVerify = false
		if *rootCA != "" {
			pem, err := os.ReadFile(*rootCA)
			roots := x509.NewCertPool()
			if err != nil || !roots.AppendCertsFromPEM(pem) {
				result["database"] = "invalid_provider_ca"
				emit()
				return
			}
			cfg.TLSConfig.RootCAs = roots
			result["explicitProviderCA"] = true
		}
		cfg.Fallbacks = nil
	}
	cfg.ConnectTimeout = 8 * time.Second
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	c, e := pgx.ConnectConfig(ctx, cfg)
	if e != nil {
		code := "connection_failed"
		var dns *net.DNSError
		var db *pgconn.PgError
		var certificate *tls.CertificateVerificationError
		var authority x509.UnknownAuthorityError
		var host x509.HostnameError
		var network *net.OpError
		switch {
		case errors.As(e, &dns):
			code = "dns_unavailable"
		case errors.As(e, &db):
			code = "postgres_" + db.Code
		case errors.Is(e, context.DeadlineExceeded):
			code = "timeout"
		case errors.As(e, &certificate):
			code = "tls_certificate_verification_failed"
		case errors.As(e, &authority):
			code = "tls_unknown_authority"
		case errors.As(e, &host):
			code = "tls_hostname_mismatch"
		case errors.As(e, &network):
			code = "network_" + network.Op
		}
		cause := e
		types := []string{}
		for cause != nil {
			types = append(types, fmt.Sprintf("%T", cause))
			cause = errors.Unwrap(cause)
		}
		result["databaseErrorTypes"] = types
		for _, marker := range []string{"network is unreachable", "No connection could be made", "certificate signed by unknown authority", "certificate is not valid", "server refused TLS connection", "cannot assign requested address", "connection refused", "incorrect password", "password authentication failed", "Tenant or user not found", "connection reset"} {
			if strings.Contains(e.Error(), marker) {
				result["databaseIssue"] = marker
				break
			}
		}
		result["database"] = code
		emit()
		return
	}
	defer c.Close(ctx)
	result["database"] = "connected_verified_tls"
	var user string
	var privileged, exists bool
	e = c.QueryRow(ctx, `select current_user,rolsuper or rolbypassrls or rolcreaterole or rolcreatedb,exists(select 1 from pg_roles where rolname='game_backend') from pg_roles where rolname=current_user`).Scan(&user, &privileged, &exists)
	if e != nil {
		result["roleInspection"] = "unavailable"
	} else {
		result["databaseRolePrivileged"] = privileged
		result["gameBackendRoleExists"] = exists
		result["usesDefaultPostgresRole"] = user == "postgres"
		if exists {
			var member bool
			if c.QueryRow(ctx, `select pg_has_role(current_user,'game_backend','member')`).Scan(&member) == nil {
				result["backendRoleMember"] = member
			}
		}
	}
	var schema bool
	if c.QueryRow(ctx, `select exists(select 1 from pg_namespace where nspname='game')`).Scan(&schema) == nil {
		result["gameSchemaExists"] = schema
	}
	if schema {
		var testWorld bool
		tx, err := c.Begin(ctx)
		if err == nil && exists {
			_, err = tx.Exec(ctx, `set local role game_backend`)
		}
		if err == nil {
			err = tx.QueryRow(ctx, `select is_test from game.worlds where id='marco05-dev'`).Scan(&testWorld)
		}
		if tx != nil {
			_ = tx.Rollback(ctx)
		}
		if err == nil {
			result["marco05WorldIsTest"] = testWorld
		} else {
			result["marco05WorldInspection"] = "missing_or_not_permitted"
		}
	}
	result["twoAuthTestUsersConfigured"] = strings.TrimSpace(os.Getenv("SUPABASE_TEST_EMAIL_A")) != "" && os.Getenv("SUPABASE_TEST_PASSWORD_A") != "" && strings.TrimSpace(os.Getenv("SUPABASE_TEST_EMAIL_B")) != "" && os.Getenv("SUPABASE_TEST_PASSWORD_B") != ""
	emit()
}
