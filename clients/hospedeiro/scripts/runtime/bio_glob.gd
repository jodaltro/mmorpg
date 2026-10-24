class_name BioGlob
extends Area2D
## A glob of unstable histamine: it flies until it touches an enemy and sticks to it with a fuse (see BioFuse). A second glob on the same
## enemy does not start another fuse: it stacks on the first, and the blast grows.

var owner_cell: BioCellActor
var def: BioAttackDef
var color := Color(1.0, 0.62, 0.2)
var dir := Vector2.RIGHT
var speed_px := 600.0
var range_px := 400.0
var fuse_seconds := 2.2
var radius_px := 100.0
var stack_bonus := 0.6

var _traveled := 0.0
var _spent := false
var _trail: CPUParticles2D


static func spawn(parent: Node, owner: BioCellActor, p_def: BioAttackDef, pos: Vector2, direction: Vector2, a: Dictionary, p_color: Color) -> BioGlob:
	var g := BioGlob.new()
	g.owner_cell = owner
	g.def = p_def
	g.position = pos
	g.dir = direction.normalized()
	g.speed_px = float(a["speed"]) * BioArt.UNIT
	g.range_px = float(a["range"]) * BioArt.UNIT
	g.fuse_seconds = float(a["fuse"])
	g.radius_px = float(a["radius"]) * BioArt.UNIT
	g.stack_bonus = float(a["stack"])
	g.color = p_color
	parent.add_child(g)
	return g


func _ready() -> void:
	collision_layer = 0
	collision_mask = BioCellActor.LAYER_COMBATANT | BioCellActor.LAYER_WALL
	z_index = 14
	material = BioArt.additive()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 0.22 * BioArt.UNIT
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_trail = BioPfx.trail(self, color, 11.0, 28)


func _physics_process(delta: float) -> void:
	var step := speed_px * delta
	position += dir * step
	_traveled += step
	queue_redraw()
	if _traveled >= range_px:
		_finish(null)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, BioArt.with_alpha(color, 0.25))
	for k in 5:
		draw_circle(Vector2.from_angle(k * TAU / 5.0 + _traveled * 0.05) * 3.5, 3.2, BioArt.with_alpha(color.darkened(0.2), 0.9))
	draw_circle(Vector2.ZERO, 3.5, BioArt.with_alpha(color.lerp(Color.WHITE, 0.6), 0.95))


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	var target := body as BioCellActor
	if target == null:
		_finish(null)
		return
	if not is_instance_valid(owner_cell) or not BioCombatRules.can_hit(owner_cell.combatant.actor, target.combatant.actor):
		return
	_finish(target)


func _finish(target: BioCellActor) -> void:
	_spent = true
	if target != null:
		BioFuse.stick(target, owner_cell, def, fuse_seconds, radius_px, stack_bonus, color)
	BioPfx.burst(BioFx.root, global_position, color, 8, 140.0, 0.3, 8.0)
	BioPfx.stop(_trail)
	queue_free()
