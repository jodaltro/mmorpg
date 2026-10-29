class_name BioCargoDirector
extends Node2D
## Carrying help to the crisis that asks for it. In the organ of that crisis a place of the tissue needs something (BioCargoRules): a few
## loads lie around the organ, the cell picks one up by touching it, drags it on a strand of membrane and drops it on the place. The
## delivery is a confirmed deed (`organ_deed`, the crisis's action), so only what the game server confirms counts; the place shows the
## crisis healing. Loads are drawn here, not as nodes, so they cost little.

signal delivered(def: String)

const LOOK_SECONDS := 0.5
const RESPAWN_SECONDS := 4.0

var world: BioWorld
var site: BioCargoSite
var carrying := -1  # index of the load the cell drags, or -1
var _def := ""
var _region: StringName = &""
var _loads: Array[Dictionary] = []  # {pos, vel, seed, back_in}
var _look_in := 0.0
var _salt := 0
var _t := 0.0


func configure(p_world: BioWorld) -> void:
	world = p_world
	z_index = 1


func current_def() -> String:
	return _def


func loads() -> int:
	return _loads.size()


## The crisis that asks for attention in a live organ, if it has something to carry; else "".
func _pick() -> Dictionary:
	if world.sync == null or world.sync.presenter == null:
		return {}
	for c in world.sync.presenter.model.ordered():
		var def := str(c.get("def", ""))
		if BioConflictFocus.demanding(c) and BioCargoRules.has(def) and world.live_regions.has(StringName(str(c.get("region", "")))):
			return c
	return {}


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_t += delta
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = LOOK_SECONDS
		_refresh(_pick())
	if _def == "":
		return
	var me := world.player.global_position
	var alive := world.player.is_active()
	for i in _loads.size():
		var l := _loads[i]
		if float(l["back_in"]) > 0.0:
			l["back_in"] = float(l["back_in"]) - delta
			if float(l["back_in"]) <= 0.0:
				_salt += 1
				l["pos"] = BioCargoRules.source_px(_def, _region, i, _salt)
			continue
		if i == carrying:
			if not alive:  # a dissolved cell lets go of what it carried
				carrying = -1
				continue
			var aim: Vector2 = world.player.velocity.normalized() if world.player.velocity.length() > 5.0 else Vector2.DOWN
			var want: Vector2 = me - aim * BioArt.UNIT * 1.3
			l["pos"] = (l["pos"] as Vector2).lerp(want, clampf(delta * 8.0, 0.0, 1.0))
			var reach := BioCargoRules.DELIVER_UNITS * BioArt.UNIT  # the load trails behind: the cell reaching the place is enough
			if site != null and ((l["pos"] as Vector2).distance_to(site.global_position) < reach or me.distance_to(site.global_position) < reach):
				_deliver(i)
		elif carrying < 0 and alive and (l["pos"] as Vector2).distance_to(me) < (BioCargoRules.PICK_UNITS + 0.6) * BioArt.UNIT:
			carrying = i
			BioFx.ring(l["pos"], 0.6, BioCargoRules.of(_def).get("cargo_color", Color.WHITE))
	if site != null:
		site.waiting = carrying >= 0
	queue_redraw()


## Follows the crisis that asks for help: its place in the tissue and the loads around the organ; nothing when there is none.
func _refresh(c: Dictionary) -> void:
	var def := str(c.get("def", ""))
	if def != _def:
		_clear()
		_def = def
		if def == "":
			return
		_region = StringName(str(c.get("region", "")))
		site = BioCargoSite.new()
		site.name = "CargoSite"
		world.add_child(site)
		site.configure(def, BioCargoRules.site_px(def, _region))
		for i in BioCargoRules.ITEMS:
			_loads.append({"pos": BioCargoRules.source_px(def, _region, i, _salt), "seed": float(i) * 1.7, "back_in": 0.0})
	if site != null:
		site.healed = BioCargoRules.healed(c)


func _clear() -> void:
	if is_instance_valid(site):
		site.queue_free()
	site = null
	_loads.clear()
	carrying = -1
	_def = ""


func _deliver(i: int) -> void:
	var c := BioCargoRules.of(_def)
	world.organ_deed.emit(str(c["action"]))
	site.pulse()
	BioFx.burst(site.global_position, c.get("cargo_color", Color.WHITE), 18, 3.5, 0.35, 0.7)
	BioFx.ring(site.global_position, 1.6, c.get("cargo_color", Color.WHITE))
	if world.sync != null and world.sync.system != null:
		world.sync.system.push_feed("Entregue: %s → %s." % [str(c["cargo"]), str(c["site"])])
	_loads[i]["back_in"] = RESPAWN_SECONDS
	carrying = -1
	delivered.emit(_def)


func _draw() -> void:
	if _def == "":
		return
	var color: Color = BioCargoRules.of(_def).get("cargo_color", Color.WHITE)
	var u := BioArt.UNIT
	for i in _loads.size():
		var l := _loads[i]
		if float(l["back_in"]) > 0.0:
			continue
		var p: Vector2 = l["pos"]
		if i == carrying:  # a strand of the cell's own membrane holds it
			draw_line(world.player.global_position, p, BioArt.with_alpha(Color(0.6, 0.95, 1.0), 0.55), 2.0, true)
		var s := float(l["seed"])
		draw_circle(p, u * 0.95, BioArt.with_alpha(color, 0.08))
		var ring := PackedVector2Array()
		for k in 12:
			var a := TAU * k / 12.0
			ring.append(p + Vector2.from_angle(a) * u * 0.42 * (1.0 + 0.12 * sin(a * 3.0 + _t * 2.0 + s)))
		for layer in 3:  # a droplet, dark at the rim and bright inside
			var shrunk := PackedVector2Array()
			for q in ring:
				shrunk.append(p + (q - p) * (1.0 - 0.28 * layer))
			draw_colored_polygon(shrunk, color.darkened(0.45 - 0.2 * layer))
		draw_circle(p + Vector2(-0.12, -0.12) * u, u * 0.08, BioArt.with_alpha(Color.WHITE, 0.6))
		if i != carrying and carrying < 0 and p.distance_to(world.player.global_position) < u * 9.0:  # near ones say what they are
			var font := ThemeDB.fallback_font
			var name_text := str(BioCargoRules.of(_def)["cargo"])
			var w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string_outline(font, p + Vector2(-w * 0.5, -u * 0.75), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.01, 0.02, 0.05, 0.9))
			draw_string(font, p + Vector2(-w * 0.5, -u * 0.75), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color.lightened(0.3))
