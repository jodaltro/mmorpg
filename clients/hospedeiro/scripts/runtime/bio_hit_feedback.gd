class_name BioHitFeedback
extends Node

var _host: BioCellActor
var _body: BioCellBody
var _color := BioArt.CYAN


func configure(host: BioCellActor, body: BioCellBody, tint: Color) -> void:
	_host = host
	_body = body
	_color = tint
	host.combatant.hit.connect(_on_hit)
	host.combatant.died.connect(_on_died)


func _on_hit(_who: BioCombatant, result: BioHitResult) -> void:
	if result.outcome == BioActor.HitOutcome.EVADED:
		BioFx.ring(_host.global_position, 0.7, Color.WHITE)
		return
	if result.damage_applied <= 0.0: return
	var direction := -_host.velocity
	var attacker := _host.combatant._last_attacker
	if is_instance_valid(attacker) and attacker.get_parent() is Node2D:
		direction = _host.global_position - (attacker.get_parent() as Node2D).global_position
	_body.hit_reaction(direction)
	BioFx.burst(_host.global_position, _color, 7, 3.5)


func _on_died(who: BioCombatant) -> void:
	BioFx.burst(_host.global_position, _color, 26, 5.5, 0.45, 0.9)
	BioFx.ring(_host.global_position, 0.8, _color)
	if who.team() != BioActor.Team.VIRUS:
		return
	var kind := BioNutrientRules.Kind.GLUCOSE if randf() < 0.5 else BioNutrientRules.Kind.LIPID
	BioFactory.spawn_nutrient.call_deferred(_host.get_parent(), _host.global_position, kind)
	_host.remove_from_group("viruses")
	_host.queue_free()
