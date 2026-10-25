class_name BioTrainingCombatant
extends BioCombatant
## A practice instrument, never a kill, source of nutrients or progression.
var practice: Dictionary = {}

func receive_hit(attacker: BioCombatant, definition: BioAttackDef) -> BioHitResult:
	if not BioCombatRules.can_hit(attacker.actor, actor) or definition.damage <= 0:
		return BioHitResult.new(BioActor.HitOutcome.IGNORED, 0)
	var key := str(attacker.actor.id)
	var counts: Dictionary = practice.get(key, {})
	counts[str(definition.id)] = int(counts.get(str(definition.id), 0)) + 1
	practice[key] = counts
	_last_attacker = attacker
	var result := BioHitResult.new(BioActor.HitOutcome.HIT, definition.damage)
	hit.emit(self, result)
	return result
