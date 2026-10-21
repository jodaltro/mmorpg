// Package store persists the command log. The log is the source of truth:
// state is rebuilt by replaying it, so any storage that can append and read
// commands in order (file, PostgreSQL, a stream) can back a world.
package store

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/jodaltro/mmorpg/engine/core"
)

type Log interface {
	Load() ([]core.Command, error)
	Append(core.Command) error
	// Reset starts an empty world. A durable log keeps the old one aside and
	// returns where (nothing is deleted); a memory log just forgets.
	Reset() (archived string, err error)
	Close() error
}

type header struct {
	Format   int    `json:"format"`
	Universe string `json:"universe"`
	Def      string `json:"def"`
}

// FileLog is an append-only JSON Lines file, fsynced on every append.
// A torn final line (crash mid-write) is discarded on open.
type FileLog struct {
	mu       sync.Mutex
	f        *os.File
	cmds     []core.Command
	path     string
	universe string
	def      string
}

var ErrMismatch = errors.New("log_belongs_to_another_universe")

func OpenFile(path, universe, def string) (*FileLog, error) {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return nil, err
	}
	l := &FileLog{f: f, path: path, universe: universe, def: def}
	if err := l.read(universe, def); err != nil {
		f.Close()
		return nil, err
	}
	return l, nil
}

func (l *FileLog) read(universe, def string) error {
	data, err := io.ReadAll(l.f)
	if err != nil {
		return err
	}
	if len(data) == 0 {
		return l.write(header{Format: 1, Universe: universe, Def: def})
	}
	if cut := bytes.LastIndexByte(data, 0x0a); cut != len(data)-1 {
		if err := l.f.Truncate(int64(cut + 1)); err != nil {
			return err
		}
		data = data[:cut+1]
	}
	sc := bufio.NewScanner(bytes.NewReader(data))
	sc.Buffer(make([]byte, 64<<10), 4<<20)
	first := true
	for sc.Scan() {
		dec := json.NewDecoder(bytes.NewReader(sc.Bytes()))
		dec.DisallowUnknownFields()
		if first {
			var h header
			if err := dec.Decode(&h); err != nil || h.Format != 1 {
				return fmt.Errorf("invalid log header")
			}
			if h.Universe != universe || h.Def != def {
				return ErrMismatch
			}
			first = false
			continue
		}
		var c core.Command
		if err := dec.Decode(&c); err != nil {
			return fmt.Errorf("invalid log entry %d: %w", len(l.cmds)+1, err)
		}
		l.cmds = append(l.cmds, c)
	}
	if err := sc.Err(); err != nil {
		return err
	}
	_, err = l.f.Seek(0, io.SeekEnd)
	return err
}

func (l *FileLog) write(v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	if _, err := l.f.Write(append(b, 0x0a)); err != nil {
		return err
	}
	return l.f.Sync()
}

func (l *FileLog) Load() ([]core.Command, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return append([]core.Command(nil), l.cmds...), nil
}

func (l *FileLog) Append(c core.Command) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.write(c)
}

// Reset renames the current file to <name>-<UTC time><ext> and starts a new
// one with a fresh header, so an old world can always be inspected or restored.
func (l *FileLog) Reset() (string, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if err := l.f.Close(); err != nil {
		return "", err
	}
	archived, err := Archive(l.path)
	if err != nil {
		return "", err
	}
	f, err := os.OpenFile(l.path, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return "", err
	}
	l.f, l.cmds = f, nil
	return archived, l.write(header{Format: 1, Universe: l.universe, Def: l.def})
}

func (l *FileLog) Close() error { return l.f.Close() }

// Archive renames a log file to <name>-<UTC time><ext> (never replacing an
// older archive) and returns the new path. Used for a new world, and when the
// universe changed so the old log can no longer be replayed.
func Archive(path string) (string, error) {
	ext := filepath.Ext(path)
	base := strings.TrimSuffix(path, ext) + "-" + time.Now().UTC().Format("20060102-150405")
	archived := base + ext
	for n := 2; ; n++ {
		if _, err := os.Stat(archived); errors.Is(err, os.ErrNotExist) {
			break
		}
		archived = fmt.Sprintf("%s-%d%s", base, n, ext)
	}
	return archived, os.Rename(path, archived)
}

// Memory is a log for tests and throwaway simulations.
type Memory struct {
	mu   sync.Mutex
	cmds []core.Command
}

func (m *Memory) Load() ([]core.Command, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]core.Command(nil), m.cmds...), nil
}
func (m *Memory) Append(c core.Command) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cmds = append(m.cmds, c)
	return nil
}
func (m *Memory) Reset() (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cmds = nil
	return "", nil
}
func (m *Memory) Close() error { return nil }
