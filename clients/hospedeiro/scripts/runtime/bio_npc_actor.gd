class_name BioNpcActor
extends Node2D
## A named cell of the engine's society in the world. It is a picture of an engine entity: where it stands and what it does come
## from the view, through the presenter; nothing here moves a fact. The membrane is the game's own BioCellBody (deformable), with
## the role's silhouette and the gesture of its work drawn over it by BioNpcFx.

var npc_id := ""
var display_name := ""
var state: BioInteractionState
var target := Vector2.ZERO  # where the engine's progress says it should be
var lod := 2:
	set(value):
		if value == lod:
			return
		lod = value
		_apply_lod()

var _fx: BioNpcFx
var _tag: Label
var _prefs: BioVisualPrefs
var _t := 0.0
var _on_screen := true
var _owed := 0.0
var _vel := Vector2.ZERO  # smoothed real velocity, for the stretch and the drag of the body
var _prev := Vector2.ZERO
var _radius_px := 30.0


func configure(id: String, name_text: String, interaction: BioInteractionState, prefs: BioVisualPrefs) -> void:
	npc_id = id
	display_name = name_text
	state = interaction
	_prefs = prefs
	var role := BioNpcRoles.role(id)
	_radius_px = float(role["radius"]) * BioArt.UNIT
	_fx = BioNpcFx.new()
	_fx.role = role
	_fx.state = interaction
	_fx.prefs = prefs
	_fx.radius_px = _radius_px
	_fx.seed_angle = float(interaction.seed_value % 628) / 100.0
	_fx.z_index = 7
	add_child(_fx)
	_tag = Label.new()
	_tag.position = Vector2(-130, -_radius_px - 44 - (interaction.seed_value % 3) * 13)  # staggered, so neighbours do not overprint
	_tag.size = Vector2(260, 40)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_tag.add_theme_font_size_override("font_size", 12)
	_tag.add_theme_color_override("font_color", BioArt.with_alpha(role["tint"], 0.95))
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.z_index = 8
	add_child(_tag)
	z_index = 5


## Where the work points (towards the tissue); while working the cell faces it.
func aim(dir: Vector2) -> void:
	if dir.length() > 0.01:
		_fx.target_dir = dir.normalized()
		if state.is_working() or state.phase == BioInteractionState.BLOCKED or state.phase == BioInteractionState.HELP:
			_fx.facing = _fx.target_dir


## A short thanks to the player who helped (the engine remembers the help; this is only the gesture).
func thank() -> void:
	_fx.thanks = 1.2


## 2: the full membrane, name and gesture; 1: the membrane with fewer points; 0: a dot. Off screen nothing is drawn.
func _apply_lod() -> void:
	if _fx == null:
		return
	var full := lod >= 2 and _on_screen
	_tag.visible = full
	_fx.visible = _on_screen
	_fx.lod = lod


func place(pos: Vector2) -> void:
	_prev = pos
	position = pos
	target = pos


## The label says what the cell does in words, so the work never depends on colour or on reading the animation.
func _caption() -> String:
	var role := BioNpcRoles.role(npc_id)
	var doing := BioNpcRoles.verb(state.gesture)
	match state.phase:
		BioInteractionState.BLOCKED:
			doing = "caminho fechado"
		BioInteractionState.HELP:
			doing = "pede ajuda"
		BioInteractionState.NOTICE:
			doing = "decidindo"
		BioInteractionState.CONFIRMED:
			doing = "concluiu"
		BioInteractionState.CANCEL:
			doing = "desistiu"
		BioInteractionState.IDLE, BioInteractionState.RECOVER:
			doing = "descansa"
	return "%s · %s\n%s" % [display_name.get_slice(",", 0), role["role"], doing]


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-delta * (3.0 if _prefs.motion_scale() >= 1.0 else 6.0))
	var delta_pos := target - position
	if delta_pos.length() > 4.0 * BioArt.UNIT * 12.0:
		position = target  # far (a reconnection, a new region): do not drag it across the body
	else:
		position += delta_pos * k
	var move := delta_pos
	if move.length() > 1.0:
		_fx.facing = move.normalized()
	_vel = _vel.lerp((position - _prev) / maxf(delta, 0.001), 1.0 - exp(-delta * 8.0))
	_prev = position
	_fx.velocity = _vel
	var seen := get_viewport_rect().grow(260.0).has_point(get_global_transform_with_canvas().origin)
	if seen != _on_screen:
		_on_screen = seen
		_apply_lod()
	if not _on_screen:
		return
	var stride := 1 if lod >= 2 else (2 if lod == 1 else 4)
	if lod == 0:
		_fx.t = _t
		if (Engine.get_process_frames() + get_instance_id()) % stride == 0:
			_fx.queue_redraw()
		return
	_fx.step_index = state.step
	_fx.thanks = maxf(0.0, _fx.thanks - delta)
	_owed += delta
	if (Engine.get_process_frames() + get_instance_id()) % stride == 0:  # far cells are shaped and drawn less often, with the time they were owed
		_fx.t = _t
		_fx.advance(_owed)
		_owed = 0.0
		if lod >= 2:
			_tag.text = _caption()
		_fx.queue_redraw()
