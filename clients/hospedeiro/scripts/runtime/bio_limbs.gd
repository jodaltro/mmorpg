class_name BioLimbs
extends Node
## The cell's way of reaching out. It reads the body (form, procedural look, genes) and grows BioLimb chains from the
## membrane: the basic lash is whatever this body would lash with, and class abilities borrow the same limbs so
## they look like THIS body doing them. It also gives the body its elastic recoil.

const MAX_LIMBS := 28

var _host: BioCellActor
var _body: BioCellBody
var _sign := 1.0


func configure(host: BioCellActor, body: BioCellBody) -> void:
	_host = host
	_body = body


func body() -> BioCellBody:
	return _body


## The current procedural style of this body's limbs.
func style() -> Dictionary:
	return BioLimbStyle.for_body(_body.form, _body.look_now, _body.genes)


## How wide the basic lash reaches, from the form (a lance is narrow, a macrophage's arm is wide).
func lash_half_angle() -> float:
	return float(style()["half_angle"])


func _count() -> int:
	return get_tree().get_nodes_in_group("limbs").size() if is_inside_tree() else 0


func _spawn(dir: Vector2, length_units: float, grow: float, hold: float, opts: Dictionary) -> BioLimb:
	if _count() >= MAX_LIMBS:
		return null
	var limb := BioLimb.new()
	limb.style = style()
	if opts.has("style"):
		limb.style.merge(opts["style"], true)
	limb.host = _host
	limb.body = _body
	limb.core = _body.core
	limb.edge = _body.edge
	limb.tint = opts.get("tint", Color(0, 0, 0, 0))
	limb.body_radius_px = _body.radius_units * BioArt.UNIT * 1.0
	limb.length_px = length_units * BioArt.UNIT
	limb.aim = dir.normalized()
	limb.grow_time = grow
	limb.hold_time = hold
	limb.follow = opts.get("follow")
	var sweep := float(opts.get("sweep", limb.style.get("sweep", 0.0)))
	if sweep > 0.0 and limb.follow == null:
		_sign = -_sign
		var half := deg_to_rad(sweep) * 0.5
		limb.sweep_from = dir.angle() - half * _sign
		limb.sweep_to = dir.angle() + half * _sign
		limb.sweep_time = grow + hold * 0.6
	limb.add_to_group("limbs")
	_host.add_child(limb)
	return limb


## One limb towards `dir` (world direction). `hold < 0` keeps it out until released.
var signature: StringName = &""  # the flavour Jev designed for this cell's effects (BioEffectSignature)


func reach(dir: Vector2, length_units: float, grow: float = 0.12, hold: float = 0.2, opts: Dictionary = {}) -> BioLimb:
	return _spawn(dir, length_units, grow / maxf(float(style()["speed"]), 0.3), hold, BioEffectSignature.sign_options(opts, signature))


## A limb that follows a moving node and stretches to it.
func reach_node(target: Node2D, max_length_units: float, grow: float = 0.14, hold: float = 0.25, opts: Dictionary = {}) -> BioLimb:
	var o := BioEffectSignature.sign_options(opts, signature)
	o["follow"] = target
	return _spawn(target.global_position - _host.global_position, max_length_units, grow, hold, o)


func fan(dir: Vector2, count: int, spread_deg: float, length_units: float, grow: float = 0.12, hold: float = 0.2, opts: Dictionary = {}) -> Array[BioLimb]:
	var out: Array[BioLimb] = []
	for i in count:
		var k := 0.0 if count == 1 else (i / float(count - 1) - 0.5)
		var a := dir.rotated(deg_to_rad(spread_deg) * k)
		var o := opts.duplicate()
		o["sweep"] = float(opts.get("sweep", 0.0))
		var limb := reach(a, length_units * (1.0 - 0.12 * absf(k)), grow, hold, o)
		if limb != null:
			limb.intensity = clampf(sqrt(2.0 / count), 0.5, 1.0)
			out.append(limb)
	return out


func radial(count: int, length_units: float, grow: float = 0.12, hold: float = 0.25, opts: Dictionary = {}) -> Array[BioLimb]:
	var out: Array[BioLimb] = []
	var phase := randf() * TAU
	for i in count:
		var o := opts.duplicate()
		o["sweep"] = float(opts.get("sweep", 0.0))
		var limb := reach(Vector2.from_angle(phase + i * TAU / count), length_units * randf_range(0.85, 1.1), grow, hold, o)
		if limb != null:
			limb.intensity = clampf(sqrt(3.0 / count), 0.35, 1.0)
			out.append(limb)
	return out


## The basic lash, as this body would do it. The cone that damages is decided by the executor and the domain;
## this is what the body does while it happens.
func lash(dir: Vector2, reach_units: float) -> void:
	var s := style()
	var length := reach_units + 0.25
	var half := float(s["half_angle"])
	var count := int(s["count"])
	if count > 1:
		fan(dir, count, half * 1.6, length, 0.1, 0.1, {"sweep": float(s["sweep"]) * 0.25})
	else:
		reach(dir, length, 0.09, 0.09, {"sweep": float(s["sweep"])})
	var rigid := float(s["stiffness"])
	_body.elastic(dir, 0.1 + 0.1 * (1.0 - rigid), 0.22 + 0.25 * (1.0 - rigid), 0.07)
