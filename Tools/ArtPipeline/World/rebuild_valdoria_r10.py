"""Rebuild the Valdoria R10 backdrop and module library from the Aseprite source.

Closes the reproducibility gap found in Phase 2: village-scene-v3.png (the map
that PromoteQuaterniusR10.cs copies into production) had no generating step.
It was verified to be exactly the top 800 rows of the R10 Aseprite document,
pixel-identical (mean diff 0.0, max 0) to:

    ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-detail-v3.aseprite

The earlier manifest pointed artSource at valdoria-llm-detail-clean.aseprite,
which differs from the backdrop by ~70/255 mean - it is a sibling, not the
parent. This script records the real chain and can verify it.

Usage:
    python Tools/ArtPipeline/World/rebuild_valdoria_r10.py --verify
    python Tools/ArtPipeline/World/rebuild_valdoria_r10.py --output <new-dir>

--verify exports the source to a temporary directory and compares against the
published assets without writing to them. --output writes to a NEW directory
and refuses to overwrite an existing one.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, sys, tempfile

ROOT = Path(__file__).resolve().parents[3]
ASEPRITE = Path(r"D:\Aseprite\Aseprite.exe")

# The canonical R10 document. Its top 800 rows are the production backdrop.
SOURCE = ROOT / "ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-detail-v3.aseprite"
BACKDROP_W, BACKDROP_H = 1536, 800

LIBRARY = ROOT / "Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Llm"
BACKDROP = LIBRARY / "village-scene-v3.png"
PRODUCTION = ROOT / "Assets/Mmorpg/Art/Production/ValdoriaEnvironment/ValdoriaVillageScene.png"

# Isolated props cropped from the cleaned sibling document by
# crop_valdoria_llm_aseprite.py. Rebuilt from the canonical manifest below.
PROP_SOURCE = ROOT / "ArtSource/Labs/World2026/R10/Aseprite/valdoria-llm-detail-clean.aseprite"


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def export_source(destination):
    """Export the Aseprite document to a PNG in a temporary location."""
    destination = Path(destination)
    if destination.exists():
        raise FileExistsError(f"Refusing to overwrite {destination}")
    if not ASEPRITE.is_file():
        raise FileNotFoundError(f"Aseprite not found at {ASEPRITE}")
    if not SOURCE.is_file():
        raise FileNotFoundError(f"R10 source missing: {SOURCE}")
    run = subprocess.run([str(ASEPRITE), "-b", str(SOURCE), "--save-as", str(destination)],
                         capture_output=True, text=True)
    if run.returncode or not destination.is_file():
        raise RuntimeError(f"Aseprite export failed: {run.stdout}\n{run.stderr}")
    return destination


def crop_backdrop(exported, destination):
    from PIL import Image
    with Image.open(exported) as raw:
        raw = raw.convert("RGBA")
        if raw.size != (1536, 1024):
            raise ValueError(f"Unexpected R10 canvas: {raw.size}")
        raw.crop((0, 0, BACKDROP_W, BACKDROP_H)).save(destination, optimize=False)
    return destination


def compare(a, b):
    """Pixel comparison. PNG encoding may differ; pixels must not."""
    from PIL import Image, ImageChops
    with Image.open(a) as ia, Image.open(b) as ib:
        ia = ia.convert("RGBA")
        ib = ib.convert("RGBA")
        if ia.size != ib.size:
            return {"sizeMatch": False, "a": ia.size, "b": ib.size}
        diff = ImageChops.difference(ia, ib)
        # RGBA.getbbox() can ignore RGB differences when alpha difference is 0.
        bbox = diff.convert("RGB").getbbox() or diff.getchannel("A").getbbox()
        return {"sizeMatch": True, "pixelIdentical": bbox is None, "diffBBox": bbox}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true",
                        help="Export to temp and compare with published assets (read-only).")
    parser.add_argument("--output", type=Path,
                        help="Write the rebuilt backdrop into a NEW directory.")
    args = parser.parse_args()
    if not args.verify and not args.output:
        parser.error("pass --verify or --output")

    if args.verify:
        tmp = Path(tempfile.mkdtemp(prefix="valdoria-r10-verify-"))
        try:
            exported = export_source(tmp / "source.png")
            rebuilt = crop_backdrop(exported, tmp / "backdrop.png")
            report = {
                "source": str(SOURCE.relative_to(ROOT)),
                "sourceSha256": sha256(SOURCE),
                "rebuiltBackdrop": str(rebuilt.name),
                "libraryBackdrop": compare(rebuilt, BACKDROP),
                "productionBackdrop": compare(rebuilt, PRODUCTION),
                "librarySha256": sha256(BACKDROP),
                "productionSha256": sha256(PRODUCTION),
                "propSource": str(PROP_SOURCE.relative_to(ROOT)),
                "propPipeline": "Tools/ArtPipeline/World/crop_valdoria_llm_aseprite.py",
            }
            report["modules"] = rebuild_modules(tmp / "modules", verify=True)
            print(json.dumps(report, indent=2))
            ok = (report["libraryBackdrop"].get("pixelIdentical") and
                  report["productionBackdrop"].get("pixelIdentical") and
                  all(row["pixelIdentical"] and row["publishedHashValid"] for row in report["modules"]))
            return 0 if ok else 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    out = args.output.resolve()
    if out.exists():
        raise FileExistsError(f"Refusing to overwrite existing directory: {out}")
    out.mkdir(parents=True)
    exported = export_source(out / "source.png")
    crop_backdrop(exported, out / "village-scene-v3.png")
    rebuild_modules(out / "modules", verify=False)
    print(json.dumps({"output": str(out), "backdropSha256": sha256(out / "village-scene-v3.png")}, indent=2))
    return 0


def rebuild_modules(out, verify):
    """Rebuild every published crop from its recorded source rectangle."""
    out.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((LIBRARY / "manifest.json").read_text(encoding="utf-8"))
    rows = []
    for asset in manifest["assets"]:
        destination = out / asset["file"]
        crop = ",".join(str(value) for value in asset["sourceCrop"])
        subprocess.run([str(ASEPRITE), "-b", str(PROP_SOURCE), "--crop", crop,
                        "--save-as", str(destination)], check=True, capture_output=True)
        if verify:
            published = LIBRARY / asset["file"]
            comparison = compare(destination, published)
            rows.append({"id": asset["id"], "pixelIdentical": comparison.get("pixelIdentical", False),
                         "publishedHashValid": sha256(published) == asset["sha256"],
                         "rebuiltSha256": sha256(destination)})
    return rows


if __name__ == "__main__":
    sys.exit(main())
