"""Rebuild contextual depth layers in a NEW directory through local Aseprite.

These are aligned silhouette masks of the composition, not reusable isolated
props or inpainted terrain. The baked background remains the visual reference.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from rebuild_valdoria_r10 import export_source, crop_backdrop, compare, ASEPRITE


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists():
        raise FileExistsError(f"Refusing to overwrite {out}")
    out.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="valdoria-depth-") as tmp:
        temp = Path(tmp)
        flat = crop_backdrop(export_source(temp / "source.png"), temp / "backdrop.png")
        subprocess.run([str(ASEPRITE), "-b", str(flat),
                        "--script-param", f"recipe={ROOT / 'Docs/Art/ValdoriaWorldBlueprint.json'}",
                        "--script-param", f"output={out.as_posix()}",
                        "--script", str(Path(__file__).with_name("valdoria_depth.lua"))], check=True)
    report = []
    for path in sorted(out.glob("*.png")):
        row = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if args.verify:
            row.update(compare(path, ROOT / "Assets/Mmorpg/Art/Production/ValdoriaEnvironment/Depth" / path.name))
        report.append(row)
    (out / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if not args.verify or all(r.get("pixelIdentical") for r in report) else 1


if __name__ == "__main__":
    sys.exit(main())
