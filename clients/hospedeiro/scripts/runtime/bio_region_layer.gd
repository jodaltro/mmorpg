class_name BioRegionLayer
extends Node2D
## The look of one region of the body, at the scale of a cell: its soft fill, the membrane of its wall (a living lining, with the
## flat nuclei of the cells that make it), streaks of blood carried by the flow, and what makes the place itself: the lining of the
## heart tightens on the beat, the air sacs breathe, the arteries run fast. It is only drawn (and the streaks only move) while the
## region is alive around the player.

var region: Dictionary
var walls: Array = []  # wall runs of this region
var seed_value := 1337

var _streaks: Array[Dictionary] = []
var _alveoli: Array[Dictionary] = []
var _t := 0.0
var _owed := 0.0
var _still: Node2D
var _lung: Node2D  # the air sacs, drawn once and breathing by scale
var _glow: Node2D  # the wall swelling on the beat: drawn once, its brightness follows the heart
var _rng := RandomNumberGenerator.new()


func configure(region_data: Dictionary, wall_runs: Array, body_seed: int) -> void:
	region = region_data
	walls = wall_runs
	seed_value = body_seed
	z_index = -6
	material = BioArt.additive()
	_rng.seed = body_seed * 7 + String(region["id"]).hash()
	_still = Node2D.new()  # what never changes is drawn once
	_still.draw.connect(_draw_still)
	add_child(_still)
	_glow = Node2D.new()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_still.use_parent_material = true
	if region["id"] == BioBodyMap.PULMAO:
		_lung = Node2D.new()
		_lung.position = (region["center"] as Vector2) * BioArt.UNIT
		_lung.draw.connect(_draw_lung)
		_lung.use_parent_material = true
		add_child(_lung)
	_glow.use_parent_material = true
	var area := BioAnatomy.polygon_area(region["outline"])
	for i in clampi(int(area / 30.0), 18, 70):
		_streaks.append({"p": _random_inside(), "age": _rng.randf() * 3.0, "life": _rng.randf_range(2.0, 5.0)})
	if region["id"] == BioBodyMap.PULMAO:
		for i in 56:
			var a := _rng.randf() * TAU
			var r := BioAnatomy.radius_at(region, a, region["phases"]) * _rng.randf_range(0.78, 0.94)
			_alveoli.append({"p": (region["center"] as Vector2) + Vector2.from_angle(a) * r, "r": _rng.randf_range(1.0, 2.1), "phase": _rng.randf() * TAU})


func _random_inside() -> Vector2:
	var a := _rng.randf() * TAU
	var d := BioAnatomy.radius_at(region, a, region["phases"]) * sqrt(_rng.randf()) * 0.92
	return (region["center"] as Vector2) + Vector2.from_angle(a) * d


func _process(delta: float) -> void:
	_t += delta
	_owed += delta
	if Engine.get_process_frames() % 2 == 0:  # streaks and the heart's fibres move at half the frame rate: it reads the same, costs half
		return
	delta = _owed
	_owed = 0.0
	var clock := Time.get_ticks_msec() * 0.001
	for s in _streaks:
		var p: Vector2 = s["p"]
		var v := BioAnatomy.flow_at(seed_value, p, clock)
		s["v"] = v
		p += v * delta * 1.1
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) > float(s["life"]) or not BioAnatomy._inside(region, p, 0.6):
			s["p"] = _random_inside()
			s["age"] = 0.0
		else:
			s["p"] = p
	queue_redraw()


## The fill and the cells of the lining: drawn once.
func _draw_still() -> void:
	var u := BioArt.UNIT
	var center: Vector2 = (region["center"] as Vector2) * u
	var edge := region["fill"] as Color
	var mid := BioArt.with_alpha(edge, 0.0)
	var outline: PackedVector2Array = region["outline"]
	for i in outline.size():
		var a := center + ((outline[i] as Vector2) * u - center) * 0.86
		var b := center + ((outline[(i + 1) % outline.size()] as Vector2) * u - center) * 0.86
		_still.draw_primitive(PackedVector2Array([center, a, b]), PackedColorArray([mid, edge, edge]), PackedVector2Array())
	var tint: Color = region["wall"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + String(region["id"]).hash()
	for run in walls:
		var pts: PackedVector2Array = run["points"]
		var carried := 0.0
		var next_at := rng.randf_range(0.8, 2.4)
		for i in pts.size() - 1:
			var seg := pts[i + 1] - pts[i]
			carried += seg.length()
			if carried < next_at:
				continue
			carried = 0.0
			next_at = rng.randf_range(1.8, 3.6)
			var tangent := seg.normalized()
			var outward := tangent.orthogonal()
			if BioAnatomy.field_at(seed_value, pts[i] + outward * 0.6) < 0.0:
				outward = -outward  # the cells of the lining sit behind the wall, away from the lumen
			var at := (pts[i] + outward * rng.randf_range(0.45, 0.8)) * u
			_still.draw_set_transform(at, tangent.angle(), Vector2(rng.randf_range(1.3, 2.2), 0.55))
			_still.draw_circle(Vector2.ZERO, 0.55 * u, BioArt.with_alpha(tint, 0.16))
			_still.draw_circle(Vector2(0.12 * u, 0.0), 0.2 * u, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.4), 0.22))
	_still.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_membrane(_still, 5.0)


func _draw_membrane(canvas: CanvasItem, width: float) -> void:
	var u := BioArt.UNIT
	var tint: Color = region["wall"]
	for run in walls:
		var pts := PackedVector2Array()
		for p in run["points"]:
			pts.append(p * u)
		canvas.draw_polyline(pts, BioArt.with_alpha(tint, tint.a * 0.35), width * 2.6, true)
		canvas.draw_polyline(pts, tint, width, true)
		canvas.draw_polyline(pts, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.5), tint.a * 0.7), 1.6, true)


func _draw_glow() -> void:
	var tint: Color = region["wall"]
	for run in walls:
		var pts := PackedVector2Array()
		for p in run["points"]:
			pts.append(p * BioArt.UNIT)
		_glow.draw_polyline(pts, BioArt.with_alpha(tint, tint.a * 0.5), 18.0, true)
		_glow.draw_polyline(pts, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.4), tint.a), 7.0, true)


func _draw() -> void:
	var center: Vector2 = (region["center"] as Vector2) * BioArt.UNIT
	var u := BioArt.UNIT
	var clock := Time.get_ticks_msec() * 0.001
	var beat := BioAnatomy.beat(clock)
	var tint: Color = region["wall"]
	# the membrane, thicker on the beat for the parts that feel the heart
	_glow.modulate.a = beat * float(region["pulse"])
	if _lung != null:
		_lung.scale = Vector2.ONE * (1.0 + 0.04 * sin(clock * 1.2))
	# blood carried by the flow: short streaks along its direction
	for s in _streaks:
		var p: Vector2 = s["p"]
		var v: Vector2 = s.get("v", Vector2.ZERO)
		var fade := sin(PI * clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0))
		var tail := p * u - v * u * 0.18
		draw_line(tail, p * u, BioArt.with_alpha(tint.lerp(Color.WHITE, 0.35), 0.35 * fade), 2.0, true)
	if region["id"] == BioBodyMap.CORACAO:
		_draw_heart(center, beat)


## Muscle fibres in the wall of the heart that tighten on each beat.
func _draw_heart(center: Vector2, beat: float) -> void:
	var u := BioArt.UNIT
	var r := float(region["radius"]) * u
	var col := BioArt.with_alpha(Color(1.0, 0.3, 0.35), 0.1 + 0.25 * beat)
	for k in 5:
		var rr := r * (0.5 + 0.1 * k) * (1.0 - 0.06 * beat)
		draw_arc(center, rr, 0.4 + k, 2.2 + k, 24, col, 2.0, true)


## Alveoli: clusters of little bubbles on the lung wall (they swell and shrink with the breath by scaling this node).
func _draw_lung() -> void:
	var u := BioArt.UNIT
	var origin := (region["center"] as Vector2)
	for al in _alveoli:
		var p: Vector2 = (al["p"] as Vector2) - origin
		var r: float = float(al["r"]) * u
		_lung.draw_arc(p * u, r, 0.0, TAU, 14, BioArt.with_alpha(Color(0.85, 0.92, 1.0), 0.5), 2.0, true)
		_lung.draw_circle(p * u, r * 0.45, BioArt.with_alpha(Color(1.0, 0.8, 0.9), 0.12))
