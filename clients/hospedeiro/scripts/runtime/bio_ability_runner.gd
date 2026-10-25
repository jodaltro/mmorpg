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
var _kits: Array[BioKit] = []  # the abilities that need more than a hit, by class
var _kit_for := {}  # kind -> kit
var last_cast: StringName = &""  # the last ability cast: the B cell's immune memory repeats it
var network_cast: Callable


func configure(host: BioCellActor, controller: BioCellController, limbs: BioLimbs, body: BioCellBody) -> void:
	_host = host
	_aim_source = controller
	_limbs = limbs
	_body = body
	for kit in [BioKitMac.new(), BioKitNeu.new(), BioKitDen.new(), BioKitB.new(), BioKitTcy.new(), BioKitTau.new(), BioKitMast.new(), BioKitEos.new(), BioKitNk.new(), BioKitTreg.new()]:
		add_child(kit)
		kit.configure(host, controller, limbs, body)
		_kits.append(kit)
		for kind in kit.kinds():
			_kit_for[kind] = kit


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


## Two abilities trade keys (what the Body window does when the player clicks two slots).
func swap_slots(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= slots.size() or b >= slots.size() or a == b:
		return
	var held := slots[a]
	slots[a] = slots[b]
	slots[b] = held
	learned.emit(&"")  # lets the bar refresh


## Puts the known abilities in the order given (what a saved build asks for); the ones it does not name keep their place after.
func arrange(order: Array) -> void:
	var wanted: Array[StringName] = []
	for id in order:
		var key := StringName(str(id))
		if slots.has(key) and not wanted.has(key):
			wanted.append(key)
	for id in slots:
		if not wanted.has(id):
			wanted.append(id)
	if wanted != slots:
		slots = wanted
		learned.emit(&"")


func _process(_delta: float) -> void:
	if _host == null or not _host.visible or BioUi.captures_input() or BioUi.typing():
		return
	for i in SLOTS:
		if Input.is_action_just_pressed("bio_ab_%d" % (i + 1)):
			perform(i)


func perform(slot: int) -> int:
	return perform_id(slot_id(slot))


func perform_id(id: StringName) -> int:
	if network_cast.is_valid():
		return network_cast.call(id)
	return _perform(id, false)


## Casts an ability without paying for it and without starting its cooldown (a memory repeating what the cell did).
func perform_free(id: StringName) -> int:
	return _perform(id, true)


func _perform(id: StringName, free: bool) -> int:
	if bool(_host.get_meta("dungeon_briefing", false)): return BioActor.AttackStatus.ON_COOLDOWN
	if id == &"" or not knows(id):
		return UNKNOWN
	if not free:
		for held in _kits:  # the same key finishes what a kit is holding (a charge, an anchor)
			if held.repress(id):
				return BioActor.AttackStatus.STARTED
	var a := BioAbilityCatalog.get_ability(id)
	if _host.combatant.genome != null:
		a = _host.combatant.genome.tune(id, a)  # the mutations change this ability's numbers
	var aim: Vector2 = _aim_source.aim if _aim_source != null else Vector2.RIGHT
	var origin := _host.global_position
	var me := _host.combatant
	var kind: String = a["kind"]
	a = BioAbilityMode.apply(BioAbilityFocus.apply(a, _host.combatant.focus), BioAbilityMode.family_of(id), _host.combatant.modes)  # the cell's focus: a wide weak reach or a narrow strong one
	var kit: BioKit = _kit_for.get(kind)
	var picked: Array = []
	if kit != null:
		picked = kit.find(kind, a, origin, aim)
		if picked.is_empty():
			return NO_TARGET
	var status: int = BioActor.AttackStatus.STARTED if free else me.actor.try_begin_attack(id, BioClock.now())
	if status != BioActor.AttackStatus.STARTED:
		return status
	var def := me.actor.attack_def(id)
	if kind != "empower" and kind != "replay" and me.spend_empower(2.0) and not free:  # a matured cell: the cast costs nothing and hits harder
		me.actor.vitals.add_atp(def.atp_cost)
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
		"zone":
			_zone(id, a, origin, aim, color)
		_:
			if kit != null:
				kit.cast(kind, id, def, a, aim, color, picked)
	if kind != "replay":
		last_cast = id
	if not free:
		BioGeneEffects.apply(_host, id, aim, def)
	performed.emit(id)
	return status


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _alive() -> bool:
	return is_instance_valid(_host) and _host.combatant.actor.vitals.is_alive()


func _hit(target: BioCellActor, def: BioAttackDef, from: Vector2, color: Color) -> BioHitResult:
	return BioStrike.land(_host, target, def, from, color)


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
	BioStrike.beam(origin + aim * 0.4 * BioArt.UNIT, tip, color, float(a["width"]) * BioArt.UNIT * 0.5)
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
