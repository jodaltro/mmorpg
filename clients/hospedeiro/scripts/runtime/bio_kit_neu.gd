class_name BioKitNeu
extends BioKit
## The neutrophil, o Armadilheiro: the first to arrive. It squeezes through the bodies in its way (diapedesis) and, when the fight is
## worth it, sets off its oxidative burst: everything runs twice as fast, and the cell pays for it with its own membrane.


func kinds() -> Array[String]:
	return ["phase", "frenzy"]


func find(_kind: String, _a: Dictionary, _origin: Vector2, _aim: Vector2) -> Array:
	return [host]


func cast(kind: String, _id: StringName, def: BioAttackDef, a: Dictionary, _aim: Vector2, color: Color, _targets: Array) -> void:
	match kind:
		"phase":
			_phase(def, a, color)
		"frenzy":
			_frenzy(a, color)


## For a moment the cell is a thread: bodies do not stop it, it runs faster, takes half of what hits it, and stings whoever it passes through.
func _phase(def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var me := host.combatant
	var seconds := float(a["seconds"])
	host.ghost(seconds)
	me.haste(float(a["speed"]), seconds, 0.0)
	me.guard(float(a["taken"]), seconds)
	body.elastic(Vector2.RIGHT, 0.0, 0.5, 0.0)
	body.swell(0.8, seconds)
	var trail := BioPfx.trail(host, color, 14.0, 36)
	var stung := {}
	var until := BioClock.now() + seconds
	while BioClock.now() < until and _alive():
		for e in BioTargeting.enemies(host.get_world_2d(), host.global_position, 0.9 * BioArt.UNIT, _team()):
			if not stung.has(e):
				stung[e] = true
				BioStrike.land(host, e, def, host.global_position, color)
				BioSignature.play(&"scar", e.global_position, color, 0.6, {"dir": host.velocity.normalized()}, null)
		await get_tree().physics_frame
	BioPfx.stop(trail)
	if is_instance_valid(host):
		body.swell(1.0, 0.1)


## The respiratory burst: cooldowns run faster, the cell runs faster, and it burns (never to death) until it ends.
func _frenzy(a: Dictionary, color: Color) -> void:
	var me := host.combatant
	var seconds := float(a["seconds"])
	me.begin_frenzy(seconds, float(a["rate"]), float(a["burn"]))
	me.haste(float(a["speed"]), seconds, 0.0)
	body.swell(1.2, 0.3)
	BioPfx.ring_burst(BioFx.root, host.global_position, color, 90.0, 28, 0.5, 11.0)
	limbs.radial(8, 1.2, 0.1, seconds * 0.6, {"tint": color, "sweep": 0.0, "style": {"tip": &"fork", "base": 6.0, "tip_w": 3.0, "stiffness": 0.2, "wave": 1.0}})
	BioHalo.ring(host, color, func() -> bool: return is_instance_valid(host) and me.is_frenzied())
