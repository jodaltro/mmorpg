class_name BioCombatant
extends Node
## Offline authority adapter: owns the domain actor and applies hits through the domain rules.

signal hit(who: BioCombatant, result: BioHitResult)
signal died(who: BioCombatant)
signal nutrient_consumed(kind: int)
signal genome_changed(genome: BioGenome)

var actor: BioActor
var genome := BioGenome.new()

var _id := "cell"
var _team: int = BioActor.Team.CELL
var _max_membrane := 100.0
var _max_atp := 100.0
var _atp_regen := 6.0

## Temporary states from abilities. Marks and guards scale the damage taken; haste speeds the cell and feeds ATP.
var _marked_until := 0.0
var _marked_mult := 1.0
var _guard_until := 0.0
var _guard_mult := 1.0
var _haste_until := 0.0
var _haste := 1.0
var _bonus_atp := 0.0
var damage_dealt_mult := 1.0  # how hard this one hits (enemies of a dungeon are tuned)

## The flavour of this cell's effects (BioEffectPhysics): the ability hits it lands carry a physical consequence.
var effect_style: StringName = &""
var focus := {}  # BioAbilityFocus.params: the risk and reward of every non-projectile ability
var modes := {}  # BioAbilityMode: how each family of abilities behaves {family: mode}
var _brittle_until := 0.0
var _burn_until := 0.0
var _burn_dps := 0.0
var _burn_fx := 0.0
var _chaining := false  # a chained blow does not chain again

## States the newer class abilities put on a cell: plain timers and small banks, read here and by the brains.
var _sleep_until := 0.0  # asleep: it does nothing until something hurts it, and that first blow lands harder
var _sleep_mult := 1.0
var _stasis_until := 0.0  # a crystal: it cannot act, nothing hurts it, and the blows it takes are kept
var _stasis_bank := 0.0
var _hidden_until := 0.0  # unseen: enemies lose it, and its first blow lands harder
var _hidden_strike := 1.0
var _hunted: BioCombatant  # the prey of a hunt: every blow on it gives cooldown time back
var _hunt_until := 0.0
var _hunt_refund := 0.0
var _hunt_atp := 0.0
var _link: Array = []  # the cells that share their wounds
var _link_until := 0.0
var _link_share := 0.0
var _grow_until := 0.0  # every kill makes it bigger and stronger, up to a few times
var _grow_stacks := 0
var _grow_max := 0
var _grow_damage := 0.0
var _grow_heal := 0.0
var _cascade_until := 0.0  # whatever it kills bursts into granules that hurt the ones next to it
var _cascade_def: BioAttackDef
var _cascade_radius := 0.0

signal grew(stacks: int)


func configure(id: String, team: int, max_membrane: float, max_atp: float, atp_regen: float) -> void:
	_id = id
	_team = team
	_max_membrane = max_membrane
	_max_atp = max_atp
	_atp_regen = atp_regen
	actor = _create()


func reset_vitals() -> void:
	actor = _create()


## Applies mutations: stats are rescaled keeping the current membrane/ATP fractions.
func set_genome(new_genome: BioGenome) -> void:
	genome = new_genome
	actor.genome = genome
	_rescale()
	genome_changed.emit(genome)


func team() -> int:
	return actor.team


func _create() -> BioActor:
	var created := BioActor.new(_id, _team, BioVitals.new(_max_membrane, _max_atp, _atp_regen))
	created.genome = genome
	var vitals := created.vitals
	vitals.rescale(_max_membrane * genome.stat(BioGene.MAX_MEMBRANE), _max_atp * genome.stat(BioGene.MAX_ATP), maxf(0.0, _atp_regen + genome.stat(BioGene.ATP_REGEN)))
	vitals.membrane = vitals.max_membrane
	vitals.atp = vitals.max_atp
	return created


func _rescale() -> void:
	actor.vitals.rescale(_max_membrane * genome.stat(BioGene.MAX_MEMBRANE), _max_atp * genome.stat(BioGene.MAX_ATP), maxf(0.0, _atp_regen + genome.stat(BioGene.ATP_REGEN)))


func _ready() -> void:
	if actor == null:
		actor = _create()


var _burn_color := Color(1.0, 0.5, 0.15)


func _process(delta: float) -> void:
	actor.vitals.tick(delta)
	if _burn_dps > 0.0:
		_tick_burn(delta)
	if BioClock.now() < _haste_until and _bonus_atp > 0.0:
		actor.vitals.add_atp(_bonus_atp * delta)


## Sets the cell alight (a flame, or a shot that sticks): `dps` membrane per second for `seconds`; a stronger burn replaces a weaker one.
func ignite(dps: float, seconds: float, color: Color = Color(1.0, 0.5, 0.15)) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_until = maxf(_burn_until, BioClock.now() + seconds)
	_burn_color = color


## A burning cell loses membrane over time.
func _tick_burn(delta: float) -> void:
	if BioClock.now() >= _burn_until or not actor.vitals.is_alive():
		_burn_dps = 0.0
		return
	var before := actor.vitals.is_alive()
	actor.vitals.take_damage(_burn_dps * delta)
	_burn_fx -= delta
	if _burn_fx <= 0.0:
		_burn_fx = 0.35
		var host := get_parent() as Node2D
		if host != null:
			BioPfx.burst(BioFx.root, host.global_position, _burn_color, 3, 90.0, 0.4, 8.0, Vector2.UP, 40.0)
	if before and not actor.vitals.is_alive():
		_burn_dps = 0.0
		died.emit(self)


func mark(mult: float, seconds: float) -> void:
	_marked_until = BioClock.now() + seconds
	_marked_mult = mult


## Asleep for `seconds`: it does nothing until something hurts it, and the blow that wakes it lands `wake_mult` times harder.
func put_to_sleep(seconds: float, wake_mult: float) -> void:
	_sleep_until = BioClock.now() + seconds
	_sleep_mult = wake_mult


func is_asleep() -> bool:
	return BioClock.now() < _sleep_until


## Cannot act: asleep or encased in a crystal.
func is_stunned() -> bool:
	var now := BioClock.now()
	return now < _sleep_until or now < _stasis_until


## Encased for `seconds`: nothing hurts it, the damage it is dealt is kept (see release_stasis).
func encase(seconds: float) -> void:
	_stasis_until = BioClock.now() + seconds
	_stasis_bank = 0.0


func is_encased() -> bool:
	return BioClock.now() < _stasis_until


func stasis_bank() -> float:
	return _stasis_bank


## Breaks the crystal and hands over every blow it kept.
func release_stasis() -> float:
	var bank := _stasis_bank
	_stasis_until = 0.0
	_stasis_bank = 0.0
	return bank


## Unseen for `seconds`: enemies lose track of it, and the first blow it lands is `strike` times harder.
func vanish(seconds: float, strike: float) -> void:
	_hidden_until = BioClock.now() + seconds
	_hidden_strike = strike


func is_hidden() -> bool:
	return BioClock.now() < _hidden_until


func reveal() -> void:
	_hidden_until = 0.0


## Hunts `prey` for `seconds`: each blow on it gives `refund` seconds of cooldown back and `atp` energy; killing it gives everything back.
func hunt(prey: BioCombatant, seconds: float, refund: float, atp: float) -> void:
	_hunted = prey
	_hunt_until = BioClock.now() + seconds
	_hunt_refund = refund
	_hunt_atp = atp


func hunted() -> BioCombatant:
	return _hunted if BioClock.now() < _hunt_until and is_instance_valid(_hunted) else null


## These cells share their wounds for `seconds`: what one loses, the others lose `share` of.
func link_with(group: Array, seconds: float, share: float) -> void:
	_link = group
	_link_until = BioClock.now() + seconds
	_link_share = share


func is_linked() -> bool:
	return BioClock.now() < _link_until


func link_group() -> Array:
	return _link if is_linked() else []


## Starts growing: one stack now, one more for every kill (up to `max_stacks`); each stack adds `damage_per` to what it deals and heals a share.
func begin_growth(seconds: float, max_stacks: int, damage_per: float, heal_share: float) -> void:
	_grow_stacks = maxi(growth_stacks(), 1)
	_grow_until = BioClock.now() + seconds
	_grow_max = max_stacks
	_grow_damage = damage_per
	_grow_heal = heal_share
	grew.emit(_grow_stacks)


func growth_stacks() -> int:
	return _grow_stacks if BioClock.now() < _grow_until else 0


func growth_ends_at() -> float:
	return _grow_until


## For `seconds`, everything this cell kills bursts: `def` hurts the enemies within `radius_units` of the body.
func start_cascade(seconds: float, def: BioAttackDef, radius_units: float) -> void:
	_cascade_until = BioClock.now() + seconds
	_cascade_def = def
	_cascade_radius = radius_units


func is_cascading() -> bool:
	return BioClock.now() < _cascade_until


## How hard this one hits, on top of the rest: it grows with every kill of a growing cell.
func dealing_mult(now: float) -> float:
	return 1.0 + _grow_damage * _grow_stacks if now < _grow_until else 1.0


func is_marked() -> bool:
	return BioClock.now() < _marked_until


func guard(taken_mult: float, seconds: float) -> void:
	_guard_until = BioClock.now() + seconds
	_guard_mult = taken_mult


func haste(speed_mult: float, seconds: float, atp_per_second: float) -> void:
	_haste_until = BioClock.now() + seconds
	_haste = speed_mult
	_bonus_atp = atp_per_second


var environment_speed := 1.0  # the body's hormones (adrenaline) make every cell quicker


func speed_mult() -> float:
	return (_haste if BioClock.now() < _haste_until else 1.0) * environment_speed


func receive_hit(attacker: BioCombatant, hit_def: BioAttackDef) -> BioHitResult:
	var now := BioClock.now()
	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0) * attacker.damage_dealt_mult * attacker.dealing_mult(now)
	var lands := BioCombatRules.can_hit(attacker.actor, actor) and hit_def.damage > 0.0
	if lands and attacker.is_hidden():  # the ambush: the first blow out of hiding
		factor *= attacker._hidden_strike
		attacker.reveal()
	if lands and now < _sleep_until:  # the blow that wakes it
		factor *= _sleep_mult
		_sleep_until = 0.0
	if now < _brittle_until:
		factor *= BioEffectPhysics.BRITTLE_MULT
	if BioAbilityFocus.applies_to(hit_def.id) and not attacker._chaining:
		factor *= float(attacker.focus.get("damage", 1.0))
	var family := BioAbilityMode.family_of(hit_def.id) if not attacker._chaining else ""
	if family != "":
		factor *= BioAbilityMode.direct(family, attacker.modes)
	var styled := attacker.effect_style != &"" and not attacker._chaining and BioAbilityCatalog.has(hit_def.id)
	if styled:
		factor *= BioEffectPhysics.direct_mult(attacker.effect_style)
	var def := hit_def
	if not is_equal_approx(factor, 1.0):
		def = BioAttackDef.new(hit_def.id, hit_def.atp_cost, hit_def.damage * factor, hit_def.cooldown, hit_def.range_units, hit_def.knockback, hit_def.invulnerable_seconds)
	if lands and now < _stasis_until:  # inside the crystal: the blow is kept, not felt
		_stasis_bank += def.damage
		return BioHitResult.new(BioActor.HitOutcome.HIT, 0.0)
	var result := BioCombatRules.resolve(attacker.actor, actor, def, now)
	if result.outcome == BioActor.HitOutcome.IGNORED:
		return result
	hit.emit(self, result)
	if styled and result.damage_applied > 0.0:
		attacker._apply_style(self, result.damage_applied, hit_def)
	if family != "" and result.outcome != BioActor.HitOutcome.EVADED:
		attacker._apply_mode(self, family, hit_def)
	if result.damage_applied > 0.0:
		if now < _link_until:
			_share_with_link(result.damage_applied, attacker)
		attacker._after_blow(self, result)
	if result.outcome == BioActor.HitOutcome.KILLED:
		died.emit(self)
	return result


## What a blow that landed does for the one who struck it: the hunt gives time back, a kill makes it grow, a kill bursts.
func _after_blow(victim: BioCombatant, result: BioHitResult) -> void:
	var now := BioClock.now()
	var killed := result.outcome == BioActor.HitOutcome.KILLED
	if victim == _hunted and now < _hunt_until:
		if killed:
			actor.reset_cooldowns()
			actor.vitals.add_atp(_hunt_atp * 4.0)
			_hunted = null
		else:
			actor.refund_cooldowns(now, _hunt_refund)
			actor.vitals.add_atp(_hunt_atp)
	if killed and now < _grow_until:
		_grow_stacks = mini(_grow_stacks + 1, _grow_max)
		actor.vitals.repair(actor.vitals.max_membrane * _grow_heal)
		grew.emit(_grow_stacks)
	if killed and now < _cascade_until:
		_cascade_from(victim)


## A wounded cell passes a share of the wound to the others of its link (they feel it directly, so it does not echo back).
func _share_with_link(dealt: float, attacker: BioCombatant) -> void:
	for other in _link:
		var mate := other as BioCombatant
		if mate == null or mate == self or not is_instance_valid(mate) or not mate.actor.vitals.is_alive():
			continue
		var taken := mate.actor.vitals.take_damage(dealt * _link_share)
		var host := mate.get_parent() as Node2D
		if host != null:
			BioPfx.burst(BioFx.root, host.global_position, Color(0.5, 1.0, 0.85), 6, 120.0, 0.3, 8.0)
		var result := BioHitResult.new(BioActor.HitOutcome.HIT if mate.actor.vitals.is_alive() else BioActor.HitOutcome.KILLED, taken)
		mate.hit.emit(mate, result)
		if result.outcome == BioActor.HitOutcome.KILLED:
			attacker._after_blow(mate, result)
			mate.died.emit(mate)


## The dead cell bursts into granules a moment later; whoever that kills bursts in turn, so a pack goes off one after another.
func _cascade_from(victim: BioCombatant) -> void:
	var corpse := victim.get_parent() as Node2D
	if corpse == null or _cascade_def == null:
		return
	var spot := corpse.global_position
	var world := corpse.get_world_2d()
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_cascading():
			return
		var radius_px := _cascade_radius * BioArt.UNIT
		BioPfx.ring_burst(BioFx.root, spot, Color(1.0, 0.6, 0.2), radius_px * 0.85, 30, 0.4, 11.0)
		BioPfx.burst(BioFx.root, spot, Color(1.0, 0.8, 0.4), 16, 200.0, 0.45, 10.0)
		for e in BioTargeting.enemies(world, spot, radius_px, actor.team):
			e.combatant.receive_hit(self, _cascade_def))


## What the family's designed mode does to a victim it just hit: reel it in, throw it away, strike it again.
func _apply_mode(victim: BioCombatant, family: String, hit_def: BioAttackDef) -> void:
	var m := BioAbilityMode.mode(family, modes)
	var host := victim.get_parent() as BioCellActor
	var mine := get_parent() as BioCellActor
	if host != null and mine != null:
		var to_me := (mine.global_position - host.global_position).normalized()
		if m.has("pull"):
			host.apply_impulse(to_me * float(m["pull"]))
		if m.has("knock"):
			host.apply_impulse(-to_me * float(m["knock"]))
	if m.has("repeat"):
		var r: Array = m["repeat"]
		for i in int(r[2]):
			get_tree().create_timer(float(r[0]) * (i + 1)).timeout.connect(func() -> void:
				if not is_instance_valid(victim) or not victim.actor.vitals.is_alive() or not is_instance_valid(self):
					return
				_chaining = true  # the second blow does not trigger modes again
				var again := BioAttackDef.new(hit_def.id, 0.0, hit_def.damage * float(r[1]), 0.0, hit_def.range_units, 0.0, 0.0)
				victim.receive_hit(self, again)
				_chaining = false
				BioPfx.burst(BioFx.root, (victim.get_parent() as Node2D).global_position, Color(1.0, 0.85, 0.6), 5, 120.0, 0.25, 8.0))


## The physical consequence of this cell's flavour on a victim it just hurt for `dealt`.
func _apply_style(victim: BioCombatant, dealt: float, hit_def: BioAttackDef) -> void:
	var now := BioClock.now()
	var host := victim.get_parent() as BioCellActor
	match effect_style:
		&"chama":
			victim.ignite(dealt * BioEffectPhysics.BURN_SHARE / BioEffectPhysics.BURN_SECONDS, BioEffectPhysics.BURN_SECONDS, Color(1.0, 0.5, 0.15))
		&"cristal":
			victim._brittle_until = now + BioEffectPhysics.BRITTLE_SECONDS
		&"nevoa":
			if host != null:
				host.slow(BioEffectPhysics.SLOW_FACTOR, BioEffectPhysics.SLOW_SECONDS)
				for e in BioTargeting.enemies(host.get_world_2d(), host.global_position, BioEffectPhysics.SLOW_RADIUS_UNITS * BioArt.UNIT, actor.team):
					(e as BioCellActor).slow(BioEffectPhysics.SLOW_FACTOR, BioEffectPhysics.SLOW_SECONDS)
		&"eletrico":
			if host != null:
				var chained := 0
				_chaining = true
				for e in BioTargeting.enemies(host.get_world_2d(), host.global_position, BioEffectPhysics.CHAIN_RADIUS_UNITS * BioArt.UNIT, actor.team):
					if e == host or chained >= BioEffectPhysics.CHAIN_TARGETS:
						continue
					chained += 1
					var arc := BioAttackDef.new(hit_def.id, 0.0, dealt * BioEffectPhysics.CHAIN_SHARE, 0.0, hit_def.range_units, 0.0, 0.0)
					(e as BioCellActor).combatant.receive_hit(self, arc)
					BioPfx.burst(BioFx.root, (e as BioCellActor).global_position, Color(0.6, 0.85, 1.0), 8, 160.0, 0.3, 8.0)
				_chaining = false
		&"organico":
			actor.vitals.repair(dealt * BioEffectPhysics.LEECH_SHARE)
