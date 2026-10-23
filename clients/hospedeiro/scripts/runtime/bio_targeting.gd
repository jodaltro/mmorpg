class_name BioTargeting
extends RefCounted
## Shared queries for abilities: who is near, in a cone, in a line, the best single target.


static func enemies(world: World2D, center: Vector2, radius_px: float, my_team: int) -> Array[BioCellActor]:
	var shape := CircleShape2D.new()
	shape.radius = radius_px
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = BioCellActor.LAYER_COMBATANT
	var out: Array[BioCellActor] = []
	for hit in world.direct_space_state.intersect_shape(query, 48):
		var cell := hit["collider"] as BioCellActor
		if cell != null and cell.is_active() and cell.combatant.actor.team != my_team and cell.combatant.actor.vitals.is_alive() and not out.has(cell):
			out.append(cell)
	return out


static func in_cone(list: Array[BioCellActor], origin: Vector2, aim: Vector2, range_px: float, half_deg: float) -> Array[BioCellActor]:
	var out: Array[BioCellActor] = []
	for c in list:
		var to := c.global_position - origin
		if to.length() - 0.5 * BioArt.UNIT <= range_px and rad_to_deg(absf(aim.angle_to(to))) <= half_deg:
			out.append(c)
	return out


## Distance from `p` to the segment a-b.
static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The best single target within range: closest to the aim line, then nearest.
static func best(list: Array[BioCellActor], origin: Vector2, aim: Vector2, range_px: float) -> BioCellActor:
	var best_cell: BioCellActor = null
	var best_score := INF
	for c in list:
		var to := c.global_position - origin
		var d := to.length()
		if d > range_px + 0.5 * BioArt.UNIT:
			continue
		var score := d + rad_to_deg(absf(aim.angle_to(to))) * 4.0
		if score < best_score:
			best_cell = c
			best_score = score
	return best_cell
