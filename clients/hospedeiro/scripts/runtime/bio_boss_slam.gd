class_name BioBossSlam
extends Node2D
## The bacillus own moves on top of the lunge every enemy has: a shockwave slam it winds up for a full second (the ground ring
## grows so it can be read and avoided) and a new bacillus that peels off it now and then. Damage goes through the same
## combat rules as every hit; the boss only starts the swing.

signal summon_requested(at: Vector2)

const SLAM_EVERY := 6.0
const WIND_UP := 1.0
const SLAM_RADIUS_UNITS := 4.2
const SUMMON_EVERY := 11.0

var _host: BioCellActor
var _prey: BioCellActor
var _body: BioCellBody
var _slam_in := 4.0
var _summon_in := SUMMON_EVERY
var _wind := -1.0


func configure(host: BioCellActor, body: BioCellBody, prey: BioCellActor) -> void:
	_host = host
	_body = body
	_prey = prey
	z_index = -3
	material = BioArt.additive()
	host.add_child(self)


func _process(delta: float) -> void:
	if _host == null or not _host.combatant.actor.vitals.is_alive():
		queue_free()
		return
	if _wind >= 0.0:
		_wind += delta
		if _body != null:
			_body.set_telegraph(clampf(_wind / WIND_UP, 0.0, 1.0))
		if _wind >= WIND_UP:
			_wind = -1.0
			if _body != null:
				_body.set_telegraph(0.0)
			_slam()
		queue_redraw()
		return
	_slam_in -= delta
	_summon_in -= delta
	if _slam_in <= 0.0:
		_wind = 0.0
		_slam_in = SLAM_EVERY
	if _summon_in <= 0.0:
		_summon_in = SUMMON_EVERY
		summon_requested.emit(_host.global_position + Vector2.from_angle(randf() * TAU) * 2.0 * BioArt.UNIT)


func _slam() -> void:
	var boss := _host.combatant
	if boss.actor.try_begin_attack(BioAttackCatalog.BACILLUS_SLAM, BioClock.now()) != BioActor.AttackStatus.STARTED:
		return
	var reach := SLAM_RADIUS_UNITS * BioArt.UNIT
	if _body != null: _body.attack_gesture(BioAttackCatalog.BACILLUS_SLAM, Vector2.DOWN)
	BioFx.shake(0.3)
	BioPfx.ring_burst(BioFx.root, _host.global_position, Color(0.8, 1.0, 0.3), reach * 0.8, 70, 0.7, 13.0)
	BioFx.ring(_host.global_position, SLAM_RADIUS_UNITS, Color(0.8, 1.0, 0.3))
	if is_instance_valid(_prey) and _prey.is_active() and _prey.global_position.distance_to(_host.global_position) <= reach:
		if BioCombatRules.can_hit(boss.actor, _prey.combatant.actor):
			var def := boss.actor.attack_def(BioAttackCatalog.BACILLUS_SLAM)
			var result := _prey.combatant.receive_hit(boss, def)
			if result.outcome == BioActor.HitOutcome.HIT or result.outcome == BioActor.HitOutcome.KILLED:
				_prey.apply_impulse((_prey.global_position - _host.global_position).normalized() * def.knockback)
	queue_redraw()


func _draw() -> void:
	if _wind < 0.0:
		return
	var k := clampf(_wind / WIND_UP, 0.0, 1.0)
	var reach := SLAM_RADIUS_UNITS * BioArt.UNIT
	draw_arc(Vector2.ZERO, reach, 0.0, TAU, 56, Color(0.8, 1.0, 0.3, 0.25 + 0.5 * k), 2.5, true)
	draw_arc(Vector2.ZERO, reach * k, 0.0, TAU, 56, Color(1.0, 1.0, 0.7, 0.7 * k), 3.5, true)
	for i in 8:
		var a := i * TAU / 8.0 + k * 1.5
		draw_line(Vector2.from_angle(a) * reach * 0.92, Vector2.from_angle(a) * reach * (0.92 - 0.2 * k), Color(1.0, 1.0, 0.7, 0.8 * k), 2.0, true)
