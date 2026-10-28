class_name BioAnatomy
extends RefCounted
## The body as DATA, at the scale of a cell: not organs but the places a cell can swim through (the niche of the marrow, a venule, the
## lumen of the heart, the air sacs of the lung, an artery). They are joined by winding vessels and all of it is ONE membrane: the
## chambers and vessels are blended into a single smooth field, shaped by noise, and the wall is the contour of that field, so the
## whole map reads as one organic object that has been modelled, not as shapes stuck together. The flow of the blood runs through it
## and beats with the heart. Everything is a pure function of the definition and the seed, and nothing here knows about Nodes.
##
## Units are world units (BioArt.UNIT pixels). Region ids match the engine's universe (medula, sangue, coracao, pulmao, aorta).
## `sangue` is the venule and its capillaries: the id stays because quests and rules already speak of the blood.

const HEART_HZ := 1.1  # beats per second of the world's pulse
const CELL := 1.0  # size of a field cell (units)
const BLEND := 5.0  # how smoothly chambers melt into their vessels (units)
const MARGIN := 10.0  # empty space kept around the body in the grid (units)
const FLOW_CELL := 1.5  # size of a flow cell (units)
const FAR := 14.0  # beyond this distance from a part, it no longer matters to the field

static var _built: Dictionary = {}
static var heart_hz := HEART_HZ  # the world's pulse follows the host's heart rate


## The authored part: where each place is, how big, how it flows, what lives there. Densities are per region at full scale.
## `bubbles` makes the wall scalloped (the air sacs); `rough` is how crinkled the membrane is there.
static func definition() -> Dictionary:
	var regions: Array[Dictionary] = [
		{"id": &"medula", "name": "NICHO DA MEDULA", "center": Vector2(0.0, 0.0), "radius": 14.0, "wobble": 0.12, "bubbles": 0, "swirl": 0.0, "pulse": 0.0, "nutrients": 27, "viruses": 0,
			"wall": Color(0.9, 0.3, 0.8, 0.35), "fill": Color(0.5, 0.25, 0.1, 0.07), "palette": [Color(1.0, 0.75, 0.25), Color(0.9, 0.2, 0.85), Color(0.35, 1.0, 0.6)]},
		{"id": &"sangue", "name": "VÊNULA", "center": Vector2(38.0, 0.0), "radius": 18.0, "wobble": 0.1, "bubbles": 0, "swirl": 2.2, "pulse": 0.25, "nutrients": 18, "viruses": 6,
			"wall": Color(0.95, 0.25, 0.6, 0.35), "fill": Color(0.5, 0.05, 0.1, 0.08), "palette": [Color(1.0, 0.15, 0.3), Color(0.9, 0.2, 0.85), Color(0.6, 0.05, 0.12)]},
		{"id": &"coracao", "name": "ENDOCÁRDIO", "center": Vector2(100.0, 0.0), "radius": 28.0, "wobble": 0.13, "bubbles": 0, "swirl": 1.6, "pulse": 1.0, "nutrients": 12, "viruses": 2,
			"wall": Color(1.0, 0.2, 0.28, 0.5), "fill": Color(0.6, 0.03, 0.08, 0.1), "palette": [Color(1.0, 0.2, 0.3), Color(0.7, 0.05, 0.15), Color(1.0, 0.5, 0.4)]},
		{"id": &"pulmao", "name": "ALVÉOLOS", "center": Vector2(100.0, -95.0), "radius": 42.0, "wobble": 0.08, "bubbles": 13, "swirl": 0.9, "pulse": 0.0, "nutrients": 30, "viruses": 4,
			"wall": Color(0.75, 0.85, 1.0, 0.4), "fill": Color(0.5, 0.65, 0.95, 0.06), "palette": [Color(0.8, 0.9, 1.0), Color(1.0, 0.7, 0.85), Color(0.5, 0.75, 1.0)]},
		{"id": &"aorta", "name": "ARTÉRIA", "center": Vector2(186.0, 20.0), "radius": 38.0, "wobble": 0.12, "bubbles": 0, "swirl": 2.6, "pulse": 0.8, "nutrients": 20, "viruses": 3,
			"wall": Color(1.0, 0.4, 0.24, 0.5), "fill": Color(0.65, 0.1, 0.05, 0.09), "palette": [Color(1.0, 0.35, 0.2), Color(1.0, 0.6, 0.3), Color(0.8, 0.1, 0.1)]},
		{"id": &"figado", "name": "SINUSOIDES DO FÍGADO", "center": Vector2(268.0, 96.0), "radius": 40.0, "wobble": 0.15, "bubbles": 0, "swirl": 0.7, "pulse": 0.3, "nutrients": 26, "viruses": 3, "toxins": 14,
			"wall": Color(0.85, 0.5, 0.15, 0.45), "fill": Color(0.45, 0.2, 0.04, 0.1), "palette": [Color(0.95, 0.65, 0.2), Color(0.6, 0.3, 0.1), Color(0.7, 0.85, 0.2)]},
	{"id": &"baco", "name": "POLPA DO BAÇO", "center": Vector2(268.0, -62.0), "radius": 38.0, "wobble": 0.13, "bubbles": 0, "swirl": 0.8, "pulse": 0.2, "nutrients": 20, "viruses": 3,
			"motes": {&"hemacia_velha": 12},
			"wall": Color(0.62, 0.42, 0.95, 0.45), "fill": Color(0.28, 0.1, 0.5, 0.1), "palette": [Color(0.7, 0.45, 1.0), Color(0.9, 0.3, 0.6), Color(0.45, 0.5, 1.0)]},
		{"id": &"intestino", "name": "CRIPTAS DO INTESTINO", "center": Vector2(170.0, 140.0), "radius": 42.0, "wobble": 0.2, "bubbles": 0, "swirl": 0.5, "pulse": 0.15, "nutrients": 44, "viruses": 4,
			"motes": {&"microbio": 12},
			"wall": Color(0.5, 0.88, 0.4, 0.45), "fill": Color(0.15, 0.4, 0.08, 0.1), "palette": [Color(0.55, 1.0, 0.4), Color(1.0, 0.85, 0.35), Color(1.0, 0.55, 0.5)]},
		{"id": &"rim", "name": "NÉFRONS DO RIM", "center": Vector2(330.0, 10.0), "radius": 36.0, "wobble": 0.1, "bubbles": 0, "swirl": 1.2, "pulse": 0.4, "nutrients": 14, "viruses": 3,
			"motes": {&"cristal_de_ureia": 12},
			"wall": Color(0.3, 0.88, 0.82, 0.45), "fill": Color(0.04, 0.3, 0.3, 0.1), "palette": [Color(0.35, 0.95, 0.9), Color(1.0, 0.85, 0.4), Color(0.4, 0.7, 1.0)]},
		{"id": &"pele", "name": "DERME E EPIDERME", "center": Vector2(-45.0, 75.0), "radius": 26.0, "wobble": 0.12, "bubbles": 0, "swirl": 0.6, "pulse": 0.1, "nutrients": 12, "viruses": 3,
			"wall": Color(0.95, 0.72, 0.55, 0.45), "fill": Color(0.5, 0.25, 0.12, 0.1), "palette": [Color(1.0, 0.75, 0.55), Color(0.9, 0.45, 0.4), Color(1.0, 0.9, 0.7)]},
		{"id": &"linfonodo", "name": "LINFONODO", "center": Vector2(350.0, -80.0), "radius": 24.0, "wobble": 0.1, "bubbles": 0, "swirl": 0.4, "pulse": 0.05, "nutrients": 10, "viruses": 2,
			"wall": Color(0.45, 0.65, 1.0, 0.45), "fill": Color(0.08, 0.15, 0.45, 0.1), "palette": [Color(0.5, 0.7, 1.0), Color(0.75, 0.9, 1.0), Color(0.35, 0.45, 0.95)]},
		{"id": &"cerebro", "name": "TECIDO CEREBRAL", "center": Vector2(205.0, -128.0), "radius": 28.0, "wobble": 0.14, "bubbles": 0, "swirl": 0.5, "pulse": 0.3, "nutrients": 14, "viruses": 2,
			"wall": Color(1.0, 0.6, 0.85, 0.45), "fill": Color(0.45, 0.1, 0.35, 0.1), "palette": [Color(1.0, 0.65, 0.9), Color(0.8, 0.5, 1.0), Color(1.0, 0.85, 0.95)]},
	]
	var links: Array[Dictionary] = [
		{"id": &"sinusoide", "from": &"medula", "to": &"sangue", "half_width": 2.6, "speed": 1.6, "pulse": 0.0, "name": "Sinusoide"},
		{"id": &"veia_cava", "from": &"sangue", "to": &"coracao", "half_width": 3.8, "speed": 3.0, "pulse": 0.5, "name": "Vênula coletora"},
		{"id": &"arteria_pulmonar", "from": &"coracao", "to": &"pulmao", "half_width": 3.4, "speed": 2.8, "pulse": 1.0, "name": "Artéria pulmonar"},
		{"id": &"aorta_ascendente", "from": &"coracao", "to": &"aorta", "half_width": 4.2, "speed": 3.6, "pulse": 1.0, "name": "Aorta ascendente"},
		{"id": &"arteria_hepatica", "from": &"aorta", "to": &"figado", "half_width": 3.2, "speed": 2.4, "pulse": 0.7, "name": "Artéria hepática"},
		{"id": &"arteria_esplenica", "from": &"aorta", "to": &"baco", "half_width": 3.0, "speed": 2.4, "pulse": 0.7, "name": "Artéria esplênica"},
		{"id": &"arteria_mesenterica", "from": &"aorta", "to": &"intestino", "half_width": 3.2, "speed": 2.4, "pulse": 0.7, "name": "Artéria mesentérica"},
		{"id": &"arteria_renal", "from": &"aorta", "to": &"rim", "half_width": 3.0, "speed": 2.6, "pulse": 0.7, "name": "Artéria renal"},
		{"id": &"capilar_dermico", "from": &"sangue", "to": &"pele", "half_width": 2.4, "speed": 1.4, "pulse": 0.3, "name": "Capilar dérmico"},
		{"id": &"vaso_linfatico", "from": &"baco", "to": &"linfonodo", "half_width": 2.2, "speed": 1.0, "pulse": 0.0, "name": "Vaso linfático"},
		{"id": &"carotida", "from": &"aorta", "to": &"cerebro", "half_width": 2.8, "speed": 2.6, "pulse": 0.8, "name": "Carótida"},
	]
	return {"regions": regions, "links": links}


## The pulse of the world at time t (seconds): a sharp beat each 1/HEART_HZ, 0 between beats.
static func beat(t: float) -> float:
	return pow(maxf(0.0, sin(TAU * heart_hz * t)), 2.0)


static func region_def(id: StringName) -> Dictionary:
	for r in definition()["regions"]:
		if r["id"] == id:
			return r
	return {}


static func radius_at(region: Dictionary, angle: float, phases: Vector2) -> float:
	var r: float = region["radius"]
	var wobble: float = region["wobble"]
	var k := 1.0 + wobble * (sin(3.0 * angle + phases.x) + 0.6 * sin(5.0 * angle + phases.y) + 0.3 * sin(8.0 * angle + phases.x * 2.0))
	return r * k


## The built body for a seed: the parts, the one field they make, its contour (the walls) and the lookups the game needs.
static func build(seed_value: int) -> Dictionary:
	if _built.has(seed_value):
		return _built[seed_value]
	var def := definition()
	var rng := RandomNumberGenerator.new()
	var regions: Array[Dictionary] = []
	for r in def["regions"]:
		var d: Dictionary = (r as Dictionary).duplicate()
		rng.seed = seed_value * 31 + String(d["id"]).hash()
		d["phases"] = Vector2(rng.randf() * TAU, rng.randf() * TAU)
		var outline := PackedVector2Array()
		for i in 96:
			var a := i * TAU / 96.0
			outline.append((d["center"] as Vector2) + Vector2.from_angle(a) * radius_at(d, a, d["phases"]))
		d["outline"] = outline
		var bubbles: Array[Dictionary] = []
		for b in int(d["bubbles"]):
			var a2 := (b + rng.randf_range(-0.25, 0.25)) * TAU / float(d["bubbles"])
			bubbles.append({"c": (d["center"] as Vector2) + Vector2.from_angle(a2) * float(d["radius"]) * rng.randf_range(0.72, 0.9), "r": float(d["radius"]) * rng.randf_range(0.2, 0.3)})
		d["bubble_list"] = bubbles
		regions.append(d)
	var links: Array[Dictionary] = []
	for l in def["links"]:
		var d: Dictionary = (l as Dictionary).duplicate()
		_wind(d, _find(regions, d["from"]), _find(regions, d["to"]), seed_value)
		links.append(d)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = 0.07
	var body := {"seed": seed_value, "regions": regions, "links": links, "noise": noise}
	_make_field(body)
	_make_walls(body)
	_make_flow(body)
	_built[seed_value] = body
	return body


## A vessel is not a straight pipe: it winds between its two chambers and swells and narrows as it goes.
static func _wind(link: Dictionary, a: Dictionary, b: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 17 + String(link["id"]).hash()
	var p0: Vector2 = a["center"]
	var p1: Vector2 = b["center"]
	var length := p0.distance_to(p1)
	var normal := (p1 - p0).normalized().orthogonal()
	var phase1 := rng.randf() * TAU
	var phase2 := rng.randf() * TAU
	var amp := length * 0.075
	var hw: float = link["half_width"]
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var n := maxi(int(length / 5.0), 8)
	for i in n + 1:
		var s := i / float(n)
		var bend := amp * sin(PI * s) * (0.8 * sin(s * TAU + phase1) + 0.4 * sin(s * TAU * 2.3 + phase2))
		points.append(p0.lerp(p1, s) + normal * bend)
		widths.append(hw * (1.0 + 0.22 * sin(s * TAU * 2.0 + phase2)))
	link["path"] = points
	link["widths"] = widths


static func _find(regions: Array, id: StringName) -> Dictionary:
	for r in regions:
		if r["id"] == id:
			return r
	return {}


static func _inside(region: Dictionary, p: Vector2, margin: float = 0.0) -> bool:
	var d := p - (region["center"] as Vector2)
	return d.length() < radius_at(region, d.angle(), region["phases"]) - margin


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Distance from p to the vessel's winding line, and the direction it runs there.
static func _vessel_probe(link: Dictionary, p: Vector2) -> Dictionary:
	var path: PackedVector2Array = link["path"]
	var widths: PackedFloat32Array = link["widths"]
	var best := INF
	var dir := Vector2.RIGHT
	var width := float(link["half_width"])
	for i in path.size() - 1:
		var d := _segment_distance(p, path[i], path[i + 1])
		if d < best:
			best = d
			dir = (path[i + 1] - path[i]).normalized()
			width = (widths[i] + widths[i + 1]) * 0.5
	return {"distance": best, "dir": dir, "half_width": width}


static func _field_inside_grid(body: Dictionary, p: Vector2) -> float:
	var q := (p - (body["origin"] as Vector2)) / CELL
	var i := clampi(int(q.x), 0, int(body["nx"]) - 1)
	var j := clampi(int(q.y), 0, int(body["ny"]) - 1)
	return (body["grid"] as PackedFloat32Array)[j * int(body["nx"]) + i]


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


## The field of the whole body at p: negative inside, positive outside, every part blended into the one before it.
static func _field_raw(body: Dictionary, p: Vector2) -> float:
	var f := 1000.0
	for region in body["regions"]:
		var d := p - (region["center"] as Vector2)
		var far := d.length() - float(region["radius"]) * 1.45
		if far > FAR:
			f = minf(f, far)
			continue
		f = _smin(f, d.length() - radius_at(region, d.angle(), region["phases"]), BLEND)
		for bub in region["bubble_list"]:
			f = _smin(f, p.distance_to(bub["c"]) - float(bub["r"]), BLEND * 0.6)
	for l in body["links"]:
		var path: PackedVector2Array = l["path"]
		var widths: PackedFloat32Array = l["widths"]
		var mid := path[path.size() / 2]
		if p.distance_to(mid) > path[0].distance_to(path[path.size() - 1]) * 0.6 + FAR:
			continue
		var best := INF
		for i in path.size() - 1:
			best = minf(best, _segment_distance(p, path[i], path[i + 1]) - (widths[i] + widths[i + 1]) * 0.5)
		f = _smin(f, best, BLEND)
	return f + (body["noise"] as FastNoiseLite).get_noise_2d(p.x, p.y) * 3.2


static func _make_field(body: Dictionary) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for region in body["regions"]:
		var r := float(region["radius"]) * 1.4
		lo = lo.min((region["center"] as Vector2) - Vector2(r, r))
		hi = hi.max((region["center"] as Vector2) + Vector2(r, r))
	for l in body["links"]:
		for p in l["path"]:
			lo = lo.min(p)
			hi = hi.max(p)
	lo -= Vector2(MARGIN, MARGIN)
	hi += Vector2(MARGIN, MARGIN)
	var nx := int(ceil((hi.x - lo.x) / CELL)) + 1
	var ny := int(ceil((hi.y - lo.y) / CELL)) + 1
	var grid := PackedFloat32Array()
	grid.resize(nx * ny)
	var inside_cells := 0
	for j in ny:
		for i in nx:
			var v := _field_raw(body, lo + Vector2(i, j) * CELL)
			grid[j * nx + i] = v
			if v < 0.0:
				inside_cells += 1
	body["origin"] = lo
	body["nx"] = nx
	body["ny"] = ny
	body["grid"] = grid
	body["area"] = inside_cells * CELL * CELL


## The flow sampled on a coarse grid for three moments of the beat, so asking for it costs a few lookups.
static func _make_flow(body: Dictionary) -> void:
	var lo: Vector2 = body["origin"]
	var nx := int(ceil(float(body["nx"]) * CELL / FLOW_CELL)) + 1
	var ny := int(ceil(float(body["ny"]) * CELL / FLOW_CELL)) + 1
	var grids: Array = []
	for b in [0.0, 0.5, 1.0]:
		var g := PackedVector2Array()
		g.resize(nx * ny)
		for j in ny:
			for i in nx:
				g[j * nx + i] = _flow_exact(body, lo + Vector2(i, j) * FLOW_CELL, b - 0.35)
		grids.append(g)
	body["flow"] = grids
	body["flow_nx"] = nx
	body["flow_ny"] = ny


## The contour of the field (marching squares), chained into closed loops and cut into runs by the place each part of the wall
## belongs to: the walls of the body.
static func _make_walls(body: Dictionary) -> void:
	var grid: PackedFloat32Array = body["grid"]
	var nx: int = body["nx"]
	var ny: int = body["ny"]
	var lo: Vector2 = body["origin"]
	var pos := {}  # edge id -> point
	var links := {}  # edge id -> neighbours along the contour
	for j in ny - 1:
		for i in nx - 1:
			var a := grid[j * nx + i]
			var b := grid[j * nx + i + 1]
			var c := grid[(j + 1) * nx + i + 1]
			var d := grid[(j + 1) * nx + i]
			var idx := (1 if a < 0.0 else 0) | (2 if b < 0.0 else 0) | (4 if c < 0.0 else 0) | (8 if d < 0.0 else 0)
			if idx == 0 or idx == 15:
				continue
			var top := (j * nx + i) * 2  # horizontal edge a-b
			var bottom := ((j + 1) * nx + i) * 2  # d-c
			var left := (j * nx + i) * 2 + 1  # vertical edge a-d
			var right := (j * nx + i + 1) * 2 + 1  # b-c
			if not pos.has(top):
				pos[top] = lo + Vector2(i + a / (a - b), j) * CELL if (a < 0.0) != (b < 0.0) else Vector2.ZERO
			if not pos.has(bottom):
				pos[bottom] = lo + Vector2(i + d / (d - c), j + 1) * CELL if (d < 0.0) != (c < 0.0) else Vector2.ZERO
			if not pos.has(left):
				pos[left] = lo + Vector2(i, j + a / (a - d)) * CELL if (a < 0.0) != (d < 0.0) else Vector2.ZERO
			if not pos.has(right):
				pos[right] = lo + Vector2(i + 1, j + b / (b - c)) * CELL if (b < 0.0) != (c < 0.0) else Vector2.ZERO
			var pairs: Array = []
			match idx:
				1, 14: pairs = [[left, top]]
				2, 13: pairs = [[top, right]]
				3, 12: pairs = [[left, right]]
				4, 11: pairs = [[right, bottom]]
				6, 9: pairs = [[top, bottom]]
				7, 8: pairs = [[left, bottom]]
				5, 10:
					var centre_inside := (a + b + c + d) * 0.25 < 0.0
					if (idx == 5) == centre_inside:
						pairs = [[top, right], [left, bottom]]
					else:
						pairs = [[left, top], [right, bottom]]
			for pair in pairs:
				for k in 2:
					if not links.has(pair[k]):
						links[pair[k]] = []
					links[pair[k]].append(pair[1 - k])
	var loops: Array = []
	var used := {}
	for start in links:
		if used.has(start):
			continue
		var loop := PackedVector2Array()
		var prev := -1
		var cur: int = start
		while not used.has(cur):
			used[cur] = true
			loop.append(pos[cur])
			var nxt: int = -1
			for n in links[cur]:
				if n != prev and not used.has(n):
					nxt = n
					break
			if nxt < 0:
				break
			prev = cur
			cur = nxt
		if loop.size() >= 12:
			loop.append(loop[0])
			loops.append(loop)
	body["loops"] = loops
	var walls: Array = []
	for loop in loops:
		var run := PackedVector2Array()
		var current: StringName = &""
		for i in loop.size():
			var id := region_at_body(body, loop[i])
			if id != current and run.size() >= 2:
				run.append(loop[i])
				walls.append({"region": current, "points": run, "color": region_def(current)["wall"]})
				run = PackedVector2Array()
			current = id
			run.append(loop[i])
		if run.size() >= 2:
			walls.append({"region": current, "points": run, "color": region_def(current)["wall"]})
	body["walls"] = walls


## The field value at p, read from the grid (bilinear): the same surface the walls are drawn on.
static func field_at(seed_value: int, p: Vector2) -> float:
	var body := build(seed_value)
	var q := (p - (body["origin"] as Vector2)) / CELL
	var nx: int = body["nx"]
	var ny: int = body["ny"]
	if q.x < 0.0 or q.y < 0.0 or q.x >= nx - 1 or q.y >= ny - 1:
		return 100.0
	var i := int(q.x)
	var j := int(q.y)
	var fx := q.x - i
	var fy := q.y - j
	var grid: PackedFloat32Array = body["grid"]
	var top := lerpf(grid[j * nx + i], grid[j * nx + i + 1], fx)
	var bottom := lerpf(grid[(j + 1) * nx + i], grid[(j + 1) * nx + i + 1], fx)
	return lerpf(top, bottom, fy)


## The region a point (units) belongs to: the chamber that holds it, or for a vessel, the chamber it is closer to.
static func region_at(seed_value: int, p: Vector2) -> StringName:
	return region_at_body(build(seed_value), p)


static func region_at_body(body: Dictionary, p: Vector2) -> StringName:
	for region in body["regions"]:
		if _inside(region, p):
			return region["id"]
	var best_link: Dictionary = {}
	var best := INF
	for l in body["links"]:
		var probe := _vessel_probe(l, p)
		if probe["distance"] < best:
			best = probe["distance"]
			best_link = l
	if not best_link.is_empty() and best < float(best_link["half_width"]) + 4.0:
		var a := _find(body["regions"], best_link["from"])
		var b := _find(body["regions"], best_link["to"])
		return a["id"] if p.distance_to(a["center"]) < p.distance_to(b["center"]) else b["id"]
	var nearest: StringName = &"medula"
	var nd := INF
	for region in body["regions"]:
		var d2 := p.distance_to(region["center"]) - float(region["radius"])
		if d2 < nd:
			nd = d2
			nearest = region["id"]
	return nearest


## Is the point (units) in the body at all: inside the membrane.
static func in_body(seed_value: int, p: Vector2) -> bool:
	return field_at(seed_value, p) < 0.0


## The flow of the blood at a point (units per second) at time t: swirls in the chambers, runs along the vessels, and everything
## surges with the heart beat according to how much each part feels it.
static func flow_at(seed_value: int, p: Vector2, t: float) -> Vector2:
	var body := build(seed_value)
	var q := (p - (body["origin"] as Vector2)) / FLOW_CELL
	var nx: int = body["flow_nx"]
	var ny: int = body["flow_ny"]
	if q.x < 0.0 or q.y < 0.0 or q.x >= nx - 1 or q.y >= ny - 1:
		return Vector2.ZERO
	var i := int(q.x)
	var j := int(q.y)
	var fx := q.x - i
	var fy := q.y - j
	var b := beat(t)
	# the flow is quadratic in the beat: three stored samples (beat 0, 1/2, 1) rebuild it exactly
	var w0 := (1.0 - b) * (1.0 - 2.0 * b)
	var w1 := 4.0 * b * (1.0 - b)
	var w2 := b * (2.0 * b - 1.0)
	var grids: Array = body["flow"]
	var out := Vector2.ZERO
	for k in 3:
		var g: PackedVector2Array = grids[k]
		var top := g[j * nx + i].lerp(g[j * nx + i + 1], fx)
		var bottom := g[(j + 1) * nx + i].lerp(g[(j + 1) * nx + i + 1], fx)
		out += top.lerp(bottom, fy) * [w0, w1, w2][k]
	return out


## The exact flow at a point for a given surge of the heart (beat - 0.35); the grid above is sampled from this.
static func _flow_exact(body: Dictionary, p: Vector2, surge: float) -> Vector2:
	if _field_inside_grid(body, p) >= 0.0:
		return Vector2.ZERO
	for region in body["regions"]:
		if not _inside(region, p):
			continue
		var d := p - (region["center"] as Vector2)
		var r := d.length()
		var limit := radius_at(region, d.angle(), region["phases"])
		var out := Vector2.ZERO
		if r > 0.5 and float(region["swirl"]) > 0.0:
			out += Vector2(-d.y, d.x) / r * float(region["swirl"]) * sin(PI * minf(r / limit, 1.0))
		for l in body["links"]:  # the chamber pushes its blood on towards the vessels that leave it
			if l["from"] == region["id"]:
				var path: PackedVector2Array = l["path"]
				out += (path[1] - path[0]).normalized() * float(l["speed"]) * 0.3 * clampf(1.0 - r / limit, 0.0, 1.0) * (1.0 + float(l["pulse"]) * surge)
		return out * (1.0 + float(region["pulse"]) * surge * 0.6)
	for l in body["links"]:
		var probe := _vessel_probe(l, p)
		var hw: float = probe["half_width"]
		if float(probe["distance"]) < hw * 1.15:
			var profile := 1.0 - pow(minf(float(probe["distance"]) / (hw * 1.15), 1.0), 2.0)  # fastest in the middle, still at the walls
			return (probe["dir"] as Vector2) * float(l["speed"]) * profile * (1.0 + float(l["pulse"]) * surge)
	return Vector2.ZERO


## Ids of the regions joined to `id` by a vessel.
static func neighbours(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for l in definition()["links"]:
		if l["from"] == id:
			out.append(l["to"])
		elif l["to"] == id:
			out.append(l["from"])
	return out


## The regions within `hops` vessels of `id` (the ones the game keeps alive around the player).
static func within(id: StringName, hops: int) -> Array[StringName]:
	var seen: Array[StringName] = [id]
	var frontier: Array[StringName] = [id]
	for _h in hops:
		var next: Array[StringName] = []
		for r in frontier:
			for n in neighbours(r):
				if not seen.has(n):
					seen.append(n)
					next.append(n)
		frontier = next
	return seen


static func polygon_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## Playable area in square units: everything inside the membrane.
static func total_area(seed_value: int) -> float:
	return float(build(seed_value)["area"])


## A random point inside a chamber (units), at least `margin` from the membrane.
static func random_point(seed_value: int, id: StringName, rng: RandomNumberGenerator, margin: float = 2.0) -> Vector2:
	var body := build(seed_value)
	var region := _find(body["regions"], id)
	for _attempt in 40:
		var a := rng.randf() * TAU
		var d := radius_at(region, a, region["phases"])
		var p := (region["center"] as Vector2) + Vector2.from_angle(a) * sqrt(rng.randf()) * d
		if field_at(seed_value, p) < -margin:
			return p
	return region["center"]


static func bounds(seed_value: int) -> Rect2:
	var body := build(seed_value)
	var r := Rect2((body["loops"][0] as PackedVector2Array)[0], Vector2.ZERO)
	for loop in body["loops"]:
		for p in loop:
			r = r.expand(p)
	return r


## Waypoints (units) for walking from one region to another along the vessels, from centre to centre.
static func route(seed_value: int, from: StringName, to: StringName) -> Array[Vector2]:
	var body := build(seed_value)
	var chain: Array[StringName] = [from]  # breadth-first over the vessels
	var parent := {from: &""}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var at: StringName = queue.pop_front()
		for n in neighbours(at):
			if not parent.has(n):
				parent[n] = at
				queue.append(n)
	var order: Array[StringName] = []
	var cur: StringName = to
	while cur != &"":
		order.push_front(cur)
		cur = parent.get(cur, &"")
	var out: Array[Vector2] = []
	for k in order.size() - 1:
		for l in body["links"]:
			var path: PackedVector2Array = l["path"]
			if l["from"] == order[k] and l["to"] == order[k + 1]:
				for p in path:
					out.append(p)
			elif l["to"] == order[k] and l["from"] == order[k + 1]:
				for i in range(path.size() - 1, -1, -1):
					out.append(path[i])
	return out


## A point along a vessel (units) at fraction f of its length, the direction it runs there and its half width there.
static func link_point(seed_value: int, link_id: StringName, f: float) -> Dictionary:
	for l in build(seed_value)["links"]:
		if l["id"] == link_id:
			var path: PackedVector2Array = l["path"]
			var widths: PackedFloat32Array = l["widths"]
			var i := clampi(int(f * (path.size() - 1)), 0, path.size() - 2)
			return {"p": path[i], "dir": (path[i + 1] - path[i]).normalized(), "half_width": (widths[i] + widths[i + 1]) * 0.5}
	return {}
