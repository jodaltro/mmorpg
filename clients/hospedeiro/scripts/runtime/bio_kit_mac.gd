class_name BioKitMac
extends BioKit
## The macrophage, o Devorador: it does not run from a blow, it makes the blow expensive, and it changes what kind of fighter it is: M1
## fights and burns, M2 mends.

var _stance_halo: BioHalo


func kinds() -> Array[String]:
	return ["counter", "stance"]


func configure(p_host: BioCellActor, p_aim: BioCellController, p_limbs: BioLimbs, p_body: BioCellBody) -> void:
	super.configure(p_host, p_aim, p_limbs, p_body)
	host.combatant.countered.connect(_on_countered)


func find(_kind: String, _a: Dictionary, _origin: Vector2, _aim: Vector2) -> Array:
	return [host]


func cast(kind: String, _id: StringName, _def: BioAttackDef, a: Dictionary, _aim: Vector2, color: Color, _targets: Array) -> void:
	match kind:
		"counter":
			_counter(a, color)
		"stance":
			_stance(a)


## The membrane hardens into plates for a moment: whoever strikes takes most of its own blow back, and is shaken.
func _counter(a: Dictionary, color: Color) -> void:
	var me := host.combatant
	me.begin_counter(float(a["seconds"]), float(a["taken"]), float(a["reflect"]), float(a["heal"]))
	body.swell(1.18, float(a["seconds"]))
	limbs.radial(10, 1.1, 0.1, float(a["seconds"]) * 0.8, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "base": 20.0, "tip_w": 18.0, "stiffness": 0.9, "wave": 0.03, "barbs": 3}})
	BioHalo.ring(host, color, func() -> bool: return is_instance_valid(host) and me.is_countering())


func _on_countered(attacker: BioCombatant) -> void:
	body.elastic(Vector2.UP, 0.0, 0.5, 0.0)
	BioFx.shake(0.1)
	var cell := attacker.get_parent() as BioCellActor
	if cell != null:
		BioStrike.beam(host.global_position, cell.global_position, Color(1.0, 0.75, 0.55), 12.0, 0.2)


## Each press changes the form: plain, then M1 (hits hard, sets what it hits alight, takes more), then M2 (hits softly, takes less, mends),
## then plain again.
func _stance(a: Dictionary) -> void:
	var me := host.combatant
	var current := me.stance_now()
	var next: StringName = &"m1" if current == &"" else &"m2" if current == &"m1" else &""
	me.set_stance(next, float(a["seconds"]) if next != &"" else 0.0, float(a["power"]))
	body.swell(1.25, 0.3)
	if is_instance_valid(_stance_halo):
		_stance_halo.queue_free()
	if next == &"":
		BioPfx.ring_burst(BioFx.root, host.global_position, Color(0.8, 0.8, 0.8), 60.0, 16, 0.4, 8.0)
		return
	var tint := Color(1.0, 0.35, 0.3) if next == &"m1" else Color(0.4, 1.0, 0.6)
	BioPfx.ring_burst(BioFx.root, host.global_position, tint, 80.0, 24, 0.5, 10.0, next == &"m2")
	_stance_halo = BioHalo.ring(host, tint, func() -> bool: return is_instance_valid(host) and me.stance_now() == next)
