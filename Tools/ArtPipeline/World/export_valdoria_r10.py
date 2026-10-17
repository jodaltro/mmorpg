"""Crop named, transparent production sprites from the layered Aseprite R10 source."""
from pathlib import Path
import hashlib, json, subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-r10-detail.aseprite"
OUT = ROOT / "Assets/Mmorpg/Art/Experimental/ValdoriaEnvironmentR10Detail"
REF = Path(r"C:\Users\Administrator\.codex\generated_images\01a14283-d9b2-79f0-b3a2-841f7b92e442\exec-f4dde60b-3233-41a6-bec2-de865c7e9020.png")
ITEMS = {
    "meadow-tile": (0, 0, 512, 512, (0.5, 0.5), "16x16 seamless meadow floor tile"),
    "village-road": (512, 0, 512, 512, (0.5, 0.5), "16x16 winding stone-and-earth route overlay"),
    "forest-stream": (1024, 0, 512, 256, (0.5, 0.5), "16x8 transparent stream overlay"),
    "cottage-walls": (0, 512, 320, 256, (0.5, 0.03), "stone/timber cottage facade with 3-unit door"),
    "cottage-roof": (320, 512, 384, 192, (0.5, 0.03), "separate overhanging shingle roof layer"),
    "oak-crown": (704, 512, 256, 256, (0.5, 0.08), "large canopy, upper foliage behind actors"),
    "oak-trunk": (1024, 256, 128, 160, (0.5, 0.08), "trunk and roots with ground pivot"),
    "footbridge": (1160, 512, 320, 128, (0.5, 0.25), "timber footbridge with stone abutments"),
    "village-well": (320, 704, 128, 160, (0.5, 0.05), "stone well and oak winch"),
    "market-cart": (448, 832, 192, 128, (0.5, 0.05), "loaded village handcart"),
    "timber-fence": (0, 800, 320, 96, (0.5, 0.05), "modular rail fence"),
    "village-bench": (640, 832, 128, 80, (0.5, 0.08), "oak village bench"),
    "flower-patch": (800, 832, 128, 80, (0.5, 0.05), "bluebell/marigold flowers"),
    "moss-boulders": (0, 896, 160, 96, (0.5, 0.05), "moss-capped stone cluster"),
    "berry-shrub": (960, 768, 192, 144, (0.5, 0.05), "flowering bush"),
    "village-sign": (1152, 832, 96, 128, (0.5, 0.04), "painted village signpost"),
    "iron-lantern": (1280, 832, 64, 128, (0.5, 0.03), "amber iron lantern"),
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = ROOT / "Temp/valdoria-r10-atlas.png"
    exe = subprocess.run([r"D:\Aseprite\Aseprite.exe", "-b", str(SOURCE), "--save-as", str(atlas)], check=True, capture_output=True, text=True)
    if not atlas.is_file():
        raise RuntimeError(f"Aseprite did not export atlas: {exe.stdout} {exe.stderr}")
    with Image.open(atlas) as raw:
        raw = raw.convert("RGBA")
        if raw.size != (1536, 1024):
            raise ValueError(f"Unexpected atlas size: {raw.size}")
        records = []
        for name, (x, y, w, h, pivot, description) in ITEMS.items():
            path = OUT / f"{name}.png"
            if path.exists():
                raise FileExistsError(f"Refusing to overwrite {path}")
            raw.crop((x, y, x+w, y+h)).save(path, optimize=False)
            with Image.open(path) as sprite:
                if sprite.size != (w, h) or sprite.mode != "RGBA":
                    raise ValueError(f"Bad export {path}: {sprite.mode} {sprite.size}")
                alpha = sprite.getchannel("A").getextrema()
                if name != "meadow-tile" and alpha[0] == 255:
                    raise ValueError(f"Expected transparent framing for {name}")
            records.append({"id": name, "file": path.name, "canvas": [w,h], "ppu": 32, "pivotNormalizedBottomLeft": list(pivot), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "description": description, "source": "ArtSource/Labs/World2026/R10/Aseprite/valdoria-village-r10-detail.aseprite"})
    manifest = {"schema": "valdoria-environment-kit/v1", "status": "experimental-integrated-for-gameplay-review", "artSource": "hand-authored pixel clusters in layered Aseprite Lua; generated LLM image is concept-only", "license": "original local project art; generated reference retained for provenance", "ppu": 32, "filter": "Point", "items": records}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    if REF.is_file():
        refs = ROOT / "ArtSource/References/Generated"
        refs.mkdir(parents=True, exist_ok=True)
        dest = refs / "ValdoriaVillageR10-Concept.png"
        if not dest.exists():
            dest.write_bytes(REF.read_bytes())
        manifest["conceptReference"] = str(dest.relative_to(ROOT)).replace("\\", "/")
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"atlas": [1536,1024], "sprites": len(records), "output": str(OUT), "conceptCopied": (REF.is_file())}, indent=2))

if __name__ == "__main__":
    main()
