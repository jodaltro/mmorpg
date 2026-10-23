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
var _brittle_until := 0.0
var _burn_until := 0.0
var _burn_dps := 0.0
var _burn_fx := 0.0
var _chaining := false  # a chained blow does not chain again


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
	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0) * attacker.damage_dealt_mult
	if now < _brittle_until:
		factor *= BioEffectPhysics.BRITTLE_MULT
	var styled := attacker.effect_style != &"" and not attacker._chaining and BioAbilityCatalog.has(hit_def.id)
	if styled:
		factor *= BioEffectPhysics.direct_mult(attacker.effect_style)
	var def := hit_def
	if not is_equal_approx(factor, 1.0):
		def = BioAttackDef.new(hit_def.id, hit_def.atp_cost, hit_def.damage * factor, hit_def.cooldown, hit_def.range_units, hit_def.knockback, hit_def.invulnerable_seconds)
	var result := BioCombatRules.resolve(attacker.actor, actor, def, now)
	if result.outcome == BioActor.HitOutcome.IGNORED:
		return result
	hit.emit(self, result)
	if styled and result.damage_applied > 0.0:
		attacker._apply_style(self, result.damage_applied, hit_def)
	if result.outcome == BioActor.HitOutcome.KILLED:
		died.emit(self)
	return result


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
