class_name BioMote
extends Area2D
## A mote of an organ (see BioMoteRules). The cell takes it by touching it; `taken` carries the kind, and the game server tells the engine
## which deed it was.

signal taken(kind: StringName)
signal collected(cell: BioCellActor)

var kind: StringName = &"hemacia_velha"

var _glow: Sprite2D
var _seed := randf() * 10.0
var _color := Color.WHITE
var _consumed := false


func configure(p_kind: StringName) -> void:
	kind = p_kind
	_color = BioMoteRules.kind(kind).get("color", Color.WHITE)


func _ready() -> void:
	collision_layer = 2
	collision_mask = BioCellActor.LAYER_COMBATANT
	z_index = 5
	add_to_group("motes")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.55 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	_glow = BioArt.make_glow(BioArt.with_alpha(_color, 1.0), 1.3, 0)
	add_child(_glow)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(_delta: float) -> void:
	var pulse := 0.75 + 0.18 * sin(Time.get_ticks_msec() * 0.004 + _seed)
	_glow.scale = Vector2.ONE * (pulse * BioArt.UNIT / 128.0)


## What the mote looks like: a disc (red cell), a rod (bacterium) or a shard (crystal), over its glow.
func _draw() -> void:
	var r := 0.3 * BioArt.UNIT
	match kind:
		&"hemacia_velha":
			draw_circle(Vector2.ZERO, r, BioArt.with_alpha(_color, 0.9))
			draw_circle(Vector2.ZERO, r * 0.45, Color(0.1, 0.02, 0.03, 0.9))
		&"microbio":
			draw_line(Vector2(-r * 0.8, 0.0), Vector2(r * 0.8, 0.0), BioArt.with_alpha(_color, 0.95), r * 0.9, true)
			draw_circle(Vector2(-r * 0.8, 0.0), r * 0.45, BioArt.with_alpha(_color, 0.95))
			draw_circle(Vector2(r * 0.8, 0.0), r * 0.45, BioArt.with_alpha(_color, 0.95))
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0.0, -r * 1.2), Vector2(r * 0.7, 0.0), Vector2(0.0, r * 1.2), Vector2(-r * 0.7, 0.0)]), BioArt.with_alpha(_color, 0.95))


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	var cell := body as BioCellActor
	if cell == null or cell.combatant.actor.team != BioActor.Team.CELL or not cell.combatant.actor.vitals.is_alive():
		return
	_consumed = true
	BioMoteRules.apply(kind, cell.combatant.actor)
	BioFx.burst(global_position, _color, 6, 1.8, 0.22, 0.35)
	remove_from_group("motes")
	taken.emit(kind)
	collected.emit(cell)
	queue_free()
