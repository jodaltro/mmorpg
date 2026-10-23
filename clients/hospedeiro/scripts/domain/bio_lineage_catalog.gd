class_name BioLineageCatalog
extends RefCounted
## Lineages (the classes). Each gives the whole body a form and passive trade-offs; the engine decides
## who becomes what, this catalogue only says what a lineage means in play. Ids use underscores here
## (the engine uses hyphens: linfocito-b -> linfocito_b).

const NONE := &""

static var _mods: Dictionary = {}
static var _names: Dictionary = {}


static func normalise(engine_id: String) -> StringName:
	return StringName(engine_id.replace("-", "_"))


## Passive stat changes of a lineage, same keys as genes (multipliers; ATP_REGEN is additive).
static func mods_of(id: StringName) -> Dictionary:
	_ensure()
	return _mods.get(id, {})


static func display_name(id: StringName) -> String:
	_ensure()
	return _names.get(id, "Esfera")


static func has_tail(id: StringName) -> bool:
	return id == &"neutrofilo"


static func _ensure() -> void:
	if not _mods.is_empty():
		return
	_add(&"mieloide", "Mieloide", {BioGene.MAX_MEMBRANE: 1.15, BioGene.NUTRIENT_YIELD: 1.1})
	_add(&"linfoide", "Linfoide", {BioGene.SPIT_DAMAGE: 1.15, BioGene.ATP_REGEN: 1.0})
	_add(&"macrofago", "Macrófago", {BioGene.MAX_MEMBRANE: 1.5, BioGene.LASH_DAMAGE: 1.1, BioGene.SPEED: 0.85})
	_add(&"neutrofilo", "Neutrófilo", {BioGene.SPEED: 1.3, BioGene.DASH_COOLDOWN: 0.8, BioGene.MAX_MEMBRANE: 0.85})
	_add(&"dendritica", "Célula dendrítica", {BioGene.NUTRIENT_YIELD: 1.4, BioGene.ATP_REGEN: 3.0})
	_add(&"linfocito_b", "Linfócito B", {BioGene.SPIT_DAMAGE: 1.5, BioGene.SPIT_COST: 0.9, BioGene.MAX_MEMBRANE: 0.9})
	_add(&"t_citotoxico", "Linfócito T citotóxico", {BioGene.LASH_DAMAGE: 1.4, BioGene.SPEED: 1.05})
	_add(&"t_auxiliar", "Linfócito T auxiliar", {BioGene.ATP_REGEN: 4.0, BioGene.MAX_MEMBRANE: 1.1, BioGene.DASH_COOLDOWN: 0.85})


static func _add(id: StringName, display: String, mods: Dictionary) -> void:
	_mods[id] = mods
	_names[id] = display
