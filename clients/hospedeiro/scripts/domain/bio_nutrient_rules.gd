class_name BioNutrientRules
extends RefCounted

enum Kind { GLUCOSE, LIPID }

const GLUCOSE_ATP := 18.0
const LIPID_REPAIR := 10.0


static func consume(actor: BioActor, kind: int) -> void:
	if not actor.vitals.is_alive():
		return
	var yield_multiplier := actor.stat(BioGene.NUTRIENT_YIELD)
	if kind == Kind.GLUCOSE:
		actor.vitals.add_atp(GLUCOSE_ATP * yield_multiplier)
	else:
		actor.vitals.repair(LIPID_REPAIR * yield_multiplier)
