class_name BioThreatSensor
extends Node
## Watches the world and tells a BioCombatState when the cell is in a fight: an enemy that has noticed it and is closing in, a hit
## taken, an attack made, or a dungeon under way. Virions that only drift by do not count; they are the weather of the body.

const ENGAGED := [BioVirusBrain.State.CHASE, BioVirusBrain.State.TELEGRAPH, BioVirusBrain.State.LUNGE, BioVirusBrain.State.RECOVER]
const RANGE_UNITS := 14.0
const SAMPLE_SECONDS := 0.25

var state := BioCombatState.new()

var _player: BioCellActor
var _dungeon: BioDungeon
var _next := 0.0


func configure(player: BioCellActor, dungeon: BioDungeon) -> void:
	_player = player
	_dungeon = dungeon
	player.combatant.hit.connect(func(_who: BioCombatant, _result: BioHitResult) -> void: state.note_threat(BioClock.now()))
	for child in player.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(func(_id: StringName, _dir: Vector2) -> void: state.note_threat(BioClock.now()))
	var runner := player.get_node_or_null("Abilities") as BioAbilityRunner
	if runner != null:
		runner.performed.connect(func(_id: StringName) -> void: state.note_threat(BioClock.now()))


func in_combat() -> bool:
	return state.in_combat(BioClock.now())


func _process(_delta: float) -> void:
	var now := BioClock.now()
	if now < _next or _player == null:
		return
	_next = now + SAMPLE_SECONDS
	if (_dungeon != null and _dungeon.active) or _engaged():
		state.note_threat(now)


func _engaged() -> bool:
	if not _player.is_active():
		return false
	var limit := RANGE_UNITS * BioArt.UNIT
	for group in ["viruses", "dungeon_enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			var cell := node as BioCellActor
			if cell == null or not cell.is_active() or cell.global_position.distance_to(_player.global_position) > limit:
				continue
			for child in cell.get_children():
				if child is BioVirusBrain and (child as BioVirusBrain).state in ENGAGED:
					return true
	return false
