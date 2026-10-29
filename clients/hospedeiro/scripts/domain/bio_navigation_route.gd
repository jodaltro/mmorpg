class_name BioNavigationRoute
extends RefCounted
## Geometry in world pixels. No scene, input, network or gameplay side effects.
var points := PackedVector2Array()
var lengths := PackedFloat64Array()
var progress := 0.0
var remaining := 0.0
var deviation := 0.0
var projection := Vector2.ZERO
var _segment := 0

func clear() -> void:
	points.clear()
	lengths.clear()
	progress = 0
	remaining = 0
	deviation = 0
	_segment = 0

func plan(seed_value: int, start: Vector2, goal: Vector2, regions: Array[StringName]) -> bool:
	clear()
	if regions.is_empty(): return false
	var spine := PackedVector2Array()
	if regions.size() == 1:
		spine.append(start)
		if not inside(seed_value, start, goal): spine.append(BioBodyMap.center_px(regions[0]))
	else:
		for i in regions.size() - 1:
			for point in BioAnatomy.route(seed_value, regions[i], regions[i + 1]):
				append_unique(spine, point * BioArt.UNIT)
	append_unique(spine, goal)
	if spine.size() == 1: spine.append(goal)
	# Enter the vessel where the player actually is, rather than returning to its region's center.
	var nearest := visible_closest(seed_value, start, spine)
	if nearest.is_empty(): return false
	var entry: Vector2 = nearest.point
	var first := int(nearest.segment) + 1
	append_unique(points, start)
	if not inside(seed_value, start, entry):  # nothing of the route is in sight (a cell in a fold of a curved vessel): walk out of it
		var way := escape(seed_value, start, spine)
		if way.is_empty():
			return false
		for i in range(1, way.size()):
			append_unique(points, way[i])
		var back := visible_closest(seed_value, points[-1], spine)
		entry = back.point
		first = int(back.segment) + 1
	append_unique(points, entry)
	for i in range(first, spine.size()): append_unique(points, spine[i])
	if points.size() < 2:
		points.append(goal + Vector2(0.01, 0))
	for i in range(1, points.size()):
		if not inside(seed_value, points[i - 1], points[i]):
			clear()
			return false
	lengths.append(0)
	for i in range(1, points.size()): lengths.append(lengths[-1] + points[i - 1].distance_to(points[i]))
	follow(start)
	return true

func follow(position: Vector2) -> void:
	var best := closest(position, points)
	if best.is_empty(): return
	projection = best.point
	_segment = int(best.segment)
	deviation = position.distance_to(projection)
	progress = lengths[_segment] + points[_segment].distance_to(projection)
	remaining = maxf(0, lengths[-1] - progress) + deviation

func ahead(distance: float) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	var at := minf(progress + distance, lengths[-1])
	for i in range(1, points.size()):
		if lengths[i] >= at:
			return points[i - 1].lerp(points[i], (at - lengths[i - 1]) / maxf(0.01, lengths[i] - lengths[i - 1]))
	return points[-1]

func path_from(position: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty(): return out
	append_unique(out, position)
	if deviation > BioArt.UNIT * 0.5: append_unique(out, projection)
	for i in range(_segment + 1, points.size()): append_unique(out, points[i])
	return out

static func closest(position: Vector2, path: PackedVector2Array) -> Dictionary:
	var best := INF
	var result := {}
	for i in range(1, path.size()):
		var point := Geometry2D.get_closest_point_to_segment(position, path[i - 1], path[i])
		var distance := position.distance_squared_to(point)
		if distance < best:
			best = distance
			result = {"point":point, "segment":i - 1}
	return result

## The closest point of the path that can be reached in a straight line from `position` (without crossing a wall); the plain closest
## one when none can. A cell next to a wall used to aim at the vessel behind it, and the whole route came out "blocked".
static func visible_closest(seed_value: int, position: Vector2, path: PackedVector2Array) -> Dictionary:
	var options: Array[Dictionary] = []
	for i in range(1, path.size()):
		var point := Geometry2D.get_closest_point_to_segment(position, path[i - 1], path[i])
		options.append({"point": point, "segment": i - 1, "d": position.distance_squared_to(point)})
	options.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["d"]) < float(y["d"]))
	for o in options:
		if inside(seed_value, position, o["point"]):
			return {"point": o["point"], "segment": o["segment"]}
	return {"point": options[0]["point"], "segment": options[0]["segment"]} if not options.is_empty() else {}

## A way out of a fold: a search over the free space of the body (one unit a step, a bounded area) from `start` to the first spot from
## which the route can be seen. Returns the corners of that way (px), or nothing when there is none near.
static func escape(seed_value: int, start: Vector2, path: PackedVector2Array) -> PackedVector2Array:
	var u := BioArt.UNIT
	var origin := (start / u).round()
	var came := {origin: origin}
	var queue: Array[Vector2] = [origin]
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	var reached := Vector2.INF
	while not queue.is_empty() and came.size() < 6000:
		var at: Vector2 = queue.pop_front()
		var near := closest(at * u, path)
		if not near.is_empty() and inside(seed_value, at * u, near.point):
			reached = at
			break
		for d in dirs:
			var n: Vector2 = at + d
			if came.has(n) or n.distance_to(origin) > 40.0 or BioAnatomy.field_at(seed_value, n) > -0.05:
				continue
			came[n] = at
			queue.append(n)
	if reached == Vector2.INF:
		return PackedVector2Array()
	var cells: Array[Vector2] = [reached]
	while cells[0] != origin:
		cells.push_front(came[cells[0]])
	var out := PackedVector2Array([start])
	for i in range(1, cells.size()):  # keep only the corners that a straight line cannot skip
		if i == cells.size() - 1 or not inside(seed_value, out[-1], cells[i + 1] * u):
			append_unique(out, cells[i] * u)
	return out

static func append_unique(path: PackedVector2Array, point: Vector2) -> void:
	if path.is_empty() or path[-1].distance_to(point) > 0.01: path.append(point)

static func inside(seed_value: int, a: Vector2, b: Vector2) -> bool:
	var samples := maxi(1, ceili(a.distance_to(b) / (BioArt.UNIT * 0.75)))
	for i in samples + 1:
		if BioAnatomy.field_at(seed_value, a.lerp(b, float(i) / samples) / BioArt.UNIT) > 0.1: return false
	return true

## Liang–Barsky clipping: lines crossing the minimap remain visible even with both ends outside it.
static func clip_segment(a: Vector2, b: Vector2, frame: Rect2) -> PackedVector2Array:
	var delta := b - a
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [a.x - frame.position.x, frame.end.x - a.x, a.y - frame.position.y, frame.end.y - a.y]
	var low := 0.0
	var high := 1.0
	for i in 4:
		if absf(p[i]) < 0.00001:
			if q[i] < 0: return PackedVector2Array()
			continue
		var ratio: float = q[i] / p[i]
		if p[i] < 0: low = maxf(low, ratio)
		else: high = minf(high, ratio)
		if low > high: return PackedVector2Array()
	return PackedVector2Array([a + delta * low, a + delta * high])
