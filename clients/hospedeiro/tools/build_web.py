"""Exports the browser build and prepares it to be served: python tools/build_web.py [out_dir]
Needs the Godot web export templates (see Docs/Hospedeiro/Online.md). Writes .br/.gz siblings next to the big files so the
server can send them as they are (the .wasm is 39 MB raw and about 8 MB in Brotli)."""
import gzip
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else (HERE.parent.parent / "build" / "web")
GODOT = os.environ.get("GODOT", r"D:\tools\godot\bin\Godot_v4.7.2-stable_win64_console.exe")

OUT.mkdir(parents=True, exist_ok=True)
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

try:
    import brotli
except ImportError:
    brotli = None
    print("brotli not installed: pip install brotli (only gzip siblings will be written)")

for f in sorted(OUT.iterdir()):
    if f.suffix not in (".wasm", ".js", ".pck", ".html", ".webmanifest"):
        continue
    raw = f.read_bytes()
    line = "%-22s %9.2f MB" % (f.name, len(raw) / 1e6)
    gz = gzip.compress(raw, 9)
    (f.parent / (f.name + ".gz")).write_bytes(gz)
    line += "  gz %6.2f MB" % (len(gz) / 1e6)
    if brotli:
        br = brotli.compress(raw, quality=11)
        (f.parent / (f.name + ".br")).write_bytes(br)
        line += "  br %6.2f MB" % (len(br) / 1e6)
    print(line)
print("ready:", OUT)
