class_name BioTouchButton
extends Control
## A button for a finger. It presses an input action while it is held, so the game reads it exactly as it reads a key. A tap that is
## shorter than a frame is stretched to MIN_HOLD, or a game that polls once per frame would never see it.

enum Shape { ROUND, PILL }

signal cast_requested(direction: Vector2)
signal tapped  # the finger landed on it (for buttons that press no action)

const MIN_HOLD_MSEC := 70

var glyph := "":
	set(value):
		if glyph != value:
			queue_redraw()
		glyph = value
var seconds := 0.0:
	set(value):
		if ceili(seconds) != ceili(value):
			queue_redraw()
		seconds = value
var cast_on_release := false
var directional := true
var aim_direction := Vector2.ZERO
var cancelled := false
var cancel_rect := Rect2()
var _contact := Vector2.ZERO
var action: StringName = &""
var caption := ""
var sub := ""  # a smaller line under the round button (the ability's name)
var color := Color(0.35, 0.85, 1.0)
var radius := 30.0
var shape := Shape.ROUND
var cooldown := 0.0  # 0..1, the part of the recharge still to go
var enabled := true
var emphasis := false  # lit while the thing it opens is open

var _index := -1
var _down_at := 0


static func round_button(p_action: StringName, p_caption: String, p_color: Color, p_radius: float) -> BioTouchButton:
	var b := BioTouchButton.new()
	b.action = p_action
	b.caption = p_caption
	b.color = p_color
	b.radius = p_radius
	b.size = Vector2.ONE * p_radius * 2.0
	return b


static func pill(p_action: StringName, p_caption: String, p_color: Color, p_size: Vector2) -> BioTouchButton:
	var b := BioTouchButton.new()
	b.action = p_action
	b.caption = p_caption
	b.color = p_color
	b.shape = Shape.PILL
	b.size = p_size
	b.radius = p_size.y * 0.5
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_let_go())  # a window opened over a held button: the release would never reach it


func is_down() -> bool:
	return _index != -1


func _has_point(point: Vector2) -> bool:
	if shape == Shape.PILL:
		return Rect2(Vector2.ZERO, size).grow(6.0).has_point(point)
	return point.distance_to(size * 0.5) <= radius * 1.12


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _index == -1 and enabled:
			_index = event.index
			_down_at = Time.get_ticks_msec()
			_contact = event.position
			aim_direction = Vector2.ZERO
			cancelled = false
			if action != &"" and not cast_on_release:
				Input.action_press(action)
			tapped.emit()
			queue_redraw()
		elif not event.pressed and event.index == _index:
			_index = -1
			if cast_on_release:
				if not cancelled and not event.canceled:
					cast_requested.emit(aim_direction)
			else:
				_release_after_minimum()
			queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _index and cast_on_release:
			var pull: Vector2 = event.position - _contact
			aim_direction = pull.normalized() if pull.length() > 14.0 else Vector2.ZERO
			cancelled = cancel_rect.has_point(get_global_transform() * event.position)
			queue_redraw()
		accept_event()
	elif event is InputEventMouse:
		accept_event()


func _release_after_minimum() -> void:
	if action == &"":
		return
	var held := Time.get_ticks_msec() - _down_at
	if held >= MIN_HOLD_MSEC:
		Input.action_release(action)
		return
	var a := action
	get_tree().create_timer((MIN_HOLD_MSEC - held) / 1000.0).timeout.connect(func() -> void: Input.action_release(a))


func _let_go() -> void:
	if _index != -1 and action != &"":
		Input.action_release(action)
	_index = -1


func _exit_tree() -> void:
	_let_go()


func set_cooldown(fraction: float) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	if not is_equal_approx(fraction, cooldown):
		cooldown = fraction
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var lit := _index != -1 or emphasis
	var alpha := 1.0 if enabled else 0.35
	if shape == Shape.PILL:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.78 if not lit else 0.95)
		box.border_color = Color(color.r, color.g, color.b, (0.55 if not lit else 1.0) * alpha)
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		_text(caption, Vector2(0, c.y + 5.0), size.x, 12, Color(1, 1, 1, 0.95 * alpha), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var ready := cooldown <= 0.0
	var rim := Color(0.72, 0.61, 0.36, 0.8) if ready else Color(0.3, 0.4, 0.48, 0.5)
	draw_circle(c, radius, Color(0.015, 0.035, 0.065, 0.82))
	draw_circle(c, radius - 4, Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.6 if ready else 0.2))
	draw_arc(c, radius - 1, 0, TAU, 48, rim, 1.5, true)
	draw_arc(c, radius - 5, -PI*0.5, -PI*0.5 + TAU * (1.0-cooldown), 40, Color(color.r,color.g,color.b,0.8), 2, true)
	if lit:
		draw_circle(c, radius - 2, Color(color.r,color.g,color.b,0.18))
	if seconds > 0.0:
		_text(str(ceili(seconds)), Vector2(0,c.y+6),size.x,18,Color(0.85,0.9,0.95),HORIZONTAL_ALIGNMENT_CENTER)
	elif not glyph.is_empty():
		BioTouchGlyph.paint(self,glyph,c,radius*0.43,Color(color.r,color.g,color.b,0.95 if ready else 0.3))
	else:
		_text(caption, Vector2(0,c.y+4),size.x,11,Color(0.8,0.87,0.9),HORIZONTAL_ALIGNMENT_CENTER)



func _text(text: String, at: Vector2, width: float, font_size: int, tint: Color, align: HorizontalAlignment, outline := false) -> void:
	var font := ThemeDB.fallback_font
	if outline:
		draw_string_outline(font, at, text, align, width, font_size, 5, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, align, width, font_size, tint)
