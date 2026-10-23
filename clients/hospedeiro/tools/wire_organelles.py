"""Wires the free-floating organelles into the body and the layer (one-off)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "scripts/runtime"


def sub(name, a, b):
    p = root / name
    s = p.read_text(encoding="utf-8", newline="")
    nl = "\r\n" if "\r\n" in s else "\n"
    a2, b2 = a.replace("\n", nl), b.replace("\n", nl)
    assert a2 in s, (name, a[:60])
    p.write_text(s.replace(a2, b2, 1), encoding="utf-8", newline="")


sub("bio_cell_body.gd", "var _pocket_layer: BioPocketLayer\n", """var _pocket_layer: BioPocketLayer
var _orgs := {}  # gene id -> {"p": Vector2, "v": Vector2, "rot": float, "spin": float, "seed": float}: the organelles floating inside
var _org_rng := RandomNumberGenerator.new()
""")
sub("bio_cell_body.gd", "func rim() -> PackedVector2Array:\n	return _rim\n", """func rim() -> PackedVector2Array:
	return _rim


## The organelles of the expressed mutations, floating freely inside the membrane.
func organelles() -> Dictionary:
	return _orgs


## Lets every organelle drift without aim: a slow random walk with drag, pushed apart from each other and from the nucleus,
## and always kept inside the membrane (a hard limit, so none can ever escape, however the body deforms or moves).
func _step_organelles(delta: float) -> void:
	delta = minf(delta, 0.05)
	for id in _orgs.keys():
		if not genes.has(id):
			_orgs.erase(id)
	var r := BioOrganelles.body_radius(_rim)
	for id in genes:
		if not _orgs.has(id):
			_orgs[id] = {"p": Vector2.from_angle(_org_rng.randf() * TAU) * r * _org_rng.randf_range(0.1, 0.45), "v": Vector2.ZERO, "rot": _org_rng.randf() * TAU, "spin": _org_rng.randf_range(-0.5, 0.5), "seed": _org_rng.randf() * 20.0}
	var list := genes.duplicate()
	var sizes := {}
	for id in list:
		sizes[id] = BioOrganelles.size_of(str(BioGeneCatalog.get_gene(id).mark.get("kind", "")), r)
	var accel := -(_smooth_velocity - _last_org_velocity) * 0.35  # a sudden push on the cell makes them lag behind
	_last_org_velocity = _smooth_velocity
	for id in list:
		var o: Dictionary = _orgs[id]
		var v: Vector2 = o["v"]
		v += Vector2(_org_rng.randf_range(-1.0, 1.0), _org_rng.randf_range(-1.0, 1.0)) * r * 1.6 * delta  # the aimless wander
		v += accel * 0.5
		v *= exp(-0.8 * delta)
		v = v.limit_length(r * 0.28)
		o["v"] = v
		o["p"] = (o["p"] as Vector2) + v * delta
		o["rot"] = float(o["rot"]) + float(o["spin"]) * delta
	for i in list.size():  # keep them off each other and off the nucleus
		var a: Dictionary = _orgs[list[i]]
		var pa: Vector2 = a["p"]
		var to_nuc := pa - _nuc_pos
		var min_nuc := _nuc_r * 1.05 + float(sizes[list[i]]) * 0.7
		if to_nuc.length() < min_nuc:
			var push := to_nuc.normalized() if to_nuc.length() > 0.01 else Vector2.RIGHT
			a["p"] = pa + push * (min_nuc - to_nuc.length()) * 0.5
			a["v"] = (a["v"] as Vector2) + push * r * 0.15
		for j in range(i + 1, list.size()):
			var b: Dictionary = _orgs[list[j]]
			var d: Vector2 = (a["p"] as Vector2) - (b["p"] as Vector2)
			var min_d := (float(sizes[list[i]]) + float(sizes[list[j]])) * 0.8
			if d.length() < min_d:
				var n := d.normalized() if d.length() > 0.01 else Vector2.from_angle(_org_rng.randf() * TAU)
				var shove := (min_d - d.length()) * 0.5
				a["p"] = (a["p"] as Vector2) + n * shove
				b["p"] = (b["p"] as Vector2) - n * shove
				a["v"] = (a["v"] as Vector2) + n * r * 0.08
				b["v"] = (b["v"] as Vector2) - n * r * 0.08
	for id in list:  # the membrane is a hard wall
		var o: Dictionary = _orgs[id]
		var p: Vector2 = o["p"]
		var limit := maxf(BioOrganelles.rim_radius_at(_rim, p.angle()) * 0.86 - float(sizes[id]) * 0.95, 0.0)
		if p.length() > limit:
			var n := p.normalized()
			o["p"] = n * limit
			var v: Vector2 = o["v"]
			if v.dot(n) > 0.0:
				o["v"] = v - n * v.dot(n) * 1.6  # bounces softly off the membrane
""")
sub("bio_cell_body.gd", "var _bulges := {}", "var _last_org_velocity := Vector2.ZERO\nvar _bulges := {}")
sub("bio_cell_body.gd", "	_pocket_layer.queue_redraw()\n", "	_step_organelles(delta)\n	_pocket_layer.queue_redraw()\n")

# the layer draws the floating organelles (normal blending, no backing discs)
(root / "bio_pocket_layer.gd").write_text('''class_name BioPocketLayer
extends Node2D
## Draws the organelles of the mutations floating inside the body, with NORMAL blending (the membrane itself is additive), so
## translucent fills and bright outlines read like fluorescence microscopy instead of adding up into a white glow.

var body: BioCellBody


func _ready() -> void:
	z_index = 11


func _draw() -> void:
	if body == null:
		return
	var rim := body.rim()
	var r := BioOrganelles.body_radius(rim)
	var t := Time.get_ticks_msec() * 0.001
	var orgs := body.organelles()
	for id in body.genes:
		if not orgs.has(id):
			continue
		var mark: Dictionary = BioGeneCatalog.get_gene(id).mark
		if mark.is_empty():
			continue
		var o: Dictionary = orgs[id]
		var size := BioOrganelles.size_of(str(mark.get("kind", "")), r)
		BioOrganelles.draw_organelle(self, mark, o["p"], size, t, float(o["rot"]), float(o["seed"]))
''', encoding="utf-8", newline="\n")
print("ok")
