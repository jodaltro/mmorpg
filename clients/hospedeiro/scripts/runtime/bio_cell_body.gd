class_name BioCellBody
extends Node2D
## Deformable glowing membrane: the rim breathes, stretches with velocity and can sprout spikes.

const RIM := 64
const NECK_SEGMENTS := 5  # tail segments filled by the body itself so the join has no seam

var radius_units := 0.55
var core := BioArt.CYAN
var edge := BioArt.DEEP_BLUE
var wobble := 0.06
var spikes := 0
var spike_length := 0.0
var spin := 0.5

var _seed := randf() * 10.0
var _flash := 0.0
var _telegraph := 0.0
var _smooth_velocity := Vector2.ZERO
var _nucleus: Sprite2D
var _rim := PackedVector2Array()
var _outline := PackedVector2Array()
var _neck := PackedVector2Array()
var tail: BioFlagellum  # when set, the membrane bulges where the tail leaves the cell
var genes: Array[StringName] = []  # expressed genes, drawn as organelles and changes to the shape
var _size_mul := 1.0
var _gene_size := 1.0

## The lineage form (BioCellForms): a plain ball until the cell differentiates. It morphs over a few seconds.
var form: StringName = &"esfera"
var tail_on := false  # only some forms keep a tail
var _form := BioCellForms.params(&"esfera", [])
var _size_now := 0.82
var _lobe_amp_now := 0.0
var _nucleus_now := 0.8
var _lobes := 0
var _front := Vector2.RIGHT
var look_now := {}  # engine axes (0-100), eased towards look_target so the body morphs slowly
var look_target := {}
var _base_core := Color.WHITE
var _base_edge := Color.WHITE
var _base_spikes := 0

## Elastic motion: a spring along a direction (negative = squashed back, positive = stretched out), a
## breathing spring for swelling, and a short queue of timed kicks (wind-up, then snap).
var _stretch := 0.0
var _stretch_v := 0.0
var _stretch_dir := Vector2.RIGHT
var _swell := 1.0
var _swell_v := 0.0
var _swell_target := 1.0
var _swell_until := 0.0
var _kicks: Array = []  # [seconds left, velocity]


func configure(radius: float, core_color: Color, edge_color: Color, spike_count: int, spike_len: float, spin_speed: float, z: int) -> void:
	radius_units = radius
	core = core_color
	edge = edge_color
	spikes = spike_count
	spike_length = spike_len
	spin = spin_speed
	z_index = z


## Each expressed gene leaves a visible mark on the body (see _draw_genes).
func apply_genome(genome: BioGenome) -> void:
	genes = genome.equipped.duplicate()
	_gene_size = 1.1 if genes.has(&"membrana_espessa") else 1.0
	_size_mul = _gene_size * (1.0 + 0.25 * _axis(&"robustez"))
	form = genome.lineage if genome.lineage != &"" else &"esfera"
	_refresh_form()


func _refresh_form() -> void:
	_form = BioCellForms.params(form, genes)
	_lobes = int(_form["lobes"])
	spikes = int(_form["spikes"])
	spike_length = float(_form["spike_len"])
	_base_spikes = spikes
	wobble = float(_form["wobble"])
	tail_on = bool(_form["tail"])
	if tail != null:
		tail.set_active(tail_on)


## The procedural body: axes decided by the engine from how this player plays (0-100 each).
## Nothing snaps: the body eases towards the new values over many seconds, in the background.
func set_look(axes: Dictionary) -> void:
	if look_target.is_empty():
		_base_core = core
		_base_edge = edge
		_base_spikes = spikes
	look_target = axes.duplicate()
	if look_now.is_empty():
		for k in axes:
			look_now[k] = 0.0  # starts neutral and grows into the look


## Back to the plain newborn look (a restarted world).
func clear_look() -> void:
	if not look_target.is_empty():
		core = _base_core
		edge = _base_edge
		spikes = _base_spikes
		if tail != null:
			tail.set_look(1.0, 1.0)
	look_target = {}
	look_now = {}


func _axis(id: StringName) -> float:
	return float(look_now.get(String(id), 0.0)) / 100.0


func _ease_look(delta: float) -> void:
	if look_target.is_empty():
		return
	for k in look_target:
		look_now[k] = move_toward(float(look_now.get(k, 0.0)), float(look_target[k]), delta * 3.0)  # ~30 s for the full range
	var f := _axis(&"ferocidade")
	var a := _axis(&"agilidade")
	var m := _axis(&"metabolismo")
	var s := _axis(&"sociabilidade")
	var q := _axis(&"misterio")
	var r := _axis(&"robustez")
	# Colour: every axis tints the cell towards its own hue.
	var mix := Color.WHITE * 0.0
	var total := 1.0
	mix += _base_core
	for pair in [[f, BioArt.CRIMSON.lerp(BioArt.MAGENTA, 0.5)], [m, BioArt.AMBER], [q, Color(0.62, 0.42, 1.0)], [s, BioArt.JADE], [a, Color(0.75, 0.95, 1.0)], [r, BioArt.DEEP_BLUE]]:
		mix += (pair[1] as Color) * float(pair[0]) * 3.2
		total += float(pair[0]) * 3.2
	core = mix / total
	core.a = 1.0
	edge = _base_edge.lerp(core, 0.55).darkened(0.1)
	spikes = _base_spikes if _base_spikes > 0 else roundi(f * 7.0)
	spike_length = maxf(spike_length, 0.06 + 0.3 * f) if _base_spikes == 0 else spike_length
	wobble = float(_form["wobble"]) + 0.06 * a
	_size_mul = _gene_size * (1.0 + 0.25 * r)
	if tail != null:
		tail.set_look(1.0 + 0.5 * a, 1.0 + 0.25 * f)


## A stretchy gesture towards `dir`: the body first pulls back (`windup`, a fraction of the radius) and, after
## `windup_time`, snaps out by `amount`, overshoots and settles like rubber.
func elastic(dir: Vector2, windup: float, amount: float, windup_time: float = 0.1) -> void:
	_stretch_dir = dir.normalized() if dir.length() > 0.01 else _stretch_dir
	_stretch_v -= windup * 15.0
	_kicks.append([windup_time, amount * 15.0])


## The whole body swells (or shrinks) to `factor` for `seconds` and springs back.
func swell(factor: float, seconds: float) -> void:
	_swell_target = factor
	_swell_until = BioClock.now() + seconds


func _step_elastic(delta: float) -> void:
	for kick in _kicks:
		kick[0] = float(kick[0]) - delta
		if float(kick[0]) <= 0.0:
			_stretch_v += float(kick[1])
	_kicks = _kicks.filter(func(k: Array) -> bool: return float(k[0]) > 0.0)
	_stretch_v += (-220.0 * _stretch - 14.0 * _stretch_v) * delta
	_stretch = clampf(_stretch + _stretch_v * delta, -0.55, 1.4)
	if _swell_target != 1.0 and BioClock.now() >= _swell_until:
		_swell_target = 1.0
	_swell_v += (-150.0 * (_swell - _swell_target) - 13.0 * _swell_v) * delta
	_swell = clampf(_swell + _swell_v * delta, 0.5, 1.8)


func flash() -> void:
	_flash = 1.0


func set_telegraph(amount: float) -> void:
	_telegraph = clampf(amount, 0.0, 1.0)


func _ready() -> void:
	material = BioArt.additive()
	_nucleus = BioArt.make_glow(core, 1.0, 2)
	add_child(_nucleus)
	_rim.resize(RIM)


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_ease_look(delta)
	_step_elastic(delta)
	var host := get_parent() as CharacterBody2D
	var v := host.velocity if host != null else Vector2.ZERO
	_smooth_velocity = _smooth_velocity.lerp(v, 1.0 - exp(-8.0 * delta))
	var t := Time.get_ticks_msec() * 0.001 + _seed
	var speed_units := _smooth_velocity.length() / BioArt.UNIT
	var dir := _smooth_velocity.normalized() if speed_units > 0.05 else Vector2.RIGHT
	_front = dir
	_size_now = move_toward(_size_now, float(_form["size"]), delta * 0.3)
	_lobe_amp_now = move_toward(_lobe_amp_now, float(_form["lobe_amp"]), delta * 0.25)
	_nucleus_now = move_toward(_nucleus_now, float(_form["nucleus"]), delta * 0.3)
	var stretch := clampf(speed_units * 0.04, 0.0, 0.35)
	var breath := 1.0 + 0.04 * sin(t * 3.0) + _telegraph * 0.28
	for i in RIM:
		var a := i * TAU / RIM
		var n := Vector2.from_angle(a)
		var w := 1.0 + wobble * (sin(a * 3.0 + t * 2.1) + 0.6 * sin(a * 5.0 - t * 3.3) + 0.4 * sin(a * 2.0 + t * 1.3))
		var spike := 0.0
		if spikes > 0:
			spike = spike_length * pow(maxf(0.0, cos((a + t * spin) * spikes)), 6.0)
		var lobe := 0.0
		if _lobes > 0:  # pseudopods: lobes that slowly crawl around the body
			lobe = _lobe_amp_now * pow(maxf(0.0, cos((a - t * 0.25) * _lobes)), 2.0)
		var along := n.dot(dir)
		var squash := 1.0 + stretch * along * along - stretch * 0.5 * (1.0 - along * along)
		var p := n * radius_units * BioArt.UNIT * (w + spike + lobe) * squash * breath * _size_mul * _size_now * _swell
		if absf(_stretch) > 0.002:  # volume-preserving rubber stretch, with the leading side bulging further
			var along_p := p.dot(_stretch_dir)
			var side := p - _stretch_dir * along_p
			var s := maxf(_stretch, -0.55)
			p = _stretch_dir * along_p * (1.0 + s) + side / sqrt(1.0 + s)
			p += _stretch_dir * maxf(0.0, along_p) * s * 0.6
		_rim[i] = p
	_neck = PackedVector2Array()
	_outline = _build_outline() if tail != null and tail_on else PackedVector2Array()
	var pulse := 1.0 + 0.12 * sin(t * 2.3)
	_nucleus.scale = Vector2.ONE * (_nucleus_now * radius_units * 1.7 * pulse * (1.0 + _telegraph * 0.5) * BioArt.UNIT / 128.0)
	_nucleus.modulate = BioArt.with_alpha(_core_now().lerp(BioArt.CRIMSON, _telegraph), 0.75)
	_nucleus.position = _smooth_velocity * 0.01
	queue_redraw()


func _core_now() -> Color:
	return core.lerp(Color.WHITE, _flash * 0.8)


func _edge_now() -> Color:
	return edge.lerp(BioArt.CRIMSON, _telegraph).lerp(Color.WHITE, _flash)


func _draw() -> void:
	if _rim.size() < 3:
		return
	var edge_now := _edge_now()
	var core_now := _core_now()
	var layers := [[1.0, BioArt.with_alpha(edge_now, 0.28)], [0.7, BioArt.with_alpha(core_now, 0.16 + _telegraph * 0.2)], [0.4, BioArt.with_alpha(core_now, 0.2)]]
	for layer in layers:
		var scaled := PackedVector2Array()
		if float(layer[0]) == 1.0 and _neck.size() >= 3:
			scaled = _neck
		else:
			for p in _rim:
				scaled.append(p * float(layer[0]))
		_fill_fan(scaled, layer[1])
	var outline := _outline if _outline.size() >= 3 else _rim
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, BioArt.with_alpha(edge_now.lerp(Color.WHITE, 0.35), 0.95), 6.0 if genes.has(&"membrana_espessa") else 3.0, true)
	_draw_genes(edge_now, core_now)
	BioCellForms.draw(self, form, genes, radius_units * BioArt.UNIT * _size_mul * _size_now, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, _front)


## Marks that come from the procedural body, not from a gene: they scale with how the player plays.
func _draw_look(t: float, r: float, tail_angle: float, edge_now: Color, core_now: Color) -> void:
	if look_now.is_empty():
		return
	var a := _axis(&"agilidade")
	var m := _axis(&"metabolismo")
	var s := _axis(&"sociabilidade")
	var q := _axis(&"misterio")
	if a > 0.3 and not genes.has(&"cilios_ageis"):  # beating cilia, more of them the more agile
		var count := int(a * 30.0)
		for i in count:
			var base := _rim[i * RIM / maxi(count, 1)]
			if tail != null and absf(angle_difference(base.angle(), tail_angle)) < 0.55:
				continue
			var tip := base + base.normalized().rotated(sin(t * 8.0 + i) * 0.4) * (8.0 + 8.0 * a)
			draw_line(base, tip, BioArt.with_alpha(core_now, 0.8), 1.8, true)
	if m > 0.25:  # granules of stored energy
		for k in int(m * 10.0):
			var ang := t * 0.2 + k * 2.399
			var pos := Vector2.from_angle(ang) * r * (0.45 + 0.35 * fmod(k * 0.37, 1.0))
			draw_circle(pos, 2.0 + 1.4 * m, BioArt.with_alpha(BioArt.AMBER.lerp(core_now, 0.3) * 0.8, 0.85))
	if s > 0.25:  # an open, luminous halo
		draw_arc(Vector2.ZERO, r * (1.35 + 0.1 * sin(t * 2.0)), 0.0, TAU, 48, BioArt.with_alpha(BioArt.JADE.lerp(core_now, 0.4), 0.45 * s), 2.5, true)
	if q > 0.2:  # orbiting violet motes of knowledge
		for k in 1 + int(q * 5.0):
			var pos2 := Vector2.from_angle(t * (0.6 + 0.1 * k) + k * 1.3) * r * 1.5
			draw_texture_rect(BioArt.glow_texture(), Rect2(pos2 - Vector2.ONE * 8.0, Vector2.ONE * 16.0), false, BioArt.with_alpha(Color(0.62, 0.42, 1.0), 0.6))


## Organelles and changes of form, one per gene, so the build can be read from the body.
func _draw_genes(edge_now: Color, core_now: Color) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	var r := radius_units * BioArt.UNIT * _size_mul
	var tail_angle := tail.tail_direction().angle() if tail != null else 0.0
	_draw_look(t, r, tail_angle, edge_now, core_now)
	if genes.is_empty():
		return
	if genes.has(&"membrana_espessa"):  # a second, thicker wall
		var wall := PackedVector2Array()
		for p in _rim:
			wall.append(p * 1.16)
		wall.append(wall[0])
		draw_polyline(wall, BioArt.with_alpha(edge_now, 0.55), 4.0, true)
	if genes.has(&"cilios_ageis"):  # a fringe of beating cilia
		var count := 36
		for i in count:
			var idx := i * RIM / count
			var base := _rim[idx]
			if tail != null and absf(angle_difference(base.angle(), tail_angle)) < 0.55:
				continue
			var beat := sin(t * 9.0 + i * 0.8) * 0.4
			var tip := base + base.normalized().rotated(beat) * (11.0 + 3.0 * sin(t * 5.0 + i))
			draw_line(base, tip, BioArt.with_alpha(BioArt.CYAN.lerp(Color.WHITE, 0.3), 0.85), 2.0, true)
	if genes.has(&"vesicula_toxica"):  # three glowing toxin sacs
		for k in 3:
			var pos := Vector2.from_angle(t * 0.5 + k * TAU / 3.0) * r * 0.62
			var pulse := 1.0 + 0.2 * sin(t * 3.0 + k)
			draw_texture_rect(BioArt.glow_texture(), Rect2(pos - Vector2.ONE * 14.0 * pulse, Vector2.ONE * 28.0 * pulse), false, BioArt.with_alpha(BioArt.TOXIN, 0.5))
			draw_circle(pos, 4.0 * pulse, BioArt.with_alpha(BioArt.TOXIN * 0.75, 0.9))
	if genes.has(&"mitocondria_avida"):  # amber mitochondria
		for k in 5:
			var a := t * 0.35 + k * TAU / 5.0
			var pos := Vector2.from_angle(a) * r * 0.66
			draw_set_transform(pos, a + PI * 0.5, Vector2(1.9, 1.0))
			draw_circle(Vector2.ZERO, 4.5, BioArt.with_alpha(BioArt.AMBER * 0.8, 0.85))
			draw_circle(Vector2.ZERO, 2.0, BioArt.with_alpha(BioArt.AMBER, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if genes.has(&"enzima_voraz"):  # digestive granules near the wall
		for k in 8:
			var a := -t * 0.25 + k * TAU / 8.0
			var pos := Vector2.from_angle(a) * r * (0.82 + 0.05 * sin(t * 2.0 + k))
			draw_texture_rect(BioArt.glow_texture(), Rect2(pos - Vector2.ONE * 9.0, Vector2.ONE * 18.0), false, BioArt.with_alpha(BioArt.JADE, 0.5))
			draw_circle(pos, 2.4, BioArt.with_alpha(BioArt.JADE * 0.8, 0.9))
	if genes.has(&"nucleo_reativo"):  # a reactive ring around the nucleus
		var ring := r * 0.46 * (1.0 + 0.08 * sin(t * 6.0))
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, BioArt.with_alpha(Color.WHITE, 0.55), 2.0, true)
		draw_arc(Vector2.ZERO, ring * 1.28, t * 2.0, t * 2.0 + PI * 1.2, 24, BioArt.with_alpha(core_now.lerp(Color.WHITE, 0.5), 0.9), 3.0, true)


## Triangle fan from the centre as raw primitives: no triangulation step that could fail on odd shapes.
func _fill_fan(points: PackedVector2Array, fill: Color) -> void:
	var colors := PackedColorArray([fill, fill, fill])
	for i in points.size():
		draw_primitive(PackedVector2Array([Vector2.ZERO, points[i], points[(i + 1) % points.size()]]), colors, PackedVector2Array())


## One silhouette: the rim where the tail leaves the cell is replaced by the tail's own edges,
## then rounded, so the tail reads as the membrane itself stretched out of the nucleus.
func _build_outline() -> PackedVector2Array:
	var left := tail.left_edge()
	var right := tail.right_edge()
	var origin := (get_parent() as Node2D).global_position
	var r_t := radius_units * BioArt.UNIT
	var j0 := -1
	for i in left.size():
		if ((left[i] + right[i]) * 0.5 - origin).length() >= r_t:
			j0 = i
			break
	if j0 < 1 or j0 + NECK_SEGMENTS >= left.size() - 2:
		return PackedVector2Array()
	var half_width := (left[j0] - right[j0]).length() * 0.5
	var step := TAU / RIM
	var cut_steps := ceili((asin(clampf(half_width / r_t, 0.0, 0.9)) + 0.05) / step)
	var centre := roundi(wrapf(tail.tail_direction().angle(), 0.0, TAU) / step) % RIM
	var out := PackedVector2Array()
	for s in range(cut_steps, RIM - cut_steps + 1):
		out.append(_rim[(centre + s) % RIM])
	var rim_count := out.size()
	for i in range(j0, right.size()):
		out.append(right[i] - origin)
	for i in range(left.size() - 1, j0 - 1, -1):
		out.append(left[i] - origin)
	# Round both junctions.
	var n := out.size()
	for pass_index in 3:
		var smoothed := out.duplicate()
		for junction in [rim_count, 0]:
			for d in range(-5, 6):
				var idx := posmod(junction + d, n)
				smoothed[idx] = (out[posmod(idx - 1, n)] + out[idx] * 2.0 + out[posmod(idx + 1, n)]) * 0.25
		out = smoothed
	_neck = out.slice(0, rim_count + NECK_SEGMENTS) + out.slice(n - NECK_SEGMENTS, n)
	return out
