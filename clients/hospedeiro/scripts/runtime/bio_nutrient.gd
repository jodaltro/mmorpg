class_name BioNutrient
extends Area2D

var kind: int = BioNutrientRules.Kind.GLUCOSE

var _glow: Sprite2D
var _seed := randf() * 10.0


static func color_of(nutrient_kind: int) -> Color:
	return BioArt.AMBER if nutrient_kind == BioNutrientRules.Kind.GLUCOSE else BioArt.JADE


func configure(nutrient_kind: int) -> void:
	kind = nutrient_kind


func _ready() -> void:
	collision_layer = 2
	collision_mask = BioCellActor.LAYER_COMBATANT
	z_index = 5
	add_to_group("nutrients")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.45 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	_glow = BioArt.make_glow(BioArt.with_alpha(color_of(kind), 0.9), 0.8, 0)
	add_child(_glow)
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	var pulse := 0.8 + 0.12 * sin(Time.get_ticks_msec() * 0.003 + _seed)
	_glow.scale = Vector2.ONE * (pulse * BioArt.UNIT / 128.0)


func attract(target: Vector2, delta: float) -> void:
	var d := target - global_position
	var dist := d.length()
	if dist < 0.01:
		return
	var pull := lerpf(7.0, 1.0, clampf(dist / (2.6 * BioArt.UNIT), 0.0, 1.0)) * BioArt.UNIT
	global_position += d / dist * pull * delta


func _on_body_entered(body: Node) -> void:
	var eater := body as BioCellActor
	if eater == null or eater.combatant.actor.team != BioActor.Team.CELL or not eater.combatant.actor.vitals.is_alive():
		return
	BioNutrientRules.consume(eater.combatant.actor, kind)
	eater.combatant.nutrient_consumed.emit(kind)
	BioFx.burst(global_position, color_of(kind), 5, 1.8, 0.22, 0.35)
	remove_from_group("nutrients")
	queue_free()
