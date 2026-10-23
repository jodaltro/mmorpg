class_name BioAbilityRunner
extends Node
## The player's class abilities. The engine decides which ones are known (starter, quest, discovery, awakening);
## this node holds them in four slots (Q F C V) and performs them. Cost and cooldown go through the domain actor
## like any attack; a target-seeking ability that finds no target costs nothing.
##
## Every ability is something THIS body does: the membrane stretches and recoils like rubber (BioCellBody.elastic and
## swell) and limbs grow out of it (BioLimbs, shaped by form, look and genes). Damage and states are still decided
## by the domain rules, never by the drawing.

signal learned(id: StringName)
signal performed(id: StringName)

const SLOTS := 4
const NO_TARGET := 10
const UNKNOWN := 11

var slots: Array[StringName] = []

var _host: BioCellActor
var _aim_source: BioCellController
var _limbs: BioLimbs
var effect_style: StringName = &""  # trait "efeito" designed by Jev
var projectile_traits := {}  # traits "trajetoria", "calibre", "impacto" (and "ritmo") designed by Jev: they change the shot itself
var _body: BioCellBody


func configure(host: BioCellActor, controller: BioCellController, limbs: BioLimbs, body: BioCellBody) -> void:
	_host = host
	_aim_source = controller
	_limbs = limbs
	_body = body


func known() -> Array[StringName]:
	return slots.duplicate()


func knows(id: StringName) -> bool:
	return slots.has(id)


## Adds an ability to the first free slot (the order of discovery). Returns false if already known or unknown to the catalogue.
func learn(id: StringName) -> bool:
	if slots.has(id) or not BioAbilityCatalog.has(id):
		return false
	slots.append(id)
	learned.emit(id)
	return true


## Forgets everything (a restarted world).
func clear() -> void:
	slots.clear()
	learned.emit(&"")  # lets the bar refresh


## Replaces what is known with the engine's list (slots keep their order; new ones append).
func set_known(ids: Array) -> void:
	for id in ids:
		learn(BioAbilityCatalog.normalise(str(id)))


func slot_id(slot: int) -> StringName:
	return slots[slot] if slot >= 0 and slot < slots.size() else &""


func cooldown_fraction(slot: int) -> float:
	var id := slot_id(slot)
	if id == &"":
		return 1.0
	var def := _host.combatant.actor.attack_def(id)
	var now := BioClock.now()
	var frac := clampf(_host.combatant.actor.cooldown_remaining(id, now) / maxf(def.cooldown, 0.01), 0.0, 1.0)
	if _host.combatant.actor.vitals.atp < def.atp_cost:
		frac = maxf(frac, 1.0)
	return frac


func _process(_delta: float) -> void:
	if _host == null or not _host.visible:
		return
	for i in SLOTS:
		if Input.is_action_just_pressed("bio_ab_%d" % (i + 1)):
			perform(i)


func perform(slot: int) -> int:
	return perform_id(slot_id(slot))


func perform_id(id: StringName) -> int:
	if id == &"" or not knows(id):
		return UNKNOWN
	var a := BioAbilityCatalog.get_ability(id)
	if _host.combatant.genome != null:
		a = _host.combatant.genome.tune(id, a)  # the mutations change this ability's numbers
	var aim: Vector2 = _aim_source.aim if _aim_source != null else Vector2.RIGHT
	var origin := _host.global_position
	var me := _host.combatant
	var kind: String = a["kind"]
	a = BioAbilityFocus.apply(a, _host.combatant.focus)  # the cell's focus: a wide weak reach or a narrow strong one
	var target: BioCellActor = null
	if kind in ["mark", "execute"]:
		var pool := BioTargeting.enemies(_host.get_world_2d(), origin, float(a["range"]) * BioArt.UNIT, me.actor.team)
		if kind == "execute":
			pool = pool.filter(func(c: BioCellActor) -> bool: return c.combatant.actor.vitals.membrane / c.combatant.actor.vitals.max_membrane <= float(a["below"]))
		target = BioTargeting.best(pool, origin, aim, float(a["range"]) * BioArt.UNIT)
		if target == null:
			return NO_TARGET
	var status := me.actor.try_begin_attack(id, BioClock.now())
	if status != BioActor.AttackStatus.STARTED:
		return status
	var def := me.actor.attack_def(id)
	var color: Color = BioEffectSignature.tint(a["color"], effect_style)
	_limbs.signature = effect_style
	match kind:
		"devour":
			_devour(def, a, aim, color)
		"cone":
			_whips(def, a, aim, color)
		"pierce":
			_lance(def, a, aim, color)
		"nova":
			_nova(id, def, a, color)
		"dash_strike":
			_dash_strike(id, def, a, origin, aim, color)
		"bolt":
			_shoot_bolts(def, a, aim, color, 1)
		"volley":
			_shoot_bolts(def, a, aim, color, int(a["count"]))
		"mark":
			_reach_and_mark([target], a, color)
		"mark_all":
			var seen := BioTargeting.enemies(_host.get_world_2d(), origin, float(a["radius"]) * BioArt.UNIT, me.actor.team)
			_reach_and_mark(seen.slice(0, 6), a, color)
			BioSignature.play(&"contours", origin, color, 1.8, {"radius": float(a["radius"]) * BioArt.UNIT, "targets": seen.map(func(e: BioCellActor) -> Vector2: return e.global_position)}, null)
		"execute":
			_execute(target, def, a, color)
		"zone":
			_zone(id, a, origin, aim, color)
		"heal":
			_heal(id, a, origin, color)
		"aura":
			_aura(id, a, color)
		"summon":
			_summon(id, a, color)
	performed.emit(id)
	return status


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _alive() -> bool:
	return is_instance_valid(_host) and _host.combatant.actor.vitals.is_alive()


func _hit(target: BioCellActor, def: BioAttackDef, from: Vector2, color: Color) -> BioHitResult:
	if not BioCombatRules.can_hit(_host.combatant.actor, target.combatant.actor):
		return null
	var result := target.combatant.receive_hit(_host.combatant, def)
	if result.outcome == BioActor.HitOutcome.HIT or result.outcome == BioActor.HitOutcome.KILLED:
		if def.knockback > 0.0:
			target.apply_impulse((target.global_position - from).normalized() * def.knockback)
		BioPfx.burst(BioFx.root, target.global_position, color, 16, 220.0, 0.5, 11.0)
	return result


## Macrophage: three broad scooping arms close in front of the body, which stretches into the bite and swells as it swallows.
func _devour(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	var reach := float(a["range"])
	_limbs.fan(aim, 3, float(a["half"]) * 1.3, reach + 0.4, 0.1, 0.24, {"tint": color, "sweep": 0.0, "style": {"tip": &"cup", "base": 26.0, "tip_w": 28.0, "stiffness": 0.35}})
	_body.elastic(aim, 0.3, 0.55, 0.1)
	BioSignature.play(&"bite", _host.global_position, color, 1.6, {"dir": aim, "reach": reach * BioArt.UNIT}, _host)
	await _wait(0.1)
	if not _alive():
		return
	_cone(def, a, _host.global_position, aim, color, true)
	_body.swell(1.18, 0.3)


## Dendritic cell: a fan of fine branching whips.
func _whips(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	var count := maxi(5, int(_limbs.style()["count"]) + 2)
	_limbs.fan(aim, count, float(a["half"]) * 2.0, float(a["range"]) + 0.35, 0.1, 0.16, {"tint": color, "sweep": 25.0, "style": {"tip": &"fork", "base": 8.0, "tip_w": 4.0, "stiffness": 0.2, "wave": 0.7}})
	_body.elastic(aim, 0.15, 0.3, 0.08)
	BioSignature.play(&"fiddleheads", _host.global_position, color, 0.9, {"dir": aim, "count": count, "spread": float(a["half"]) * 2.0, "length": (float(a["range"]) + 0.35) * BioArt.UNIT}, _host)
	await _wait(0.08)
	if _alive():
		_cone(def, a, _host.global_position, aim, color, false)


## Cytotoxic T cell: the body thrusts a rigid lance.
func _lance(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color) -> void:
	_limbs.reach(aim, float(a["range"]) + 0.5, 0.07, 0.14, {"tint": color, "sweep": 0.0, "style": {"tip": &"spear", "stiffness": 0.97, "wave": 0.02, "base": 14.0, "tip_w": 2.0, "barbs": 3}})
	_body.elastic(aim, 0.3, 0.6, 0.06)
	_host.apply_impulse(aim * 2.5)
	await _wait(0.07)
	if _alive():
		_pierce(def, a, _host.global_position, aim, color)


func _cone(def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color, devour: bool) -> void:
	var half := float(a["half"])
	var reach := float(a["range"])
	BioPfx.burst(BioFx.root, origin + aim * reach * 0.5 * BioArt.UNIT, color, 26, 260.0, 0.45, 12.0, aim, half)
	var inside := BioTargeting.in_cone(BioTargeting.enemies(_host.get_world_2d(), origin, (reach + 0.6) * BioArt.UNIT, _host.combatant.actor.team), origin, aim, reach * BioArt.UNIT, half)
	for e in inside:
		var result := _hit(e, def, origin, color)
		if devour and result != null and result.damage_applied > 0.0:
			_host.combatant.actor.vitals.repair(result.damage_applied * float(a["heal"]))
	BioFx.shake(0.1)


func _pierce(def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color) -> void:
	var reach_px := float(a["range"]) * BioArt.UNIT
	var tip := origin + aim * reach_px
	BioPfx.burst(BioFx.root, origin + aim * reach_px * 0.5, color, 14, 260.0, 0.3, 7.0, aim, 4.0)
	_beam(origin + aim * 0.4 * BioArt.UNIT, tip, color, float(a["width"]) * BioArt.UNIT * 0.5)
	var width_px := float(a["width"]) * BioArt.UNIT
	var below := float(a["execute_below"])
	for e in BioTargeting.enemies(_host.get_world_2d(), origin + aim * reach_px * 0.5, reach_px * 0.6 + width_px, _host.combatant.actor.team):
		if BioTargeting.distance_to_segment(e.global_position, origin, tip) > width_px:
			continue
		var v := e.combatant.actor.vitals
		var hit_def := def
		if v.membrane / v.max_membrane <= below:  # perforin on a weakened cell finishes it
			hit_def = BioAttackDef.new(def.id, def.atp_cost, def.damage * float(a["execute_mult"]), def.cooldown, def.range_units, def.knockback, def.invulnerable_seconds)
		_hit(e, hit_def, origin, color)
		BioSignature.play(&"pore", e.global_position, color, 1.2, {}, e)
	BioFx.shake(0.12)


## A lance of light that thins and fades: a wide soft stroke under a white-hot core.
func _beam(from: Vector2, to: Vector2, color: Color, width_px: float) -> void:
	var soft := Line2D.new()
	soft.points = PackedVector2Array([from, to])
	soft.width = width_px
	soft.default_color = BioArt.with_alpha(color, 0.5)
	soft.begin_cap_mode = Line2D.LINE_CAP_ROUND
	soft.end_cap_mode = Line2D.LINE_CAP_ROUND
	soft.material = BioArt.additive()
	soft.z_index = 16
	var core := Line2D.new()
	core.points = soft.points
	core.width = width_px * 0.3
	core.default_color = Color(1, 1, 1, 0.95)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	soft.add_child(core)
	BioFx.root.add_child(soft)
	var tween := soft.create_tween()
	tween.set_parallel(true)
	tween.tween_property(soft, "modulate:a", 0.0, 0.35)
	tween.tween_property(soft, "width", 0.0, 0.35)
	tween.chain().tween_callback(soft.queue_free)


## The body swells with the charge, then its own limbs burst out in every direction. A plasma cell fills with cisternae and
## releases a crescent wall of antibodies; a macrophage's pseudopods leave swirled grooves behind.
func _nova(id: StringName, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var charge := maxf(float(a.get("charge", 0.0)), 0.14)
	var radius := float(a["radius"])
	var plasma := float(a.get("charge", 0.0)) > 0.0
	_body.swell(1.35, charge + 0.1)
	if plasma:
		BioSignature.play(&"cartwheel", _host.global_position, color, charge, {"radius": 28.0 * 1.35}, _host)
	await _wait(charge)
	if not _alive():
		return
	var origin := _host.global_position
	var aim: Vector2 = _aim_source.aim if _aim_source != null else Vector2.RIGHT
	_limbs.radial(clampi(int(radius * 3.0), 8, 14), radius, 0.09, 0.16, {"tint": color, "sweep": 0.0})
	_body.swell(0.82, 0.12)
	if plasma:
		BioSignature.play(&"wall", origin, color, 1.6, {"dir": aim, "reach": radius * BioArt.UNIT}, null)
	else:
		BioSignature.play(&"grooves", origin, color, 1.2, {"radius": radius * BioArt.UNIT}, null)
	for e in BioTargeting.enemies(_host.get_world_2d(), origin, radius * BioArt.UNIT, _host.combatant.actor.team):
		_hit(e, def, origin, color)
	BioFx.shake(0.2)


## Compresses like a spring, then launches stretched into a lance and rebounds.
func _dash_strike(id: StringName, def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color) -> void:
	_body.elastic(aim, 0.45, 1.0, 0.13)
	_host.apply_impulse(-aim * 3.0)
	await _wait(0.13)
	if not _alive():
		return
	_host.dash(aim, float(a["distance"]), 0.2)
	_limbs.reach(aim, 1.7, 0.08, 0.3, {"tint": color, "sweep": 0.0, "style": {"tip": &"spear", "stiffness": 0.9, "wave": 0.05}})
	if id == &"explosao_neutrofilica":
		BioSignature.play(&"diapedesis", _host.global_position, color, 1.0, {"dir": aim}, _host)
	var seen := {}
	var until := BioClock.now() + 0.26
	while BioClock.now() < until and is_instance_valid(_host):
		for e in BioTargeting.enemies(_host.get_world_2d(), _host.global_position, 0.95 * BioArt.UNIT, _host.combatant.actor.team):
			if not seen.has(e):
				seen[e] = true
				_hit(e, def, _host.global_position - aim * BioArt.UNIT, color)
				if id == &"golpe_litico":
					BioSignature.play(&"scar", e.global_position, color, 0.8, {"dir": aim}, null)
				_body.elastic(-aim, 0.0, 0.35, 0.0)  # the impact squashes the body back
				BioFx.shake(0.12)
		await get_tree().physics_frame


## Antibodies bud off the membrane: a Y grows out, then is fired from its tip while the body recoils.
func _shoot_bolts(def: BioAttackDef, a: Dictionary, aim: Vector2, color: Color, count: int) -> void:
	var style := {"tip": &"y", "stiffness": 0.7, "base": 8.0, "tip_w": 6.0, "wave": 0.1}
	var buds: Array[BioLimb] = []
	if count == 1:
		var bud := _limbs.reach(aim, 1.2, 0.08, 0.16, {"tint": color, "sweep": 0.0, "style": style})
		if bud != null:
			buds.append(bud)
	else:
		buds.append_array(_limbs.fan(aim, count, float(a["spread"]) * 1.2, 1.35, 0.1, 0.2, {"tint": color, "sweep": 0.0, "style": style}))
	_body.elastic(aim, 0.12, 0.3, 0.06)
	await _wait(0.1)
	if not _alive():
		return
	_host.apply_impulse(-aim * 1.6)
	_body.elastic(aim, 0.4, 0.0, 0.0)
	var homing := bool(a.get("homing", false))
	var shot := BioProjectileDesign.params(projectile_traits) if BioProjectileDesign.is_designed(projectile_traits) else {}
	for i in count:
		var dir := aim
		var from := _host.global_position + aim * 0.7 * BioArt.UNIT
		if i < buds.size() and is_instance_valid(buds[i]):
			from = buds[i].tip_global()
			dir = (from - _host.global_position).normalized()
		var bolt := BioAbilityBolt.spawn(_host.get_parent(), _host.combatant, def, from, dir, float(a["speed"]), float(a["range"]), color, homing, shot)
		if count > 1:  # a salvo braids: neighbours swap sides in flight
			bolt.weave_amp = 9.0
			bolt.weave_phase = i * TAU / count * 2.0


## Fine limbs reach out to each target and tag it, the tag landing when the tip touches.
func _reach_and_mark(targets: Array, a: Dictionary, color: Color) -> void:
	var length := float(a.get("range", a.get("radius", 8.0))) + 0.5
	for t in targets:
		if is_instance_valid(t):
			_limbs.reach_node(t as Node2D, length, 0.14, 0.3, {"tint": color, "style": {"tip": &"fork", "base": 7.0, "tip_w": 4.0, "stiffness": 0.25}})
	if not targets.is_empty() and is_instance_valid(targets[0]):
		_body.elastic(targets[0].global_position - _host.global_position, 0.1, 0.25, 0.08)
	await _wait(0.16)
	for t in targets:
		if is_instance_valid(t):
			_mark(t as BioCellActor, a, color)


func _mark(target: BioCellActor, a: Dictionary, color: Color) -> void:
	target.combatant.mark(float(a["mult"]), float(a["seconds"]))
	if a.has("slow"):
		target.slow(1.0 - float(a["slow"]), float(a["seconds"]))
	BioMarkGlyph.attach(target, color, float(a["seconds"]), StringName(str(a.get("mark_kind", ""))))
	BioPfx.burst(BioFx.root, target.global_position, color, 6, 90.0, 0.45, 7.0)


func _execute(target: BioCellActor, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var v := target.combatant.actor.vitals
	var kill := BioAttackDef.new(def.id, def.atp_cost, maxf(def.damage, v.membrane + 1.0), def.cooldown, def.range_units, 0.0, 0.0)
	_limbs.reach_node(target, float(a["range"]) + 0.5, 0.16, 0.3, {"tint": color, "style": {"tip": &"spear", "stiffness": 0.95, "wave": 0.03}})
	_body.elastic(target.global_position - _host.global_position, 0.2, 0.5, 0.1)
	BioSignature.play(&"blebs", target.global_position, color, 0.4, {"radius": 22.0}, target)
	var tween := target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE * 0.75, 0.3)
	await _wait(0.3)
	if is_instance_valid(target):
		target.scale = Vector2.ONE
		if target.combatant.actor.vitals.is_alive():
			var at := target.global_position
			_hit(target, kill, _host.global_position, color)
			BioSignature.play(&"bodies", at, color, 1.8, {}, null)
			BioFx.shake(0.16)


## Zones: a limb stretches to the spot (or the body bursts in place), and the effect appears at its tip.
func _zone(id: StringName, a: Dictionary, origin: Vector2, aim: Vector2, color: Color) -> void:
	var reach := float(a["reach"])
	var style := str(a.get("style", ""))
	var spot := origin + aim * reach * BioArt.UNIT
	if reach > 0.0:
		if style == "net":
			_limbs.fan(aim, 5, 60.0, reach + 0.2, 0.14, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"fork", "base": 6.0, "tip_w": 3.0, "stiffness": 0.2, "wave": 0.5}})
		else:
			_limbs.reach(aim, reach + 0.2, 0.14, 0.4, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "base": 17.0, "tip_w": 20.0}})
		_body.elastic(aim, 0.25, 0.5, 0.08)
		await _wait(0.14)
	else:  # centred on the body: it swells, bristles with short bumpy limbs, and releases
		_body.swell(1.28, 0.22)
		_limbs.radial(8, float(a.get("radius", 2.0)) * 0.55, 0.12, 0.3, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "bumps": 3, "base": 14.0, "tip_w": 12.0}})
		await _wait(0.12)
	if _alive():
		BioAbilityZone.spawn(_host.get_parent(), _host, id, spot if reach > 0.0 else _host.global_position, a)


func _heal(id: StringName, a: Dictionary, origin: Vector2, color: Color) -> void:
	_limbs.radial(5, 1.4, 0.16, float(a["seconds"]) * 0.5, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "wave": 0.9, "stiffness": 0.1, "motes": true}})
	_body.swell(1.12, 0.5)
	var params := a.duplicate()
	params["style"] = "heal"
	params["radius"] = 1.4
	params["duration"] = float(a["seconds"])
	params["follow"] = true
	BioAbilityZone.spawn(_host.get_parent(), _host, id, origin, params)


## Shield: the body thickens and armoured limbs ring it. Song: soft tendrils sway in rhythm.
func _aura(id: StringName, a: Dictionary, color: Color) -> void:
	var style := str(a.get("style", "shield"))
	var duration := float(a["duration"])
	var me := _host.combatant
	if style == "shield":
		me.guard(float(a["taken"]), duration)
		_body.swell(1.22, duration)
		_limbs.radial(8, 1.25, 0.12, duration * 0.85, {"tint": color, "sweep": 0.0, "style": {"tip": &"blob", "base": 22.0, "tip_w": 20.0, "stiffness": 0.85, "wave": 0.04, "barbs": 2}})
	elif style == "song":
		me.haste(float(a["speed"]), duration, float(a.get("regen_atp", 0.0)))
		_limbs.radial(5, 1.9, 0.2, duration * 0.8, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "wave": 1.0, "stiffness": 0.08, "motes": true}})
		_body.elastic(Vector2.UP, 0.0, 0.2, 0.0)
	var params := {"style": style, "color": color, "radius": 1.4 if style == "shield" else 3.2, "duration": duration, "follow": true}
	BioAbilityZone.spawn(_host.get_parent(), _host, id, _host.global_position, params)


## Sentinels bud off the body: bulbs grow out, then orbit as separate lights.
func _summon(id: StringName, a: Dictionary, color: Color) -> void:
	_limbs.radial(int(a["count"]), 1.7, 0.14, 0.35, {"tint": color, "sweep": 0.0, "style": {"tip": &"bulb", "stiffness": 0.3}})
	_body.swell(1.12, 0.3)
	await _wait(0.3)
	if not _alive():
		return
	var params := a.duplicate()
	params["style"] = "sentinels"
	params["radius"] = 2.0
	params["follow"] = true
	BioAbilityZone.spawn(_host.get_parent(), _host, id, _host.global_position, params)
