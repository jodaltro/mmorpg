class_name BioMine
extends Node2D
## A granule of histamine the mast cell leaves in its wake. It arms, waits for an enemy to come close and goes off; and a granule that
## goes off sets off the ones near it, so a trail laid across a corridor is a fuse.

const TRIGGER_UNITS := 1.3

var owner_cell: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.62, 0.2)
var radius_px := 70.0  # the blast
var arm_time := 0.5
var lifetime := 12.0

var _age := 0.0
var _scan := 0.0
var _fuse := -1.0
var _seed := randf() * 10.0


static func spawn(parent: Node, owner: BioCellActor, p_def: BioAttackDef, pos: Vector2, radius_units: float, arm: float, life: float, p_color: Color) -> BioMine:
	var m := BioMine.new()
	m.owner_cell = owner
	m.def = p_def
	m.position = pos
	m.radius_px = radius_units * BioArt.UNIT
	m.arm_time = arm
	m.lifetime = life
	m.color = p_color
	parent.add_child(m)
	return m


func _ready() -> void:
	add_to_group("bio_mines")
	z_index = 10
	material = BioArt.additive()
	BioPfx.burst(BioFx.root, global_position, color, 6, 60.0, 0.3, 7.0)


func is_armed() -> bool:
	return _age >= arm_time


## Sets this granule off in `seconds` (a neighbour went off).
func trigger_in(seconds: float) -> void:
	if _fuse < 0.0:
		_fuse = seconds


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime or not is_instance_valid(owner_cell):
		queue_free()
		return
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			_detonate()
	elif is_armed():
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.1
			if not BioTargeting.enemies(get_world_2d(), global_position, TRIGGER_UNITS * BioArt.UNIT, owner_cell.combatant.actor.team).is_empty():
				trigger_in(0.08)
	queue_redraw()


func _detonate() -> void:
	remove_from_group("bio_mines")
	BioPfx.ring_burst(BioFx.root, global_position, color, radius_px * 0.85, 26, 0.4, 10.0)
	BioPfx.burst(BioFx.root, global_position, color.lerp(Color.WHITE, 0.4), 18, 260.0, 0.5, 10.0)
	BioFx.shake(0.08)
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_cell.combatant.actor.team):
		BioStrike.land(owner_cell, e, def, global_position, color)
	for node in get_tree().get_nodes_in_group("bio_mines"):
		var other := node as BioMine
		if other != null and other.global_position.distance_to(global_position) <= radius_px * 1.5:
			other.trigger_in(0.12)
	queue_free()


func _draw() -> void:
	var armed := is_armed()
	var pulse := 0.5 + 0.5 * sin(_age * (18.0 if _fuse >= 0.0 else 5.0 if armed else 2.0) + _seed)
	var fade := clampf((lifetime - _age) / 1.0, 0.0, 1.0)
	var dim := 1.0 if armed else 0.45
	draw_circle(Vector2.ZERO, 22.0, BioArt.with_alpha(color, 0.16 * fade * dim))
	for k in 6:  # the lumpy sac of a granule
		var a := k * TAU / 6.0 + _seed
		draw_circle(Vector2.from_angle(a) * 7.0, 6.0 + 0.8 * sin(_age * 2.0 + k), BioArt.with_alpha(color.darkened(0.15), 0.9 * fade * dim))
	draw_circle(Vector2.ZERO, 7.0, BioArt.with_alpha(color.lerp(Color.WHITE, 0.55), (0.7 + 0.3 * pulse) * fade * dim))
	if armed:
		draw_arc(Vector2.ZERO, TRIGGER_UNITS * BioArt.UNIT, 0.0, TAU, 28, BioArt.with_alpha(color, (0.22 + 0.2 * pulse) * fade), 1.8, true)
