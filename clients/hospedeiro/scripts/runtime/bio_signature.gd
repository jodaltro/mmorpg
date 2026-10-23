class_name BioSignature
extends Node2D
## One-shot visual signatures of class abilities. Each ability has its own choreography (from the art-direction pass): none
## of them is "a ring" or "a burst of dots". A signature only draws; damage and states are decided elsewhere.
##
## kind: bite (macrophage phagocytosis), grooves (pseudopod swirl), diapedesis (neutrophil dash ghosts and ice),
## fiddleheads (dendrite whips unfurling), contours (chemical map), cartwheel (plasma cell charge), wall (antibody crescent),
## pore (perforin hole), scar (lytic cut), blebs (apoptosis), bodies (apoptotic bodies), pincer (antibody closing).

var kind: StringName
var color := Color.WHITE
var dur := 1.0
var data := {}
var follow: Node2D

var _age := 0.0
var _seed := randf() * 10.0
var _path: Array = []  # [position, age] samples (diapedesis)


static func play(kind_id: StringName, at: Vector2, tint: Color, seconds: float, extra: Dictionary = {}, follow_node: Node2D = null) -> BioSignature:
	if BioFx.root == null:
		return null
	var s := BioSignature.new()
	s.kind = kind_id
	s.color = tint
	s.dur = seconds
	s.data = extra
	s.follow = follow_node
	s.z_index = 15
	s.material = BioArt.additive()
	BioFx.root.add_child(s)
	s.global_position = at
	return s


func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	if kind == &"diapedesis":
		_path.append([global_position, _age])
		_path = _path.filter(func(p: Array) -> bool: return _age - float(p[1]) < 0.7)
	if _age >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_age / dur, 0.0, 1.0)
	var fade := clampf((dur - _age) / maxf(dur * 0.35, 0.05), 0.0, 1.0)
	match kind:
		&"bite":
			_bite(k, fade)
		&"grooves":
			_grooves(k, fade)
		&"diapedesis":
			_diapedesis(fade)
		&"fiddleheads":
			_fiddleheads(k, fade)
		&"contours":
			_contours(k, fade)
		&"cartwheel":
			_cartwheel(k, fade)
		&"wall":
			_wall(k, fade)
		&"pore":
			_pore(k, fade)
		&"scar":
			_scar(k, fade)
		&"blebs":
			_blebs(k, fade)
		&"bodies":
			_bodies(k, fade)
		&"pincer":
			_pincer(k, fade)


func _c(a: float, lighten: float = 0.0) -> Color:
	return BioArt.with_alpha(color.lerp(Color.WHITE, lighten), a)


func _dir() -> Vector2:
	return (data.get("dir", Vector2.RIGHT) as Vector2).normalized()


## Phagocytosis: two mirrored arms open, close into a teardrop around the prey, which shrinks back into the body
## and is digested in a green vesicle that pulses three times.
func _bite(k: float, fade: float) -> void:
	var d := _dir()
	var reach: float = float(data.get("reach", 120.0))
	var open := clampf(k / 0.25, 0.0, 1.0)
	var close := clampf((k - 0.25) / 0.3, 0.0, 1.0)
	var shrink := clampf((k - 0.55) / 0.25, 0.0, 1.0)
	if k < 0.8:
		var spread := deg_to_rad(35.0) * (1.0 - close * 0.95) * open
		var length := reach * (0.45 + 0.55 * open) * (1.0 - shrink * 0.8)
		var pts := PackedVector2Array()
		for side in [-1.0, 1.0]:
			var arm := PackedVector2Array()
			for i in 9:
				var f := i / 8.0
				arm.append(d.rotated(float(side) * spread * (1.0 - f * 0.4)) * length * f + d.orthogonal() * float(side) * sin(f * PI) * length * 0.18 * (1.0 - close))
			draw_polyline(arm, _c(0.85 * (1.0 - shrink)), 4.0, true)
			if side < 0.0:
				pts.append_array(arm)
			else:
				var rev := arm.duplicate()
				rev.reverse()
				pts.append_array(rev)
		if close > 0.3 and pts.size() >= 3:  # the closed sac: a soft drop
			var fill := _c(0.14 * (1.0 - shrink))
			for i in pts.size() - 1:
				draw_primitive(PackedVector2Array([Vector2.ZERO, pts[i], pts[i + 1]]), PackedColorArray([_c(0.0), fill, fill]), PackedVector2Array())
		for i in 8:  # motes sucked in towards the sac
			var a := d.angle() + (i - 3.5) * 0.35
			var from := Vector2.from_angle(a) * reach * 0.9
			draw_circle(from.lerp(d * reach * 0.3, clampf(k * 1.6 + i * 0.05, 0.0, 1.0)), 2.2, _c(0.7 * (1.0 - k), 0.4))
	if k > 0.55:  # the digesting vesicle inside the body
		var pulse := 0.5 + 0.5 * sin((k - 0.55) / 0.45 * TAU * 3.0)
		var v := Vector2(0, -2)
		draw_circle(v, 9.0, Color(0.7, 1.0, 0.25, 0.1 + 0.2 * pulse) * Color(1, 1, 1, fade))
		draw_arc(v, 9.0, 0.0, TAU, 18, Color(0.72, 1.0, 0.3, 0.8 * fade), 2.0, true)
		for b in 3:
			var rise := fmod((k - 0.55) * 3.0 + b * 0.33, 1.0)
			draw_circle(v + Vector2((b - 1) * 4.0, -rise * 16.0), 1.6, Color(0.8, 1.0, 0.5, 0.8 * (1.0 - rise) * fade))


## Eight pseudopods lashed out in a swirl leave eight curved grooves, like the blades of a turbine.
func _grooves(k: float, fade: float) -> void:
	var r: float = float(data.get("radius", 150.0))
	var out := clampf(k / 0.25, 0.0, 1.0)
	for i in 8:
		var a0 := i * TAU / 8.0
		var pts := PackedVector2Array()
		for j in 11:
			var f := j / 10.0
			var swirl := f * f * 0.9
			pts.append(Vector2.from_angle(a0 + swirl) * (r * 0.25 + r * 0.75 * f * out))
		draw_polyline(pts, _c(0.45 * fade), 1.6, true)
		if out < 1.0 or k < 0.4:  # the whip tips curl as they reach their end
			var tip := pts[pts.size() - 1]
			var curl := Vector2.from_angle(a0 + 0.9 + 0.7) * 14.0
			draw_polyline(PackedVector2Array([tip, tip + curl * 0.5 + tip.normalized() * 4.0, tip + curl]), _c(0.8 * fade, 0.4), 3.0, true)


## The neutrophil squeezes through: ghost silhouettes along its path and a strip of ice that thins out, with crystals.
func _diapedesis(fade: float) -> void:
	if _path.size() < 2:
		return
	var origin := global_position
	var pts := PackedVector2Array()
	for p in _path:
		pts.append((p[0] as Vector2) - origin)
	var width := 7.0
	for i in pts.size() - 1:
		var age_i := _age - float(_path[i][1])
		var w := width * (1.0 - clampf(age_i / 0.7, 0.0, 1.0)) + 1.0
		draw_line(pts[i], pts[i + 1], _c(0.55 * (1.0 - age_i / 0.7), 0.5), w, true)
	var travelled := 0.0
	for i in range(1, pts.size()):
		travelled += pts[i].distance_to(pts[i - 1])
		if int(travelled / 25.0) != int((travelled - pts[i].distance_to(pts[i - 1])) / 25.0):  # a crystal every 25 px
			var age_c := _age - float(_path[i][1])
			var s := 4.0 * (1.0 - clampf(age_c / 0.7, 0.0, 1.0))
			var p := pts[i] + Vector2(0, -s * 2.0)
			draw_polyline(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.6, 0), p + Vector2(0, s), p + Vector2(-s * 0.6, 0), p + Vector2(0, -s)]), _c(0.8, 0.6), 1.4, true)
	for g in 4:  # four fading ghosts of the teardrop body
		var idx := maxi(pts.size() - 1 - (g + 1) * 3, 0)
		var d := _dir()
		var at := pts[idx]
		var alpha: float = [0.6, 0.45, 0.3, 0.15][g] * fade
		var body := PackedVector2Array()
		for i in 14:
			var a := i * TAU / 14.0
			var along := Vector2.from_angle(a).dot(d)
			body.append(at + Vector2.from_angle(a) * 12.0 * Vector2(1.0 + 1.3 * maxf(along, 0.0) ** 2, 1.0).x * (1.0 + 0.9 * absf(along)) * 0.55)
		body.append(body[0])
		draw_polyline(body, _c(alpha, 0.4), 2.0, true)


## Dendrite buds curled like fern fiddleheads unfurl into whips and leave a faint Y ghost on each tip.
func _fiddleheads(k: float, fade: float) -> void:
	var d := _dir()
	var count: int = int(data.get("count", 5))
	var spread := deg_to_rad(float(data.get("spread", 70.0)))
	var length: float = float(data.get("length", 120.0))
	var curl := clampf(1.0 - k / 0.4, 0.0, 1.0)
	for i in count:
		var a := d.rotated(lerpf(-spread * 0.5, spread * 0.5, i / float(maxi(count - 1, 1))))
		var base := a * 24.0
		if curl > 0.01:
			var pts := PackedVector2Array()
			for j in 14:
				var f := j / 13.0
				var ang := f * TAU * 1.5 * curl
				pts.append(base + a * f * length * (1.0 - curl) * 0.4 + Vector2.from_angle(a.angle() + ang) * (9.0 * (1.0 - f * 0.7)) * curl)
			draw_polyline(pts, _c(0.9 * fade, 0.3), 2.2, true)
			draw_circle(pts[pts.size() - 1], 2.4, _c(0.95, 0.6))
		if k > 0.3:  # the Y left hanging on the tip
			var tip := a * length
			var g := _c(0.3 * clampf((1.0 - k) / 0.6, 0.0, 1.0), 0.4)
			draw_line(tip - a * 8.0, tip, g, 2.0, true)
			draw_line(tip, tip + a.rotated(0.6) * 10.0, g, 2.0, true)
			draw_line(tip, tip + a.rotated(-0.6) * 10.0, g, 2.0, true)


## A topographic map of the chemical gradient lights up from the outside in, a radar sweep passes, and arrows on every
## enemy point back at the cell.
func _contours(k: float, fade: float) -> void:
	var r: float = float(data.get("radius", 300.0))
	for ring in 4:
		var lit := clampf((k * 4.0 - (3 - ring) * 0.6) / 0.6, 0.0, 1.0)
		if lit <= 0.0:
			continue
		var rr := r * (0.28 + 0.24 * ring)
		var pts := PackedVector2Array()
		for i in 25:
			var a := i * TAU / 24.0
			pts.append(Vector2.from_angle(a) * rr * (1.0 + 0.09 * sin(a * 3.0 + ring * 1.7 + _seed) + 0.05 * sin(a * 7.0 - ring)))
		draw_polyline(pts, _c(0.65 * lit * fade, 0.2), 1.6, true)
		for m in 12:  # dots racing along the contour, alternating direction between neighbours
			var f := fmod(_age * 0.12 * (1.0 if ring % 2 == 0 else -1.0) + m / 12.0 + 1.0, 1.0)
			draw_circle(pts[int(f * 24.0) % 24], 1.8, _c(0.8 * lit * fade, 0.5))
	var sweep := clampf(k / 0.3, 0.0, 1.0)
	if sweep < 1.0:
		var a := sweep * TAU
		for s in 4:
			draw_line(Vector2.ZERO, Vector2.from_angle(a + s * 0.08) * r * 0.5, _c(0.55 * (1.0 - s * 0.22), 0.4), 1.6, true)
	for e in data.get("targets", []):
		var rel: Vector2 = (e as Vector2) - global_position
		var toward := -rel.normalized()
		var mid := rel + toward * 14.0
		draw_line(rel, mid, _c(0.85 * fade, 0.4), 2.0, true)
		draw_line(mid, mid - toward.rotated(0.5) * 5.0, _c(0.85 * fade, 0.4), 2.0, true)
		draw_line(mid, mid - toward.rotated(-0.5) * 5.0, _c(0.85 * fade, 0.4), 2.0, true)


## A plasma cell's charge: stacked cisternae (rough ER) fill the body one line at a time and the nucleus becomes a
## spoked cartwheel.
func _cartwheel(k: float, fade: float) -> void:
	var r: float = float(data.get("radius", 30.0))
	var lines := 2 + int(k * 7.0)
	for i in lines:
		var y := lerpf(-r * 0.7, r * 0.7, (i + 0.5) / 8.0)
		var half := sqrt(maxf(r * r * 0.5 - y * y, 1.0)) * 1.1
		var pts := PackedVector2Array()
		for j in 9:
			var f := j / 8.0
			pts.append(Vector2(lerpf(-half, half, f), y + sin(_age * 5.0 + f * 6.0 + i) * 2.0))
		draw_polyline(pts, _c(0.7 * fade, 0.3), 1.6, true)
		for j in 3:
			draw_circle(Vector2(lerpf(-half, half, fmod(_age * 1.5 + j * 0.33 + i * 0.1, 1.0)), y), 1.4, _c(0.9, 0.6))
	var c := Vector2(r * 0.25, 0)
	draw_arc(c, r * 0.32, 0.0, TAU, 20, _c(0.9, 0.5), 2.0, true)
	for s in 6:
		var a := _age * 5.0 + s * TAU / 6.0
		draw_line(c, c + Vector2.from_angle(a) * r * 0.32, _c(0.8, 0.5), 1.6, true)


## The released antibodies form a crescent wall of mini-Ys that sweeps outwards and then hangs in the air, turning slowly.
func _wall(k: float, fade: float) -> void:
	var d := _dir()
	var reach: float = float(data.get("reach", 200.0))
	var travel := clampf(k / 0.45, 0.0, 1.0)
	var rr := reach * (0.2 + 0.8 * (1.0 - pow(1.0 - travel, 2.0)))
	for i in 60:
		var f := i / 59.0 - 0.5
		var a := d.angle() + f * deg_to_rad(140.0)
		var p := Vector2.from_angle(a) * rr
		var spin := a + (0.0 if travel < 1.0 else (_age - dur * 0.45) * 1.2)
		var col := _c(0.8 * fade, 0.4)
		var stem := p + Vector2.from_angle(spin) * 5.0
		draw_line(p, stem, col, 1.4, true)
		draw_line(stem, stem + Vector2.from_angle(spin + 0.6) * 3.5, col, 1.4, true)
		draw_line(stem, stem + Vector2.from_angle(spin - 0.6) * 3.5, col, 1.4, true)


## A perforin pore: an octagonal ring punched through the membrane, hollow in the middle, dripping cytoplasm.
func _pore(k: float, fade: float) -> void:
	var r := 6.0 * clampf(k * 6.0, 0.2, 1.0)
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2.from_angle(i * TAU / 8.0 + PI / 8.0) * r)
	draw_polyline(pts, _c(0.95 * fade, 0.3), 2.4, true)
	draw_polyline(PackedVector2Array([pts[0] * 0.6, pts[2] * 0.6, pts[4] * 0.6, pts[6] * 0.6, pts[0] * 0.6]), _c(0.35 * fade), 1.2, true)
	for dnum in 3:
		var fall := fmod(k * 1.4 + dnum * 0.3, 1.0)
		draw_circle(Vector2((dnum - 1) * 4.0, r + fall * 16.0), 1.9 * (1.0 - fall * 0.5), _c(0.7 * (1.0 - fall) * fade))


## A lytic cut: a crescent scar that splits into two lips, a dark gap between them, and injected granules.
func _scar(k: float, fade: float) -> void:
	var d := _dir()
	var gap := 4.0 * clampf(k * 2.0, 0.0, 1.0)
	var base := d.angle()
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 14:
			var f := i / 13.0 - 0.5
			var a := base + f * deg_to_rad(100.0)
			var taper := 1.0 - absf(f) * 1.4
			pts.append(Vector2.from_angle(a) * (30.0 + float(side) * gap * taper))
		draw_polyline(pts, _c(0.9 * fade, 0.2), 2.6, true)
	for g in 5:  # granules injected inwards
		var a := base + (g - 2) * 0.2
		var f := clampf(k * 3.0 - g * 0.1, 0.0, 1.0)
		draw_line(Vector2.from_angle(a) * (44.0 - 18.0 * f), Vector2.from_angle(a) * (36.0 - 18.0 * f), _c(0.7 * fade, 0.5), 1.8, true)
	for dr in 6:
		var a := base + (dr - 2.5) * 0.17
		var t := clampf(k * 1.6, 0.0, 1.0)
		draw_circle(Vector2.from_angle(a) * 30.0 + Vector2.from_angle(a + PI * 0.5) * t * 14.0 * (1.0 if dr % 2 == 0 else -1.0), 2.0, _c(0.7 * (1.0 - t) * fade))


## Apoptosis: the target bubbles with blebs as it shrinks.
func _blebs(k: float, fade: float) -> void:
	var r: float = float(data.get("radius", 22.0))
	var count := 8
	for i in count:
		var a := i * TAU / count + _seed
		var inflate := 0.5 + 0.5 * sin(_age * 14.0 + i * 1.9)
		var br := (3.0 + 5.0 * inflate) * (0.5 + k)
		var p := Vector2.from_angle(a) * r * (1.0 - 0.3 * k)
		draw_arc(p, br, a - PI * 0.5, a + PI * 0.5, 8, _c(0.9 * fade, 0.3), 2.0, true)
		if inflate > 0.92:
			draw_circle(p + Vector2.from_angle(a) * br, 1.4, _c(0.9, 0.7))


## The apoptotic bodies left behind: double-bordered spheres with a blinking "eat me" dot, drifting apart.
func _bodies(k: float, fade: float) -> void:
	for i in 5:
		var a := i * TAU / 5.0 + _seed
		var p := Vector2.from_angle(a) * (6.0 + 20.0 * _age * 0.9)
		var r := 6.0 * (1.0 - k * 0.5)
		draw_arc(p, r, 0.0, TAU, 14, _c(0.85 * fade, 0.2), 1.8, true)
		draw_arc(p, r * 0.65, 0.0, TAU, 12, _c(0.5 * fade), 1.4, true)
		if fmod(_age + i * 0.2, 1.0) < 0.5:
			draw_circle(p, 1.6, _c(0.95 * fade, 0.8))
	for s in 10:
		var a2 := s * 0.9 + _seed
		var f := clampf(_age * 1.6, 0.0, 1.0)
		var q := Vector2.from_angle(a2) * (4.0 + 26.0 * f)
		if f < 1.0:
			draw_line(q, q + Vector2.from_angle(a2 + 1.0) * 3.0, _c(0.8 * (1.0 - f)), 1.6, true)


## An antibody closing like a pincer on what it hit, and staying there for a moment.
func _pincer(k: float, fade: float) -> void:
	var d := _dir()
	var close := clampf(k / 0.2, 0.0, 1.0)
	var arm := 10.0
	var ang := lerpf(0.9, 0.35, close)
	var stem := -d * 4.0
	draw_line(stem - d * 8.0, stem, _c(0.9 * fade, 0.4), 2.6, true)
	for side in [-1.0, 1.0]:
		var tip := stem + d.rotated(float(side) * ang) * arm
		draw_line(stem, tip, _c(0.9 * fade, 0.4), 2.6, true)
		draw_circle(tip, 2.6, _c(0.95 * fade, 0.8))
