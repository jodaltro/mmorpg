package main

import (
	"context"
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	authority "mmorpg/authority"
)

func main() {
	envFile := flag.String("env-file", "", "Optional explicit local configuration file; environment takes priority")
	flag.Parse()
	if authority.LoadEnvironmentFile(*envFile) != nil {
		log.Fatal("invalid_environment_file")
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	auth, e := authority.NewSupabaseAuth(os.Getenv("SUPABASE_URL"), os.Getenv("SUPABASE_PUBLISHABLE_KEY"), os.Getenv("AUTH_MODE"), "authenticated", os.Getenv("ALLOW_LOCAL_AUTH") == "true")
	if e != nil {
		log.Fatal("invalid_auth_configuration")
	}
	cfg, e := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if e != nil || os.Getenv("DATABASE_URL") == "" {
		log.Fatal("invalid_database_configuration")
	}
	// Avoid leaking credentials or SQL parameters through logs. Require TLS for non-loopback database connections.
	if cfg.ConnConfig.Host != "127.0.0.1" && cfg.ConnConfig.Host != "localhost" && (cfg.ConnConfig.TLSConfig == nil || cfg.ConnConfig.TLSConfig.InsecureSkipVerify) {
		log.Fatal("database_tls_verification_required")
	}
	if cfg.ConnConfig.Host != "127.0.0.1" && cfg.ConnConfig.Host != "localhost" {
		for _, fallback := range cfg.ConnConfig.Fallbacks {
			if fallback.TLSConfig == nil || fallback.TLSConfig.InsecureSkipVerify {
				log.Fatal("database_tls_downgrade_forbidden")
			}
		}
	}
	cfg.MaxConns = 8
	cfg.MinConns = 0
	cfg.ConnConfig.ConnectTimeout = 5 * time.Second
	pool, e := pgxpool.NewWithConfig(ctx, cfg)
	if e != nil {
		log.Fatal("database_unavailable")
	}
	defer pool.Close()
	store := &authority.Store{Pool: pool, EnableDevImport: os.Getenv("ENABLE_DEV_IMPORT") == "true"}
	if store.CheckRole(ctx) != nil {
		log.Fatal("unsafe_database_role")
	}
	address := os.Getenv("LISTEN_ADDR")
	if address == "" {
		address = "127.0.0.1:8093"
	}
	host, _, e := net.SplitHostPort(address)
	if e != nil || host != "127.0.0.1" {
		log.Fatal("development_loopback_required")
	}
	server := &http.Server{Addr: address, Handler: authority.Handler(store, auth), ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 32768}
	go func() {
		<-ctx.Done()
		bounded, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(bounded)
	}()
	log.Print("authority_listening_loopback")
	if e = server.ListenAndServe(); e != nil && e != http.ErrServerClosed {
		log.Fatal("server_stopped")
	}
}
