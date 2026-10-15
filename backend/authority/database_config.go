package authority

import (
	"errors"
	"net/url"
	"path/filepath"
	"strings"
)

// Derives only the direct endpoint of the SAME authenticated Supabase project.
// Passwords are parsed and percent-encoded, never interpolated into shell command text.
func DirectSupabaseDatabaseURL(rawDatabase, rawAuthURL, rootCA string) (string, error) {
	db, e := url.Parse(rawDatabase)
	auth, ae := url.Parse(rawAuthURL)
	if e != nil || ae != nil || db.Scheme != "postgres" && db.Scheme != "postgresql" || db.User == nil || auth.Scheme != "https" || !strings.HasSuffix(auth.Hostname(), ".supabase.co") || auth.User != nil || db.Fragment != "" {
		return "", errors.New("invalid_direct_database_configuration")
	}
	ref := strings.TrimSuffix(auth.Hostname(), ".supabase.co")
	if strings.Contains(ref, ".") || ref == "" {
		return "", errors.New("invalid_project_identity")
	}
	user := db.User.Username()
	direct := "db." + ref + ".supabase.co"
	if strings.HasSuffix(db.Hostname(), ".pooler.supabase.com") {
		if !strings.HasSuffix(user, "."+ref) {
			return "", errors.New("project_identity_mismatch")
		}
		user = strings.TrimSuffix(user, "."+ref)
	} else if db.Hostname() != direct {
		return "", errors.New("project_identity_mismatch")
	}
	password, ok := db.User.Password()
	if !ok || password == "" {
		return "", errors.New("database_password_missing")
	}
	db.Host = direct + ":5432"
	db.User = url.UserPassword(user, password)
	q := db.Query()
	q.Set("sslmode", "verify-full")
	if rootCA != "" {
		absolute, e := filepath.Abs(rootCA)
		if e != nil {
			return "", errors.New("invalid_ca_path")
		}
		q.Set("sslrootcert", filepath.ToSlash(absolute))
	}
	db.RawQuery = q.Encode()
	return db.String(), nil
}
