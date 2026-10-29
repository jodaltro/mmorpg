class_name BioTerrainDirector
extends Node2D
## The work of the terrain in the organ of the crisis that asks for help (BioTerrainRules): a barricade to break, a block to push to its
## groove, debris to swallow, wounded cells to heal, a hot spot to cool, a hidden sign to mark. The props answer the GESTURE of the ability
## the player casts (its kind and reach), and only the calling that owns the verb is paid by the engine, so the recommended calling is the
## one that can do the job. Finishing a prop is a confirmed deed (`organ_deed`, `terreno-<verb>-<crisis>`). Props are drawn here, not as
## nodes. Presentation only: the crisis's numbers are the engine's.

signal worked(verb: String)

const LOOK_SECONDS := 0.5
const DONE_SECONDS := 2.0
const RESPAWN_SECONDS := 9.0
const NEAR_UNITS := 12.0
const SIZE_UNITS := 1.3
const PUSH_SPEED := 11.0  # units/s a push gives a block
const SLOT_UNITS := 1.3  # a block this close to its groove is home
const SAY_SECONDS := 1.4

var world: BioWorld
var _def := ""
var _region: StringName = &""
var _props: Array[Dictionary] = []  # {verb, pos, seed, progress, state, left, shake, slot, vel, say_at}
var _floats: Array[Dictionary] = []  # {pos, text, color, age}
var _look_in := 0.0
var _salt := 0
var _t := 0.0


func configure(p_world: BioWorld) -> void:
	world = p_world
	z_index = 1
	if world.abilities != null:
		world.abilities.performed.connect(_on_cast)
		world.abilities.terrain_probe = _probe


func current_def() -> String:
	return _def


func props() -> Array[Dictionary]:
	return _props


func prop_of(verb: String) -> Dictionary:
	for p in _props:
		if p["verb"] == verb:
			return p
	return {}


func _role() -> String:
	return str(world.engine_calling_view().get("role", "")) if world != null else ""


## What the terrain works on where the player is: the crisis that asks for help in this organ, else the organ's own routine (every part of
## the body always has work). The other organs' props are not made until the player gets there.
func _pick() -> Dictionary:
	var here := world.region
	if not world.live_regions.has(here):
		return {}
	if world.sync != null and world.sync.presenter != null:
		for c in world.sync.presenter.model.ordered():
			var def := str(c.get("def", ""))
			if BioConflictFocus.demanding(c) and StringName(str(c.get("region", ""))) == here and not BioTerrainRules.verbs_for(def).is_empty():
				return c
	var organ := "organ-" + str(here)
	if not BioTerrainRules.verbs_for(organ).is_empty():
		return {"def": organ, "region": str(here)}
	return {}


func _refresh(c: Dictionary) -> void:
	var def := str(c.get("def", ""))
	if def == _def:
		return
	_def = def
	_props.clear()
	if def == "":
		return
	_region = StringName(str(c.get("region", "")))
	for verb in BioTerrainRules.verbs_for(def):
		_props.append(_make(verb, _props.size()))


func _make(verb: String, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d:%d" % [_def, verb, index, _salt])
	var pos := BioBodyMap.random_point_px(rng, _region, BioCargoRules.site_px(_def, _region), 6.0)
	var slot := Vector2.ZERO
	if verb == "empurrar":
		slot = BioBodyMap.random_point_near_px(rng, _region, pos, 13.0, 7.0)
	return {"verb": verb, "pos": pos, "seed": rng.randf() * 100.0, "progress": 0.0, "state": &"live", "left": 0.0, "shake": 0.0, "slot": slot, "vel": Vector2.ZERO, "say_at": -9.0}


## Whether a cast would work on a prop in reach: a target-seeking gesture pays and plays on the terrain when it has no enemy to seek.
func _probe(id: StringName, a: Dictionary, origin: Vector2, aim: Vector2) -> bool:
	var kind := str(a.get("kind", ""))
	var role := _role()
	for p in _props:
		if p["state"] == &"live" and BioTerrainRules.verbs_of_kind(kind).has(p["verb"]) and BioTerrainRules.can(p["verb"], role) and BioTerrainRules.reaches(kind, a, origin, aim, p["pos"], SIZE_UNITS):
			return true
	return false


func _on_cast(id: StringName) -> void:
	if world == null or world.player == null:
		return
	var a := BioAbilityCatalog.get_ability(id)
	if a.is_empty():
		return
	var kind := str(a.get("kind", ""))
	var origin := world.player.global_position
	var aim := world.abilities.last_aim
	var verbs := BioTerrainRules.verbs_of_kind(kind)
	var role := _role()
	if verbs.has("curar") and BioTerrainRules.can("curar", role) and world.sync != null and world.sync.crowd != null:  # healing reaches the body's cells
		world.sync.crowd.heal_near(origin, BioTerrainRules.reach_units(a) * BioArt.UNIT, 14.0)
	for p in _props:
		if p["state"] != &"live" or not BioTerrainRules.reaches(kind, a, origin, aim, p["pos"], SIZE_UNITS):
			continue
		var verb: String = p["verb"]
		if not verbs.has(verb):
			_say(p, "isto não funciona aqui", Color(0.7, 0.75, 0.85))
		elif not BioTerrainRules.can(verb, role):
			_say(p, "precisa do chamado: %s" % BioTerrainRules.role_text(verb), BioUi.WARN)
		else:
			_apply(p, kind, a, origin)


func _say(p: Dictionary, text: String, color: Color) -> void:
	if _t - float(p["say_at"]) < SAY_SECONDS:
		return
	p["say_at"] = _t
	_floats.append({"pos": (p["pos"] as Vector2) + Vector2(0, -BioArt.UNIT * 1.6), "text": text, "color": color, "age": 0.0})


func _apply(p: Dictionary, kind: String, a: Dictionary, origin: Vector2) -> void:
	var verb: String = p["verb"]
	var color: Color = BioTerrainRules.info(verb)["color"]
	var pos: Vector2 = p["pos"]
	p["shake"] = 1.0
	if verb == "empurrar":
		var away := (pos - origin).normalized()
		if kind in ["pull", "tether", "decoy"]:
			away = -away
		p["vel"] = away * BioArt.UNIT * PUSH_SPEED
		BioFx.burst(pos, color, 6, 3.0, 0.3, 0.4)
		_floats.append({"pos": pos + Vector2(0, -BioArt.UNIT * 1.4), "text": "empurrado", "color": color, "age": 0.0})
		return
	var gain := BioTerrainRules.power(verb, kind, a)
	p["progress"] = minf(1.0, float(p["progress"]) + gain)
	match verb:
		"romper":
			BioFx.burst(pos, Color(0.8, 0.45, 0.35), 9, 4.0, 0.3, 0.5)
			BioFx.shake(0.25)
		"limpar":
			BioFx.burst(pos, color, 7, -2.0, 0.25, 0.5)
		"curar":
			BioFx.ring(pos, 1.6, color)
		"acalmar":
			BioFx.burst(pos, color, 8, 2.0, 0.35, 0.8)
		"marcar":
			BioFx.ring(pos, 2.2, color)
	_floats.append({"pos": pos + Vector2(0, -BioArt.UNIT * 1.5), "text": "%d%%" % roundi(float(p["progress"]) * 100.0), "color": color, "age": 0.0})
	if float(p["progress"]) >= 1.0:
		_done(p)


func _done(p: Dictionary) -> void:
	var verb: String = p["verb"]
	var color: Color = BioTerrainRules.info(verb)["color"]
	var pos: Vector2 = p["pos"]
	p["state"] = &"done"
	p["left"] = DONE_SECONDS
	p["progress"] = 1.0
	world.organ_deed.emit(BioTerrainRules.action(verb, _def))
	BioFx.burst(pos, color, 22, 4.5, 0.4, 0.8)
	BioFx.ring(pos, 2.4, color)
	_floats.append({"pos": pos + Vector2(0, -BioArt.UNIT * 1.8), "text": "feito!", "color": color, "age": 0.0})
	if world.sync != null and world.sync.system != null:
		world.sync.system.push_feed("%s: %s." % [str(BioTerrainRules.info(verb)["name"]), BioTerrainRules.prop_name(_def, verb)])
	worked.emit(verb)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_t += delta
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = LOOK_SECONDS
		_refresh(_pick())
	for i in range(_floats.size() - 1, -1, -1):
		_floats[i]["age"] = float(_floats[i]["age"]) + delta
		if float(_floats[i]["age"]) > 1.2:
			_floats.remove_at(i)
	if _props.is_empty() and _floats.is_empty():
		return
	for i in _props.size():
		var p := _props[i]
		p["shake"] = maxf(0.0, float(p["shake"]) - delta * 4.0)
		match p["state"]:
			&"done":
				p["left"] = float(p["left"]) - delta
				if float(p["left"]) <= 0.0:
					p["state"] = &"gone"
					p["left"] = RESPAWN_SECONDS
			&"gone":
				p["left"] = float(p["left"]) - delta
				if float(p["left"]) <= 0.0:
					_salt += 1
					_props[i] = _make(str(p["verb"]), i)
			&"live":
				if p["verb"] == "empurrar":
					_push(p, delta)
	queue_redraw()


func _push(p: Dictionary, delta: float) -> void:
	var vel: Vector2 = p["vel"]
	if vel.length() > 2.0:
		var old: Vector2 = p["pos"]
		var next := old + vel * delta
		if BioBodyMap.region_of(next) != _region:  # the wall of the organ stops it
			p["vel"] = -vel * 0.3
		else:
			p["pos"] = next
			p["vel"] = vel * exp(-delta * 2.2)
	else:
		p["vel"] = Vector2.ZERO
	p["progress"] = clampf(1.0 - (p["pos"] as Vector2).distance_to(p["slot"]) / maxf(1.0, BioArt.UNIT * 13.0), 0.0, 0.99)
	if (p["pos"] as Vector2).distance_to(p["slot"]) < SLOT_UNITS * BioArt.UNIT:
		_done(p)


# ----------------------------------------------------------------------------------------------- drawing

func _draw() -> void:
	if world == null or world.player == null:
		return
	var me := world.player.global_position
	var role := _role()
	for p in _props:
		if p["state"] == &"gone":
			continue
		var near: bool = (p["pos"] as Vector2).distance_to(me) < NEAR_UNITS * BioArt.UNIT
		var mine := BioTerrainRules.can(p["verb"], role)
		_draw_prop(p, mine, near)
	var font := ThemeDB.fallback_font
	for f in _floats:
		var age: float = float(f["age"])
		var at: Vector2 = (f["pos"] as Vector2) + Vector2(0, -age * 22.0)
		var w := font.get_string_size(str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var al := clampf(1.0 - age / 1.2, 0.0, 1.0)
		draw_string_outline(font, at + Vector2(-w * 0.5, 0), str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.01, 0.03, 0.05, al))
		draw_string(font, at + Vector2(-w * 0.5, 0), str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BioArt.with_alpha(f["color"], al))


func _blob(center: Vector2, radius: float, seed_value: float, points: int, lump: float, spin: float = 0.0) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i in points:
		var a := TAU * i / points + spin
		ring.append(center + Vector2.from_angle(a) * radius * (1.0 + lump * sin(a * 3.0 + seed_value) + lump * 0.6 * sin(a * 5.0 + seed_value * 1.7)))
	return ring


func _fill(ring: PackedVector2Array, fill: Color, edge: Color, width: float = 2.0) -> void:
	var tris := Geometry2D.triangulate_polygon(ring)
	if not tris.is_empty():
		draw_colored_polygon(ring, fill)
	var closed := ring.duplicate()
	closed.append(ring[0])
	draw_polyline(closed, edge, width, true)


func _draw_prop(p: Dictionary, mine: bool, near: bool) -> void:
	var u := BioArt.UNIT
	var verb: String = p["verb"]
	var color: Color = BioTerrainRules.info(verb)["color"]
	var prog := float(p["progress"])
	var s := float(p["seed"])
	var dim := 1.0 if mine else 0.5
	var done: bool = p["state"] == &"done"
	var shake := Vector2.from_angle(_t * 60.0 + s) * float(p["shake"]) * 4.0
	var at: Vector2 = (p["pos"] as Vector2) + shake
	if done:
		var k := 1.0 - float(p["left"]) / DONE_SECONDS
		draw_arc(at, u * (1.0 + 2.5 * k), 0.0, TAU, 32, BioArt.with_alpha(color, 0.9 * (1.0 - k)), 3.0, true)
	draw_circle(at, u * 1.9, BioArt.with_alpha(color, 0.05 * dim))
	match verb:
		"romper":
			var r := u * 1.15 * (1.0 - 0.45 * prog) * (0.0 if done else 1.0)
			if r > 1.0:
				var ring := _blob(at, r, s, 10, 0.16)
				_fill(ring, BioArt.with_alpha(Color(0.34, 0.1, 0.12), 0.95 * dim), BioArt.with_alpha(Color(0.75, 0.3, 0.28), dim), 3.0)
				for i in 2 + int(prog * 6.0):  # cracks open as it gives
					var a := s + i * 1.9
					draw_line(at, at + Vector2.from_angle(a) * r * 0.95, BioArt.with_alpha(Color(1.0, 0.7, 0.55), 0.8 * dim), 1.5, true)
		"empurrar":
			var slot: Vector2 = p["slot"]
			draw_arc(slot, u * SLOT_UNITS, 0.0, TAU, 28, BioArt.with_alpha(color, (0.5 + 0.3 * sin(_t * 3.0)) * dim), 3.0, true)  # the groove
			draw_arc(slot, u * SLOT_UNITS * 0.55, 0.0, TAU, 20, BioArt.with_alpha(color, 0.35 * dim), 2.0, true)
			if not done and near:
				var to := (slot - at).normalized()
				for i in 5:
					var q := at + to * u * (1.8 + i * 0.9)
					draw_circle(q, 2.0, BioArt.with_alpha(color, 0.35 * dim * (1.0 - i * 0.15)))
			if not done:
				var ring := _blob(at, u * 1.0, s, 12, 0.07, _t * 0.0)
				_fill(ring, BioArt.with_alpha(Color(0.5, 0.55, 0.65), 0.95 * dim), BioArt.with_alpha(color, dim), 3.0)
				draw_circle(at + Vector2(-0.3, -0.3) * u, u * 0.25, BioArt.with_alpha(Color.WHITE, 0.4 * dim))
		"limpar":
			for i in 6:
				var off := Vector2.from_angle(s + i * 1.05) * u * (0.35 + 0.5 * fposmod(i * 0.37, 1.0))
				var r := u * (0.35 + 0.15 * fposmod(i * 0.61, 1.0)) * (1.0 - prog) * (0.0 if done else 1.0)
				if r > 1.0:
					var ring := _blob(at + off, r, s + i, 8, 0.2, _t * 0.4)
					_fill(ring, BioArt.with_alpha(Color(0.5, 0.45, 0.16), 0.9 * dim), BioArt.with_alpha(color, 0.9 * dim), 1.5)
		"curar":
			var sick := Color(0.55, 0.22, 0.3)
			var well := Color(0.45, 1.0, 0.65)
			var body := sick.lerp(well, prog)
			for i in 3:
				var off := Vector2.from_angle(s + i * 2.1) * u * 0.8
				var wob := 1.0 + 0.1 * sin(_t * (3.0 + 5.0 * prog) + i)
				var ring := _blob(at + off, u * 0.5 * wob, s + i, 10, 0.08)
				_fill(ring, BioArt.with_alpha(body.darkened(0.2), 0.95 * dim), BioArt.with_alpha(body.lightened(0.2), dim), 2.0)
				draw_circle(at + off, u * 0.18, BioArt.with_alpha(body.lightened(0.45), 0.9 * dim))
			if prog < 1.0:
				var k := 0.5 + 0.5 * sin(_t * 6.0)  # "this one needs mending": the pulsing cross
				var c := Color(1.0, 0.3, 0.35, (0.5 + 0.4 * k) * dim)
				var cs := 6.0 + 2.0 * k
				var cp := at + Vector2(0, -u * 1.5)
				draw_line(cp + Vector2(-cs, 0), cp + Vector2(cs, 0), c, 3.0, true)
				draw_line(cp + Vector2(0, -cs), cp + Vector2(0, cs), c, 3.0, true)
		"acalmar":
			var ember := Color(1.0, 0.42, 0.2)
			var cool := Color(0.45, 0.75, 1.0)
			var body := ember.lerp(cool, prog)
			var flick := 1.0 + 0.1 * sin(_t * (14.0 - 10.0 * prog))
			var ring := _blob(at, u * 0.85 * flick, s, 12, 0.1, _t)
			_fill(ring, BioArt.with_alpha(body.darkened(0.25), 0.95 * dim), BioArt.with_alpha(body.lightened(0.2), dim), 3.0)
			draw_circle(at, u * 0.4, BioArt.with_alpha(body.lightened(0.5), 0.9 * dim))
			if prog < 0.7:
				for i in 3:  # heat waves
					var k := fposmod(_t * 0.8 + i * 0.33, 1.0)
					draw_arc(at, u * (0.9 + 1.4 * k), 0.0, TAU, 28, BioArt.with_alpha(body, 0.5 * (1.0 - k) * dim), 2.0, true)
		"marcar":
			var shown := 0.25 + 0.75 * minf(1.0, prog * 2.0)
			var sz := u * (0.45 + 0.4 * prog)
			var pulse := 0.6 + 0.4 * sin(_t * 4.0 + s)
			var dia := PackedVector2Array([at + Vector2(0, -sz), at + Vector2(sz * 0.7, 0), at + Vector2(0, sz), at + Vector2(-sz * 0.7, 0)])
			draw_colored_polygon(dia, BioArt.with_alpha(color, 0.35 * shown * pulse * dim))
			dia.append(dia[0])
			draw_polyline(dia, BioArt.with_alpha(color, shown * dim), 2.0, true)
			if prog > 0.0:
				draw_arc(at, sz * 1.6, 0.0, TAU, 24, BioArt.with_alpha(color, 0.8 * dim), 2.0, true)
	if prog > 0.0 and prog < 1.0 and verb != "empurrar":  # how far along it is
		var box := Rect2(at + Vector2(-16, u * 1.35), Vector2(32, 4))
		draw_rect(box, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(box.position, Vector2(box.size.x * prog, 4)), color)
	if near and not done:
		var font := ThemeDB.fallback_font
		var name_text := BioTerrainRules.prop_name(_def, verb)
		var sub := "%s · %s" % [BioTerrainRules.role_text(verb), str(BioTerrainRules.info(verb)["how"])] if mine else "só para: %s" % BioTerrainRules.role_text(verb)
		var w1 := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var top := at + Vector2(0, -u * 2.0 - (14.0 if verb == "curar" else 0.0))
		draw_string_outline(font, top + Vector2(-w1 * 0.5, 0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.01, 0.02, 0.05, 0.9))
		draw_string(font, top + Vector2(-w1 * 0.5, 0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color.lightened(0.3))
		draw_string_outline(font, top + Vector2(-w2 * 0.5, 13), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.01, 0.02, 0.05, 0.9))
		draw_string(font, top + Vector2(-w2 * 0.5, 13), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BioUi.GOOD if mine else BioUi.WARN)
