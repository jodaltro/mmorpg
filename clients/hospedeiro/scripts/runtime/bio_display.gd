class_name BioDisplay
extends Node
## Sizes the interface for the screen in the hand. The project is drawn for 1600x900, and on a phone held sideways that shrinks every
## label below what a person can read. Here one interface unit is about one CSS pixel (never fewer than MIN_HEIGHT units tall), and
## the camera widens so the arena still shows a comparable stretch of the body.

signal laid_out(logical: Vector2)

const MIN_HEIGHT := 420.0
const MAX_HEIGHT := 900.0
const DESKTOP_ZOOM := 1.35  # what BioCameraFollow uses on a monitor
const COVERAGE := 0.7  # how much of the desktop's field of view a phone keeps

var world: Node
var logical_size := Vector2(1600, 900)


func _ready() -> void:
	get_window().size_changed.connect(apply)
	apply()


func apply() -> void:
	var win := get_window()
	var pixels := Vector2(win.size)
	if pixels.x < 2.0 or pixels.y < 2.0:
		return
	var css := BioPlatform.css_size()
	var height := clampf(css.y, MIN_HEIGHT, MAX_HEIGHT)
	win.content_scale_size = Vector2i(roundi(height * pixels.x / pixels.y), roundi(height))
	logical_size = Vector2(win.content_scale_size)
	if world != null and is_instance_valid(world.camera):
		world.camera.zoom = Vector2.ONE * DESKTOP_ZOOM * (height / MAX_HEIGHT) / COVERAGE
	laid_out.emit(logical_size)


## Too narrow to play (a phone held upright): the game asks to be turned.
func is_portrait() -> bool:
	return logical_size.x < logical_size.y
