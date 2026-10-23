"""E2 (exploration), client wiring: link_point in the anatomy, niche positions, the exploration node in the world, the compass,
the atlas fed by the engine and the host sync. One-off edits."""
from pathlib import Path

base = Path(__file__).resolve().parents[1]


def sub(rel, a, b):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (rel, a[:60])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


def append(rel, text):
    p = base / rel
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    p.write_text(s.rstrip("\r\n") + nl + text.replace("\n", nl), encoding="utf-8", newline="")


append("scripts/domain/bio_anatomy.gd", '''

## A point along a vessel (units) at fraction f of its length, the direction it runs there and its half width there.
static func link_point(seed_value: int, link_id: StringName, f: float) -> Dictionary:
	for l in build(seed_value)["links"]:
		if l["id"] == link_id:
			var path: PackedVector2Array = l["path"]
			var widths: PackedFloat32Array = l["widths"]
			var i := clampi(int(f * (path.size() - 1)), 0, path.size() - 2)
			return {"p": path[i], "dir": (path[i + 1] - path[i]).normalized(), "half_width": (widths[i] + widths[i + 1]) * 0.5}
	return {}
''')
append("scripts/runtime/bio_body_map.gd", '''

## Where a niche hides in its region (px): a fixed point, the same for everyone, away from the walls.
static func niche_px(id: String, region: StringName) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + id.hash()
	return BioAnatomy.random_point(seed_value, region, rng, 7.0) * BioArt.UNIT
''')

w = "scripts/runtime/bio_world.gd"
sub(w, "var atlas: BioAtlas\n", "var atlas: BioAtlas\nvar exploration: BioExploration\nvar compass_text := \"\"\n")
sub(w, "	vitals_panel = BioVitalsPanel.new()\n", "	exploration = BioExploration.new()\n	exploration.name = \"Exploration\"\n	add_child(exploration)\n	exploration.configure(player, seed_value)\n	vitals_panel = BioVitalsPanel.new()\n")
sub(w, """	else:
		hud.set_guide(false, Vector2.ZERO, "")
""", """	elif not dungeon.active and player.is_active() and exploration != null:
		var trail := exploration.compass(player.global_position, region)
		if trail.is_empty() or float(trail["distance"]) < 12.0:
			hud.set_guide(false, Vector2.ZERO, "")
		else:
			compass_text = str(trail["hint"])
			hud.set_guide(true, (trail["target"] as Vector2) - player.global_position, "rastro químico · %d" % roundi(float(trail["distance"])))
	else:
		hud.set_guide(false, Vector2.ZERO, "")
""")
a = "scripts/runtime/bio_atlas.gd"
sub(a, "func forget_all() -> void:", """## Regions the engine remembers this cell visited (silent: it is history, not news).
func merge(ids: Array) -> void:
	var changed := false
	for id in ids:
		var key := StringName(str(id))
		if not known.has(key) and BioAnatomy.region_def(key).size() > 0:
			known.append(key)
			changed = true
	if changed:
		_save()


func forget_all() -> void:""")
h = "scripts/runtime/bio_host_sync.gd"
sub(h, "	if view.get(\"vitals\") is Array:\n", "	if view.get(\"explore\") is Dictionary:\n		_world.exploration.apply(view[\"explore\"])\n	var visited: Array = []\n	for f in view.get(\"facts\", []):\n		if f.get(\"p\", \"\") == \"visitou\":\n			visited.append(f.get(\"o\", \"\"))\n	if not visited.is_empty():\n		_world.atlas.merge(visited)\n	if view.get(\"vitals\") is Array:\n")
sub(h, "	_world.region_changed.connect(_on_region)\n", "	_world.region_changed.connect(_on_region)\n	_world.exploration.niche_reached.connect(func(id: String) -> void:\n		if link.online:\n			link.occur(\"achar-nicho\", {\"niche\": id}))\n")
sub(h, "			\"mutated\":\n", "			\"nicho\":\n				_world.hud.show_banner(str(e.get(\"text\", \"\")))\n				_world.get_tree().create_timer(6.0).timeout.connect(func() -> void:\n					if is_instance_valid(_world.hud) and _world.hud.banner_text() == str(e.get(\"text\", \"\")):\n						_world.hud.show_banner(\"\"))\n			\"mutated\":\n")
print("ok")
