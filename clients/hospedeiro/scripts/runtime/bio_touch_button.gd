class_name BioTouchButton
extends Control
## A button for a finger. It presses an input action while it is held, so the game reads it exactly as it reads a key. A tap that is
## shorter than a frame is stretched to MIN_HOLD, or a game that polls once per frame would never see it.

enum Shape { ROUND, PILL }

signal tapped  # the finger landed on it (for buttons that press no action)

const MIN_HOLD_MSEC := 70

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
			if action != &"":
				Input.action_press(action)
			tapped.emit()
			queue_redraw()
		elif not event.pressed and event.index == _index:
			_index = -1
			_release_after_minimum()
			queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouse:
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
	draw_circle(c, radius, Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, (0.7 if not lit else 0.92) * alpha))
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 28
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * cooldown * float(i) / float(steps)
			pts.append(c + Vector2.from_angle(a) * (radius - 2.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
	draw_arc(c, radius - 1.5, 0.0, TAU, 40, Color(color.r, color.g, color.b, (0.9 if lit else 0.55) * alpha), 3.0 if lit else 2.0, true)
	if lit:
		draw_circle(c, radius * 0.55, Color(color.r, color.g, color.b, 0.28))
	var big := 18 if caption.length() <= 2 else 12
	_text(caption, Vector2(0, c.y + big * 0.36), size.x, big, Color(1, 1, 1, 0.96 * alpha), HORIZONTAL_ALIGNMENT_CENTER)
	if not sub.is_empty():  # the name, in up to two short lines above the circle
		var font := ThemeDB.fallback_font
		var width := 104.0
		var measured := font.get_multiline_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, width, 11, 2)
		var at := Vector2(c.x - width * 0.5, -5.0 - measured.y + font.get_ascent(11))
		draw_multiline_string_outline(font, at, sub, HORIZONTAL_ALIGNMENT_CENTER, width, 11, 2, 5, Color(0, 0, 0, 0.9))
		draw_multiline_string(font, at, sub, HORIZONTAL_ALIGNMENT_CENTER, width, 11, 2, Color(0.88, 0.95, 1.0, 0.95 * alpha))


func _text(text: String, at: Vector2, width: float, font_size: int, tint: Color, align: HorizontalAlignment, outline := false) -> void:
	var font := ThemeDB.fallback_font
	if outline:
		draw_string_outline(font, at, text, align, width, font_size, 5, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, align, width, font_size, tint)
