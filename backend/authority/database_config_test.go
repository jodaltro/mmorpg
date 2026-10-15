package authority

import (
	"net/url"
	"strings"
	"testing"
)

func TestDirectConfigurationPreservesPasswordAndRejectsWrongProject(t *testing.T) {
	original := &url.URL{Scheme: "postgresql", Host: "aws-0-region.pooler.supabase.com:5432", Path: "/postgres", User: url.UserPassword("postgres.exampleproject", "p@ss word:#?%")}
	normalized, e := DirectSupabaseDatabaseURL(original.String(), "https://exampleproject.supabase.co", "certs/supabase-prod-ca-2021.crt")
	if e != nil {
		t.Fatal(e)
	}
	parsed, _ := url.Parse(normalized)
	password, _ := parsed.User.Password()
	if password != "p@ss word:#?%" || parsed.User.Username() != "postgres" || parsed.Host != "db.exampleproject.supabase.co:5432" || parsed.Query().Get("sslmode") != "verify-full" || parsed.Query().Get("sslrootcert") == "" {
		t.Fatal("configuration changed identity/password or did not verify TLS")
	}
	for _, invalid := range []string{"https://example.com", strings.Replace(original.String(), "postgres.exampleproject", "postgres.otherproject", 1), "postgresql://postgres:fake@db.otherproject.supabase.co/postgres"} {
		if _, e := DirectSupabaseDatabaseURL(invalid, "https://exampleproject.supabase.co", ""); e == nil {
			t.Fatal("wrong project accepted")
		}
	}
}
