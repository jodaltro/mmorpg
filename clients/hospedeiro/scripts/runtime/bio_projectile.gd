class_name BioProjectile
extends Area2D

var speed_units := 14.0

var _owner_combatant: BioCombatant
var _def: BioAttackDef
var _direction := Vector2.RIGHT
var _traveled := 0.0


func launch(attacker: BioCombatant, def: BioAttackDef, direction: Vector2) -> void:
	_owner_combatant = attacker
	_def = def
	_direction = direction.normalized()


func _ready() -> void:
	collision_layer = 0
	collision_mask = BioCellActor.LAYER_COMBATANT | BioCellActor.LAYER_WALL
	z_index = 12
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.18 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	add_child(BioArt.make_glow(BioArt.TOXIN, 0.9, 0))
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _owner_combatant == null:
		return
	var step := speed_units * BioArt.UNIT * delta
	position += _direction * step
	_traveled += step
	if _traveled >= _def.range_units * BioArt.UNIT:
		_fizzle()


func _on_body_entered(body: Node) -> void:
	if _owner_combatant == null:
		return
	var target := body as BioCellActor
	if target == null:
		_fizzle()
		return
	if target.combatant == _owner_combatant or not BioCombatRules.can_hit(_owner_combatant.actor, target.combatant.actor):
		return
	var result := target.combatant.receive_hit(_owner_combatant, _def)
	if result.outcome != BioActor.HitOutcome.EVADED:
		target.apply_impulse(_direction * _def.knockback)
	_fizzle()


func _fizzle() -> void:
	BioFx.burst(global_position, BioArt.TOXIN, 6, 2.5, 0.28, 0.4)
	_owner_combatant = null
	queue_free()
