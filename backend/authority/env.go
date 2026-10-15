package authority

import (
	"bufio"
	"errors"
	"os"
	"strings"
)

var environmentNames = map[string]bool{"DATABASE_URL": true, "SUPABASE_URL": true, "SUPABASE_PUBLISHABLE_KEY": true, "AUTH_MODE": true, "ALLOW_LOCAL_AUTH": true, "LISTEN_ADDR": true, "ENABLE_DEV_IMPORT": true, "AUTH_AUDIENCE": true, "SUPABASE_TEST_EMAIL_A": true, "SUPABASE_TEST_PASSWORD_A": true, "SUPABASE_TEST_EMAIL_B": true, "SUPABASE_TEST_PASSWORD_B": true}

// Explicit optional local file: literal values; no shell evaluation, expansion or secret logging.
func LoadEnvironmentFile(path string) error {
	if path == "" {
		return nil
	}
	f, e := os.Open(path)
	if e != nil {
		return errors.New("environment_file_unavailable")
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 4096), 65536)
	values := map[string]string{}
	for scanner.Scan() {
		line := strings.TrimSpace(strings.TrimPrefix(scanner.Text(), "\ufeff"))
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		name, value, ok := strings.Cut(line, "=")
		name = strings.TrimSpace(name)
		value = strings.TrimSpace(value)
		if !ok || !environmentNames[name] {
			return errors.New("invalid_environment_file")
		}
		if _, exists := values[name]; exists {
			return errors.New("invalid_environment_file")
		}
		if strings.HasPrefix(value, "\"") || strings.HasPrefix(value, "'") {
			if len(value) < 2 || value[len(value)-1] != value[0] {
				return errors.New("invalid_environment_file")
			}
			value = value[1 : len(value)-1]
		}
		values[name] = value
	}
	if scanner.Err() != nil {
		return errors.New("invalid_environment_file")
	}
	for name, value := range values {
		if os.Getenv(name) == "" {
			if os.Setenv(name, value) != nil {
				return errors.New("invalid_environment_file")
			}
		}
	}
	return nil
}
