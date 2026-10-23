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


func _process(delta: float) -> void:
	actor.vitals.tick(delta)
	if BioClock.now() < _haste_until and _bonus_atp > 0.0:
		actor.vitals.add_atp(_bonus_atp * delta)


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


func speed_mult() -> float:
	return _haste if BioClock.now() < _haste_until else 1.0


func receive_hit(attacker: BioCombatant, hit_def: BioAttackDef) -> BioHitResult:
	var now := BioClock.now()
	var factor := (_marked_mult if now < _marked_until else 1.0) * (_guard_mult if now < _guard_until else 1.0)
	var def := hit_def
	if not is_equal_approx(factor, 1.0):
		def = BioAttackDef.new(hit_def.id, hit_def.atp_cost, hit_def.damage * factor, hit_def.cooldown, hit_def.range_units, hit_def.knockback, hit_def.invulnerable_seconds)
	var result := BioCombatRules.resolve(attacker.actor, actor, def, now)
	if result.outcome == BioActor.HitOutcome.IGNORED:
		return result
	hit.emit(self, result)
	if result.outcome == BioActor.HitOutcome.KILLED:
		died.emit(self)
	return result
