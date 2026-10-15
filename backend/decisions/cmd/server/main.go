package main

import (
	"flag"
	"log/slog"
	"math"
	decisions "mmorpg/decisions"
	"net/http"
	"os"
	"time"
)

func main() {
	address := flag.String("listen", "127.0.0.1:8091", "Development loopback only")
	mode := flag.String("mode", "Deterministic", "Deterministic or OpenRouter")
	timeout := flag.Duration("timeout", 5*time.Second, "Provider timeout")
	minimum := flag.Float64("minimum-confidence", 0, "Optional provisional threshold; zero disables gating")
	directory := flag.String("data-dir", "data", "Persistent decisions directory; one server instance only")
	envFile := flag.String("env-file", ".env", "Optional local secret file; environment takes priority")
	flag.Parse()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if !decisions.LocalAddress(*address) || (*mode != "Deterministic" && *mode != "OpenRouter") || *timeout <= 0 || *timeout > 30*time.Second || *minimum < 0 || *minimum > 1 || math.IsNaN(*minimum) || math.IsInf(*minimum, 0) {
		logger.Error("invalid_configuration")
		os.Exit(2)
	}
	var provider decisions.DecisionProvider = decisions.DeterministicDecisionProvider{}
	if *mode == "OpenRouter" {
		key, err := decisions.ResolveOpenRouterAPIKey(*envFile)
		if err != nil {
			logger.Error("invalid_secret_configuration")
			os.Exit(2)
		}
		provider = &decisions.OpenRouterJevProvider{APIKey: key, Timeout: *timeout}
	}
	service := &decisions.Service{Provider: provider, Timeout: *timeout + time.Second, MinimumConfidence: *minimum, Directory: *directory, Logger: logger}
	server := &http.Server{Addr: *address, Handler: decisions.Handler(service), ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: *timeout + 5*time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	logger.Info("listening", "address", *address, "mode", *mode)
	if server.ListenAndServe() != nil {
		logger.Error("server_stopped")
		os.Exit(1)
	}
}
