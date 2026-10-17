#!/usr/bin/env python3
"""Valdoria Terrain Agent v1: deterministic semantic 2D/3-4 terrain authoring.

Only writes to a new output directory. Produces diagnostic previews, not
production-quality environment sprites, Unity scenes, hydrology or weather.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

VERSION = "terrain-agent/1.0.0"
MATERIALS = {
    "grass": (91, 111, 65),
    "forest": (61, 85, 60),
    "dirt": (136, 108, 76),
    "mud": (89, 83, 65),
    "sand": (159, 137, 92),
    "rock": (102, 103, 99),
}
OUTPUTS = ("region.json", "height.png", "terrain-preview.png")


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(payload):
    return hashlib.sha256(payload).hexdigest()


def read_json(path):
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream)


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def validate(recipe, patch=None):
    if recipe.get("schema") != "valdoria-terrain-recipe/v1":
        raise ValueError("Unsupported recipe schema")
    w, h = recipe.get("size", [0, 0])
    if not all(type(v) is int and 16 <= v <= 256 for v in (w, h)):
        raise ValueError("size must be two integers in [16,256]")
    if type(recipe.get("seed")) is not int:
        raise ValueError("seed must be an integer")
    if not 0 < float(recipe.get("cellSizeUnits", 0)) <= 8:
        raise ValueError("cellSizeUnits outside (0,8]")
    if not isinstance(recipe.get("regionId"), str) or not recipe["regionId"]:
        raise ValueError("regionId required")
    if not 0 <= float(recipe.get("baseElevation", -1)) <= 1:
        raise ValueError("baseElevation outside [0,1]")
    for feature in recipe.get("features", []):
        if feature.get("kind") not in ("hill", "valley", "plateau"):
            raise ValueError("Unknown terrain feature")
        if len(feature["center"]) != 2 or len(feature["radius"]) != 2 or min(feature["radius"]) <= 0:
            raise ValueError("Invalid feature coordinates/radii")
        if feature["kind"] == "plateau" and not 0 <= feature.get("targetElevation", -1) <= 1:
            raise ValueError("plateau targetElevation outside [0,1]")
    for zone in recipe.get("protectedZones", []):
        if len(zone.get("rect", [])) != 4 or zone["rect"][2] <= 0 or zone["rect"][3] <= 0:
            raise ValueError("Invalid protected rectangle")
        if not 0 <= zone.get("targetElevation", -1) <= 1:
            raise ValueError("Invalid protected zone elevation")
    route = recipe.get("route", {})
    if route and (len(route.get("points", [])) < 2 or route.get("halfWidth", 0) <= 0):
        raise ValueError("Route requires two points and positive halfWidth")
    if patch is not None:
        if patch.get("schema") != "valdoria-terrain-patch/v1":
            raise ValueError("Unsupported patch schema")
        for op in patch.get("operations", []):
            if op.get("kind") not in ("raise", "lower", "flatten", "paint"):
                raise ValueError("Unsupported patch operation")
            if len(op.get("center", [])) != 2 or op.get("radius", 0) <= 0:
                raise ValueError("Invalid patch brush")
            if op["kind"] == "paint" and op.get("material") not in MATERIALS:
                raise ValueError("Unsupported material")
            if op["kind"] == "flatten" and not 0 <= op.get("targetElevation", -1) <= 1:
                raise ValueError("Invalid flatten elevation")


def lattice(seed, x, y):
    raw = f"{seed}:{x}:{y}".encode("ascii")
    return int.from_bytes(hashlib.sha256(raw).digest()[:8], "big") / 18446744073709551615.0


def noise(seed, x, y):
    ix, iy = math.floor(x), math.floor(y)
    tx, ty = x - ix, y - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = lattice(seed, ix, iy) * (1 - tx) + lattice(seed, ix + 1, iy) * tx
    b = lattice(seed, ix, iy + 1) * (1 - tx) + lattice(seed, ix + 1, iy + 1) * tx
    return a * (1 - ty) + b * ty


def fractal(seed, x, y, scale=0.075):
    value, weight, total = 0.0, 0.0, 0.0
    for octave in range(4):
        amp = 0.55 ** octave
        value += amp * noise(seed + octave * 7919, x * scale * (2 ** octave), y * scale * (2 ** octave))
        weight += amp
    return (value / weight - 0.5) * 2


def brush(x, y, center, radius):
    dx, dy = (x - center[0]) / radius[0], (y - center[1]) / radius[1]
    return math.exp(-3.0 * (dx * dx + dy * dy))


def segment_distance(x, y, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = clamp(((x - a[0]) * dx + (y - a[1]) * dy) / max(1e-8, dx * dx + dy * dy))
    return math.hypot(x - (a[0] + t * dx), y - (a[1] + t * dy))


def generate(recipe, patch=None):
    validate(recipe, patch)
    w, h = recipe["size"]
    seed = recipe["seed"]
    heights, reserved, in_route = [], [], []
    for y in range(h):
        row, protected_row, route_row = [], [], []
        for x in range(w):
            elevation = recipe["baseElevation"] + 0.29 * fractal(seed, x, y)
            for f in recipe.get("features", []):
                effect = brush(x, y, f["center"], f["radius"])
                if f["kind"] == "hill":
                    elevation += f.get("strength", 0.30) * effect
                elif f["kind"] == "valley":
                    elevation -= abs(f.get("strength", 0.25)) * effect
                else:
                    elevation += (f["targetElevation"] - elevation) * effect
            if patch:
                for op in patch.get("operations", []):
                    weight = math.exp(-3 * ((x - op["center"][0]) ** 2 + (y - op["center"][1]) ** 2) / (op["radius"] ** 2))
                    if op["kind"] == "raise":
                        elevation += abs(op.get("strength", 0.1)) * weight
                    elif op["kind"] == "lower":
                        elevation -= abs(op.get("strength", 0.1)) * weight
                    elif op["kind"] == "flatten":
                        elevation += (op["targetElevation"] - elevation) * weight
            is_protected = False
            for zone in recipe.get("protectedZones", []):
                zx, zy, zw, zh = zone["rect"]
                if zx <= x < zx + zw and zy <= y < zy + zh:
                    elevation = zone["targetElevation"]
                    is_protected = True
            road = recipe.get("route", {})
            on_road = False
            if road:
                d = min(segment_distance(x, y, a, b) for a, b in zip(road["points"], road["points"][1:]))
                on_road = d <= road["halfWidth"]
                if on_road:
                    elevation = road.get("targetElevation", recipe["baseElevation"])
            row.append(clamp(elevation))
            protected_row.append(is_protected or on_road)
            route_row.append(on_road)
        heights.append(row)
        reserved.append(protected_row)
        in_route.append(route_row)

    layers = {k: [] for k in ("elevationMilli", "slopeMilli", "moistureMilli", "material", "walkable", "waterCandidate", "reserved")}
    counts = {k: 0 for k in MATERIALS}
    for y in range(h):
        for x in range(w):
            elevation = heights[y][x]
            dx = (heights[y][min(x + 1, w - 1)] - heights[y][max(x - 1, 0)]) / (2 if 0 < x < w - 1 else 1)
            dy = (heights[min(y + 1, h - 1)][x] - heights[max(y - 1, 0)][x]) / (2 if 0 < y < h - 1 else 1)
            slope = math.hypot(dx, dy)
            moisture = clamp(0.47 + 0.32 * fractal(seed + 121831, x, y, 0.045) + 0.24 * (0.5 - elevation))
            candidate = elevation < recipe.get("waterCandidateBelow", 0.24) and not reserved[y][x]
            material = "rock" if elevation > 0.72 or slope > 0.14 else (
                "mud" if moisture > 0.62 and elevation < 0.33 else (
                "sand" if elevation < 0.27 else ("forest" if moisture > 0.59 else "grass")))
            if in_route[y][x]:
                material = "dirt"
            if patch and not reserved[y][x]:
                for op in patch.get("operations", []):
                    if op["kind"] == "paint" and math.hypot(x - op["center"][0], y - op["center"][1]) <= op["radius"]:
                        material = op["material"]
            walk = reserved[y][x] or (not candidate and slope <= 0.16 and elevation <= 0.8)
            layers["elevationMilli"].append(round(elevation * 1000))
            layers["slopeMilli"].append(round(slope * 1000))
            layers["moistureMilli"].append(round(moisture * 1000))
            layers["material"].append(material)
            layers["walkable"].append(bool(walk))
            layers["waterCandidate"].append(bool(candidate))
            layers["reserved"].append(bool(reserved[y][x]))
            counts[material] += 1

    result = {
        "schema": "valdoria-world-region/v1", "generator": VERSION,
        "regionId": recipe["regionId"], "seed": seed, "size": [w, h],
        "cellSizeUnits": recipe["cellSizeUnits"],
        "coordinates": "row-major top-left; Unity world Y increases upward; worldY=(height-1-row)*cellSizeUnits",
        "layers": layers,
        "summary": {"materials": counts, "walkable": sum(layers["walkable"]), "waterCandidates": sum(layers["waterCandidate"])}
    }
    return result


def render(region):
    w, h = region["size"]
    layer = region["layers"]
    elevation = Image.new("L", (w, h))
    elevation.putdata([round(v * 255 / 1000) for v in layer["elevationMilli"]])
    size = 12
    preview = Image.new("RGB", (w * size, h * size))
    draw = ImageDraw.Draw(preview)
    for i, material in enumerate(layer["material"]):
        x, y = i % w, i // w
        rgb = MATERIALS[material]
        shading = int((layer["elevationMilli"][i] - 500) / 55)
        color = tuple(max(0, min(255, c + shading)) for c in rgb)
        x0, y0 = x * size, y * size
        draw.rectangle((x0, y0, x0 + size - 1, y0 + size - 1), fill=color)
        if layer["waterCandidate"][i]:
            draw.rectangle((x0 + 2, y0 + 2, x0 + size - 3, y0 + size - 3), outline=(75, 110, 137))
        if not layer["walkable"][i] and not layer["waterCandidate"][i]:
            draw.line((x0 + 2, y0 + 2, x0 + size - 3, y0 + size - 3), fill=(62, 63, 65), width=1)
        if layer["reserved"][i]:
            draw.point((x0 + size // 2, y0 + size // 2), fill=(218, 197, 132))
    return elevation, preview


def write_output(recipe, patch, output):
    output = Path(output).resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite {output}")
    region = generate(recipe, patch)
    output.mkdir(parents=True)
    height, preview = render(region)
    (output / "region.json").write_bytes(canonical(region) + b"\n")
    height.save(output / "height.png")
    preview.save(output / "terrain-preview.png")
    manifest = {
        "schema": "valdoria-terrain-build/v1", "generator": VERSION,
        "recipeSha256": digest(canonical(recipe)), "patchSha256": digest(canonical(patch)) if patch else None,
        "outputs": {name: digest((output / name).read_bytes()) for name in OUTPUTS},
        "status": "diagnostic-only-not-production-art"
    }
    (output / "manifest.json").write_bytes(canonical(manifest) + b"\n")
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("inspect", "generate", "verify"))
    parser.add_argument("--recipe", type=Path, required=True)
    parser.add_argument("--patch", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    recipe = read_json(args.recipe)
    patch = read_json(args.patch) if args.patch else None
    validate(recipe, patch)
    if args.command == "inspect":
        print(json.dumps({"valid": True, "regionId": recipe["regionId"], "size": recipe["size"],
                          "seed": recipe["seed"], "features": len(recipe.get("features", [])),
                          "patchOperations": len(patch.get("operations", [])) if patch else 0}, indent=2))
        return 0
    if args.output is None:
        parser.error("--output is required for generate and verify")
    if args.command == "generate":
        manifest = write_output(recipe, patch, args.output)
        print(json.dumps(manifest, indent=2))
        return 0
    if not args.output.is_dir():
        raise FileNotFoundError(args.output)
    published = read_json(args.output / "manifest.json")
    with tempfile.TemporaryDirectory(prefix="valdoria-terrain-verify-") as tmp:
        expected = write_output(recipe, patch, Path(tmp) / "generated")
    ok = expected == published and all(
        digest((args.output / name).read_bytes()) == expected["outputs"][name] for name in OUTPUTS
    )
    print(json.dumps({"valid": ok, "regionId": recipe["regionId"], "expected": expected["outputs"]}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
