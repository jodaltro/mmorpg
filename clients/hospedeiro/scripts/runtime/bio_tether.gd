class_name BioTether
extends Node2D
## The eosinophil latches onto one enemy with a rope of granules. While it holds, the enemy is reeled in towards the cell and corroded
## by a share of its OWN life each second (so a colossus pays far more than a speck), until the time is up, the rope is stretched too far
## or either of them dies.

var owner_cell: BioCellActor
var target: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.32, 0.32)
var duration := 4.0
var pct := 0.06  # of the victim's maximum life, per second
var cap := 24.0  # most one second can take
var leash_px := 120.0  # it is reeled in until it is this close
var pull := 5.0  # units per second
var snap_px := 480.0  # beyond this the rope breaks

var _age := 0.0
var _tick := 0.0
var _seed := randf() * 10.0


static func spawn(parent: Node, owner: BioCellActor, victim: BioCellActor, p_def: BioAttackDef, a: Dictionary, p_color: Color) -> BioTether:
	var t := BioTether.new()
	t.owner_cell = owner
	t.target = victim
	t.def = p_def
	t.color = p_color
	t.duration = float(a["duration"])
	t.pct = float(a["pct"])
	t.cap = float(a["cap"])
	t.leash_px = float(a["leash"]) * BioArt.UNIT
	t.pull = float(a["pull"])
	t.snap_px = float(a["snap"]) * BioArt.UNIT
	parent.add_child(t)
	return t


func _ready() -> void:
	z_index = 9
	material = BioArt.additive()


func _alive() -> bool:
	return is_instance_valid(owner_cell) and is_instance_valid(target) and owner_cell.combatant.actor.vitals.is_alive() and target.combatant.actor.vitals.is_alive() and target.is_active()


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration or not _alive():
		_end()
		return
	var gap := target.global_position - owner_cell.global_position
	if gap.length() > snap_px:
		_end()
		return
	if gap.length() > leash_px:  # reeled in
		target.global_position += -gap.normalized() * minf(pull * BioArt.UNIT * delta, gap.length() - leash_px)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		var share := minf(target.combatant.actor.vitals.max_membrane * pct, cap) * 0.5
		BioStrike.land(owner_cell, target, BioStrike.with_damage(def, def.damage + share), owner_cell.global_position, color)
		BioPfx.burst(BioFx.root, target.global_position, color, 5, 90.0, 0.3, 7.0)
	queue_redraw()


func _end() -> void:
	if is_instance_valid(target):
		BioPfx.burst(BioFx.root, target.global_position, color, 10, 150.0, 0.4, 8.0)
	queue_free()


func _draw() -> void:
	if not _alive():
		return
	var a := owner_cell.global_position
	var b := target.global_position
	var fade := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var along := b - a
	var side := along.orthogonal().normalized()
	var points := PackedVector2Array()
	for i in 17:  # a rope that sags and sways, taut when the victim is far
		var f := i / 16.0
		var slack := clampf(1.0 - along.length() / maxf(snap_px, 1.0), 0.0, 1.0)
		var sag := sin(f * PI) * (10.0 + 24.0 * slack) * sin(_age * 3.0 + _seed)
		points.append(to_local(a + along * f + side * sag))
	draw_polyline(points, BioArt.with_alpha(color, 0.35 * fade), 7.0, true)
	draw_polyline(points, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.8 * fade), 2.0, true)
	for k in 7:  # granules sliding along it, towards the victim
		var f2 := fposmod(_age * 0.9 + k / 7.0, 1.0)
		var idx := int(f2 * 16.0)
		draw_circle(points[idx], 3.0 + 1.5 * sin(f2 * PI), BioArt.with_alpha(color.lerp(Color.WHITE, 0.7), 0.95 * fade))
	draw_arc(to_local(b), 22.0, _age * 2.0, _age * 2.0 + 4.0, 12, BioArt.with_alpha(color, 0.8 * fade), 2.4, true)
