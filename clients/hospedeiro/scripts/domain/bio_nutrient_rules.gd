class_name BioNutrientRules
extends RefCounted

enum Kind { GLUCOSE, LIPID }

const GLUCOSE_ATP := 18.0
const LIPID_REPAIR := 10.0


## What the host's insulin adds to what a nutrient is worth (set by the world from the body's vitals).
static var body_multiplier := 1.0


static func consume(actor: BioActor, kind: int) -> void:
	if not actor.vitals.is_alive():
		return
	var yield_multiplier := actor.stat(BioGene.NUTRIENT_YIELD) * body_multiplier
	if kind == Kind.GLUCOSE:
		actor.vitals.add_atp(GLUCOSE_ATP * yield_multiplier)
	else:
		actor.vitals.repair(LIPID_REPAIR * yield_multiplier)
