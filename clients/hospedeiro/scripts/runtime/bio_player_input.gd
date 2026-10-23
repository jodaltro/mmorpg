class_name BioPlayerInput
extends Node

var _controller: BioCellController
var _host: Node2D


static func ensure_actions() -> void:
	_bind("bio_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("bio_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("bio_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("bio_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("bio_aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind("bio_aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind("bio_aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind("bio_aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind("bio_lash", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J), _button(JOY_BUTTON_X)])
	_bind("bio_spit", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K), _button(JOY_BUTTON_B)])
	_bind("bio_dash", [_key(KEY_SPACE), _key(KEY_SHIFT), _button(JOY_BUTTON_A)])
	_bind("bio_respawn", [_key(KEY_R)])
	_bind("bio_pick_1", [_key(KEY_1)])
	_bind("bio_pick_2", [_key(KEY_2)])
	_bind("bio_pick_3", [_key(KEY_3)])
	_bind("bio_decline", [_key(KEY_X)])
	_bind("bio_accept", [_key(KEY_Y)])
	_bind("bio_refuse", [_key(KEY_N)])
	_bind("bio_interact", [_key(KEY_E)])
	_bind("bio_leave", [_key(KEY_BACKSPACE)])
	_bind("bio_map", [_key(KEY_M)])
	_bind("bio_vitals", [_key(KEY_TAB)])
	_bind("bio_codex", [_key(KEY_B)])
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


func _process(_delta: float) -> void:
	if _controller == null or not _host.visible:
		return
	_controller.move(Input.get_vector("bio_left", "bio_right", "bio_up", "bio_down"))
	var stick := Input.get_vector("bio_aim_left", "bio_aim_right", "bio_aim_up", "bio_aim_down")
	if stick.length_squared() > 0.2:
		_controller.set_aim(stick)
	else:
		_controller.set_aim(_host.get_global_mouse_position() - _host.global_position)
	if Input.is_action_pressed("bio_lash"):
		_controller.lash()
	if Input.is_action_pressed("bio_spit"):
		_controller.spit()
	if Input.is_action_just_pressed("bio_dash"):
		_controller.dash()


static func _bind(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
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
