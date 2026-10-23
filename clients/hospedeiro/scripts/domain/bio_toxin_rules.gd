class_name BioToxinRules
extends RefCounted
## The liver's verb is to filter: a toxin mote is cleared by touching it. It costs the membrane, unless the cell carries peroxisomes
## (the organelle that breaks toxins down), which turn it into energy instead.

const DAMAGE := 5.0
const RESISTANT_ATP := 10.0
const RESISTANT_GENE := &"peroxissomos"


## Applies one toxin to the actor; returns the membrane it cost (0 for a cell that resists).
static func filter(actor: BioActor, resistant: bool) -> float:
	if not actor.vitals.is_alive():
		return 0.0
	if resistant:
		actor.vitals.add_atp(RESISTANT_ATP)
		return 0.0
	return actor.vitals.take_damage(DAMAGE)
