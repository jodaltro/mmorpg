class_name BioBestiary
extends RefCounted
## What lives in each organ, outside the dungeons. The blood has its spiny virions; every other organ has its own wild things, with
## their own look and their own way of fighting (a clot that is slow and heavy, cocci that come in pairs, a spore that keeps away and
## throws spores, a plaque, an embolus that charges from afar, a parasite that splits in two). A region lists {kind, weight}; the kind
## `virion` is the classic one, the others are defined in BioDungeonPlan.enemy.

const VIRION := &"virion"

const NATIVES := {
	&"sangue": [[&"virion", 100]],
	&"coracao": [[&"virion", 35], [&"trombo", 65]],
	&"pulmao": [[&"virion", 20], [&"pneumococo", 40], [&"esporo_fungico", 40]],
	&"aorta": [[&"virion", 20], [&"placa", 40], [&"embolo", 40]],
	&"figado": [[&"virion", 20], [&"plasmodio", 45], [&"esporo_de_bile", 35]],
	&"baco": [[&"virion", 15], [&"meningococo", 45], [&"bacteria_encapsulada", 40]],
	&"intestino": [[&"virion", 10], [&"bacteria_enterica", 40], [&"verme_intestinal", 30], [&"esporo_de_clostridio", 20]],
	&"rim": [[&"virion", 15], [&"cristal_de_urato", 45], [&"calculo_renal", 25], [&"espiculo_de_oxalato", 15]],
}


## The kinds that live in a region (as [kind, weight] pairs); the virion alone where nothing else is said.
static func natives(region: StringName) -> Array:
	return NATIVES.get(region, [[VIRION, 100]])


## One kind drawn for a new arrival in the region.
static func pick(region: StringName, rng: RandomNumberGenerator) -> StringName:
	var list := natives(region)
	var total := 0
	for entry in list:
		total += int(entry[1])
	var roll := rng.randi() % maxi(total, 1)
	for entry in list:
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return VIRION
