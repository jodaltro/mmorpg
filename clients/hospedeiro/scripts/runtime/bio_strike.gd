class_name BioStrike
extends RefCounted
## What every ability shares: landing a blow (the domain rules decide what it does) and the lance of light a few of them draw.


## Lands `def` on `target` for `host`: knockback and sparks when it hurts. Returns the result, or null when the target cannot be hit.
static func land(host: BioCellActor, target: BioCellActor, def: BioAttackDef, from: Vector2, color: Color) -> BioHitResult:
	if not BioCombatRules.can_hit(host.combatant.actor, target.combatant.actor):
		return null
	var result := target.combatant.receive_hit(host.combatant, def)
	if result.outcome == BioActor.HitOutcome.HIT or result.outcome == BioActor.HitOutcome.KILLED:
		if def.knockback > 0.0:
			target.apply_impulse((target.global_position - from).normalized() * def.knockback)
		BioPfx.burst(BioFx.root, target.global_position, color, 16, 220.0, 0.5, 11.0)
	return result


## The same attack with another damage (a blow that grows with something).
static func with_damage(def: BioAttackDef, damage: float) -> BioAttackDef:
	return BioAttackDef.new(def.id, def.atp_cost, damage, def.cooldown, def.range_units, def.knockback, def.invulnerable_seconds)


## A lance of light that thins and fades: a wide soft stroke under a white-hot core.
static func beam(from: Vector2, to: Vector2, color: Color, width_px: float, seconds: float = 0.35) -> void:
	var soft := Line2D.new()
	soft.points = PackedVector2Array([from, to])
	soft.width = width_px
	soft.default_color = BioArt.with_alpha(color, 0.5)
	soft.begin_cap_mode = Line2D.LINE_CAP_ROUND
	soft.end_cap_mode = Line2D.LINE_CAP_ROUND
	soft.material = BioArt.additive()
	soft.z_index = 16
	var core := Line2D.new()
	core.points = soft.points
	core.width = width_px * 0.3
	core.default_color = Color(1, 1, 1, 0.95)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	soft.add_child(core)
	BioFx.root.add_child(soft)
	var tween := soft.create_tween()
	tween.set_parallel(true)
	tween.tween_property(soft, "modulate:a", 0.0, seconds)
	tween.tween_property(soft, "width", 0.0, seconds)
	tween.chain().tween_callback(soft.queue_free)


## The first wall between two points (or `to` when the way is clear), so nothing is thrown through the membrane.
static func clear_point(world: World2D, from: Vector2, to: Vector2, margin_px: float = 0.0) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, to, BioCellActor.LAYER_WALL)
	var found := world.direct_space_state.intersect_ray(query)
	if found.is_empty():
		return to
	var at: Vector2 = found["position"]
	return at - (to - from).normalized() * margin_px
