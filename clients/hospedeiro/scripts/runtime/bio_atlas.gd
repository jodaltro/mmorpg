class_name BioAtlas
extends CanvasLayer
## The atlas of the body (key M): the regions the cell has been to are drawn and named, the ones it has not are only a dim, unnamed
## outline, the vessels between them are lines, and a marker shows where the cell is. Discovery is remembered between sessions.

signal discovered(region: StringName)

var known: Array[StringName] = []
var persist_path := ""  # empty: nothing is saved

var _panel: Control
var _player: Node2D
var _region: StringName = &"medula"
var _seed := 1337


func configure(player: Node2D, body_seed: int, save_path: String) -> void:
	_player = player
	_seed = body_seed
	persist_path = save_path
	layer = 13
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.draw.connect(_paint)
	add_child(_panel)
	_load()
	for id in [BioBodyMap.MEDULA, BioBodyMap.SANGUE]:
		discover(id)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_panel.queue_redraw()


func knows(id: StringName) -> bool:
	return known.has(id)


func set_region(id: StringName) -> void:
	_region = id
	discover(id)


## Marks a region as visited. Returns true the first time.
func discover(id: StringName) -> bool:
	if known.has(id):
		return false
	known.append(id)
	_save()
	discovered.emit(id)
	return true


## Regions the engine remembers this cell visited (silent: it is history, not news).
func merge(ids: Array) -> void:
	var changed := false
	for id in ids:
		var key := StringName(str(id))
		if not known.has(key) and BioAnatomy.region_def(key).size() > 0:
			known.append(key)
			changed = true
	if changed:
		_save()


func forget_all() -> void:
	known.clear()
	_save()
	for id in [BioBodyMap.MEDULA, BioBodyMap.SANGUE]:
		discover(id)


func _process(_delta: float) -> void:
	if _panel.visible:
		_panel.queue_redraw()


func _save() -> void:
	if persist_path.is_empty():
		return
	var file := FileAccess.open(persist_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"known": known.map(func(id: StringName) -> String: return String(id))}))


func _load() -> void:
	if persist_path.is_empty() or not FileAccess.file_exists(persist_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(persist_path))
	if data is Dictionary:
		for id in data.get("known", []):
			var key := StringName(str(id))
			if not known.has(key) and BioAnatomy.region_def(key).size() > 0:
				known.append(key)


func _paint() -> void:
	var size := _panel.size
	_panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.88))
	var body := BioAnatomy.build(_seed)
	var box := BioAnatomy.bounds(_seed).grow(14.0)
	var frame := Rect2(Vector2(80, 90), size - Vector2(160, 170))
	var scale := minf(frame.size.x / box.size.x, frame.size.y / box.size.y)
	var offset := frame.position + (frame.size - box.size * scale) * 0.5 - box.position * scale
	var font := ThemeDB.fallback_font
	_panel.draw_string(font, Vector2(80, 60), "ATLAS DO CORPO   ·   %d de %d regiões   ·   M para fechar" % [known.size(), (body["regions"] as Array).size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(0.8, 0.95, 1.0, 0.95))
	var to_screen := func(p: Vector2) -> Vector2: return p * scale + offset
	for loop in body["loops"]:  # the whole body is one membrane: its shape is always there, only dim where the cell has not been
		var shape := PackedVector2Array()
		for p in loop:
			shape.append(to_screen.call(p))
		shape.remove_at(shape.size() - 1)
		if not Geometry2D.triangulate_polygon(shape).is_empty():
			_panel.draw_colored_polygon(shape, Color(0.35, 0.4, 0.55, 0.07))
	for l in body["links"]:  # the route of the vessels where both ends are known
		if known.has(l["from"]) and known.has(l["to"]):
			var line := PackedVector2Array()
			for p in l["path"]:
				line.append(to_screen.call(p))
			_panel.draw_polyline(line, Color(1.0, 0.45, 0.5, 0.4), 3.0, true)
	for run in body["walls"]:
		var pts := PackedVector2Array()
		for p in run["points"]:
			pts.append(to_screen.call(p))
		if known.has(run["region"]):
			var tint: Color = run["color"]
			_panel.draw_polyline(pts, BioArt.with_alpha(tint, 0.35), 7.0 if run["region"] != _region else 10.0, true)
			_panel.draw_polyline(pts, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.3), 0.95), 2.5, true)
		else:
			_panel.draw_polyline(pts, Color(0.55, 0.6, 0.7, 0.3), 2.0, true)
	var index := 0
	for region in body["regions"]:
		var at: Vector2 = to_screen.call(region["center"])
		var side := -1.0 if index % 2 == 0 else 1.0  # names alternate above and below so neighbours do not collide
		index += 1
		var label := str(region["name"]) if known.has(region["id"]) else "?"
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15 if known.has(region["id"]) else 26)
		_panel.draw_string(font, at + Vector2(-text_size.x * 0.5, 6.0 + side * (float(region["radius"]) * scale * 0.55)), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15 if known.has(region["id"]) else 26, Color(1, 1, 1, 0.92) if known.has(region["id"]) else Color(0.7, 0.75, 0.85, 0.5))
	if is_instance_valid(_player):
		var at := (_player.global_position / BioArt.UNIT) * scale + offset
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		_panel.draw_circle(at, 9.0 + 4.0 * pulse, Color(0.2, 0.9, 1.0, 0.25))
		_panel.draw_circle(at, 5.0, Color(0.7, 1.0, 1.0, 0.95))
