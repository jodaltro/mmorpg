class_name BioTouchStick
extends Control
## A thumb stick. `floating` sticks appear where the finger lands inside their area (to move); fixed ones are a base the finger
## drags from the centre of (to attack and aim). The value is a vector with length 0..1 once the dead zone is passed.

signal engaged_changed(engaged: bool)

var floating := true
var relative_aim := false  # attack starts from the contact, so tapping never changes aim
var radius := 64.0
var dead_zone := 0.16
var color := Color(0.35, 0.85, 1.0)
var label := ""
var attack_style := false
var held_by_touch := false  # the finger is on it, however little it moved

var _index := -1
var _origin := Vector2.ZERO
var _finger := Vector2.ZERO
var _value := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree() and _index != -1:
			_release())  # a window opened under the thumb: the release would never reach it


func value() -> Vector2:
	return _value


func is_engaged() -> bool:
	return _index != -1


func _has_point(point: Vector2) -> bool:
	if floating:
		return Rect2(Vector2.ZERO, size).has_point(point)
	return point.distance_to(size * 0.5) <= radius * 1.25


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _index == -1:
			_index = event.index
			_origin = event.position if floating or relative_aim else size * 0.5
			_finger = event.position
			_update()
			engaged_changed.emit(true)
			queue_redraw()
		elif not event.pressed and event.index == _index:
			_release()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _index:
			_finger = event.position
			_update()
			queue_redraw()
		accept_event()
	elif event is InputEventMouse:
		accept_event()


func _release() -> void:
	_index = -1
	_value = Vector2.ZERO
	engaged_changed.emit(false)
	queue_redraw()


func _exit_tree() -> void:
	if _index != -1:
		_release()


func _update() -> void:
	var pull := (_finger - _origin) / radius
	var length := pull.length()
	_value = Vector2.ZERO if length < dead_zone else pull.normalized() * minf(length, 1.0)


func _draw() -> void:
	var base := _origin if (floating and _index != -1) else (size * 0.5 if not floating else Vector2(radius + 56.0, size.y - radius - 30.0))
	var active := _index != -1
	draw_circle(base, radius, Color(color.r, color.g, color.b, 0.10 if not active else 0.16))
	draw_arc(base, radius, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.55 if active else 0.28), 2.0, true)
	if attack_style:
		draw_arc(base,radius-5,0,TAU,48,Color(0.72,0.61,0.36,0.85),2,true)
		BioTouchGlyph.paint(self,"attack",base,radius*0.38,Color(0.75,0.91,1,0.95))
		return
	var knob := base + (_value * radius if active else Vector2.ZERO)
	draw_circle(knob, radius * 0.42, Color(color.r, color.g, color.b, 0.55 if active else 0.22))
	draw_arc(knob, radius * 0.42, 0.0, TAU, 28, Color(1, 1, 1, 0.5 if active else 0.2), 1.5, true)
	if not label.is_empty() and not active:
		draw_string(ThemeDB.fallback_font, base + Vector2(-radius, radius * 0.18), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 13, Color(1, 1, 1, 0.55))
