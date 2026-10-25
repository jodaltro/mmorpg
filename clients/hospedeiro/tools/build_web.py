"""Exports the browser build and prepares it to be served: python tools/build_web.py [out_dir]
Needs the Godot web export templates (see Docs/Hospedeiro/Online.md). Writes .br/.gz siblings next to the big files so the
server can send them as they are (the .wasm is 39 MB raw and about 8 MB in Brotli)."""
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else (HERE.parent.parent / "build" / "web")
GODOT = os.environ.get("GODOT", r"D:\tools\godot\bin\Godot_v4.7.2-stable_win64_console.exe")

OUT.mkdir(parents=True, exist_ok=True)
previous = {}
for old in OUT.glob('*.gz'):
    try:
        previous[old.name[:-3]] = (hashlib.sha256(gzip.decompress(old.read_bytes())).digest(), old.read_bytes(), old.with_suffix('.br').read_bytes())
    except (OSError, EOFError):
        pass
for old in OUT.iterdir():  # emptied, not removed: a server may be standing in the folder
    shutil.rmtree(old) if old.is_dir() else old.unlink()

run = subprocess.run([GODOT, "--headless", "--path", str(HERE), "--export-release", "Web", str(OUT / "index.html")], capture_output=True, text=True)
log = run.stdout + run.stderr
bad = [l for l in log.splitlines() if "ERROR" in l or "SCRIPT ERROR" in l]
if run.returncode != 0 or bad or not (OUT / "index.wasm").exists():
    print("\n".join(bad[:20]) or log[-2000:])
    sys.exit("export failed")

for name in ("manifest.webmanifest", "icon-192.png", "icon-512.png"):
    shutil.copy(HERE / "web" / name, OUT / name)

# The exact same deterministic Go core runs privately in a browser worker.
GO = os.environ.get("GO", r"D:\tools\go\bin\go.exe")
env = dict(os.environ, GOOS="js", GOARCH="wasm")
subprocess.run([GO, "build", "-trimpath", "-o", str(OUT / "worldsim-local.wasm"), "./cmd/worldsim-browser"], cwd=HERE.parents[1] / "engine", env=env, check=True)
goroot = Path(subprocess.check_output([GO, "env", "GOROOT"], text=True).strip())
shutil.copy(goroot / "lib" / "wasm" / "wasm_exec.js", OUT / "wasm_exec.js")
for name in ("personal.js", "personal-party.js", "personal-worker.js", "qrcode.js"):
    shutil.copy(HERE / "web" / name, OUT / name)
shutil.copy(HERE.parents[1] / "universes" / "hospedeiro" / "universe.json", OUT / "personal-universe.json")
shutil.copytree(HERE / "web" / "licenses", OUT / "licenses", dirs_exist_ok=True)
shutil.copy(goroot / "LICENSE", OUT / "licenses" / "Go-BSD.txt")

assets = sorted(f for f in OUT.iterdir() if f.is_file() and f.suffix not in ('.br', '.gz'))
digest = hashlib.sha256(b''.join(hashlib.sha256(f.read_bytes()).digest() for f in assets)).hexdigest()[:16]
service_worker = (HERE / 'web' / 'personal-sw.js').read_text(encoding='utf-8')
service_worker = service_worker.replace('__BUILD__', digest).replace('__ASSETS__', json.dumps(['/' + f.name for f in assets]))
(OUT / 'personal-sw.js').write_text(service_worker, encoding='utf-8')

try:
    import brotli
except ImportError:
    brotli = None
    print("brotli not installed: pip install brotli (only gzip siblings will be written)")

for f in sorted(OUT.iterdir()):
    if f.suffix not in (".wasm", ".js", ".pck", ".html", ".webmanifest", ".json"):
        continue
    raw = f.read_bytes()
    cached = previous.get(f.name)
    if cached and cached[0] != hashlib.sha256(raw).digest(): cached = None
    line = "%-22s %9.2f MB" % (f.name, len(raw) / 1e6)
    gz = cached[1] if cached else gzip.compress(raw, 9)
    (f.parent / (f.name + ".gz")).write_bytes(gz)
    line += "  gz %6.2f MB" % (len(gz) / 1e6)
    if brotli:
        br = cached[2] if cached else brotli.compress(raw, quality=11)
        (f.parent / (f.name + ".br")).write_bytes(br)
        line += "  br %6.2f MB" % (len(br) / 1e6)
    print(line)
print("ready:", OUT)
