class_name BioAbilityRunner
extends Node
## The player's class abilities. The engine decides which ones are known (starter, quest, discovery, awakening);
## this node holds them in four slots (Q F C V) and performs them. Cost and cooldown go through the domain actor
## like any attack; a target-seeking ability that finds no target costs nothing.

signal learned(id: StringName)
signal performed(id: StringName)

const SLOTS := 4
const NO_TARGET := 10
const UNKNOWN := 11

var slots: Array[StringName] = []

var _host: BioCellActor
var _aim := Vector2.RIGHT
var _aim_source: BioCellController


func configure(host: BioCellActor, controller: BioCellController) -> void:
	_host = host
	_aim_source = controller


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
	var aim: Vector2 = _aim_source.aim if _aim_source != null else Vector2.RIGHT
	var origin := _host.global_position
	var me := _host.combatant
	var kind: String = a["kind"]
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
	var color: Color = a["color"]
	match kind:
		"devour":
			_cone(def, a, origin, aim, color, true)
		"cone":
			_cone(def, a, origin, aim, color, false)
		"pierce":
			_pierce(def, a, origin, aim, color)
		"nova":
			_nova(id, def, a, color)
		"dash_strike":
			_dash_strike(def, a, origin, aim, color)
		"bolt":
			BioAbilityBolt.spawn(_host.get_parent(), me, def, origin + aim * 0.7 * BioArt.UNIT, aim, float(a["speed"]), float(a["range"]), color, bool(a.get("homing", false)))
		"volley":
			var n := int(a["count"])
			var spread := deg_to_rad(float(a["spread"]))
			for i in n:
				var ang := lerpf(-spread * 0.5, spread * 0.5, i / float(maxi(n - 1, 1)))
				BioAbilityBolt.spawn(_host.get_parent(), me, def, origin + aim * 0.7 * BioArt.UNIT, aim.rotated(ang), float(a["speed"]), float(a["range"]), color, false)
		"mark":
			_mark(target, a, color)
		"mark_all":
			for e in BioTargeting.enemies(_host.get_world_2d(), origin, float(a["radius"]) * BioArt.UNIT, me.actor.team):
				_mark(e, a, color)
			BioFx.ring(origin, float(a["radius"]), color)
			BioPfx.ring_burst(BioFx.root, origin, color, float(a["radius"]) * BioArt.UNIT * 0.8, 70, 1.0, 9.0)
		"execute":
			_execute(target, def, a, color)
		"zone":
			var spot := origin + aim * float(a["reach"]) * BioArt.UNIT
			BioAbilityZone.spawn(_host.get_parent(), _host, id, spot, a)
		"heal":
			a = a.duplicate()
			a["style"] = "heal"
			a["radius"] = 1.4
			a["duration"] = float(a["seconds"])
			a["follow"] = true
			BioAbilityZone.spawn(_host.get_parent(), _host, id, origin, a)
		"aura":
			_aura(id, a, color)
		"summon":
			a = a.duplicate()
			a["style"] = "sentinels"
			a["radius"] = 2.0
			a["follow"] = true
			BioAbilityZone.spawn(_host.get_parent(), _host, id, origin, a)
	performed.emit(id)
	return status


func _hit(target: BioCellActor, def: BioAttackDef, from: Vector2, color: Color) -> BioHitResult:
	if not BioCombatRules.can_hit(_host.combatant.actor, target.combatant.actor):
		return null
	var result := target.combatant.receive_hit(_host.combatant, def)
	if result.outcome == BioActor.HitOutcome.HIT or result.outcome == BioActor.HitOutcome.KILLED:
		if def.knockback > 0.0:
			target.apply_impulse((target.global_position - from).normalized() * def.knockback)
		BioPfx.burst(BioFx.root, target.global_position, color, 16, 220.0, 0.5, 11.0)
	return result


func _cone(def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color, devour: bool) -> void:
	var half := float(a["half"])
	var reach := float(a["range"])
	BioFx.arc(origin, aim, reach, half, color)
	BioPfx.burst(BioFx.root, origin + aim * reach * 0.5 * BioArt.UNIT, color, 26, 260.0, 0.45, 12.0, aim, half)
	var inside := BioTargeting.in_cone(BioTargeting.enemies(_host.get_world_2d(), origin, (reach + 0.6) * BioArt.UNIT, _host.combatant.actor.team), origin, aim, reach * BioArt.UNIT, half)
	for e in inside:
		var result := _hit(e, def, origin, color)
		if devour and result != null and result.damage_applied > 0.0:
			_host.combatant.actor.vitals.repair(result.damage_applied * float(a["heal"]))
			BioPfx.ring_burst(BioFx.root, _host.global_position, color, 40.0, 14, 0.5, 9.0, true)
	BioFx.shake(0.1)


func _pierce(def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color) -> void:
	var reach_px := float(a["range"]) * BioArt.UNIT
	var tip := origin + aim * reach_px
	BioPfx.burst(BioFx.root, origin + aim * reach_px * 0.5, color, 30, 340.0, 0.35, 10.0, aim, 6.0)
	BioPfx.burst(BioFx.root, tip, Color.WHITE, 10, 200.0, 0.4, 9.0, aim, 40.0)
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


func _nova(id: StringName, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var charge := float(a.get("charge", 0.0))
	var radius := float(a["radius"])
	if charge > 0.0:
		BioPfx.ring_burst(BioFx.root, _host.global_position, color, radius * BioArt.UNIT, 60, charge, 12.0, true)
		await get_tree().create_timer(charge).timeout
		if not is_instance_valid(_host) or not _host.combatant.actor.vitals.is_alive():
			return
	var origin := _host.global_position
	BioFx.ring(origin, radius, color)
	BioFx.ring(origin, radius * 0.65, Color.WHITE)
	BioPfx.ring_burst(BioFx.root, origin, color, radius * BioArt.UNIT * 0.4, 64, 0.7, 14.0)
	BioPfx.burst(BioFx.root, origin, color, 36, 380.0, 0.8, 14.0)
	for e in BioTargeting.enemies(_host.get_world_2d(), origin, radius * BioArt.UNIT, _host.combatant.actor.team):
		_hit(e, def, origin, color)
	BioFx.shake(0.2)


func _dash_strike(def: BioAttackDef, a: Dictionary, origin: Vector2, aim: Vector2, color: Color) -> void:
	_host.dash(aim, float(a["distance"]), 0.2)
	BioPfx.trail(_host, color, 16.0, 40)
	BioFx.ring(origin, 0.6, color)
	var seen := {}
	var until := BioClock.now() + 0.26
	while BioClock.now() < until and is_instance_valid(_host):
		for e in BioTargeting.enemies(_host.get_world_2d(), _host.global_position, 0.95 * BioArt.UNIT, _host.combatant.actor.team):
			if not seen.has(e):
				seen[e] = true
				_hit(e, def, _host.global_position - aim * BioArt.UNIT, color)
				BioFx.shake(0.12)
		await get_tree().physics_frame


func _mark(target: BioCellActor, a: Dictionary, color: Color) -> void:
	target.combatant.mark(float(a["mult"]), float(a["seconds"]))
	if a.has("slow"):
		target.slow(1.0 - float(a["slow"]), float(a["seconds"]))
	BioMarkGlyph.attach(target, color, float(a["seconds"]))
	BioPfx.burst(BioFx.root, target.global_position, color, 18, 160.0, 0.6, 10.0)


func _execute(target: BioCellActor, def: BioAttackDef, a: Dictionary, color: Color) -> void:
	var v := target.combatant.actor.vitals
	var kill := BioAttackDef.new(def.id, def.atp_cost, maxf(def.damage, v.membrane + 1.0), def.cooldown, def.range_units, 0.0, 0.0)
	BioPfx.ring_burst(BioFx.root, target.global_position, color, 80.0, 40, 0.4, 11.0, true)
	await get_tree().create_timer(0.28).timeout
	if is_instance_valid(target) and target.combatant.actor.vitals.is_alive():
		_hit(target, kill, _host.global_position, color)
		BioFx.ring(target.global_position, 1.2, color)
		BioFx.shake(0.16)


func _aura(id: StringName, a: Dictionary, color: Color) -> void:
	var style := str(a.get("style", "shield"))
	var duration := float(a["duration"])
	var me := _host.combatant
	if style == "shield":
		me.guard(float(a["taken"]), duration)
	elif style == "song":
		me.haste(float(a["speed"]), duration, float(a.get("regen_atp", 0.0)))
	var params := {"style": style, "color": color, "radius": 1.4 if style == "shield" else 3.2, "duration": duration, "follow": true}
	BioAbilityZone.spawn(_host.get_parent(), _host, id, _host.global_position, params)
