package decisions

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLocalEnvKeyLiteralFormats(t *testing.T) {
	t.Setenv("OPENROUTER_API_KEY", "")
	for _, body := range []string{
		"OPENROUTER_API_KEY=test-only-local-value\n",
		"# local configuration\r\nOPENROUTER_API_KEY = \"test-only-local-value\"\r\n",
		"\ufeffexport OPENROUTER_API_KEY='test-only-local-value'\r\n",
	} {
		path := filepath.Join(t.TempDir(), ".env")
		if os.WriteFile(path, []byte(body), 0600) != nil {
			t.Fatal("fixture write")
		}
		key, err := ResolveOpenRouterAPIKey(path)
		if err != nil || key != "test-only-local-value" {
			t.Fatal("literal file parsing failed")
		}
	}
}
func TestEnvironmentOverridesLocalEnvAndMissingFileIsOptional(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".env")
	t.Setenv("OPENROUTER_API_KEY", "test-only-environment")
	key, err := ResolveOpenRouterAPIKey(path)
	if err != nil || key != "test-only-environment" {
		t.Fatal("environment precedence")
	}
	t.Setenv("OPENROUTER_API_KEY", "")
	key, err = ResolveOpenRouterAPIKey(path)
	if err != nil || key != "" {
		t.Fatal("optional missing file")
	}
	os.WriteFile(path, []byte("OPENROUTER_API_KEY=\n"), 0600)
	key, err = ResolveOpenRouterAPIKey(path)
	if err != nil || key != "" {
		t.Fatal("empty placeholder")
	}
}
func TestInvalidEnvFailsWithoutExposingContents(t *testing.T) {
	t.Setenv("OPENROUTER_API_KEY", "")
	for _, body := range []string{
		"OPENROUTER_API_KEY='test-only-local-value",
		"OPENROUTER_API_KEY=test-only-local-value\nOPENROUTER_API_KEY=duplicate",
		"OPENROUTER_API_KEY=test-only-local-value\x00",
		strings.Repeat("test-only-local-value", 4096),
	} {
		path := filepath.Join(t.TempDir(), ".env")
		os.WriteFile(path, []byte(body), 0600)
		_, err := ResolveOpenRouterAPIKey(path)
		if err == nil || strings.Contains(err.Error(), "test-only-local-value") {
			t.Fatal("invalid file handling")
		}
	}
}
