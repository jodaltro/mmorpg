class_name BioSqueeze
extends Node2D
## The cytotoxic T cell's synapse, held to the end: the victim is dragged in front of the cell and kept there, unable to act, while the
## squeeze tightens (every beat harder than the one before). If the victim is nearly dead when it ends, it is finished; the cell moves
## slowly while it holds, and the grip breaks if the two are pulled too far apart.

var host: BioCellActor
var victim: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.25, 0.3)
var seconds := 2.0
var step := 6.0  # more damage with every beat
var finish_below := 0.3
var leash_px := 300.0
var hold_px := 62.0

var _age := 0.0
var _clock := 0.0
var _beats := 0


static func grip(owner: BioCellActor, target: BioCellActor, p_def: BioAttackDef, a: Dictionary, p_color: Color) -> BioSqueeze:
	var s := BioSqueeze.new()
	s.host = owner
	s.victim = target
	s.def = p_def
	s.color = p_color
	s.seconds = float(a["seconds"])
	s.step = float(a["step"])
	s.finish_below = float(a["finish_below"])
	s.leash_px = float(a["leash"]) * BioArt.UNIT
	s.z_index = 13
	s.material = BioArt.additive()
	target.add_child(s)
	target.combatant.stun(s.seconds + 0.2)
	target.cancel_dash()
	owner.slow(0.45, s.seconds)
	return s


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(host) or not is_instance_valid(victim) or not host.combatant.actor.vitals.is_alive() or not victim.combatant.actor.vitals.is_alive():
		_release(false)
		return
	var gap := victim.global_position - host.global_position
	if gap.length() > leash_px:
		_release(false)
		return
	var spot := host.global_position + gap.normalized() * hold_px  # kept right in front of the cell
	victim.move_and_collide((spot - victim.global_position).limit_length(420.0 * delta))
	victim.combatant.stun(0.25)
	_clock -= delta
	if _clock <= 0.0:
		_clock = 0.25
		_beats += 1
		BioStrike.land(host, victim, BioStrike.with_damage(def, def.damage + step * _beats), host.global_position, color)
		BioFx.shake(0.04 + 0.01 * _beats)
	if _age >= seconds:
		_release(true)


func _release(finished: bool) -> void:
	if is_instance_valid(host):
		host.slow(1.0, 0.01)
	if finished and is_instance_valid(victim) and is_instance_valid(host):
		var v := victim.combatant.actor.vitals
		if v.is_alive() and v.membrane / v.max_membrane <= finish_below:  # nearly dead: the synapse finishes it
			BioStrike.land(host, victim, BioStrike.with_damage(def, v.membrane + 1.0), host.global_position, color)
			BioSignature.play(&"pore", victim.global_position, color, 1.2, {}, null)
		BioPfx.burst(BioFx.root, victim.global_position, color, 16, 220.0, 0.5, 10.0)
	if is_instance_valid(victim):
		victim.combatant._stun_until = 0.0
	queue_free()


func _draw() -> void:
	var tight := clampf(_age / seconds, 0.0, 1.0)
	var r := 38.0 - 14.0 * tight
	var fade := clampf((seconds - _age) / 0.2, 0.0, 1.0)
	for k in 8:  # jaws closing in on the victim
		var a := k * TAU / 8.0 + _age * 0.8
		var tip := Vector2.from_angle(a) * r
		var root := Vector2.from_angle(a) * (r + 18.0)
		var side := Vector2.from_angle(a + PI * 0.5) * 3.0
		draw_primitive(PackedVector2Array([root + side, tip, root - side]), PackedColorArray([BioArt.with_alpha(color, 0.3 * fade), BioArt.with_alpha(Color.WHITE, 0.9 * fade), BioArt.with_alpha(color, 0.3 * fade)]), PackedVector2Array())
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, BioArt.with_alpha(color.lerp(Color.WHITE, 0.4), (0.5 + 0.4 * tight) * fade), 2.2, true)
	var beat := 0.5 + 0.5 * sin(_age * 25.0)
	draw_circle(Vector2.ZERO, 5.0 + 3.0 * beat * tight, BioArt.with_alpha(Color.WHITE, 0.8 * fade))
