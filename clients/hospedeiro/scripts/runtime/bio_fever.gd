class_name BioFever
extends Node2D
## A fever that catches. The enemy it lands on burns for a while, and after a beat it gives the fever to the nearest enemy that does not
## have it yet (a few times in a row), so a pack lights up like a fuse. It is the body's own cure turned against the invaders.

var owner_cell: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.55, 0.25)
var left := 5.0
var hops := 3
var spread_after := 1.2
var hop_px := 260.0

var _victim: BioCellActor
var _tick := 0.0
var _passed := false
var _age := 0.0
var _flash := 0.0
var _flash_to := Vector2.ZERO


## Gives `target` the fever (or renews it, when it already burns). Returns it.
static func catch_on(target: BioCellActor, owner: BioCellActor, p_def: BioAttackDef, a: Dictionary, hops_left: int, p_color: Color) -> BioFever:
	for child in target.get_children():
		var existing := child as BioFever
		if existing != null:
			existing.left = float(a["seconds"])
			return existing
	var f := BioFever.new()
	f.owner_cell = owner
	f.def = p_def
	f.color = p_color
	f.left = float(a["seconds"])
	f.hops = hops_left
	f.spread_after = float(a["spread"])
	f.hop_px = float(a["hop"]) * BioArt.UNIT
	f._victim = target
	f.z_index = 12
	f.material = BioArt.additive()
	target.add_child(f)
	return f


func _process(delta: float) -> void:
	_age += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if not is_instance_valid(owner_cell) or not is_instance_valid(_victim) or not _victim.combatant.actor.vitals.is_alive():
		queue_free()
		return
	left -= delta
	if left <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		BioStrike.land(owner_cell, _victim, def, _victim.global_position, color)
	if not _passed and hops > 0 and _age >= spread_after:
		_passed = true
		_pass_on()
	queue_redraw()


## The nearest enemy without the fever, within reach, catches it.
func _pass_on() -> void:
	var best: BioCellActor = null
	for e in BioTargeting.enemies(_victim.get_world_2d(), _victim.global_position, hop_px, owner_cell.combatant.actor.team):
		if e == _victim or e.get_children().any(func(c: Node) -> bool: return c is BioFever):
			continue
		if best == null or e.global_position.distance_to(_victim.global_position) < best.global_position.distance_to(_victim.global_position):
			best = e
	if best == null:
		return
	var a := {"seconds": left + 1.0, "spread": spread_after, "hop": hop_px / BioArt.UNIT}
	catch_on(best, owner_cell, def, a, hops - 1, color)
	_flash = 1.0
	_flash_to = best.global_position - _victim.global_position
	BioPfx.burst(BioFx.root, best.global_position, color, 12, 150.0, 0.4, 9.0)


func _draw() -> void:
	var fade := clampf(left / 0.5, 0.0, 1.0)
	for k in 7:  # embers rising off the fever, and the shimmer of heat
		var f := fposmod(_age * 0.7 + k / 7.0, 1.0)
		var at := Vector2(sin(k * 2.3 + _age * 2.0) * 14.0, -10.0 - f * 34.0)
		draw_circle(at, 3.0 * (1.0 - f) + 1.0, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), (1.0 - f) * 0.9 * fade))
	draw_arc(Vector2.ZERO, 30.0 + 2.0 * sin(_age * 6.0), 0.0, TAU, 28, BioArt.with_alpha(color, 0.35 * fade), 2.0, true)
	if _flash > 0.0:
		draw_line(Vector2.ZERO, _flash_to * (1.0 - _flash), BioArt.with_alpha(Color.WHITE, 0.9 * _flash), 3.0, true)
