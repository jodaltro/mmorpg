// Writes ONLY public Auth settings + development login credentials, never PostgreSQL or admin secrets.
package main

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"strings"

	authority "mmorpg/authority"
)

func main() {
	env := flag.String("env-file", ".env", "Explicit development environment")
	output := flag.String("output", "../../Temp/m05-live-auth.json", "NEW ignored test fixture outside Assets")
	flag.Parse()
	if authority.LoadEnvironmentFile(*env) != nil {
		panic("development_configuration_unavailable")
	}
	absolute, e := filepath.Abs(*output)
	if e != nil || strings.Contains(strings.ToLower(filepath.ToSlash(absolute)), "/assets/") {
		panic("fixture_must_remain_outside_assets")
	}
	fixture := map[string]string{"authUrl": os.Getenv("SUPABASE_URL"), "publishableKey": os.Getenv("SUPABASE_PUBLISHABLE_KEY"), "backendUrl": "http://127.0.0.1:8094", "emailA": os.Getenv("SUPABASE_TEST_EMAIL_A"), "passwordA": os.Getenv("SUPABASE_TEST_PASSWORD_A"), "emailB": os.Getenv("SUPABASE_TEST_EMAIL_B"), "passwordB": os.Getenv("SUPABASE_TEST_PASSWORD_B")}
	bytes, e := json.Marshal(fixture)
	if e != nil {
		panic("fixture_serialization_failed")
	}
	f, e := os.OpenFile(absolute, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if e != nil {
		panic("fixture_destination_exists_or_unavailable")
	}
	defer f.Close()
	if _, e = f.Write(bytes); e != nil {
		panic("fixture_write_failed")
	}
	_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"fixtureCreatedOutsideAssets": true, "databaseCredentialsIncluded": false, "credentialsPrinted": false})
}
