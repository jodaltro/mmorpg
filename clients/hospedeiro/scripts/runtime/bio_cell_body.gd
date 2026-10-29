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
var wear_enabled := false # enemies only; never changes the logical collider or combat stats
var integrity := 1.0
var _integrity_target := 1.0
var _integrity_initialized := false
var _wear_host: BioCellActor
var _shed: Array[Dictionary] = [] # bounded, local draw particles; no extra Nodes or packets

var _seed := randf() * 10.0
var _flash := 0.0
var _telegraph := 0.0
var _telegraph_target := 0.0
var _hit_serial := 0
var _attack_serial := 0
var _attack_kind := ""
var _attack_dir := Vector2.RIGHT
var _attack_left := 0.0
var _impact_left := 0.0
var _impact_dir := Vector2.RIGHT
var _remote_hit := -1
var _remote_attack := -1
var evolution_white := 0.0
var _evolution_hold := false
var _held_genome: BioGenome
var _held_traits := {}
var _held_axes := {}
var _has_held_traits := false

func begin_evolution() -> void:
	_evolution_hold = true
	_held_genome = null
	_held_traits = {}
	_held_axes = {}
	_has_held_traits = false

func finish_evolution() -> void:
	_evolution_hold = false
	if _held_genome != null: apply_genome(_held_genome)
	if _has_held_traits: set_traits(_held_traits)
	if not _held_axes.is_empty(): set_look(_held_axes)
	_held_genome = null
	_has_held_traits = false
	_held_traits = {}
	_held_axes = {}
	_size_now = float(_form["size"])
	_lobe_amp_now = float(_form["lobe_amp"])
	_nucleus_now = float(_form["nucleus"])
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
var traits := {}  # the signature Jev designed (nucleo, membrana, organelas, brilho): see BioDesign
var _base_core := Color.WHITE
var _base_edge := Color.WHITE
var _base_spikes := 0

## Elastic motion: a spring along a direction (negative = squashed back, positive = stretched out), a
## breathing spring for swelling, and a short queue of timed kicks (wind-up, then snap).
const SPRING_STEP := 0.016  # seconds: the longest step the body's springs take at once

var _stretch := 0.0
var _stretch_v := 0.0
var _stretch_dir := Vector2.RIGHT
var _swell := 1.0
var _swell_v := 0.0
var _swell_target := 1.0
var _swell_until := 0.0
var _poly := 0
var _poly_amp := 0.0
var _oval := 0.0
var _ascend := 0.0  # how far it has risen (BioGenome.ascension), eased
var _ascend_target := 0.0
var _human := 0.0  # the humanoid factor (0..1) derived from it
var _walk := 0.0
var _face := 1.0
var _nuc_pos := Vector2.ZERO
var _nuc_r := 6.0
var _nuc_rot := 0.0
var _kicks: Array = []  # [seconds left, velocity]
var _pocket_layer: BioPocketLayer
var _orgs := {}  # gene id -> {"p": Vector2, "v": Vector2, "rot": float, "spin": float, "seed": float}: the organelles floating inside
var _org_rng := RandomNumberGenerator.new()
var _last_org_velocity := Vector2.ZERO
var _bulges := {}  # limb id -> [angle, amount, spread]: the membrane swells where a limb is being pushed out


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
	if _evolution_hold:
		_held_genome = genome
		return
	genes = genome.equipped.duplicate()
	_gene_size = 1.1 if genes.has(&"membrana_espessa") else 1.0
	_size_mul = _gene_size * (1.0 + 0.25 * _axis(&"robustez"))
	form = genome.lineage if genome.lineage != &"" else &"esfera"
	_ascend_target = genome.ascension()
	_refresh_form()


func _refresh_form() -> void:
	_form = BioCellForms.params(form, genes)
	_lobes = int(_form["lobes"])
	spikes = int(_form["spikes"])
	spike_length = float(_form["spike_len"])
	_base_spikes = spikes
	wobble = float(_form["wobble"])
	tail_on = bool(_form["tail"])
	_poly = int(_form["poly"])
	_poly_amp = float(_form["poly_amp"])
	_oval = float(_form["oval"])
	if tail != null:
		tail.set_active(tail_on)


## The procedural body: axes decided by the engine from how this player plays (0-100 each).
## Nothing snaps: the body eases towards the new values over many seconds, in the background.
func set_look(axes: Dictionary) -> void:
	if _evolution_hold:
		_held_axes = axes.duplicate()
		return
	if look_target.is_empty():
		_base_core = core
		_base_edge = edge
		_base_spikes = spikes
	look_target = axes.duplicate()
	if look_now.is_empty():
		for k in axes:
			look_now[k] = 0.0  # starts neutral and grows into the look


## The traits Jev designed for this cell. They only change how the body is drawn.
func set_traits(designed: Dictionary) -> void:
	if _evolution_hold:
		_held_traits = designed.duplicate()
		_has_held_traits = true
		return
	traits = designed.duplicate()
	queue_redraw()


## Back to the plain newborn look (a restarted world).
func clear_look() -> void:
	traits = {}
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


## A limb tells the body where it is emerging, so the membrane and the nucleus flow into it instead of it being stuck on.
func set_bulge(id: int, angle: float, amount: float, spread: float) -> void:
	_bulges[id] = [angle, amount, spread]


func clear_bulge(id: int) -> void:
	_bulges.erase(id)


func _step_elastic(delta: float) -> void:
	for kick in _kicks:
		kick[0] = float(kick[0]) - delta
		if float(kick[0]) <= 0.0:
			_stretch_v += float(kick[1])
	_kicks = _kicks.filter(func(k: Array) -> bool: return float(k[0]) > 0.0)
	if _swell_target != 1.0 and BioClock.now() >= _swell_until:
		_swell_target = 1.0
	# The springs are stiff: one long step (a hitch when a form changes or a corridor loads) makes them oscillate to their limits and the
	# body flashes between a needle and a pancake. Small fixed steps keep them stable whatever the frame took.
	var steps := clampi(ceili(delta / SPRING_STEP), 1, 12)
	var h := minf(delta, SPRING_STEP * 12.0) / steps
	for i in steps:
		_stretch_v += (-220.0 * _stretch - 14.0 * _stretch_v) * h
		_stretch = clampf(_stretch + _stretch_v * h, -0.55, 1.4)
		_swell_v += (-150.0 * (_swell - _swell_target) - 13.0 * _swell_v) * h
		_swell = clampf(_swell + _swell_v * h, 0.5, 1.8)


func flash() -> void:
	_flash = 1.0


## Presentation only: the membrane reacts without moving the logical hitbox.
func hit_reaction(direction: Vector2 = Vector2.RIGHT) -> void:
	_hit_serial += 1
	_impact_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_impact_left = 0.24
	flash()
	elastic(_impact_dir, 0.10, 0.18, 0.025)


func attack_gesture(kind: StringName, direction: Vector2) -> void:
	_attack_serial += 1
	_attack_kind = str(kind)
	_attack_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_attack_left = 0.38
	var recoil := kind == BioAttackCatalog.ENEMY_SPIT
	elastic(-_attack_dir if recoil else _attack_dir, 0.12, 0.26 if recoil else 0.45, 0.075)
	swell(1.10, 0.10)


## Cumulative counters survive snapshot coalescing. First appearance never replays old blows.
func combat_visual_state() -> Array:
	return [_hit_serial, _attack_serial, snappedf(_telegraph_target, 0.01), _attack_kind, snappedf(_attack_dir.x, 0.01), snappedf(_attack_dir.y, 0.01)]


func apply_combat_visual(state: Array) -> void:
	if state.size() != 6: return
	var hits := int(state[0])
	var attacks := int(state[1])
	if _remote_hit >= 0 and hits > _remote_hit: hit_reaction(-_smooth_velocity)
	if _remote_attack >= 0 and attacks > _remote_attack:
		attack_gesture(StringName(str(state[3])), Vector2(float(state[4]), float(state[5])))
	_remote_hit = hits
	_remote_attack = attacks
	set_telegraph(float(state[2]))


func set_telegraph(amount: float) -> void:
	_telegraph_target = clampf(amount, 0.0, 1.0)


func set_integrity(fraction: float) -> void:
	if not wear_enabled: return
	var next := clampf(fraction, 0.0, 1.0)
	if not _integrity_initialized:
		_integrity_initialized = true
		integrity = next # first sight of an injured replica is not a new hit
	elif next < _integrity_target:
		var count := mini(32, spikes) if spikes > 0 else 6
		for i in count:
			if _spike_health(i, count, _integrity_target) > 0.5 and _spike_health(i, count, next) <= 0.5 and _shed.size() < 12:
				var angle := i * TAU/count - (Time.get_ticks_msec()*0.001+_seed)*spin
				_shed.append({"angle":angle,"age":0.0,"size":3.0 + float(i%3)})
	_integrity_target = next


static func _spike_health(index: int, count: int, health: float) -> float:
	if health <= 0: return 0
	var threshold := (fposmod(index * 0.61803398875, 1.0) + 0.5/maxi(1,count))*0.85
	return smoothstep(threshold - 0.07, threshold + 0.07, health)


func wear_size() -> float:
	return lerpf(0.84, 1.0, integrity) if wear_enabled else 1.0


func wound_strength() -> float:
	return pow(clampf(1.0-integrity, 0, 1), 0.7) if wear_enabled else 0.0


func _step_wear(delta: float) -> void:
	integrity = lerpf(integrity, _integrity_target, 1.0-exp(-9.0*delta))
	if not _shed.is_empty():
		for bit in _shed: bit.age = float(bit.age) + delta
		_shed = _shed.filter(func(bit: Dictionary) -> bool: return float(bit.age) < 0.7)


func rim() -> PackedVector2Array:
	return _rim


## The organelles of the expressed mutations, floating freely inside the membrane.
func organelles() -> Dictionary:
	return _orgs


## Lets every organelle drift without aim: a slow random walk with drag, pushed apart from each other and from the nucleus,
## and always kept inside the membrane (a hard limit, so none can ever escape, however the body deforms or moves).
func _step_organelles(delta: float) -> void:
	delta = minf(delta, 0.05)
	for id in _orgs.keys():
		if not genes.has(id):
			_orgs.erase(id)
	var r := BioOrganelles.body_radius(_rim)
	for id in genes:
		if not _orgs.has(id):
			_orgs[id] = {"p": Vector2.from_angle(_org_rng.randf() * TAU) * r * _org_rng.randf_range(0.1, 0.45), "v": Vector2.ZERO, "rot": _org_rng.randf() * TAU, "spin": _org_rng.randf_range(-0.5, 0.5), "seed": _org_rng.randf() * 20.0}
	var list := genes.duplicate()
	var sizes := {}
	for id in list:
		sizes[id] = BioOrganelles.size_of(str(BioGeneCatalog.get_gene(id).mark.get("kind", "")), r)
	var accel := -(_smooth_velocity - _last_org_velocity) * 0.35  # a sudden push on the cell makes them lag behind
	_last_org_velocity = _smooth_velocity
	for id in list:
		var o: Dictionary = _orgs[id]
		var v: Vector2 = o["v"]
		v += Vector2(_org_rng.randf_range(-1.0, 1.0), _org_rng.randf_range(-1.0, 1.0)) * r * 1.6 * delta  # the aimless wander
		v += accel * 0.5
		v *= exp(-0.8 * delta)
		v = v.limit_length(r * 0.28)
		o["v"] = v
		o["p"] = (o["p"] as Vector2) + v * delta
		o["rot"] = float(o["rot"]) + float(o["spin"]) * delta
	for i in list.size():  # keep them off each other and off the nucleus
		var a: Dictionary = _orgs[list[i]]
		var pa: Vector2 = a["p"]
		var to_nuc := pa - _nuc_pos
		var min_nuc := _nuc_r * 1.05 + float(sizes[list[i]]) * 0.7
		if to_nuc.length() < min_nuc:
			var push := to_nuc.normalized() if to_nuc.length() > 0.01 else Vector2.RIGHT
			a["p"] = pa + push * (min_nuc - to_nuc.length()) * 0.5
			a["v"] = (a["v"] as Vector2) + push * r * 0.15
		for j in range(i + 1, list.size()):
			var b: Dictionary = _orgs[list[j]]
			var d: Vector2 = (a["p"] as Vector2) - (b["p"] as Vector2)
			var min_d := (float(sizes[list[i]]) + float(sizes[list[j]])) * 0.8
			if d.length() < min_d:
				var n := d.normalized() if d.length() > 0.01 else Vector2.from_angle(_org_rng.randf() * TAU)
				var shove := (min_d - d.length()) * 0.5
				a["p"] = (a["p"] as Vector2) + n * shove
				b["p"] = (b["p"] as Vector2) - n * shove
				a["v"] = (a["v"] as Vector2) + n * r * 0.08
				b["v"] = (b["v"] as Vector2) - n * r * 0.08
	for id in list:  # the membrane is a hard wall
		var o: Dictionary = _orgs[id]
		var p: Vector2 = o["p"]
		var limit := maxf(BioOrganelles.rim_radius_at(_rim, p.angle()) * 0.86 - float(sizes[id]) * 0.95, 0.0)
		if p.length() > limit:
			var n := p.normalized()
			o["p"] = n * limit
			var v: Vector2 = o["v"]
			if v.dot(n) > 0.0:
				o["v"] = v - n * v.dot(n) * 1.6  # bounces softly off the membrane


func _ready() -> void:
	material = BioArt.additive()
	_wear_host = get_parent() as BioCellActor
	_pocket_layer = BioPocketLayer.new()
	_pocket_layer.body = self
	_pocket_layer.name = "Pockets"
	add_child(_pocket_layer)
	_nucleus = BioArt.make_glow(core, 1.0, 2)
	add_child(_nucleus)
	_rim.resize(RIM)


## Every polygon of a membrane is a fresh GPU buffer each frame, and the cell of the player is the only one the eye follows: a cell off
## screen is not redrawn at all (on any device), and on a phone
## the others are redrawn only every `background_stride` frames (with the time they were owed).
static var background_stride := 1
var _owed := 0.0


func _process(delta: float) -> void:
	if wear_enabled and is_instance_valid(_wear_host):
		var vitals := _wear_host.combatant.actor.vitals
		set_integrity(vitals.membrane / maxf(1.0, vitals.max_membrane))
	if not _evolution_hold: evolution_white = move_toward(evolution_white, 0.0, delta * 1.8)
	if absf(integrity-_integrity_target) < 0.002 and _shed.is_empty() and evolution_white <= 0 and not _evolution_hold and _impact_left <= 0 and _attack_left <= 0 and _telegraph_target <= 0.01 and absf(_stretch) < 0.015 and _kicks.is_empty():
		var host_node := get_parent()
		var mine: Variant = BioFx.root.get("player") if BioFx.root != null else null
		if host_node != null and host_node != mine:
			_owed = minf(_owed + delta, 0.12)
			if not get_viewport_rect().grow(260.0).has_point(get_global_transform_with_canvas().origin):
				return
			if (Engine.get_process_frames() + int(get_instance_id() % background_stride)) % background_stride != 0:
				return
			delta = _owed
			_owed = 0.0
	_step_wear(delta)
	_flash = move_toward(_flash, 0.0, delta * 4.5)
	_telegraph = lerpf(_telegraph, _telegraph_target, 1.0 - exp(-14.0 * delta))
	_attack_left = maxf(0.0, _attack_left - delta)
	_impact_left = maxf(0.0, _impact_left - delta)
	position = _impact_dir * sin((0.24 - _impact_left) * 65.0) * 3.0 * (_impact_left / 0.24)
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
	_ascend = move_toward(_ascend, _ascend_target, delta * 0.18)
	_human = _ascend  # the ghost shape grows continuously with it
	_walk += speed_units * delta * 1.7
	_face = lerpf(_face, signf(_smooth_velocity.x) if absf(_smooth_velocity.x) > 8.0 else _face, 1.0 - exp(-6.0 * delta))
	var stretch := clampf(speed_units * 0.04, 0.0, 0.35)
	var breath := 1.0 + 0.04 * sin(t * 3.0) + _telegraph * 0.28
	for i in RIM:
		var a := i * TAU / RIM
		var n := Vector2.from_angle(a)
		var w := 1.0 + wobble * (sin(a * 3.0 + t * 2.1) + 0.6 * sin(a * 5.0 - t * 3.3) + 0.4 * sin(a * 2.0 + t * 1.3))
		var spike := 0.0
		if spikes > 0:
			spike = spike_length * pow(maxf(0.0, cos((a + t * spin) * spikes)), 6.0)
			if wear_enabled:
				var index := posmod(roundi((a+t*spin)*spikes/TAU), spikes)
				spike *= _spike_health(index, spikes, integrity)
		var lobe := 0.0
		if _lobes > 0:  # pseudopods: lobes that slowly crawl around the body
			lobe = _lobe_amp_now * pow(maxf(0.0, cos((a - t * 0.25) * _lobes)), 2.0) * (1.0 - 0.8 * _human)  # the pseudopod lobes melt into the figure
		var along := n.dot(dir)
		var silhouette := 1.0
		if _poly > 0:
			silhouette += _poly_amp * cos(_poly * a) * (1.0 - 0.6 * _human)
		if _oval > 0.0:
			silhouette += _oval * (2.0 * along * along - 1.0)
		var squash := 1.0 + stretch * along * along - stretch * 0.5 * (1.0 - along * along)
		var swelling_sum := 0.0
		for b in _bulges.values():
			var d := angle_difference(a, float(b[0])) / float(b[2])
			swelling_sum += float(b[1]) * exp(-d * d)
		var swelling := 1.0 + minf(swelling_sum, 0.5)  # many limbs at once never blow the body up
		if wear_enabled and integrity < 0.999:
			silhouette *= 1.0 - (1.0-integrity)*0.16*pow(maxf(0.0, cos(a*3.0+_seed)), 4.0)
		var p := n * radius_units * BioArt.UNIT * (w + spike + lobe) * squash * breath * _size_mul * _size_now * wear_size() * _swell * swelling * silhouette * BioGhostForm.radius_mul(form, a, _human, t)
		if _human > 0.0:  # a floaty lean with the motion, and a slow bob: one body, like a ghost
			p = p.rotated(BioGhostForm.lean(_smooth_velocity.x, _human)) + Vector2(0.0, sin(t * 1.4) * 2.5 * _human)
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
	_nucleus.modulate = BioArt.with_alpha(_core_now().lerp(BioArt.CRIMSON, _telegraph), 0.4 * (1.0 - 0.6 * _human))
	_nucleus.modulate = _nucleus.modulate.lerp(Color.WHITE, evolution_white)
	var r_px := radius_units * BioArt.UNIT * _size_mul * _size_now * wear_size()
	var pull := Vector2.ZERO
	for b in _bulges.values():
		pull += Vector2.from_angle(float(b[0])) * float(b[1])
	_nuc_pos = _smooth_velocity * 0.01 + pull * radius_units * BioArt.UNIT * 0.55
	_nuc_r = r_px * 0.42 * _nucleus_now * pulse
	if not genes.is_empty():  # room for the pockets below: the nucleus never grows over them
		_nuc_r = minf(_nuc_r, r_px * 0.3)
	if _human > 0.0:  # the nucleus rises into the head
		_nuc_pos = _nuc_pos.lerp(BioGhostForm.head_center(form, r_px, _human), minf(_human * 1.5, 1.0)).rotated(BioGhostForm.lean(_smooth_velocity.x, _human))
	if _human > 0.0:
		_nuc_r = minf(_nuc_r, BioGhostForm.head_room(form, r_px, _human) * 0.8)
	_nucleus.position = _nuc_pos
	_step_organelles(delta)
	_pocket_layer.queue_redraw()
	_nucleus.scale = Vector2.ONE * (_nuc_r * 2.5 * (1.0 + _telegraph * 0.5) / 128.0)
	if pull.length() > 0.02:  # the nucleus stretches towards where the limb is growing
		_nucleus.rotation = pull.angle()
		_nuc_rot = pull.angle() * 0.5
		_nucleus.scale *= Vector2(1.0 + minf(pull.length(), 1.0) * 0.7, 1.0 - minf(pull.length(), 1.0) * 0.12)
	else:
		_nucleus.rotation = 0.0
		_nuc_rot = lerp_angle(_nuc_rot, 0.0, 0.1)
	queue_redraw()


func _core_now() -> Color:
	return (core.lerp(Color(0.46,0.36,0.5), (1.0-integrity)*0.45) if wear_enabled else core).lerp(Color.WHITE, _flash * 0.8)


func _edge_now() -> Color:
	return edge.lerp(BioArt.CRIMSON, _telegraph).lerp(Color.WHITE, _flash)


func _draw() -> void:
	if _rim.size() < 3:
		return
	var edge_now := _edge_now()
	var core_now := _core_now()
	var glow := BioDesign.glow(str(traits.get("brilho", "")))
	if glow.a > 0.0:
		core_now = core_now.lerp(glow, 0.55)
		edge_now = edge_now.lerp(glow, 0.35)
	var r_px := radius_units * BioArt.UNIT * _size_mul * _size_now * wear_size()
	if _impact_left > 0.0:
		var progress := 1.0 - _impact_left / 0.24
		draw_arc(Vector2.ZERO, r_px * (1.05 + progress * 0.55), 0, TAU, 32, Color(1.0, 0.86, 0.72, (1.0-progress)*0.8), 2.0, true)
	if _attack_left > 0.0:
		var progress := 1.0 - _attack_left / 0.38
		var angle := _attack_dir.angle()
		draw_arc(Vector2.ZERO, r_px * (1.0 + sin(progress*PI)*0.45), angle-0.65, angle+0.65, 16, BioArt.with_alpha(BioArt.AMBER, sin(progress*PI)*0.7), 2.5, true)
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
	_draw_membrane_trait(closed, edge_now, Time.get_ticks_msec() * 0.001 + _seed)
	if wear_enabled: _draw_wear(r_px, edge_now)
	if str(traits.get("nucleo", "")) == "composto":
		BioNucleusShapes.draw_composite(self, _nuc_pos, _nuc_r, _nuc_rot, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, int(BioDesign.LOBES.get(str(traits.get("lobulacao", "")), 5)), str(traits.get("recorte", "liso")), str(traits.get("nucleolo", "nenhum")))
	else:
		BioNucleusShapes.draw(self, BioDesign.nucleus_form(str(traits.get("nucleo", "")), form), _nuc_pos, _nuc_r, _nuc_rot, Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, 6 if genes.has(&"nucleo_multilobulado") else 3)
	_draw_genes(edge_now, core_now)
	_draw_organelle_trait(radius_units * BioArt.UNIT * _size_mul * _size_now * wear_size(), Time.get_ticks_msec() * 0.001 + _seed, core_now)
	BioCellForms.draw(self, form, genes, radius_units * BioArt.UNIT * _size_mul * _size_now * wear_size(), Time.get_ticks_msec() * 0.001 + _seed, core_now, edge_now, _front, _human, not genes.is_empty())
	if evolution_white > 0:
		_fill_fan(_rim, Color(1, 1, 1, evolution_white))
		draw_arc(Vector2.ZERO, r_px * 1.28, 0, TAU, 48, Color(0.7, 0.94, 1.0, evolution_white*0.6), 3.0, true)
		if _evolution_hold:
			var orbit := Time.get_ticks_msec() * 0.001
			for i in 3:
				var angle := orbit * 0.7 + i * TAU / 3
				draw_arc(Vector2.ZERO, r_px * 1.7, angle, angle + 0.85, 16, Color(0.55,0.9,1.0,0.5), 1.5, true)
			for i in 10:
				var phase := fmod(orbit * 0.6 + i * 0.1, 1.0)
				var at := Vector2.from_angle(i * TAU / 10 + orbit * 0.25) * r_px * lerpf(2.6,1.1,phase)
				draw_circle(at, 1.2, Color(0.7,0.95,1.0,sin(phase*PI)*0.8))


## Persistent wounds and short-lived flakes, drawn in the same bounded canvas pass.
func _draw_wear(radius: float, tint: Color) -> void:
	var worn := wound_strength()
	var t := Time.get_ticks_msec()*0.001 + _seed
	for i in (3 if worn > 0.01 else 0):
		var dir := Vector2.from_angle(_seed + i*TAU/3)
		var seam := PackedVector2Array([dir*radius*0.30, dir.rotated(0.15)*radius*0.50, dir.rotated(-0.08)*radius*0.68, dir*radius*0.9])
		draw_polyline(seam, Color(1.0,0.68,0.72,worn*0.85), 1.5, true)
	if integrity < 0.3:
		draw_arc(_nuc_pos, _nuc_r*1.25, 0, TAU, 24, Color(1,0.65,0.35,(0.3-integrity)*(1.5+0.7*sin(t*5))), 1.7, true)
	for bit in _shed:
		var age := float(bit.age)
		var dir := Vector2.from_angle(float(bit.angle))
		var p := dir*radius*(1.0+age*2.6) + dir.orthogonal()*sin(age*5)*radius*0.2
		var size := float(bit.size)*(1.0-age/0.7)
		var axis := dir.rotated(age*4.0)
		if spikes == 0:
			draw_circle(p, size, BioArt.with_alpha(tint, 1.0-age/0.7))
		else:
			draw_colored_polygon(PackedVector2Array([p+axis*size*2, p-axis*size+axis.orthogonal()*size, p-axis*size-axis.orthogonal()*size]), BioArt.with_alpha(tint, 1.0-age/0.7))


## The membrane texture Jev chose: ripples, spines, beads, a second wall (smooth leaves it plain).
func _draw_membrane_trait(closed: PackedVector2Array, edge_now: Color, t: float) -> void:
	var style := str(traits.get("membrana", ""))
	if style == "" or style == "lisa" or closed.size() < 8:
		return
	var n := closed.size() - 1
	var col := BioArt.with_alpha(edge_now.lerp(Color.WHITE, 0.4), 0.85)
	match style:
		"ondulada":
			var wave := PackedVector2Array()
			for i in n + 1:
				var p := closed[i % n]
				wave.append(p + p.normalized() * (4.0 + 3.0 * sin(i * 0.9 + t * 2.4)))
			draw_polyline(wave, BioArt.with_alpha(col, 0.55), 2.0, true)
		"espinhosa":
			for k in 16:
				var p2 := closed[(k * n / 16) % n]
				draw_line(p2, p2 + p2.normalized() * (9.0 + 3.0 * sin(t * 3.0 + k)), col, 2.2, true)
		"contas":
			for k in 26:
				draw_circle(closed[(k * n / 26) % n] * 1.04, 2.6, col)
		"dupla":
			var outer := PackedVector2Array()
			for p3 in closed:
				outer.append(p3 * 1.13)
			draw_polyline(outer, BioArt.with_alpha(col, 0.6), 2.0, true)


## The organelles Jev chose to dominate the inside: a few of one kind drifting under the membrane.
func _draw_organelle_trait(r: float, t: float, core_now: Color) -> void:
	var kind := str(traits.get("organelas", ""))
	if kind == "":
		return
	for k in 7:
		var ang := t * (0.12 + 0.02 * k) + k * 2.399
		var pos := Vector2.from_angle(ang) * r * (0.3 + 0.38 * fmod(k * 0.37, 1.0))
		match kind:
			"mitocondrias":
				draw_set_transform(pos, ang, Vector2(1.7, 0.8))
				draw_circle(Vector2.ZERO, 4.0, BioArt.with_alpha(BioArt.AMBER, 0.75))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"lisossomos":
				draw_circle(pos, 3.6, BioArt.with_alpha(Color(0.45, 1.0, 0.45), 0.7))
			"vesiculas":
				draw_arc(pos, 4.4, 0.0, TAU, 14, BioArt.with_alpha(Color(0.85, 0.92, 1.0), 0.7), 1.8, true)
			"tubulos":
				draw_line(pos, pos + Vector2.from_angle(ang + 1.0) * 14.0, BioArt.with_alpha(core_now.lerp(Color.WHITE, 0.4), 0.7), 1.6, true)
			"vacuolos":
				draw_arc(pos, 6.5, 0.0, TAU, 16, BioArt.with_alpha(Color(0.75, 0.9, 1.0), 0.5), 2.2, true)
			"granulos":
				draw_circle(pos, 2.8, BioArt.with_alpha(Color(0.25, 0.08, 0.2), 0.9))
				draw_circle(pos, 1.4, BioArt.with_alpha(BioArt.CRIMSON, 0.9))


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


## What the expressed genes show on the body: a thicker wall (structural), and one small pocket per gene in its own fixed
## place (see BioOrganelles), so the build reads at a glance and no mutation hides another.
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
			wall.append(p * 1.12)
		wall.append(wall[0])
		draw_polyline(wall, BioArt.with_alpha(edge_now, 0.5), 3.0, true)


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
