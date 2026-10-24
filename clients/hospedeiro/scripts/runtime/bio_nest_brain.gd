class_name BioNestBrain
extends Node
## A nest: it never moves, and while it lives it keeps making more of its kind (up to a few at a time) near itself. The room is not
## clear until it is broken. `spawn` is asked for a new one at a position.

var spawn: Callable
var every := 5.0
var cap := 4
var alive_of_kind := Callable()  # returns how many of its brood are alive

var _host: BioCellActor
var _body: BioCellBody
var _next := 0.0


func configure(host: BioCellActor, body: BioCellBody) -> void:
	_host = host
	_body = body
	_next = BioClock.now() + every


func _process(_delta: float) -> void:
	if _host == null or not _host.combatant.actor.vitals.is_alive() or not spawn.is_valid():
		return
	var now := BioClock.now()
	if _host.combatant.is_stunned():  # a sleeping nest lays nothing
		_next = maxf(_next, now + 0.2)
		_body.set_telegraph(0.0)
		return
	if now < _next - every * 0.3:
		_body.set_telegraph(0.0)
	else:
		_body.set_telegraph(clampf(1.0 - (_next - now) / (every * 0.3), 0.0, 1.0))  # it swells before it lays
	if now < _next:
		return
	_next = now + every
	_body.set_telegraph(0.0)
	if alive_of_kind.is_valid() and int(alive_of_kind.call()) >= cap:
		return
	spawn.call(_host.global_position + Vector2.from_angle(randf() * TAU) * 1.4 * BioArt.UNIT)
