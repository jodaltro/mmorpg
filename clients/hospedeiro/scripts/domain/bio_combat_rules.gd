class_name BioCombatRules
extends RefCounted


static func can_hit(attacker: BioActor, target: BioActor) -> bool:
	return attacker != target and attacker.team != target.team and target.vitals.is_alive()


## Damage comes from the catalog definition; the caller only names which attack landed on whom.
static func resolve(attacker: BioActor, target: BioActor, def: BioAttackDef, now: float) -> BioHitResult:
	if not can_hit(attacker, target) or def.damage <= 0.0:
		return BioHitResult.new(BioActor.HitOutcome.IGNORED, 0.0)
	return target.receive_hit(def, now)
