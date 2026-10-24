class_name BioFuse
extends Node2D
## The globs of unstable histamine stuck to one enemy. Every glob is a granule on its rim that swells and beats faster as the fuse runs
## down; when it ends (or the enemy dies) they all go off at once, and each one past the first makes the blast bigger.

var owner_cell: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.62, 0.2)
var radius_px := 100.0
var stack_bonus := 0.6
var stacks := 1

var _total := 2.2
var _left := 2.2
var _victim: BioCellActor
var _gone := false


## Sticks a glob to `target`: a new fuse, or one more stack on the fuse this cell already lit there.
static func stick(target: BioCellActor, owner: BioCellActor, p_def: BioAttackDef, seconds: float, p_radius_px: float, bonus: float, p_color: Color) -> BioFuse:
	for child in target.get_children():
		var existing := child as BioFuse
		if existing != null and existing.owner_cell == owner and not existing._gone:
			existing.stacks += 1
			existing._left = minf(existing._total, existing._left + 0.5)
			BioPfx.burst(BioFx.root, target.global_position, p_color, 6, 100.0, 0.3, 8.0)
			return existing
	var f := BioFuse.new()
	f.owner_cell = owner
	f.def = p_def
	f.color = p_color
	f.radius_px = p_radius_px
	f.stack_bonus = bonus
	f._total = seconds
	f._left = seconds
	f._victim = target
	f.z_index = 13
	f.material = BioArt.additive()
	target.add_child(f)
	target.combatant.died.connect(func(_who: BioCombatant) -> void: f._burst())  # it goes off with the corpse
	return f


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_burst()
		return
	queue_redraw()


## The blast the fuse holds now: the base blow, and more for every stack past the first.
func blast_damage() -> float:
	return def.damage * (1.0 + stack_bonus * (stacks - 1))


func _burst() -> void:
	if _gone:
		return
	_gone = true
	if is_instance_valid(owner_cell) and is_instance_valid(_victim):
		var at := _victim.global_position
		var blow := BioStrike.with_damage(def, blast_damage())
		BioPfx.ring_burst(BioFx.root, at, color, radius_px * 0.9, 34, 0.45, 11.0)
		BioPfx.burst(BioFx.root, at, color.lerp(Color.WHITE, 0.4), 18 + stacks * 4, 260.0, 0.5, 11.0)
		BioFx.shake(0.1 + 0.03 * stacks)
		for e in BioTargeting.enemies(_victim.get_world_2d(), at, radius_px, owner_cell.combatant.actor.team):
			BioStrike.land(owner_cell, e, blow, at, color)
	queue_free()


func _draw() -> void:
	var urgency := 1.0 - clampf(_left / _total, 0.0, 1.0)
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * (6.0 + 22.0 * urgency))
	var rim := 26.0
	for k in stacks:
		var a := k * TAU / maxf(stacks, 3.0) + 0.6
		var p := Vector2.from_angle(a) * rim
		draw_circle(p, 8.0 + 4.0 * beat * urgency, BioArt.with_alpha(color, 0.25 + 0.3 * urgency))
		draw_circle(p, 4.0 + 1.5 * beat, BioArt.with_alpha(color.lerp(Color.WHITE, 0.5 + 0.4 * beat), 0.95))
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU * (1.0 - urgency), 40, BioArt.with_alpha(color, 0.18 + 0.2 * urgency), 1.6, true)  # the blast, closing like a clock
