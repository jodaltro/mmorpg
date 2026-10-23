class_name BioAbilityBolt
extends Area2D
## An antibody (or any bolt) in flight: a glowing head with a comet trail, optionally homing on the nearest
## enemy, drawn as a Y when it is an antibody. Damage comes from the domain definition, never from here.

var _owner_combatant: BioCombatant
var _def: BioAttackDef
var _dir := Vector2.RIGHT
var _speed_px := 600.0
var _range_px := 500.0
var _color := Color.WHITE
var _homing := false
var _traveled := 0.0
var _trail: CPUParticles2D


static func spawn(parent: Node, owner_combatant: BioCombatant, def: BioAttackDef, pos: Vector2, dir: Vector2, speed_units: float, range_units: float, color: Color, homing: bool) -> BioAbilityBolt:
	var bolt := BioAbilityBolt.new()
	bolt._owner_combatant = owner_combatant
	bolt._def = def
	bolt._dir = dir.normalized()
	bolt._speed_px = speed_units * BioArt.UNIT
	bolt._range_px = range_units * BioArt.UNIT
	bolt._color = color
	bolt._homing = homing
	bolt.position = pos
	parent.add_child(bolt)
	return bolt


func _ready() -> void:
	collision_layer = 0
	collision_mask = BioCellActor.LAYER_COMBATANT | BioCellActor.LAYER_WALL
	z_index = 14
	material = BioArt.additive()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.2 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_trail = BioPfx.trail(self, _color, 13.0, 36)
	BioPfx.burst(BioFx.root, global_position, _color, 8, 120.0, 0.35, 9.0, _dir, 40.0)


func _physics_process(delta: float) -> void:
	if _owner_combatant == null:
		return
	if _homing:
		var near := BioTargeting.enemies(get_world_2d(), global_position, 4.0 * BioArt.UNIT, _owner_combatant.actor.team)
		var best := BioTargeting.best(near, global_position, _dir, 4.0 * BioArt.UNIT)
		if best != null:
			_dir = _dir.slerp((best.global_position - global_position).normalized(), 1.0 - exp(-7.0 * delta)).normalized()
	var step := _speed_px * delta
	position += _dir * step
	_traveled += step
	queue_redraw()
	if _traveled >= _range_px:
		_end(false)


func _draw() -> void:
	var angle := _dir.angle()
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	if _homing or _def.id == &"salva_de_anticorpos":  # the antibody Y
		var c := BioArt.with_alpha(_color.lerp(Color.WHITE, 0.4), 0.95)
		draw_line(Vector2(-14, 0), Vector2(0, 0), c, 3.0, true)
		draw_line(Vector2(0, 0), Vector2(11, -8), c, 3.0, true)
		draw_line(Vector2(0, 0), Vector2(11, 8), c, 3.0, true)
		draw_circle(Vector2(11, -8), 3.0, BioArt.with_alpha(Color.WHITE, 0.95))
		draw_circle(Vector2(11, 8), 3.0, BioArt.with_alpha(Color.WHITE, 0.95))
	draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -16.0, Vector2.ONE * 32.0), false, BioArt.with_alpha(_color, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node) -> void:
	if _owner_combatant == null:
		return
	var target := body as BioCellActor
	if target == null:
		_end(false)
		return
	if target.combatant == _owner_combatant or not BioCombatRules.can_hit(_owner_combatant.actor, target.combatant.actor):
		return
	var result := target.combatant.receive_hit(_owner_combatant, _def)
	if result.outcome != BioActor.HitOutcome.EVADED and _def.knockback > 0.0:
		target.apply_impulse(_dir * _def.knockback)
	_end(true)


func _end(hit: bool) -> void:
	if _owner_combatant == null:
		return
	_owner_combatant = null
	BioPfx.burst(BioFx.root, global_position, _color, 22 if hit else 8, 200.0, 0.5, 12.0)
	if hit:
		BioFx.ring(global_position, 0.5, _color)
	BioPfx.stop(_trail)
	queue_free()
