// Public configuration export only. No account passwords, DB connection, access or refresh tokens.
package main

import (
	"encoding/json"
	"flag"
	authority "mmorpg/authority"
	"os"
)

func main() {
	env := flag.String("env-file", ".env", "Explicit configuration")
	out := flag.String("output", "../../Temp/m05-public-config.json", "New public fixture outside Assets")
	flag.Parse()
	if authority.LoadEnvironmentFile(*env) != nil {
		os.Exit(1)
	}
	if _, e := authority.NewSupabaseAuth(os.Getenv("SUPABASE_URL"), os.Getenv("SUPABASE_PUBLISHABLE_KEY"), os.Getenv("AUTH_MODE"), "authenticated", false); e != nil {
		os.Exit(1)
	}
	f, e := os.OpenFile(*out, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if e != nil {
		os.Exit(1)
	}
	defer f.Close()
	if json.NewEncoder(f).Encode(map[string]string{"authUrl": os.Getenv("SUPABASE_URL"), "publishableKey": os.Getenv("SUPABASE_PUBLISHABLE_KEY"), "backendUrl": "http://127.0.0.1:8093"}) != nil {
		os.Exit(1)
	}
	json.NewEncoder(os.Stdout).Encode(map[string]bool{"publicConfigurationExported": true, "secretsIncluded": false})
}
