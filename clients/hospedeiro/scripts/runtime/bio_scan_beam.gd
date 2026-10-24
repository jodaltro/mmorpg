class_name BioScanBeam
extends Node2D
## The dendritic cell's sweep: a beam of light that comes out of the cell and follows the aim, slowly, for a few seconds, burning what it
## crosses. The cell moves slowly while it holds, and the beam can only turn so fast: it is aimed by leading, not by flicking.

var host: BioCellActor
var aim_source: BioCellController
var def: BioAttackDef
var color := Color(0.5, 0.95, 1.0)
var seconds := 2.6
var range_px := 360.0
var width_px := 22.0
var turn := 2.2  # radians per second
var tick := 0.2

var _age := 0.0
var _clock := 0.0
var _dir := Vector2.RIGHT
var _end := Vector2.ZERO


static func open(parent: Node, owner: BioCellActor, aim: BioCellController, p_def: BioAttackDef, a: Dictionary, p_color: Color) -> BioScanBeam:
	var b := BioScanBeam.new()
	b.host = owner
	b.aim_source = aim
	b.def = p_def
	b.color = p_color
	b.seconds = float(a["seconds"])
	b.range_px = float(a["range"]) * BioArt.UNIT
	b.width_px = float(a["width"]) * BioArt.UNIT
	b.turn = float(a["turn"])
	b.tick = float(a["every"])
	b._dir = aim.aim if aim != null else Vector2.RIGHT
	b.z_index = 15
	b.material = BioArt.additive()
	parent.add_child(b)
	b.global_position = owner.global_position
	owner.slow(0.55, b.seconds)
	return b


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= seconds or not is_instance_valid(host) or not host.combatant.actor.vitals.is_alive():
		if is_instance_valid(host):
			host.slow(1.0, 0.01)
		queue_free()
		return
	global_position = host.global_position
	var want := aim_source.aim if aim_source != null else _dir
	_dir = _dir.rotated(clampf(_dir.angle_to(want), -turn * delta, turn * delta))
	_end = BioStrike.clear_point(get_world_2d(), global_position, global_position + _dir * range_px)
	_clock -= delta
	if _clock <= 0.0:
		_clock = tick
		var team := host.combatant.actor.team
		for e in BioTargeting.enemies(get_world_2d(), (global_position + _end) * 0.5, global_position.distance_to(_end) * 0.5 + width_px, team):
			if BioTargeting.distance_to_segment(e.global_position, global_position, _end) <= width_px:
				BioStrike.land(host, e, def, global_position, color)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((seconds - _age) / 0.3, 0.0, 1.0) * clampf(_age / 0.1, 0.0, 1.0)
	var to := _end - global_position
	var side := to.orthogonal().normalized()
	draw_line(Vector2.ZERO, to, BioArt.with_alpha(color, 0.25 * fade), width_px * 1.6, true)
	draw_line(Vector2.ZERO, to, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5), 0.55 * fade), width_px * 0.5, true)
	draw_line(Vector2.ZERO, to, BioArt.with_alpha(Color.WHITE, 0.95 * fade), 2.4, true)
	for k in 9:  # the sweep: bars that travel along the beam
		var f := fposmod(_age * 1.6 + k / 9.0, 1.0)
		var at := to * f
		draw_line(at - side * width_px * 0.8, at + side * width_px * 0.8, BioArt.with_alpha(color.lerp(Color.WHITE, 0.6), (1.0 - f) * 0.8 * fade), 1.6, true)
	draw_circle(to, 7.0 + 3.0 * sin(_age * 14.0), BioArt.with_alpha(Color.WHITE, 0.8 * fade))
