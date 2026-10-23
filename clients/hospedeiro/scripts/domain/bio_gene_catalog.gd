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


	# Class mutations: the ones that change the form drastically. Only their lineage meets them.
	_add(&"pseudopodes_gigantes", "Pseudópodes Gigantes", {BioGene.MAX_MEMBRANE: 1.4, BioGene.LASH_DAMAGE: 1.2, BioGene.SPEED: 0.88}, &"macrofago")
	_add(&"lisossomos_acidos", "Lisossomos Ácidos", {BioGene.NUTRIENT_YIELD: 1.5, BioGene.SPIT_DAMAGE: 1.25, BioGene.MAX_ATP: 0.9}, &"macrofago")
	_add(&"rede_de_dna", "Rede de DNA", {BioGene.LASH_RANGE: 1.35, BioGene.SPEED: 1.15, BioGene.MAX_MEMBRANE: 0.85}, &"neutrofilo")
	_add(&"nucleo_multilobulado", "Núcleo Multilobulado", {BioGene.DASH_COOLDOWN: 0.7, BioGene.SPEED: 1.1, BioGene.LASH_DAMAGE: 0.9}, &"neutrofilo")
	_add(&"dendritos_ramificados", "Dendritos Ramificados", {BioGene.NUTRIENT_YIELD: 1.6, BioGene.LASH_RANGE: 1.25, BioGene.MAX_MEMBRANE: 0.88}, &"dendritica")
	_add(&"esporos_de_antigeno", "Esporos de Antígeno", {BioGene.ATP_REGEN: 3.0, BioGene.SPIT_DAMAGE: 1.2, BioGene.SPEED: 0.9}, &"dendritica")
	_add(&"anticorpos_em_y", "Anticorpos em Y", {BioGene.SPIT_DAMAGE: 1.6, BioGene.SPIT_COST: 1.2, BioGene.MAX_MEMBRANE: 0.9}, &"linfocito_b")
	_add(&"plasmocito", "Plasmócito", {BioGene.ATP_REGEN: 5.0, BioGene.SPIT_DAMAGE: 1.3, BioGene.SPEED: 0.75}, &"linfocito_b")
	_add(&"granulos_de_perforina", "Grânulos de Perforina", {BioGene.LASH_DAMAGE: 1.45, BioGene.SPIT_DAMAGE: 1.15, BioGene.MAX_MEMBRANE: 0.85}, &"t_citotoxico")
	_add(&"agulha_litica", "Agulha Lítica", {BioGene.LASH_RANGE: 1.5, BioGene.LASH_DAMAGE: 1.3, BioGene.SPIT_COST: 1.2}, &"t_citotoxico")
	_add(&"halo_de_citocinas", "Halo de Citocinas", {BioGene.MAX_MEMBRANE: 1.3, BioGene.ATP_REGEN: 4.0, BioGene.LASH_DAMAGE: 0.85}, &"t_auxiliar")
	_add(&"coro_de_interleucinas", "Coro de Interleucinas", {BioGene.NUTRIENT_YIELD: 1.4, BioGene.DASH_COOLDOWN: 0.75, BioGene.SPIT_DAMAGE: 0.9}, &"t_auxiliar")


static func _add(id: StringName, display_name: String, mods: Dictionary, requires_lineage: StringName = &"") -> void:
	_genes[id] = BioGene.new(id, display_name, mods, requires_lineage)
