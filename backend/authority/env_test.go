package authority

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestExplicitEnvironmentFileIsLiteralAndDoesNotLeakSecrets(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".env")
	t.Setenv("SUPABASE_URL", "")
	t.Setenv("SUPABASE_PUBLISHABLE_KEY", "existing-public-key")
	if os.WriteFile(path, []byte("\ufeff# local\r\nSUPABASE_URL='https://example.invalid'\r\nSUPABASE_PUBLISHABLE_KEY=other\r\n"), 0600) != nil {
		t.Fatal("fixture")
	}
	if e := LoadEnvironmentFile(path); e != nil || os.Getenv("SUPABASE_URL") != "https://example.invalid" || os.Getenv("SUPABASE_PUBLISHABLE_KEY") != "existing-public-key" {
		t.Fatal("precedence/parser")
	}
	for _, bad := range []string{"UNKNOWN_SECRET=fixture-secret", "DATABASE_URL='fixture-secret", "DATABASE_URL=one\nDATABASE_URL=fixture-secret"} {
		_ = os.WriteFile(path, []byte(bad), 0600)
		e := LoadEnvironmentFile(path)
		if e == nil || strings.Contains(e.Error(), "fixture-secret") {
			t.Fatal("invalid configuration or leak")
		}
	}
	if LoadEnvironmentFile("") != nil {
		t.Fatal("optional env file")
	}
}
