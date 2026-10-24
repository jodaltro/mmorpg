class_name BioSingularity
extends Node2D
## A point of tolerance that draws everything in. Enemies in its reach are pulled to the middle (through walls never, and stronger the
## closer they are) and kept there; when it collapses, whatever is still in the heart of it takes the blow, so the longer it held, the
## more it caught.

var owner_cell: BioCellActor
var def: BioAttackDef
var color := Color(0.5, 1.0, 0.8)
var radius_px := 260.0
var seconds := 2.2
var pull_speed := 8.0  # units per second at the edge
var core_px := 96.0  # the collapse hurts what is within this

var _age := 0.0
var _seed := randf() * 10.0


static func open(parent: Node, owner: BioCellActor, p_def: BioAttackDef, pos: Vector2, a: Dictionary, p_color: Color) -> BioSingularity:
	var s := BioSingularity.new()
	s.owner_cell = owner
	s.def = p_def
	s.position = pos
	s.color = p_color
	s.radius_px = float(a["radius"]) * BioArt.UNIT
	s.seconds = float(a["seconds"])
	s.pull_speed = float(a["pull"])
	s.core_px = float(a["core"]) * BioArt.UNIT
	parent.add_child(s)
	return s


func _ready() -> void:
	z_index = 7
	material = BioArt.additive()
	BioPfx.ring_burst(BioFx.root, global_position, color, radius_px * 0.9, 40, 0.5, 10.0, true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_cell):
		queue_free()
		return
	_age += delta
	if _age >= seconds:
		_collapse()
		return
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_cell.combatant.actor.team):
		var gap := global_position - e.global_position
		var dist := gap.length()
		if dist < 8.0:
			continue
		var nearness := 1.0 - clampf(dist / radius_px, 0.0, 1.0)
		e.move_and_collide(gap.normalized() * minf(pull_speed * BioArt.UNIT * (0.45 + 0.9 * nearness) * delta, dist))
		e.velocity *= 0.9
	queue_redraw()


func _collapse() -> void:
	BioPfx.ring_burst(BioFx.root, global_position, color, core_px * 1.4, 36, 0.45, 12.0)
	BioPfx.burst(BioFx.root, global_position, color.lerp(Color.WHITE, 0.6), 30, 300.0, 0.55, 11.0)
	BioFx.shake(0.16)
	for e in BioTargeting.enemies(get_world_2d(), global_position, core_px, owner_cell.combatant.actor.team):
		BioStrike.land(owner_cell, e, def, global_position, color)
	queue_free()


func _draw() -> void:
	var t := _age / seconds
	var fade := clampf((seconds - _age) / 0.25, 0.0, 1.0) * clampf(_age / 0.15, 0.0, 1.0)
	for k in 4:  # rings that fall inwards
		var f := fposmod(_age * 1.2 + k * 0.25, 1.0)
		draw_arc(Vector2.ZERO, radius_px * (1.0 - f), 0.0, TAU, 40, BioArt.with_alpha(color, 0.35 * f * fade), 2.0, true)
	for k in 14:  # motes spiralling in
		var f := fposmod(_age * 0.7 + k / 14.0, 1.0)
		var a := k * 1.7 + f * 5.0 + _seed
		draw_circle(Vector2.from_angle(a) * radius_px * (1.0 - f), 2.5 + 2.0 * f, BioArt.with_alpha(color.lerp(Color.WHITE, 0.6), 0.85 * f * fade))
	draw_circle(Vector2.ZERO, core_px * (0.4 + 0.5 * t), BioArt.with_alpha(color, 0.10 * fade))
	draw_circle(Vector2.ZERO, 11.0 + 5.0 * t, BioArt.with_alpha(Color.WHITE, 0.9 * fade))
	draw_arc(Vector2.ZERO, core_px, 0.0, TAU * t, 32, BioArt.with_alpha(color, 0.7 * fade), 2.0, true)  # the collapse, closing in
