class_name BioKitEos
extends BioKit
## The eosinophil, the Caça-Colossos: it latches onto the big ones and corrodes them from inside, freezes a monster in crystal to save up
## the blows for a blast, grows with every kill, and, curled into a ball, bounces through the room.

var _growing := false


func kinds() -> Array[String]:
	return ["tether", "crystal", "grow", "roll"]


func configure(p_host: BioCellActor, p_aim: BioCellController, p_limbs: BioLimbs, p_body: BioCellBody) -> void:
	super.configure(p_host, p_aim, p_limbs, p_body)
	host.combatant.grew.connect(_on_grew)


func find(kind: String, a: Dictionary, origin: Vector2, aim: Vector2) -> Array:
	if kind == "grow" or kind == "roll":
		return [host]
	return super.find(kind, a, origin, aim)


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, targets: Array) -> void:
	match kind:
		"tether":
			_tether(def, a, color, targets[0] as BioCellActor)
		"crystal":
			_crystal(def, a, color, targets[0] as BioCellActor)
		"grow":
			_grow(a, color)
		"roll":
			_roll(def, a, aim, color)


## A hooked limb flies to the enemy and the rope holds.
func _tether(def: BioAttackDef, a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.12, 0.35, {"tint": color, "style": {"tip": &"fork", "base": 10.0, "tip_w": 5.0, "stiffness": 0.5}})
	body.elastic(target.global_position - host.global_position, 0.25, 0.4, 0.08)
	await _wait(0.12)
	if _alive() and is_instance_valid(target) and target.combatant.actor.vitals.is_alive():
		BioTether.spawn(host.get_parent(), host, target, def, a, color)


## A spike of protein pierces the enemy and the crystal grows over it.
func _crystal(def: BioAttackDef, a: Dictionary, color: Color, target: BioCellActor) -> void:
	limbs.reach_node(target, float(a["range"]) + 0.5, 0.14, 0.3, {"tint": color, "style": {"tip": &"spear", "stiffness": 0.95, "wave": 0.03, "barbs": 2}})
	body.elastic(target.global_position - host.global_position, 0.2, 0.5, 0.1)
	await _wait(0.16)
	if _alive() and is_instance_valid(target) and target.combatant.actor.vitals.is_alive():
		BioCrystal.grow(host, target, def, a, color)


## Every kill within the time makes the cell bigger and harder-hitting (and mends it a little); when the time is up it shrinks back.
func _grow(a: Dictionary, color: Color) -> void:
	var me := host.combatant
	me.begin_growth(float(a["seconds"]), int(a["stacks"]), float(a["dmg_per"]), float(a["heal_per"]))
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 70.0, 20, 0.5, 9.0, true)
	if _growing:
		return
	_growing = true
	var per := float(a["size_per"])
	while _alive() and BioClock.now() < me.growth_ends_at():
		var want := 1.0 + per * me.growth_stacks()
		host.scale = host.scale.lerp(Vector2.ONE * want, 0.12)
		await get_tree().physics_frame
	_growing = false
	if is_instance_valid(host):
		var tween := host.create_tween()
		tween.tween_property(host, "scale", Vector2.ONE, 0.4)


func _on_grew(stacks: int) -> void:
	if not _growing and stacks <= 1:
		return
	body.swell(1.3, 0.25)
	BioPfx.burst(BioFx.root, host.global_position, Color(1.0, 0.45, 0.4), 12 + 3 * stacks, 220.0, 0.5, 10.0)


## The cell curls into a ball, takes less from what hits it, and bounces: off walls, and off the enemies it damages on the way.
func _roll(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	var me := host.combatant
	var seconds := float(a["seconds"])
	me.guard(float(a["taken"]), seconds)
	body.swell(0.9, seconds)
	var last_hit := {}
	var on_bump := func(collider: Object, normal: Vector2) -> void:
		var other := collider as BioCellActor
		if other == null:
			BioPfx.burst(BioFx.root, host.global_position - normal * 0.5 * BioArt.UNIT, color, 6, 160.0, 0.3, 8.0, normal, 50.0)
			body.elastic(normal, 0.0, 0.3, 0.0)
			return
		var now := BioClock.now()
		if float(last_hit.get(other, -1.0)) > now - 0.3:
			return
		last_hit[other] = now
		BioStrike.land(host, other, def, host.global_position, color)
		BioFx.shake(0.1)
		body.elastic(normal, 0.0, 0.4, 0.0)
	host.bumped.connect(on_bump)
	host.roll(aim, float(a["speed"]), seconds, float(a["steer"]))
	var trail := BioPfx.trail(host, color, 16.0, 30)
	await _wait(seconds)
	if is_instance_valid(host):
		host.end_roll()
		host.bumped.disconnect(on_bump)
	BioPfx.stop(trail)
