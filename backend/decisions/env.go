package decisions

import (
	"bytes"
	"errors"
	"io"
	"os"
	"strings"
)

// ResolveOpenRouterAPIKey loads a local secret without modifying the parent process.
// Environment takes priority. File parsing is literal: no interpolation or shell evaluation.
func ResolveOpenRouterAPIKey(path string) (string, error) {
	if key := os.Getenv("OPENROUTER_API_KEY"); key != "" {
		return key, nil
	}
	if path == "" {
		return "", nil
	}
	file, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", errors.New("secret_file_unavailable")
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, 65537))
	if err != nil || len(data) > 65536 {
		return "", errors.New("invalid_secret_file")
	}
	data = bytes.TrimPrefix(data, []byte{0xef, 0xbb, 0xbf}) // PowerShell UTF-8 BOM.
	var key string
	found := false
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		name, value, ok := strings.Cut(line, "=")
		if !ok {
			return "", errors.New("invalid_secret_file")
		}
		if strings.TrimSpace(name) != "OPENROUTER_API_KEY" {
			continue
		}
		if found {
			return "", errors.New("invalid_secret_file")
		}
		found = true
		value = strings.TrimSpace(value)
		if strings.HasPrefix(value, "\"") || strings.HasPrefix(value, "'") {
			if len(value) < 2 || value[len(value)-1] != value[0] {
				return "", errors.New("invalid_secret_file")
			}
			value = value[1 : len(value)-1]
		}
		if strings.ContainsAny(value, "\r\n\x00") {
			return "", errors.New("invalid_secret_file")
		}
		key = value
	}
	return key, nil
}
