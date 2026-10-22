class_name BioGeneCatalog
extends RefCounted

static var _genes: Dictionary = {}


static func get_gene(id: StringName) -> BioGene:
	_ensure()
	return _genes[id]


static func all_ids() -> Array:
	_ensure()
	return _genes.keys()


static func _ensure() -> void:
	if not _genes.is_empty():
		return
	_add(&"flagelo_calejado", "Flagelo Calejado", {BioGene.LASH_DAMAGE: 1.25, BioGene.SPEED: 0.92})
	_add(&"cilios_ageis", "Cílios Ágeis", {BioGene.SPEED: 1.18, BioGene.MAX_MEMBRANE: 0.9})
	_add(&"membrana_espessa", "Membrana Espessa", {BioGene.MAX_MEMBRANE: 1.3, BioGene.SPEED: 0.9})
	_add(&"mitocondria_avida", "Mitocôndria Ávida", {BioGene.ATP_REGEN: 4.0, BioGene.MAX_ATP: 0.8})
	_add(&"vesicula_toxica", "Vesícula Tóxica", {BioGene.SPIT_DAMAGE: 1.4, BioGene.SPIT_COST: 1.3})
	_add(&"nucleo_reativo", "Núcleo Reativo", {BioGene.DASH_COOLDOWN: 0.65, BioGene.MAX_MEMBRANE: 0.92})
	_add(&"cauda_longa", "Cauda Longa", {BioGene.LASH_RANGE: 1.3, BioGene.LASH_DAMAGE: 0.9})
	_add(&"enzima_voraz", "Enzima Voraz", {BioGene.NUTRIENT_YIELD: 1.5, BioGene.ATP_REGEN: -2.0})


static func _add(id: StringName, display_name: String, mods: Dictionary) -> void:
	_genes[id] = BioGene.new(id, display_name, mods)
