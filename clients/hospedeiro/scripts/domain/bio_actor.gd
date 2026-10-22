class_name BioActor
extends RefCounted

enum Team { CELL, VIRUS }
enum AttackStatus { STARTED, DEAD, ON_COOLDOWN, NOT_ENOUGH_ATP }
enum HitOutcome { IGNORED, EVADED, HIT, KILLED }

var id: String
var team: int
var vitals: BioVitals
var genome: BioGenome  # optional; null means no mutations
var invulnerable_until: float = 0.0
var _ready_at: Dictionary = {}


func _init(p_id: String, p_team: int, p_vitals: BioVitals) -> void:
	id = p_id
	team = p_team
	vitals = p_vitals


## Value of a genome stat; neutral (1.0, or 0.0 for additive stats) without a genome.
func stat(key: StringName) -> float:
	if genome != null:
		return genome.stat(key)
	return 0.0 if BioGene.is_additive(key) else 1.0


## The attack as this actor performs it: the catalog definition shaped by its genome.
func attack_def(attack_id: StringName) -> BioAttackDef:
	var def := BioAttackCatalog.get_def(attack_id)
	return genome.modify(def) if genome != null else def


func cooldown_remaining(attack_id: StringName, now: float) -> float:
	var ready: float = _ready_at.get(attack_id, 0.0)
	return ready - now if ready > now else 0.0


func is_invulnerable(now: float) -> bool:
	return now < invulnerable_until


func try_begin_attack(attack_id: StringName, now: float) -> int:
	var def := attack_def(attack_id)
	if not vitals.is_alive():
		return AttackStatus.DEAD
	if cooldown_remaining(attack_id, now) > 0.0:
		return AttackStatus.ON_COOLDOWN
	if not vitals.try_spend_atp(def.atp_cost):
		return AttackStatus.NOT_ENOUGH_ATP
	_ready_at[attack_id] = now + def.cooldown
	if def.invulnerable_seconds > 0.0:
		invulnerable_until = maxf(invulnerable_until, now + def.invulnerable_seconds)
	return AttackStatus.STARTED


func receive_hit(def: BioAttackDef, now: float) -> BioHitResult:
	if not vitals.is_alive():
		return BioHitResult.new(HitOutcome.IGNORED, 0.0)
	if is_invulnerable(now):
		return BioHitResult.new(HitOutcome.EVADED, 0.0)
	var applied := vitals.take_damage(def.damage)
	return BioHitResult.new(HitOutcome.HIT if vitals.is_alive() else HitOutcome.KILLED, applied)
