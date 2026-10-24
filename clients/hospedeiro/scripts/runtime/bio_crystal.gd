class_name BioCrystal
extends Node2D
## A Charcot-Leyden crystal grown around an enemy. Inside it the enemy cannot move or act and nothing hurts it: every blow it takes is
## kept instead. When the crystal gives, all that was kept is thrown out at once, in a blast that hurts everything near it, the enemy
## included, for more than what was kept. Hit the thing you froze, then stand where the others are.

var owner_cell: BioCellActor
var victim: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.45, 0.4)
var seconds := 3.0
var bank_mult := 1.5
var radius_px := 120.0

var _age := 0.0
var _gone := false
var _seed := randf() * 10.0


## Encases `target`. Returns the crystal.
static func grow(owner: BioCellActor, target: BioCellActor, p_def: BioAttackDef, a: Dictionary, p_color: Color) -> BioCrystal:
	var c := BioCrystal.new()
	c.owner_cell = owner
	c.victim = target
	c.def = p_def
	c.color = p_color
	c.seconds = float(a["seconds"])
	c.bank_mult = float(a["bank"])
	c.radius_px = float(a["radius"]) * BioArt.UNIT
	target.combatant.encase(c.seconds)
	target.cancel_dash()
	c.z_index = 12
	c.material = BioArt.additive()
	target.add_child(c)
	BioPfx.burst(BioFx.root, target.global_position, p_color.lerp(Color.WHITE, 0.4), 18, 180.0, 0.5, 9.0)
	return c


func _process(delta: float) -> void:
	_age += delta
	if _age >= seconds or not is_instance_valid(victim) or not victim.combatant.is_encased():
		_shatter()
		return
	queue_redraw()


## The crystal gives: what it kept (and the base blow) goes out around it.
func _shatter() -> void:
	if _gone:
		return
	_gone = true
	if is_instance_valid(victim) and is_instance_valid(owner_cell):
		var kept := victim.combatant.release_stasis()
		var at := victim.global_position
		var blow := BioStrike.with_damage(def, def.damage + kept * bank_mult)
		BioPfx.ring_burst(BioFx.root, at, color, radius_px * 0.9, 40, 0.5, 12.0)
		BioPfx.burst(BioFx.root, at, color.lerp(Color.WHITE, 0.5), 30, 320.0, 0.6, 11.0)
		for k in 8:  # shards flying out
			BioPfx.burst(BioFx.root, at, Color.WHITE, 2, 360.0, 0.5, 8.0, Vector2.from_angle(k * TAU / 8.0), 12.0)
		BioFx.shake(0.18)
		for e in BioTargeting.enemies(victim.get_world_2d(), at, radius_px, owner_cell.combatant.actor.team):
			BioStrike.land(owner_cell, e, blow, at, color)
	queue_free()


func _draw() -> void:
	var grow_in := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((seconds - _age) / 0.3, 0.0, 1.0)
	var kept := clampf(victim.combatant.stasis_bank() / 80.0, 0.0, 1.0) if is_instance_valid(victim) else 0.0
	var glow := 0.4 + 0.5 * kept + 0.1 * sin(_age * (4.0 + 14.0 * kept))
	for k in 9:  # bipyramids: the shape of the crystal the eosinophil's own protein makes
		var a := k * TAU / 9.0 + _seed
		var len := (30.0 + 12.0 * sin(k * 2.3 + _seed)) * grow_in
		var wide := 6.0 + 2.0 * (k % 3)
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * wide
		var base := dir * 16.0
		var tip := dir * (16.0 + len)
		draw_primitive(PackedVector2Array([base + side, tip, base - side]), PackedColorArray([BioArt.with_alpha(color, 0.35 * fade), BioArt.with_alpha(Color.WHITE, glow * fade), BioArt.with_alpha(color, 0.35 * fade)]), PackedVector2Array())
		draw_line(base, tip, BioArt.with_alpha(Color.WHITE, 0.6 * glow * fade), 1.4, true)
	draw_circle(Vector2.ZERO, 30.0 * grow_in, BioArt.with_alpha(color, (0.10 + 0.22 * kept) * fade))
	draw_arc(Vector2.ZERO, radius_px * (0.25 + 0.75 * kept), 0.0, TAU, 32, BioArt.with_alpha(color, 0.18 * fade), 1.4, true)  # how far the blast would reach now
