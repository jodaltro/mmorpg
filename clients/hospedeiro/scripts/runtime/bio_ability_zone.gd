class_name BioAbilityZone
extends Node2D
## A lasting ability effect: acid pools, DNA nets, delayed traps, poison clouds, spore rain, fever, the flesh
## shield, the cytokine song, healing and orbiting sentinels. Each has its own look and its own particles; the
## damage and the states it applies go through the same combat rules as everything else.

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

var _age := 0.0
var _tick := 0.0
var _fired := false
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
	z.position = pos
	parent.add_child(z)
	return z


func _ready() -> void:
	z_index = 6
	material = BioArt.additive()
	_hit_def = BioAttackDef.new(ability, 0.0, tick_damage, 0.0, 0.0, 0.0, 0.0)
	var amount := 26
	var size := 11.0
	var rise := 0.0
	match style:
		"acid", "poison":
			rise = 30.0
		"spores", "heal", "song", "heat":
			rise = 55.0
		"net", "trap":
			amount = 10
			size = 8.0
		"shield":
			amount = 20
	_stream = BioPfx.stream(self, color, amount, 1.1, size, radius_px * 0.85, rise, 26.0)
	if style == "trap":
		_stream.amount = 6
	BioPfx.ring_burst(BioFx.root, global_position, color, radius_px * 0.8, 30, 0.5, 10.0)
	BioFx.ring(global_position, radius_px / BioArt.UNIT * 0.9, color)


func _process(delta: float) -> void:
	_age += delta
	if follow and is_instance_valid(host):
		global_position = host.global_position
	if is_instance_valid(_stream):
		_stream.global_position = global_position
	_tick -= delta
	if style == "trap":
		if not _fired and _age >= delay:
			_detonate()
		if _fired and _age >= delay + 0.35:
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
	queue_redraw()
	if _age >= duration:
		_finish()


func _finish() -> void:
	BioPfx.stop(_stream)
	BioPfx.burst(BioFx.root, global_position, color, 14, 120.0, 0.5, 10.0)
	queue_free()


## Half-second pulse: damage and slowing of everything inside.
func _pulse() -> void:
	if tick_damage <= 0.0 and slow >= 1.0:
		return
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_combatant.actor.team):
		if tick_damage > 0.0:
			e.combatant.receive_hit(owner_combatant, _hit_def)
		if slow < 1.0:
			e.slow(slow, 0.8)
		BioPfx.burst(BioFx.root, e.global_position, color, 3, 60.0, 0.4, 8.0)


func _detonate() -> void:
	_fired = true
	var def := BioAttackDef.new(ability, 0.0, burst_damage, 0.0, 0.0, 9.0, 0.0)
	for e in BioTargeting.enemies(get_world_2d(), global_position, radius_px, owner_combatant.actor.team):
		e.combatant.receive_hit(owner_combatant, def)
		e.apply_impulse((e.global_position - global_position).normalized() * 9.0)
	BioFx.ring(global_position, radius_px / BioArt.UNIT, color)
	BioFx.ring(global_position, radius_px / BioArt.UNIT * 0.6, Color.WHITE)
	BioPfx.ring_burst(BioFx.root, global_position, color, radius_px * 0.5, 56, 0.6, 13.0)
	BioPfx.burst(BioFx.root, global_position, color, 40, 320.0, 0.8, 15.0)
	BioFx.shake(0.14)


func _sentinel_pos(i: int) -> Vector2:
	var a := _age * 2.2 + i * TAU / maxi(sentinels, 1)
	return Vector2.from_angle(a) * (radius_px * 0.9)


func _sentinel_hits() -> void:
	if _tick > 0.0 or tick_damage <= 0.0:
		return
	for i in sentinels:
		for e in BioTargeting.enemies(get_world_2d(), global_position + _sentinel_pos(i), 0.9 * BioArt.UNIT, owner_combatant.actor.team):
			e.combatant.receive_hit(owner_combatant, _hit_def)
			BioPfx.burst(BioFx.root, e.global_position, color, 6, 120.0, 0.4, 9.0)


func _draw() -> void:
	var t := _age + _seed
	var grow := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((duration - _age) / 0.5, 0.0, 1.0)
	var r := radius_px * grow
	var c := color
	match style:
		"acid", "poison":
			for k in 3:
				var off := Vector2.from_angle(t * 0.7 + k * 2.1) * r * 0.25
				draw_texture_rect(BioArt.glow_texture(), Rect2(off - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, BioArt.with_alpha(c, 0.18 * fade))
			for k in 9:
				var a := k * 2.399 + t * 0.4
				var pos := Vector2.from_angle(a) * r * fmod(k * 0.37, 0.8)
				var rise := fmod(t * 0.6 + k * 0.31, 1.0)
				draw_arc(pos + Vector2(0, -rise * 14.0), 4.0 + 3.0 * rise, 0.0, TAU, 14, BioArt.with_alpha(c, 0.8 * (1.0 - rise) * fade), 1.6, true)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, BioArt.with_alpha(c, 0.55 * fade), 2.5, true)
		"net":
			for i in 12:
				var a := i * TAU / 12.0
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * r, BioArt.with_alpha(c, 0.7 * fade), 1.4, true)
			for ring in [0.35, 0.65, 1.0]:
				var pts := PackedVector2Array()
				for i in 13:
					pts.append(Vector2.from_angle(i * TAU / 12.0) * r * float(ring) * (1.0 + 0.03 * sin(t * 3.0 + i)))
				draw_polyline(pts, BioArt.with_alpha(c, 0.6 * fade), 1.3, true)
		"trap":
			var urgency := clampf(_age / maxf(delay, 0.1), 0.0, 1.0)
			var blink := 0.5 + 0.5 * sin(_age * (6.0 + 22.0 * urgency))
			draw_arc(Vector2.ZERO, r * (1.0 - 0.1 * blink), 0.0, TAU, 56, BioArt.with_alpha(c, 0.35 + 0.5 * blink), 2.5, true)
			draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -18.0, Vector2.ONE * 36.0), false, BioArt.with_alpha(Color(1.0, 0.6, 0.7), 0.4 + 0.5 * blink))
			for i in 8:
				var a := i * TAU / 8.0 + t
				draw_line(Vector2.from_angle(a) * r * 0.25, Vector2.from_angle(a) * r * 0.8, BioArt.with_alpha(c, 0.5), 1.2, true)
		"spores":
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, BioArt.with_alpha(c, 0.5 * fade), 2.0, true)
			draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2.0), false, BioArt.with_alpha(c, 0.1 * fade))
		"heat":
			for k in 4:
				draw_arc(Vector2.ZERO, r * (0.3 + 0.22 * k + 0.05 * sin(t * 4.0 + k)), 0.0, TAU, 48, BioArt.with_alpha(Color(1.0, 0.5 - 0.1 * k, 0.2), 0.45 * fade), 2.0, true)
			draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2.0), false, BioArt.with_alpha(Color(1.0, 0.45, 0.2), 0.16 * fade))
		"shield":
			var seg := 6
			for i in seg:
				var a := t * 1.4 + i * TAU / seg
				draw_arc(Vector2.ZERO, r, a, a + TAU / seg * 0.72, 12, BioArt.with_alpha(c, 0.9 * fade), 5.0, true)
			draw_arc(Vector2.ZERO, r * 0.86, 0.0, TAU, 56, BioArt.with_alpha(c, 0.25 * fade), 2.0, true)
		"song":
			for k in 3:
				var phase := fmod(t * 0.7 + k / 3.0, 1.0)
				draw_arc(Vector2.ZERO, r * (0.5 + 0.9 * phase), 0.0, TAU, 56, BioArt.with_alpha(c, 0.6 * (1.0 - phase) * fade), 2.2, true)
		"heal":
			draw_texture_rect(BioArt.glow_texture(), Rect2(Vector2.ONE * -r * 0.8, Vector2.ONE * r * 1.6), false, BioArt.with_alpha(c, 0.22 * fade))
			var crossing := 10.0 + 4.0 * sin(t * 4.0)
			draw_line(Vector2(-crossing, 0), Vector2(crossing, 0), BioArt.with_alpha(c, 0.9 * fade), 3.0, true)
			draw_line(Vector2(0, -crossing), Vector2(0, crossing), BioArt.with_alpha(c, 0.9 * fade), 3.0, true)
		"sentinels":
			draw_arc(Vector2.ZERO, radius_px * 0.9, 0.0, TAU, 56, BioArt.with_alpha(c, 0.18 * fade), 1.5, true)
			for i in sentinels:
				var pos := _sentinel_pos(i)
				draw_texture_rect(BioArt.glow_texture(), Rect2(pos - Vector2.ONE * 16.0, Vector2.ONE * 32.0), false, BioArt.with_alpha(c, 0.9 * fade))
				draw_circle(pos, 5.0, BioArt.with_alpha(Color.WHITE, 0.9 * fade))
