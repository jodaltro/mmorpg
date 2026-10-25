class_name BioNetPreview
extends Node2D
## Speculative graphics only. No combatant, collision, damage, collection or rewards.
var world: BioWorld
var shots: Array[Dictionary] = []
var visual_count := 0

func play(id: StringName, aim: Vector2, token: int) -> void:
	visual_count += 1
	var cell := world.player
	var runner := world.abilities
	var color := BioArt.TOXIN
	var body := runner._body
	var definition := cell.combatant.actor.attack_def(id)
	if id == BioAttackCatalog.FLAGELLUM_LASH:
		for target in _targets():
			var to := target.global_position - cell.global_position
			if to.length() < (definition.range_units + 0.5) * BioArt.UNIT and absf(aim.angle_to(to)) < deg_to_rad(75): _impact(target)
	elif id == BioAttackCatalog.TOXIN_SPIT:
		shot(cell.global_position + aim * 0.7 * BioArt.UNIT, aim, 14, definition.range_units, color, token)
		body.elastic(-aim, 0.1, 0.2, 0.04)
	elif id == BioAttackCatalog.MEMBRANE_DASH:
		BioFx.ring(cell.global_position, 0.5, BioArt.DEEP_BLUE)
	elif BioAbilityCatalog.has(id):
		var ability := BioAbilityCatalog.get_ability(id)
		if cell.combatant.genome != null: ability = cell.combatant.genome.tune(id, ability)
		color = ability.get("color", BioArt.CYAN)
		var kind := str(ability.get("kind", ""))
		body.elastic(aim, 0.16, 0.3, 0.05)
		body.swell(1.12, 0.12)
		match kind:
			"cone", "devour": runner._limbs.fan(aim, 4, 60, float(ability.get("range", 2)), 0.08, 0.16, {"tint":color})
			"pierce", "dash_strike", "execute", "leap": runner._limbs.reach(aim, float(ability.get("range", 2)), 0.06, 0.18, {"tint":color})
			"bolt", "sticky", "beam": shot(cell.global_position + aim * 0.7 * BioArt.UNIT, aim, float(ability.get("speed", 16)), float(ability.get("range", 9)), color, token)
			_: BioFx.ring(cell.global_position, 0.7, color)

func shot(origin: Vector2, direction: Vector2, speed: float, reach: float, tint: Color, token: int) -> void:
	shots.append({"point":origin,"previous":origin,"velocity":direction.normalized()*speed*BioArt.UNIT,"remaining":reach*BioArt.UNIT,"color":tint,"token":token})

func cancel(token: int) -> void:
	shots = shots.filter(func(item: Dictionary) -> bool: return int(item.token) != token)

func _process(delta: float) -> void:
	if shots.is_empty(): return
	var targets := _targets()
	for item in shots:
		item.previous = item.point
		var travel: Vector2 = item.velocity * minf(delta, 0.05)
		item.point += travel
		item.remaining -= travel.length()
		for target in targets:
			if BioTargeting.distance_to_segment(target.global_position, item.previous, item.point) <= 0.65 * BioArt.UNIT:
				_impact(target)
				item.remaining = 0
				break
	shots = shots.filter(func(item: Dictionary) -> bool: return float(item.remaining) > 0)
	queue_redraw()

func _targets() -> Array[BioCellActor]:
	var result: Array[BioCellActor] = []
	for node in world.get_tree().get_nodes_in_group("cells"):
		if node is BioCellActor and node.is_active() and node.get_world_2d() == world.player.get_world_2d() and node.combatant.team() != world.player.combatant.team(): result.append(node)
	return result

func _impact(target: BioCellActor) -> void:
	for child in target.get_children():
		if child is BioCellBody: child.flash()  # provisional contact, never a damage number or health change

func _draw() -> void:
	for item in shots:
		var point: Vector2 = to_local(item.point)
		var color: Color = item.color
		draw_line(point - (item.velocity as Vector2).normalized() * 18, point, Color(color, 0.5), 4, true)
		draw_circle(point, 5, color)
		draw_circle(point, 2, Color.WHITE)
