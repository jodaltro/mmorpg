class_name BioAbilityZone
extends Node2D
## A lasting ability effect on the ground: the neutrophil's DNA net, a lattice of double helices that slows and wounds whatever is
## caught in it (and that a cell's designed behaviour can make wander after the enemies). Damage and states go through the same
## combat rules as everything else.

var owner_combatant: BioCombatant
var host: BioCellActor
var ability: StringName
var style := ""
var color := Color.WHITE
var radius_px := 100.0
var duration := 4.0
var follow := false
var tick_damage := 0.0  # damage per half second to enemies inside
var slow := 1.0  # movement multiplier applied to enemies inside (1 = none)
var drift := 0.0  # units per second towards the nearest enemy (the wandering zone)

var _age := 0.0
var _tick := 0.0
var _seed := randf() * 10.0
var _hit_def: BioAttackDef


static func spawn(parent: Node, host_cell: BioCellActor, id: StringName, pos: Vector2, params: Dictionary) -> BioAbilityZone:
	var z := BioAbilityZone.new()
	z.owner_combatant = host_cell.combatant
	z.host = host_cell
	z.ability = id
	z.style = str(params.get("style", ""))
	z.color = params.get("color", Color.WHITE)
	z.radius_px = float(params.get("radius", 2.5)) * BioArt.UNIT
	z.duration = float(params.get("duration", 4.0))
	z.follow = bool(params.get("follow", false))
	z.tick_damage = float(params.get("tick", 0.0))
	z.slow = float(params.get("slow", 0.0))
	z.slow = 1.0 - z.slow if z.slow > 0.0 else 1.0
	z.drift = float(params.get("drift", 0.0))
	z.position = pos
	parent.add_child(z)
	return z


func _ready() -> void:
	z_index = 6
	material = BioArt.additive()
	_hit_def = BioAttackDef.new(ability, 0.0, tick_damage, 0.0, 0.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if not is_instance_valid(owner_combatant):
		_finish()
		return
	_age += delta
	if drift > 0.0 and is_instance_valid(owner_combatant.get_parent()):
		var near := BioTargeting.enemies(get_world_2d(), global_position, 7.0 * BioArt.UNIT, owner_combatant.actor.team)
		var best := BioTargeting.best(near, global_position, Vector2.ZERO, 7.0 * BioArt.UNIT)
		if best != null:
			global_position = global_position.move_toward(best.global_position, drift * BioArt.UNIT * delta)
	if follow and is_instance_valid(host):
		global_position = host.global_position
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_pulse()
	if Engine.get_process_frames() % 2 == 0:  # a zone's drawing is detailed and slow-moving: every second frame is enough
		queue_redraw()
	if _age >= duration:
		_finish()


func _finish() -> void:
	queue_free()


## Half-second pulse: damage and slowing of everything inside.
func _pulse() -> void:
	if tick_damage <= 0.0 and slow >= 1.0:
		return
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_combatant.actor.team):
		if tick_damage > 0.0:
			e.combatant.receive_hit(owner_combatant, _hit_def)
		if slow < 1.0:
			e.slow(slow, 0.8)


func _c(a: float, lighten: float = 0.0) -> Color:
	return BioArt.with_alpha(color.lerp(Color.WHITE, lighten), a)


func _draw() -> void:
	var t := _age + _seed
	var grow := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var r := radius_px * grow
	if style == "acid":
		draw_circle(Vector2.ZERO, r, _c(0.08 * fade))
		for i in 4:
			var rr := r * (0.3 + 0.18 * i)
			draw_arc(Vector2.ZERO, rr, t * (0.3 + i * 0.1), t * (0.3 + i * 0.1) + TAU * 0.8, 32, _c(0.5 * fade), 2, true)
		for i in 9:
			var at := Vector2.from_angle(i * TAU / 9 + t * 0.2) * r * (0.3 + 0.5 * absf(sin(i + t)))
			draw_circle(at, 2 + sin(t * 3 + i), _c(0.7 * fade, 0.3))
		return
	_net(t, r, fade)


## The DNA net: seven spokes of twisting double strands joined by rungs, with four rings of knots that blink.
func _net(t: float, r: float, fade: float) -> void:
	var collapse := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var length := r * collapse
	var spokes := 7
	for i in spokes:
		var a := i * TAU / spokes + 0.1
		var dir := Vector2.from_angle(a)
		var perp := dir.orthogonal()
		var prev_a := Vector2.ZERO
		var prev_b := Vector2.ZERO
		var steps := int(length / 6.0)
		for s in range(1, steps + 1):
			var d := s * 6.0
			var amp := 3.0 * (1.0 + 0.25 * sin(t * 3.0 * TAU * 0.5 + i))
			var wave := sin(d / 8.0 * PI + t * 3.0) * amp
			var pa := dir * d + perp * wave
			var pb := dir * d - perp * wave
			draw_line(prev_a, pa, _c(0.75 * fade, 0.3), 1.4, true)
			draw_line(prev_b, pb, _c(0.75 * fade, 0.3), 1.4, true)
			if s % 2 == 0:
				draw_line(pa, pb, _c(0.3 * fade, 0.5), 1.0, true)
			prev_a = pa
			prev_b = pb
	for ring in 4:
		var rr := length * (0.25 + 0.25 * ring)
		var pts := PackedVector2Array()
		for i in spokes + 1:
			pts.append(Vector2.from_angle(i * TAU / spokes + 0.1) * rr * (1.0 + 0.02 * sin(t * 3.0 + i + ring)))
		draw_polyline(pts, _c(0.55 * fade, 0.3), 1.3, true)
		for i in spokes:
			var blink := 0.5 + 0.5 * sin(t * 2.0 + i * 1.7 + ring * 2.3)
			if blink > 0.7:
				draw_circle(pts[i], 2.2, _c(0.95 * fade, 0.8))
