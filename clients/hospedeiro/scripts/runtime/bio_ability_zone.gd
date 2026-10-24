class_name BioAbilityZone
extends Node2D
## A lasting ability effect. Every style has its own signature, taken from the biology of what it is: a corrosive puddle with
## a honeycomb of bubbling hexagons (acid), a DNA net of double helices (net), a capsule that bursts into a flower of chromatin
## hooks (trap), a drifting cloud of granule blobs (poison), vesicles that fall and bloom into a mycelium (spores), a mirage of
## heat bands (heat), plates of cytoskeleton armour (shield), a staff of travelling notes (song), a lymphatic vessel that raises
## orbiting sentinels (sentinels) and cytokine hexagons that dock on receptors (heal). Damage and states go through the same
## combat rules as everything else.

const TRAP_LINGER := 1.6

var owner_combatant: BioCombatant
var host: BioCellActor
var ability: StringName
var style := ""
var color := Color.WHITE
var radius_px := 100.0
var duration := 4.0
var follow := false
var tick_damage := 0.0  # damage per half second to enemies inside
var slow := 1.0  # movement multiplier applied to enemies inside (1 = none)
var delay := 0.0  # a trap waits this long, then bursts once
var burst_damage := 0.0
var heal_total := 0.0  # membrane restored over the duration (to the owner)
var regen_membrane := 0.0  # per second, while the owner stands inside
var regen_atp := 0.0
var sentinels := 0
var weaken := 1.0  # enemies inside deal this share of their damage (1 = unchanged)
var drift := 0.0  # units per second towards the nearest enemy (the wandering zone)

var _age := 0.0
var _tick := 0.0
var _fired := false
var _fired_at := 0.0
var _stream: CPUParticles2D
var _seed := randf() * 10.0
var _hit_def: BioAttackDef


static func spawn(parent: Node, host_cell: BioCellActor, id: StringName, pos: Vector2, params: Dictionary) -> BioAbilityZone:
	var z := BioAbilityZone.new()
	z.owner_combatant = host_cell.combatant
	z.host = host_cell
	z.ability = id
	z.style = str(params.get("style", ""))
	z.color = params.get("color", Color.WHITE)
	z.radius_px = float(params.get("radius", 2.5)) * BioArt.UNIT
	z.duration = float(params.get("duration", 4.0))
	z.follow = bool(params.get("follow", false))
	z.tick_damage = float(params.get("tick", 0.0))
	z.slow = float(params.get("slow", 0.0))
	z.slow = 1.0 - z.slow if z.slow > 0.0 else 1.0
	z.delay = float(params.get("delay", 0.0))
	z.burst_damage = float(params.get("burst", 0.0))
	z.heal_total = float(params.get("amount", 0.0))
	z.regen_membrane = float(params.get("regen_membrane", 0.0))
	z.regen_atp = float(params.get("regen_atp", 0.0))
	z.sentinels = int(params.get("count", 0)) if z.style == "sentinels" else 0
	z.drift = float(params.get("drift", 0.0))
	z.weaken = float(params.get("weaken", 1.0))
	z.position = pos
	parent.add_child(z)
	return z


func _ready() -> void:
	z_index = 6
	material = BioArt.additive()
	_hit_def = BioAttackDef.new(ability, 0.0, tick_damage, 0.0, 0.0, 0.0, 0.0)
	var amount := 0
	var rise := 0.0
	var size := 9.0
	match style:  # each style keeps only the particles that belong to its own story
		"acid", "poison":
			amount = 10
			rise = 30.0
		"heat":
			amount = 12
			rise = 45.0
			color = Color(1.0, 0.7, 0.2)
		"spores":
			amount = 6
			rise = 20.0
		"song", "heal":
			amount = 6
			rise = 40.0
		"edema":
			amount = 5
			rise = 18.0
	if amount > 0:
		_stream = BioPfx.stream(self, color, amount, 1.2, size, radius_px * 0.8, rise, 22.0)


func _process(delta: float) -> void:
	_age += delta
	if drift > 0.0 and is_instance_valid(owner_combatant.get_parent()) and style != "trap":
		var near := BioTargeting.enemies(get_world_2d(), global_position, 7.0 * BioArt.UNIT, owner_combatant.actor.team)
		var best := BioTargeting.best(near, global_position, Vector2.ZERO, 7.0 * BioArt.UNIT)
		if best != null:
			global_position = global_position.move_toward(best.global_position, drift * BioArt.UNIT * delta)
	if follow and is_instance_valid(host):
		global_position = host.global_position
	if is_instance_valid(_stream):
		_stream.global_position = global_position
	_tick -= delta
	if style == "trap":
		if not _fired and _age >= delay:
			_detonate()
		if _fired and _age >= delay + TRAP_LINGER:
			_finish()
		queue_redraw()
		return
	if _tick <= 0.0:
		_tick = 0.5
		_pulse()
	if style == "heal" and heal_total > 0.0 and is_instance_valid(host):
		host.combatant.actor.vitals.repair(heal_total / duration * delta)
	if (regen_membrane > 0.0 or regen_atp > 0.0) and is_instance_valid(host) and global_position.distance_to(host.global_position) <= radius_px:
		host.combatant.actor.vitals.repair(regen_membrane * delta)
		host.combatant.actor.vitals.add_atp(regen_atp * delta)
	if sentinels > 0:
		_sentinel_hits()
	if Engine.get_process_frames() % 2 == 0:  # a zone's drawing is detailed and slow-moving: every second frame is enough
		queue_redraw()
	if _age >= duration:
		_finish()


func _finish() -> void:
	BioPfx.stop(_stream)
	queue_free()


## Half-second pulse: damage and slowing of everything inside.
func _pulse() -> void:
	if tick_damage <= 0.0 and slow >= 1.0 and weaken >= 1.0:
		return
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_combatant.actor.team):
		if tick_damage > 0.0:
			e.combatant.receive_hit(owner_combatant, _hit_def)
		if slow < 1.0:
			e.slow(slow, 0.8)
		if weaken < 1.0:
			e.combatant.weaken(weaken, 0.8)
		if style == "heat":
			BioPfx.burst(BioFx.root, e.global_position, Color(1.0, 0.5, 0.2), 3, 50.0, 0.4, 7.0)


func _detonate() -> void:
	_fired = true
	_fired_at = _age
	var def := BioAttackDef.new(ability, 0.0, burst_damage, 0.0, 0.0, 9.0, 0.0)
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_combatant.actor.team):
		e.combatant.receive_hit(owner_combatant, def)
		e.apply_impulse((e.global_position - global_position).normalized() * 9.0)
	BioFx.shake(0.14)


func _sentinel_pos(i: int) -> Vector2:
	var rise := clampf((_age - 0.25) / 0.1, 0.0, 1.0) * (1.0 - clampf((_age - (duration - 0.3)) / 0.3, 0.0, 1.0))
	var a := _age * TAU * 1.5 / 1.0 * 0.5 + i * TAU / maxi(sentinels, 1)
	return Vector2.from_angle(a) * (radius_px * 0.9) * rise


func _sentinel_hits() -> void:
	if _tick > 0.0 or tick_damage <= 0.0:
		return
	for i in sentinels:
		for e in BioTargeting.enemies(get_world_2d(), global_position + _sentinel_pos(i), 0.9 * BioArt.UNIT, owner_combatant.actor.team):
			e.combatant.receive_hit(owner_combatant, _hit_def)
			BioPfx.burst(BioFx.root, e.global_position, color, 4, 90.0, 0.35, 7.0)


func _c(a: float, lighten: float = 0.0) -> Color:
	return BioArt.with_alpha(color.lerp(Color.WHITE, lighten), a)


func _draw() -> void:
	var t := _age + _seed
	var grow := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var r := radius_px * grow
	match style:
		"acid":
			_acid(t, r, fade)
		"net":
			_net(t, r, fade)
		"trap":
			_trap(t, r)
		"poison":
			_poison(t, r, fade)
		"spores":
			_spores(t, r, fade)
		"heat":
			_heat(t, r, fade)
		"shield":
			_shield(t, fade)
		"song":
			_song(t, r, fade)
		"heal":
			_heal(t, fade)
		"sentinels":
			_sentinels(t, fade)
		"edema":
			_edema(t, r, fade)
		"calm":
			_calm(t, r, fade)


## The swollen tissue: a cluster of translucent blisters that fill and sag, bobbing, with beads of fluid sliding down.
func _edema(t: float, r: float, fade: float) -> void:
	for i in 9:
		var base := Vector2.from_angle(i * 2.399 + sin(t * 0.4 + i) * 0.2) * r * (0.15 + 0.6 * fmod(i * 0.41, 1.0))
		var size := (11.0 + 12.0 * fmod(i * 0.57, 1.0)) * (r / maxf(radius_px, 1.0)) * (1.0 + 0.16 * sin(t * 1.8 + i * 1.3))
		draw_circle(base, size, _c(0.1 * fade))
		draw_arc(base, size, 0.0, TAU, 20, _c(0.55 * fade, 0.3), 1.8, true)
		draw_arc(base + Vector2(-size * 0.25, -size * 0.25), size * 0.5, PI * 1.1, PI * 1.6, 8, _c(0.7 * fade, 0.7), 1.4, true)  # the shine on a blister
		var bead := fmod(t * 0.6 + i * 0.31, 1.0)
		draw_circle(base + Vector2(size * 0.4, size * (0.2 + 0.9 * bead)), 1.6 * (1.0 - bead) + 0.6, _c(0.8 * (1.0 - bead) * fade, 0.5))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, _c(0.2 * fade), 1.2, true)


## Tolerance: rings that do not spread but fall inward, slow and even, around a still point. Nothing flickers: it is the opposite of an alarm.
func _calm(t: float, r: float, fade: float) -> void:
	for k in 4:
		var phase := fmod(t * 0.22 + k * 0.25, 1.0)
		draw_arc(Vector2.ZERO, r * (1.0 - 0.85 * phase), 0.0, TAU, 56, _c(0.55 * (1.0 - phase) * fade, 0.2), 2.2, true)
	draw_circle(Vector2.ZERO, 4.0 + sin(t * 1.1), _c(0.9 * fade, 0.7))
	for i in 10:  # a handful of motes settling toward the centre
		var life := fmod(t * 0.25 + i * 0.113, 1.0)
		draw_circle(Vector2.from_angle(i * 2.399) * r * (1.0 - life), 1.8 * (1.0 - life) + 0.5, _c(0.8 * (1.0 - life) * fade, 0.5))

## A corrosive puddle: a living irregular outline whose edge erodes a vertex at a time, a honeycomb of hexagons that flicker,
## and bubbles that pop with a little cross.
func _acid(t: float, r: float, fade: float) -> void:
	var n := 18
	var eroded := int(_age / 0.7) % n
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		var noise := 0.5 * sin(i * 2.3 + t * 2.0) + 0.5 * sin(i * 5.1 - t * 1.3)
		var shrink := 0.06 if i == eroded else 0.0
		pts.append(Vector2.from_angle(a) * r * (1.0 + 0.14 * noise - shrink - 0.2 * clampf((_age - (duration - 0.5)) / 0.5, 0.0, 1.0) * (1.0 if i % 3 else 0.5)))
	for i in n:
		var c0 := _c(0.04 * fade)
		var c1 := _c(0.2 * fade)
		draw_primitive(PackedVector2Array([Vector2.ZERO, pts[i], pts[(i + 1) % n]]), PackedColorArray([c0, c1, c1]), PackedVector2Array())
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _c(0.7 * fade, 0.2), 2.2, true)
	var hex := 10.0
	for q in range(-6, 7):
		for s in range(-6, 7):
			var p := Vector2((q + s * 0.5) * hex * 1.8, s * hex * 1.56)
			if p.length() < r * 0.85:
				var blink := 0.5 + 0.5 * sin(t * 1.5 + q * 1.3 + s * 2.1)
				if blink > 0.6:
					var hp := PackedVector2Array()
					for k in 7:
						hp.append(p + Vector2.from_angle(k * TAU / 6.0 + PI / 6.0) * hex * 0.9)
					draw_polyline(hp, _c(0.2 * (blink - 0.6) * 2.5 * fade, 0.3), 1.2, true)
	for b in 7:  # bubbles that rise and pop
		var life := fmod(t * 0.9 + b * 0.37, 1.0)
		var a := b * 2.399 + floorf(t * 0.9 + b * 0.37) * 1.7
		var p2 := Vector2.from_angle(a) * r * (0.15 + 0.65 * fmod(b * 0.31 + floorf(t * 0.9 + b * 0.37) * 0.23, 1.0))
		if life < 0.85:
			draw_arc(p2 + Vector2(0, -life * 10.0), 1.5 + 2.5 * life, 0.0, TAU, 10, _c(0.8 * (1.0 - life) * fade, 0.4), 1.4, true)
		else:  # the pop: a tiny cross
			var s2 := 3.0
			draw_line(p2 - Vector2(s2, 0), p2 + Vector2(s2, 0), _c(0.9 * fade, 0.6), 1.2, true)
			draw_line(p2 - Vector2(0, s2), p2 + Vector2(0, s2), _c(0.9 * fade, 0.6), 1.2, true)


## DNA strands thrown as a web: seven spokes that are double helices with rungs, heptagonal rings, histone nodes that blink,
## trembling at 3 Hz; at the end the web comes apart from the outside in.
func _net(t: float, r: float, fade: float) -> void:
	var collapse := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var length := r * collapse
	var spokes := 7
	for i in spokes:
		var a := i * TAU / spokes + 0.1
		var dir := Vector2.from_angle(a)
		var perp := dir.orthogonal()
		var prev_a := Vector2.ZERO
		var prev_b := Vector2.ZERO
		var steps := int(length / 6.0)
		for s in range(1, steps + 1):
			var d := s * 6.0
			var amp := 3.0 * (1.0 + 0.25 * sin(t * 3.0 * TAU * 0.5 + i))
			var wave := sin(d / 8.0 * PI + t * 3.0) * amp
			var pa := dir * d + perp * wave
			var pb := dir * d - perp * wave
			draw_line(prev_a, pa, _c(0.75 * fade, 0.3), 1.4, true)
			draw_line(prev_b, pb, _c(0.75 * fade, 0.3), 1.4, true)
			if s % 2 == 0:
				draw_line(pa, pb, _c(0.3 * fade, 0.5), 1.0, true)
			prev_a = pa
			prev_b = pb
	for ring in 4:
		var rr := length * (0.25 + 0.25 * ring)
		var pts := PackedVector2Array()
		for i in spokes + 1:
			pts.append(Vector2.from_angle(i * TAU / spokes + 0.1) * rr * (1.0 + 0.02 * sin(t * 3.0 + i + ring)))
		draw_polyline(pts, _c(0.55 * fade, 0.3), 1.3, true)
		for i in spokes:
			var blink := 0.5 + 0.5 * sin(t * 2.0 + i * 1.7 + ring * 2.3)
			if blink > 0.7:
				draw_circle(pts[i], 2.2, _c(0.95 * fade, 0.8))


## A capsule that is laid down, trembles ever faster, then blooms into four petals and twelve chromatin filaments that
## snap straight, hook, and finally lie limp and pulsing.
func _trap(t: float, r: float) -> void:
	var ice := Color(0.55, 0.85, 1.0)
	if not _fired:
		var prog := clampf(_age / maxf(delay, 0.1), 0.0, 1.0)
		var shake := (1.0 + 7.0 * prog) * 0.4
		for i in 8:  # the dashed membrane turns
			var a := t * 1.2 + i * TAU / 8.0
			draw_arc(Vector2.ZERO, 11.0, a, a + TAU / 8.0 * 0.55, 6, _c(0.9, 0.5), 1.8, true)
		for k in 3:  # the lobed nucleus comes undone, trembling
			var a2 := t * (2.0 + 6.0 * prog) * TAU * 0.3 + k * TAU / 3.0
			draw_circle(Vector2.from_angle(a2) * (2.5 + shake) + Vector2(sin(t * 40.0 + k), cos(t * 37.0 + k)) * shake * 0.4, 2.2, _c(0.9, 0.7))
		var spark := Vector2.from_angle(t * 9.0) * 15.0
		draw_circle(spark, 1.6, _c(0.95, 0.8))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, _c(0.12 + 0.2 * prog), 1.2, true)
		return
	var since := _age - _fired_at
	var life := clampf((delay + TRAP_LINGER - _age) / 0.5, 0.0, 1.0)
	var petal := clampf(since / 0.3, 0.0, 1.0)
	for i in 4:  # four petals opening
		var a := i * TAU / 4.0 + PI / 4.0
		draw_arc(Vector2.from_angle(a) * 5.0 * petal, 14.0 * petal, a - 0.9, a + 0.9, 10, _c(0.85 * life, 0.4), 2.2, true)
	var snap := clampf(since / 0.1, 0.0, 1.0)
	var droop := clampf((since - 0.15) / 0.5, 0.0, 1.0)
	for i in 12:
		var a := i * TAU / 12.0 + 0.2
		var dir := Vector2.from_angle(a)
		var length := r * 0.95 * snap
		var pts := PackedVector2Array()
		for j in 12:
			var f := j / 11.0
			var hook := 0.0
			if f > 0.8:
				hook = (f - 0.8) * 5.0 * (1.0 - droop * 0.7)  # the tip curls into a grapple
			var sag := droop * f * f * 14.0 * (1.0 if i % 2 == 0 else -1.0)
			pts.append(dir * length * f + dir.orthogonal() * (sag + hook * 9.0 * (1.0 if i % 2 == 0 else -1.0)))
		var pulse := 0.6 + 0.4 * sin(t * 4.0 + i)
		draw_polyline(pts, BioArt.with_alpha(ice.lerp(Color.WHITE, 0.5 * (1.0 - droop)), (0.9 - 0.35 * droop) * life * pulse), 1.8, true)
		if snap >= 1.0:
			draw_circle(pts[11], 2.2, BioArt.with_alpha(Color.WHITE, 0.85 * life))


## A cloud with no edge: translucent blobs drifting on slow noise around the cell, breathing as one.
func _poison(t: float, r: float, fade: float) -> void:
	for i in 7:
		var base := Vector2.from_angle(i * 0.9 + t * 0.22 + sin(t * 0.7 + i) * 0.5) * r * (0.3 + 0.35 * fmod(i * 0.37, 1.0))
		var size := (18.0 + 14.0 * fmod(i * 0.53, 1.0)) * (r / maxf(radius_px, 1.0)) * (1.0 + 0.12 * sin(t * 1.6 + i))
		var age_tint := clampf(_age / duration, 0.0, 1.0)
		var col := color.lerp(Color.WHITE, 0.3).lerp(color.darkened(0.1), age_tint)
		draw_texture_rect(BioArt.glow_texture(), Rect2(base - Vector2.ONE * size * 1.6, Vector2.ONE * size * 3.2), false, BioArt.with_alpha(col, 0.16 * fade))
		draw_arc(base, size * 0.8, 0.0, TAU, 16, BioArt.with_alpha(col, 0.14 * fade), 1.2, true)
	for k in 6:  # six pores around the cell breathe the cloud out
		var a := k * TAU / 6.0 + 0.4
		var open := 0.5 + 0.5 * sin(t * 2.0 + k)
		draw_arc(Vector2.ZERO, 22.0, a - 0.14, a + 0.14, 5, BioArt.with_alpha(Color(0.9, 1.0, 0.7), 0.6 * open * fade), 2.0, true)


## Vesicles fall slantwise and bloom where they land into tiny flowers that breathe, tied together by a mycelium of threads.
func _spores(t: float, r: float, fade: float) -> void:
	var count := 20
	var spots: Array[Vector2] = []
	var open: Array[float] = []
	for i in count:
		var ang := i * 2.399 + _seed
		var ground := Vector2.from_angle(ang) * r * (0.15 + 0.8 * fmod(i * 0.173, 1.0))
		var born := i * 0.17
		var cycle := _age - born
		spots.append(ground)
		var bloomed := clampf((cycle - 0.7) / 0.25, 0.0, 1.0)
		open.append(bloomed)
		if cycle < 0.0:
			continue
		if cycle < 0.7:  # still falling: oblique snow with a sway
			var f := cycle / 0.7
			var p := ground + Vector2(-26.0 * (1.0 - f) + sin(cycle * 7.0) * 4.0, -70.0 * (1.0 - f))
			draw_circle(p, 3.0, _c(0.8 * fade, 0.5))
			draw_arc(p, 4.5, 0.0, TAU, 10, _c(0.45 * fade), 1.2, true)
		else:
			var breathe := 1.0 + 0.1 * sin(t * 2.0 + i)
			for p5 in 5:
				var a := p5 * TAU / 5.0 + i
				draw_line(ground, ground + Vector2.from_angle(a) * 4.5 * bloomed * breathe, _c(0.9 * fade, 0.4), 1.6, true)
	for i in count:  # the mycelium
		for j in range(i + 1, count):
			if open[i] > 0.9 and open[j] > 0.9 and spots[i].distance_to(spots[j]) < r * 0.5:
				draw_line(spots[i], spots[j], _c(0.18 * fade, 0.3), 1.0, true)


## A heat mirage: wavering bands rise inside an ellipse whose colour goes from amber at the edge to white-hot at the centre.
func _heat(t: float, r: float, fade: float) -> void:
	for layer in 3:
		var s := 1.0 - layer * 0.28
		var col := Color(1.0, 0.55, 0.15).lerp(Color(1.0, 0.97, 0.85), layer / 2.0)
		var pts := PackedVector2Array()
		for i in 32:
			var a := i * TAU / 32.0
			pts.append(Vector2(cos(a) * r * s, sin(a) * r * 0.68 * s))
		for i in 32:
			draw_primitive(PackedVector2Array([Vector2.ZERO, pts[i], pts[(i + 1) % 32]]), PackedColorArray([BioArt.with_alpha(col, 0.0), BioArt.with_alpha(col, 0.09 * fade), BioArt.with_alpha(col, 0.09 * fade)]), PackedVector2Array())
	for b in 6:  # the rising bands
		var y := fmod(t * 0.35 + b / 6.0, 1.0) * r * 1.36 - r * 0.68
		var half := r * sqrt(maxf(1.0 - pow(y / (r * 0.68), 2.0), 0.0))
		var pts2 := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			pts2.append(Vector2(lerpf(-half, half, f), -y + sin(f * 14.0 + t * 3.0) * 3.0))
		draw_polyline(pts2, BioArt.with_alpha(Color(1.0, 0.8, 0.45), 0.5 * fade * (1.0 - absf(y) / (r * 0.7))), 1.6, true)
	if _age > duration - 0.7:  # a scorch mark is left behind
		draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 24, BioArt.with_alpha(Color(0.6, 0.2, 0.05), 0.25), 6.0, true)


## Six armour plates slide into place one after another over a lattice of actin, flash when struck, and peel off at the end.
func _shield(t: float, fade: float) -> void:
	var inner := radius_px * 0.8
	var outer := radius_px * 1.08
	var peel := clampf((_age - (duration - 0.45)) / 0.45, 0.0, 1.0)
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var arrive := clampf((_age - 0.04 * k) / 0.12, 0.0, 1.0)
		var slide := (1.0 - arrive) * 15.0 + peel * 15.0
		var spin := peel * 0.5 * (1.0 if k % 2 == 0 else -1.0)
		var half := TAU / 12.0 * 0.82
		var pts := PackedVector2Array([
			Vector2.from_angle(a - half + spin) * (inner + slide), Vector2.from_angle(a + half + spin) * (inner + slide),
			Vector2.from_angle(a + half * 0.8 + spin) * (outer + slide), Vector2.from_angle(a - half * 0.8 + spin) * (outer + slide)])
		var alpha: float = arrive * (1.0 - peel) * fade
		draw_primitive(pts, PackedColorArray([_c(0.34 * alpha), _c(0.34 * alpha), _c(0.5 * alpha, 0.2), _c(0.5 * alpha, 0.2)]), PackedVector2Array())
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), _c(0.9 * alpha, 0.3), 2.0, true)
		draw_line(Vector2.from_angle(a) * inner * 0.3, Vector2.from_angle(a + TAU / 3.0 + 0.0) * inner * 0.3, _c(0.2 * alpha), 1.0, true)
		draw_line(Vector2.from_angle(a) * inner * 0.8, Vector2.from_angle(a + PI) * inner * 0.8, _c(0.18 * alpha), 1.0, true)  # the lattice


## A staff of notes: three parallel sine lines run out in four directions, turning slowly, with hexagon notes riding them.
func _song(t: float, r: float, fade: float) -> void:
	for d in 4:
		var base := d * TAU / 4.0 + t * deg_to_rad(15.0)
		var dir := Vector2.from_angle(base)
		var perp := dir.orthogonal()
		for line in 3:
			var pts := PackedVector2Array()
			for i in 13:
				var f := i / 12.0
				var dist := r * 0.35 + r * 0.65 * f
				pts.append(dir * dist + perp * ((line - 1) * 5.0 + sin(f * 9.0 - t * 4.0) * 4.0))
			draw_polyline(pts, _c(0.5 * fade * (1.0 - 0.5 * line * 0.3)), 1.4, true)
		for n in 3:  # notes drifting up the staff
			var f2 := fmod(t * 0.45 + n / 3.0 + d * 0.17, 1.0)
			var dist2 := r * 0.35 + r * 0.65 * f2
			var np := dir * dist2 + perp * (sin(f2 * 9.0 - t * 4.0) * 4.0) + Vector2(0, -f2 * 14.0)
			var hexa := PackedVector2Array()
			for k in 7:
				hexa.append(np + Vector2.from_angle(k * TAU / 6.0) * 3.2)
			draw_polyline(hexa, _c(0.9 * (1.0 - f2) * fade, 0.5), 1.4, true)
			draw_line(np + Vector2(3.0, 0), np + Vector2(3.0, -6.0), _c(0.8 * (1.0 - f2) * fade, 0.5), 1.2, true)


## Cytokine messages: three hexagons leave the body on winding paths and dock on receptor cavities along the membrane, which
## light up while a thread of light stitches once around the contour.
func _heal(t: float, fade: float) -> void:
	var rr := 24.0
	for h in 3:
		var base := h * TAU / 3.0 + 0.5
		var out := clampf((_age - h * 0.12) / 0.55, 0.0, 1.0)
		var wind := sin(out * PI)  # out and back
		var dist := rr + 30.0 * wind
		var a := base + sin(out * PI * 2.0) * 0.6
		var p := Vector2.from_angle(a) * dist
		var hexa := PackedVector2Array()
		for k in 7:
			hexa.append(p + Vector2.from_angle(k * TAU / 6.0 + t) * 4.0)
		if out < 1.0:
			draw_polyline(hexa, _c(0.95 * fade, 0.5), 1.6, true)
			for tr in 5:
				var back := clampf(out - tr * 0.04, 0.0, 1.0)
				var q := Vector2.from_angle(base + sin(back * PI * 2.0) * 0.6) * (rr + 30.0 * sin(back * PI))
				draw_circle(q, 1.4, _c((0.6 - tr * 0.1) * fade, 0.4))
		else:  # docked: a concave cavity glows on the membrane
			draw_arc(Vector2.from_angle(base) * (rr + 2.0), 6.0, base + PI - 1.0, base + PI + 1.0, 8, _c(0.95 * fade, 0.5), 2.2, true)
	var stitch := clampf(_age / 1.0, 0.0, 1.0)
	if stitch < 1.0:
		draw_arc(Vector2.ZERO, rr + 1.0, stitch * TAU - 0.9, stitch * TAU, 12, _c(0.9 * fade, 0.6), 2.0, true)


## A lymphatic vessel is drawn under the cell (two lines with V-shaped valves); diamonds rise from it and orbit, each tied to
## the cell by a sagging thread; at the end they dive back and the vessel closes like a zip.
func _sentinels(t: float, fade: float) -> void:
	var ground := Vector2(0, 22.0)
	var ext := clampf(_age / 0.25, 0.0, 1.0) * (1.0 - clampf((_age - (duration - 0.3)) / 0.3, 0.0, 1.0))
	var half := 40.0 * ext
	for side in [-1.0, 1.0]:
		draw_line(ground + Vector2(-half, float(side) * 4.0), ground + Vector2(half, float(side) * 4.0), _c(0.6 * fade, 0.2), 1.6, true)
	var x := -half
	while x < half:  # valves
		draw_line(ground + Vector2(x, -4.0), ground + Vector2(x + 6.0, 0.0), _c(0.5 * fade, 0.3), 1.2, true)
		draw_line(ground + Vector2(x + 6.0, 0.0), ground + Vector2(x, 4.0), _c(0.5 * fade, 0.3), 1.2, true)
		x += 12.0
	for i in sentinels:
		var p := _sentinel_pos(i)
		var s := 7.0
		var diamond := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0), p + Vector2(0, -s)])
		draw_polyline(diamond, _c(0.95 * fade, 0.4), 1.8, true)
		draw_circle(p, 2.6, _c(0.95 * fade, 0.8))
		var mid := p * 0.5 + Vector2(0, 8.0 + 4.0 * sin(t * 2.0 + i))
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, p]), _c(0.35 * fade, 0.3), 1.0, true)
