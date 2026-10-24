class_name BioAllyBrain
extends Node
## An auxiliary the T helper cell calls: it goes after the nearest enemy and bites it, and when there is none it stays near its caller.
## It lives for a while (or until it is killed) and then fades.

var _host: BioCellActor
var _body: BioCellBody
var _owner: BioCellActor
var _def: BioAttackDef
var _color := Color(1.0, 0.85, 0.4)
var _until := 0.0
var _next_bite := 0.0
var _chase_units := 11.0


func configure(host: BioCellActor, body: BioCellBody, owner: BioCellActor, def: BioAttackDef, color: Color, seconds: float) -> void:
	_host = host
	_body = body
	_owner = owner
	_def = def
	_color = color
	_until = BioClock.now() + seconds


func _process(_delta: float) -> void:
	if _host == null:
		return
	var now := BioClock.now()
	if now >= _until or not _host.combatant.actor.vitals.is_alive() or not is_instance_valid(_owner):
		BioPfx.burst(BioFx.root, _host.global_position, _color, 14, 180.0, 0.5, 9.0)
		_host.queue_free()
		return
	var enemies := BioTargeting.enemies(_host.get_world_2d(), _host.global_position, _chase_units * BioArt.UNIT, _host.combatant.actor.team)
	var target: BioCellActor = null
	for e in enemies:
		if target == null or e.global_position.distance_to(_host.global_position) < target.global_position.distance_to(_host.global_position):
			target = e
	if target == null:  # nothing to bite: stay close to whoever called it
		var back := _owner.global_position - _host.global_position
		_host.set_intent(back.normalized() * 0.7 if back.length() > 3.0 * BioArt.UNIT else Vector2.ZERO)
		return
	var to := target.global_position - _host.global_position
	_host.set_intent(to.normalized() * 0.95)
	if to.length() <= 1.5 * BioArt.UNIT and now >= _next_bite:
		_next_bite = now + 0.8
		_body.elastic(to, 0.2, 0.5, 0.06)
		BioStrike.land(_host, target, _def, _host.global_position, _color)
