class_name BioTouchMinimap
extends Control
## Compact atlas (the whole body, the cell, the route and a ring on every crisis); a tap or a click opens the full map.
var world: BioWorld
var _body := {}
var _age := 0.0
var _last_route_active := false

func configure(value: BioWorld) -> void:
	world = value
	_body = BioAnatomy.build(world.seed_value)
	size = Vector2(92,92)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if tapped:
		world.atlas.toggle()
		accept_event()

func _process(delta: float) -> void:
	_age += delta
	var active := world != null and world.journey != null and world.journey.has_target
	if _age > 0.2 or active != _last_route_active:
		_age = 0
		_last_route_active = active
		queue_redraw()

func route_segments(frame: Rect2, factor: float, offset: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if world.journey == null: return out
	var path := world.journey.navigation_path()
	for i in range(1, path.size()):
		var segment := BioNavigationRoute.clip_segment(path[i - 1] / BioArt.UNIT * factor + offset, path[i] / BioArt.UNIT * factor + offset, frame)
		if segment.size() == 2: out.append(segment)
	return out

## Every crisis that asks for attention is a ring on its organ; when it is off the minimap the ring sits on the edge, towards it.
func _draw_crises(frame: Rect2, factor: float, offset: Vector2) -> void:
	if world.sync == null or world.sync.presenter == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	for c in world.sync.presenter.model.ordered():
		if not BioConflictFocus.demanding(c):
			continue
		for region in _body.get("regions", []):
			if str(region["id"]) != str(c.get("region", "")):
				continue
			var at: Vector2 = (region["center"] as Vector2) * factor + offset
			var p := Vector2(clampf(at.x, frame.position.x + 6.0, frame.end.x - 6.0), clampf(at.y, frame.position.y + 6.0, frame.end.y - 6.0))
			var color: Color = BioConflictFocus.PHASE_COLOR.get(str(c.get("phase", "")), Color.WHITE)
			draw_circle(p, 3.0, color)
			draw_arc(p, 6.0 + 2.0 * pulse, 0.0, TAU, 20, color, 1.5, true)


func _draw() -> void:
	if world == null:
		return
	draw_style_box(BioUi.style(Color(0.01,0.025,0.05,0.86),Color(0.55,0.65,0.7,0.45),8,0),Rect2(Vector2.ZERO,size))
	var me_units := world.player.global_position/BioArt.UNIT
	var factor := 78.0/52.0
	var offset := size*0.5-me_units*factor
	var frame := Rect2(Vector2(7,7),size-Vector2(14,14))
	for wall in _body.get("walls",[]):
		if not world.atlas.knows(wall["region"]):
			continue
		var points: PackedVector2Array = wall["points"]
		for i in range(1,points.size()):
			var a: Vector2 = points[i-1]*factor+offset
			var b: Vector2 = points[i]*factor+offset
			var visible_segment := BioNavigationRoute.clip_segment(a, b, frame)
			if visible_segment.size() == 2:
				draw_line(visible_segment[0], visible_segment[1], Color(0.3,0.65,0.75,0.65),1,true)
	for segment in route_segments(frame, factor, offset):
		draw_polyline(segment, Color(0.01, 0.05, 0.1, 0.9), 5, true)
		draw_polyline(segment, Color(0.35, 1, 1, 0.95), 2, true)
	if world.journey != null and world.journey.has_target:
		var ahead := world.journey.target / BioArt.UNIT * factor + offset
		var center := size * 0.5
		var direction := center.direction_to(ahead)
		var arrow := center + direction * minf(22, center.distance_to(ahead))
		draw_polyline(PackedVector2Array([arrow - direction * 5 + direction.orthogonal() * 3, arrow, arrow - direction * 5 - direction.orthogonal() * 3]), Color(0.75, 1, 1), 2, true)
	_draw_crises(frame, factor, offset)
	for resident in world.sync._residents.values():
		if is_instance_valid(resident):
			var at: Vector2 = resident.global_position/BioArt.UNIT*factor+offset
			if frame.has_point(at):
				draw_circle(at,1.6,Color(0.9,0.75,0.4,0.8))
	var font := ThemeDB.fallback_font  # the places in view are named
	for region in _body.get("regions", []):
		var at: Vector2 = (region["center"] as Vector2) * factor + offset
		if frame.grow(-14.0).has_point(at):
			var label := str(BioBodyMap.SHORT.get(region["id"], ""))
			var label_at := at + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, 4)
			draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.01, 0.02, 0.05, 0.95))
			draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.9, 1.0, 0.9))
	draw_circle(size*0.5,5,Color(0.5,1,1,0.2))
	draw_circle(size*0.5,2.5,Color(0.8,1,1))
	draw_string(ThemeDB.fallback_font,Vector2(9,15),"N",HORIZONTAL_ALIGNMENT_LEFT,12,8,Color(0.7,0.8,0.85,0.6))
