class_name BioToxin
extends Area2D
## A toxin mote drifting in the liver. Touching it filters it (see BioToxinRules): the body is cleaner, the cell pays unless it has peroxisomes.

signal filtered

var resistant_check: Callable  # () -> bool, asked at the moment of contact

var _glow: Sprite2D
var _seed := randf() * 10.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = BioCellActor.LAYER_COMBATANT
	z_index = 5
	add_to_group("toxins")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.55 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	_glow = BioArt.make_glow(BioArt.with_alpha(Color(0.65, 0.95, 0.15), 1.0), 1.4, 0)
	add_child(_glow)
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var pulse := 0.75 + 0.18 * sin(Time.get_ticks_msec() * 0.005 + _seed)
	_glow.scale = Vector2.ONE * (pulse * BioArt.UNIT / 128.0)


func _on_body_entered(body: Node) -> void:
	var cell := body as BioCellActor
	if cell == null or cell.combatant.actor.team != BioActor.Team.CELL or not cell.combatant.actor.vitals.is_alive():
		return
	var resistant: bool = resistant_check.call() if resistant_check.is_valid() else false
	BioToxinRules.filter(cell.combatant.actor, resistant)
	BioFx.burst(global_position, Color(0.65, 0.9, 0.15) if not resistant else BioArt.AMBER, 6, 1.8, 0.22, 0.35)
	remove_from_group("toxins")
	filtered.emit()
	queue_free()
