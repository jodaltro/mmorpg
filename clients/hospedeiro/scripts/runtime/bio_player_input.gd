class_name BioPlayerInput
extends Node

var touch: BioTouchControls  # set when the screen is a finger's: movement and aim come from it, not from the mouse

var _controller: BioCellController
var _host: Node2D
var _mouse_aim_until := 0


static func ensure_actions() -> void:
	_bind("bio_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("bio_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("bio_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("bio_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("bio_aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind("bio_aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind("bio_aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind("bio_aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	var with_mouse := not BioPlatform.is_touch()  # on a touch screen a tap that becomes a mouse click is not an attack
	_bind("bio_lash", ([_mouse(MOUSE_BUTTON_LEFT)] if with_mouse else []) + [_key(KEY_J), _button(JOY_BUTTON_X)])
	_bind("bio_spit", ([_mouse(MOUSE_BUTTON_RIGHT)] if with_mouse else []) + [_key(KEY_K), _button(JOY_BUTTON_B)])
	_bind("bio_dash", [_key(KEY_SPACE), _key(KEY_SHIFT), _button(JOY_BUTTON_A)])
	_bind("bio_respawn", [_key(KEY_R)])
	_bind("bio_pick_1", [_key(KEY_1)])
	_bind("bio_pick_2", [_key(KEY_2)])
	_bind("bio_pick_3", [_key(KEY_3)])
	_bind("bio_pick_4", [_key(KEY_4)])
	_bind("bio_pick_5", [_key(KEY_5)])
	_bind("bio_decline", [_key(KEY_X)])
	_bind("bio_accept", [_key(KEY_Y)])
	_bind("bio_refuse", [_key(KEY_N)])
	_bind("bio_interact", [_key(KEY_E)])
	_bind("bio_leave", [_key(KEY_BACKSPACE)])
	_bind("bio_map", [_key(KEY_M)])
	_bind("bio_vitals", [_key(KEY_TAB)])
	_bind("bio_codex", [_key(KEY_B)])
	_bind("bio_body", [_key(KEY_G)])
	_bind("bio_debug_toggle", [_key(KEY_F3)])
	_bind("bio_jev", [_key(KEY_F2)])
	_bind("bio_menu", [_key(KEY_ESCAPE)])
	_bind("bio_debug_style", [_key(KEY_F4)])
	_bind("bio_debug_random", [_key(KEY_F5)])
	_bind("bio_debug_engine", [_key(KEY_F6)])
	_bind("bio_debug_impact", [_key(KEY_F7)])
	_bind("bio_debug_path", [_key(KEY_F8)])
	_bind("bio_debug_calibre", [_key(KEY_F9)])
	_bind("bio_ab_1", [_key(KEY_Q)])
	_bind("bio_ab_2", [_key(KEY_F)])
	_bind("bio_ab_3", [_key(KEY_C)])
	_bind("bio_ab_4", [_key(KEY_V)])
	for i in 9:
		_bind("bio_num_%d" % (i + 1), [_key(KEY_1 + i)])


func configure(controller: BioCellController, host: Node2D) -> void:
	_controller = controller
	_host = host
	ensure_actions()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 1:
		_mouse_aim_until = Time.get_ticks_msec() + 2000


func _process(_delta: float) -> void:
	if _controller == null or not _host.visible:
		return
	if BioUi.typing() or BioUi.captures_input():  # a window owns input until dismissed
		_controller.move(Vector2.ZERO)
		return
	var heading := Input.get_vector("bio_left", "bio_right", "bio_up", "bio_down")
	if touch != null and touch.move_vector() != Vector2.ZERO:
		heading = touch.move_vector()
	_controller.move(heading)
	var stick := Input.get_vector("bio_aim_left", "bio_aim_right", "bio_aim_up", "bio_aim_down")
	if stick.length_squared() > 0.2:
		_controller.set_aim(stick)
	elif touch != null:
		_controller.set_aim(touch.aim_vector(), touch.attack_stick.value() != Vector2.ZERO)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Time.get_ticks_msec() < _mouse_aim_until:
		_controller.set_aim(_host.get_global_mouse_position() - _host.global_position)
	else:
		_controller.auto_aim()
	if BioUi.captures_input():  # a click on a window is not an attack
		return
	var world := _host.get_parent() as BioWorld
	var pointer_blocked := world != null and world.tutorial != null and world.tutorial.blocks_pointer()
	pointer_blocked = pointer_blocked or (world != null and world.journey != null and world.journey.blocks_pointer())
	if Input.is_action_pressed("bio_lash") and not (pointer_blocked and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_controller.lash()
	if Input.is_action_pressed("bio_spit") and not (pointer_blocked and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_controller.spit()
	if Input.is_action_just_pressed("bio_dash"):
		_controller.dash()


static func _bind(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
