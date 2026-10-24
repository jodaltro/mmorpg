class_name BioAbilityBolt
extends Area2D
## An antibody (or any bolt) in flight: a glowing head with a comet trail, optionally homing on the nearest enemy, drawn as a Y when it
## is an antibody. Damage comes from the domain definition, never from here. The shot itself can be designed by Jev (see
## BioProjectileDesign): how it flies, how big it is and what it does on arrival (pierce, burst, fragment, stick).

var _owner_combatant: BioCombatant
var _def: BioAttackDef
var _dir := Vector2.RIGHT
var _speed_px := 600.0
var _range_px := 500.0
var _color := Color.WHITE
var _homing := false
var _traveled := 0.0
var _trail: CPUParticles2D
var weave_phase := 0.0  # a salvo braids: neighbours swap sides as they fly
var weave_amp := 0.0
var _spin := 0.0
var _wake: Array = [[], []]  # the two arm tips draw a double thread behind
var _centre := Vector2.ZERO

var design := {}  # BioProjectileDesign.params of this shot (empty: the plain bolt)
var _path := ""
var _turn := 0.0  # radians per second of the "arco" trajectory
var _homing_radius := 4.0
var _homing_rate := 7.0
var _dmg_scale := 1.0  # a piercing shot weakens with every enemy it goes through
var _pierce_left := 0
var _fragment := false  # a fragment does not fragment again
var _ignore: Node  # the body a fragment was born from
var _hit_bodies: Array[Node] = []
var _size := 1.0


static func spawn(parent: Node, owner_combatant: BioCombatant, def: BioAttackDef, pos: Vector2, dir: Vector2, speed_units: float, range_units: float, color: Color, homing: bool, designed: Dictionary = {}) -> BioAbilityBolt:
	var bolt := BioAbilityBolt.new()
	bolt._owner_combatant = owner_combatant
	bolt._dir = dir.normalized()
	bolt._color = color
	bolt.position = pos
	if designed.is_empty():
		bolt._def = def
		bolt._speed_px = speed_units * BioArt.UNIT
		bolt._range_px = range_units * BioArt.UNIT
		bolt._homing = homing
	else:
		bolt.design = designed
		bolt._def = BioAttackDef.new(def.id, def.atp_cost, def.damage * float(designed["damage"]), def.cooldown, def.range_units, def.knockback, def.invulnerable_seconds)
		bolt._speed_px = speed_units * float(designed["speed"]) * BioArt.UNIT
		bolt._range_px = range_units * float(designed["range"]) * BioArt.UNIT
		bolt._path = str(designed["path"])
		bolt._homing = (bolt._path == "teleguiada") or (bolt._path == "" and homing)
		if bolt._path == "teleguiada":
			bolt._homing_radius = 6.5
			bolt._homing_rate = 11.0
		if bolt._path == "arco":
			bolt._turn = 1.15 * (1.0 if randf() < 0.5 else -1.0)
		bolt._pierce_left = int(designed["pierce"])
		bolt._size = float(designed["radius_units"]) / 0.2
	parent.add_child.call_deferred(bolt)  # a fragment is born inside a physics callback
	return bolt


func _ready() -> void:
	_centre = position
	collision_layer = 0
	collision_mask = BioCellActor.LAYER_COMBATANT | BioCellActor.LAYER_WALL
	z_index = 14
	material = BioArt.additive()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(design.get("radius_units", 0.2)) * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_trail = BioPfx.trail(self, _color, 13.0 * clampf(_size, 0.6, 1.8), 36)
	BioPfx.burst(BioFx.root, global_position, _color, 8, 120.0, 0.35, 9.0, _dir, 40.0)


func _physics_process(delta: float) -> void:
	if _owner_combatant == null:
		return
	if _homing:
		var near := BioTargeting.enemies(get_world_2d(), global_position, _homing_radius * BioArt.UNIT, _owner_combatant.actor.team)
		var best := BioTargeting.best(near, global_position, _dir, _homing_radius * BioArt.UNIT)
		if best != null:
			_dir = _dir.slerp((best.global_position - global_position).normalized(), 1.0 - exp(-_homing_rate * delta)).normalized()
	if _turn != 0.0:
		_dir = _dir.rotated(_turn * delta)  # the arc
	var step := _speed_px * delta
	_centre += _dir * step
	_traveled += step
	_spin += delta * 12.0
	var offset := _dir.orthogonal() * weave_amp * sin(_traveled / 36.0 + weave_phase)
	match _path:
		"ondulada":
			offset = _dir.orthogonal() * 22.0 * sin(_traveled / 30.0 + weave_phase)
		"espiral":
			offset = Vector2.from_angle(_traveled / 16.0 + weave_phase) * 24.0
	position = _centre + offset
	for w in 2:
		var tip := Vector2(5.0, -7.0 if w == 0 else 7.0).rotated(_dir.angle())
		(_wake[w] as Array).append(position + tip)
		if (_wake[w] as Array).size() > 14:
			(_wake[w] as Array).pop_front()
	queue_redraw()
	if _traveled >= _range_px:
		_impact(global_position, null)
		_end(false)


func _draw() -> void:
	for w in 2:  # the double thread, in this node's own space
		var pts := PackedVector2Array()
		for p in _wake[w]:
			pts.append((p as Vector2) - position)
		if pts.size() >= 2:
			draw_polyline(pts, BioArt.with_alpha(_color.lerp(Color.WHITE, 0.3), 0.45), 1.5 * _size, true)
	var angle := _dir.angle()
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE * _size)
	var impact := str(design.get("impact", "simples"))
	if _homing:  # the antibody Y
		var c := BioArt.with_alpha(_color.lerp(Color.WHITE, 0.4), 0.95)
		draw_line(Vector2(-14, 0), Vector2(0, 0), c, 3.0, true)
		draw_line(Vector2(0, 0), Vector2(11, -8), c, 3.0, true)
		draw_line(Vector2(0, 0), Vector2(11, 8), c, 3.0, true)
		draw_circle(Vector2(11, -8), 3.0, BioArt.with_alpha(Color.WHITE, 0.95))
		draw_circle(Vector2(11, 8), 3.0, BioArt.with_alpha(Color.WHITE, 0.95))
	match impact:  # what it will do on arrival shows on the shot
		"perfurante":
			draw_line(Vector2(-6, 0), Vector2(26, 0), BioArt.with_alpha(Color.WHITE, 0.9), 2.4, true)
			draw_primitive(PackedVector2Array([Vector2(26, -4), Vector2(26, 4), Vector2(36, 0)]), PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]), PackedVector2Array())
		"explosivo":
			draw_arc(Vector2.ZERO, 11.0 + 2.5 * sin(_spin), 0.0, TAU, 18, BioArt.with_alpha(Color(1.0, 0.7, 0.3), 0.8), 2.2, true)
		"fragmenta":
			for k in 3:
				draw_circle(Vector2.from_angle(_spin + k * TAU / 3.0) * 9.0, 2.6, BioArt.with_alpha(Color.WHITE, 0.9))
		"grudento":
			for k in 3:
				draw_circle(Vector2(-6.0 - 5.0 * k, 2.0 * sin(_spin + k)), 3.0 - k * 0.7, BioArt.with_alpha(_color.lerp(Color(0.5, 1.0, 0.3), 0.6), 0.8))
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -16.0, Vector2.ONE * 32.0), false, BioArt.with_alpha(_color, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node) -> void:
	if _owner_combatant == null:
		return
	var target := body as BioCellActor
	if target == null:
		_impact(global_position, null)
		_end(false)
		return
	if target.combatant == _owner_combatant or not BioCombatRules.can_hit(_owner_combatant.actor, target.combatant.actor) or body == _ignore or _hit_bodies.has(body):
		return
	_hit_bodies.append(body)
	var def := _def
	if not is_equal_approx(_dmg_scale, 1.0):
		def = BioAttackDef.new(_def.id, _def.atp_cost, _def.damage * _dmg_scale, _def.cooldown, _def.range_units, _def.knockback, _def.invulnerable_seconds)
	var result := target.combatant.receive_hit(_owner_combatant, def)
	if result.outcome != BioActor.HitOutcome.EVADED and _def.knockback > 0.0:
		target.apply_impulse(_dir * _def.knockback)
	if result.outcome != BioActor.HitOutcome.EVADED and float(design.get("dot_share", 0.0)) > 0.0:
		var seconds := float(design["dot_seconds"])
		target.combatant.ignite(def.damage * float(design["dot_share"]) / seconds, seconds, _color.lerp(Color(0.5, 1.0, 0.3), 0.5))
	if _pierce_left > 0 and result.outcome != BioActor.HitOutcome.KILLED:
		_pierce_left -= 1  # it goes on through, weaker
		_dmg_scale *= float(design["falloff"])
		BioPfx.burst(BioFx.root, target.global_position, _color, 6, 140.0, 0.3, 8.0, _dir, 50.0)
		return
	_impact(target.global_position, target)
	_end(true)


## What the shot does where it ends: a burst hurts everyone near, a fragmenting shot breaks into pieces that fly on.
func _impact(at: Vector2, victim: Node) -> void:
	if _owner_combatant == null or design.is_empty():
		return
	var aoe_radius := float(design.get("aoe_radius", 0.0))
	if aoe_radius > 0.0:
		var arc := BioAttackDef.new(_def.id, 0.0, _def.damage * _dmg_scale * float(design["aoe_share"]), 0.0, _def.range_units, 0.0, 0.0)
		for e in BioTargeting.enemies(get_world_2d(), at, aoe_radius * BioArt.UNIT, _owner_combatant.actor.team):
			if e != victim and not _hit_bodies.has(e):
				e.combatant.receive_hit(_owner_combatant, arc)
		BioPfx.ring_burst(BioFx.root, at, Color(1.0, 0.7, 0.35), aoe_radius * BioArt.UNIT * 0.8, 30, 0.45, 12.0)
	var frags := int(design.get("frag_count", 0))
	if frags > 0 and not _fragment:
		var piece := BioAttackDef.new(_def.id, 0.0, _def.damage * float(design["frag_share"]), 0.0, _def.range_units, 0.0, 0.0)
		for k in frags:
			var d := _dir.rotated(0.55 + k * TAU / frags)
			var f := BioAbilityBolt.spawn(get_parent(), _owner_combatant, piece, at, d, _speed_px / BioArt.UNIT, float(design["frag_range"]), _color, false)
			f._fragment = true
			f._ignore = victim
			f._size = 0.7


func _end(hit: bool) -> void:
	if _owner_combatant == null:
		return
	_owner_combatant = null
	BioPfx.burst(BioFx.root, global_position, _color, 10 if hit else 4, 140.0, 0.4, 8.0)
	if hit:
		BioSignature.play(&"pincer", global_position, _color, 0.6, {"dir": _dir})
	BioPfx.stop(_trail)
	queue_free()
