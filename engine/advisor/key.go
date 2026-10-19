package advisor

import (
	"bytes"
	"errors"
	"io"
	"os"
	"strings"
)

// ResolveKey reads OPENROUTER_API_KEY from the environment, else from a
// local ignored file. Parsing is literal: no interpolation, no shell.
func ResolveKey(path string) (string, error) {
	if key := os.Getenv("OPENROUTER_API_KEY"); key != "" {
		return key, nil
	}
	if path == "" {
		return "", nil
	}
	f, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", errors.New("secret_file_unavailable")
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, 65537))
	if err != nil || len(data) > 65536 {
		return "", errors.New("invalid_secret_file")
	}
	data = bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf})
	key := ""
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "export "))
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		name, value, ok := strings.Cut(line, "=")
		if !ok {
			return "", errors.New("invalid_secret_file")
		}
		if strings.TrimSpace(name) != "OPENROUTER_API_KEY" {
			continue
		}
		value = strings.TrimSpace(value)
		if len(value) >= 2 && (value[0] == 0x22 || value[0] == 0x27) && value[len(value)-1] == value[0] {
			value = value[1 : len(value)-1]
		}
		if strings.ContainsAny(value, "\r\n\x00") {
			return "", errors.New("invalid_secret_file")
		}
		key = value
	}
	return key, nil
}
