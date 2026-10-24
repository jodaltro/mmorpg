class_name BioDisplay
extends Node
## Sizes the interface for the screen in the hand. The project is drawn for 1600x900, and on a phone held sideways that shrinks every
## label below what a person can read. Here one interface unit is about one CSS pixel (never fewer than MIN_HEIGHT units tall), and
## the camera widens so the arena still shows a comparable stretch of the body.

signal laid_out(logical: Vector2)
signal scale_changed(value: float)

const MIN_SCALE := 0.75
const MAX_SCALE := 1.25
const MIN_HEIGHT := 420.0
const MAX_HEIGHT := 900.0
const DESKTOP_ZOOM := 1.35  # what BioCameraFollow uses on a monitor
const COVERAGE := 0.7  # how much of the desktop's field of view a phone keeps

var preferences_path := "user://hospedeiro_display.cfg"
var interface_scale := 1.0
var world: Node
var logical_size := Vector2(1600, 900)


func _ready() -> void:
	_load_scale()
	get_window().size_changed.connect(apply)
	apply()


func apply() -> void:
	var win := get_window()
	var pixels := Vector2(win.size)
	if pixels.x < 2.0 or pixels.y < 2.0:
		return
	var css := BioPlatform.css_size()
	var height := clampf(css.y, MIN_HEIGHT, MAX_HEIGHT) / interface_scale
	win.content_scale_size = Vector2i(roundi(height * pixels.x / pixels.y), roundi(height))
	logical_size = Vector2(win.content_scale_size)
	if world != null and is_instance_valid(world.camera):
		world.camera.zoom = Vector2.ONE * DESKTOP_ZOOM * (height / MAX_HEIGHT) / COVERAGE
	laid_out.emit(logical_size)


## Too narrow to play (a phone held upright): the game asks to be turned.
func is_portrait() -> bool:
	return logical_size.x < logical_size.y


func set_interface_scale(value: float) -> void:
	var next := snappedf(clampf(value,MIN_SCALE,MAX_SCALE),0.05) if is_finite(value) else 1.0
	if is_equal_approx(next,interface_scale):
		return
	interface_scale = next
	if BioPlatform.is_web():
		JavaScriptBridge.eval("try { localStorage.setItem('hospedeiro.interfaceScale', %s); } catch(e) {}" % JSON.stringify(str(interface_scale)),true)
	apply()
	if not preferences_path.is_empty():
		var config := ConfigFile.new()
		config.set_value("interface","scale",interface_scale)
		config.save(preferences_path)
	scale_changed.emit(interface_scale)


func _load_scale() -> void:
	if BioPlatform.is_web():
		var saved: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('hospedeiro.interfaceScale');}catch(e){return null;}})()",true)
		if saved != null and str(saved).is_valid_float() and is_finite(float(saved)):
			interface_scale = snappedf(clampf(float(saved),MIN_SCALE,MAX_SCALE),0.05)
			return
	if preferences_path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(preferences_path) != OK:
		return
	var value: Variant = config.get_value("interface","scale",1.0)
	if (value is float or value is int) and is_finite(float(value)):
		interface_scale = snappedf(clampf(float(value),MIN_SCALE,MAX_SCALE),0.05)
