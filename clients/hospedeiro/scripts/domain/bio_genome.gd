class_name BioGenome
extends RefCounted
## The genes a cell currently expresses. There are no levels: power comes only from the chosen
## mutations, and every slot is a trade-off.

## Six pockets: a body can wear a good set of mutations at once instead of swapping one for another.
const SLOTS := 6
## Own class mutations needed for the final form (the rest of the slots are free for general ones).
const ASCENSION_GENES := 4

var equipped: Array[StringName] = []
var lineage: StringName = &""  # the class (BioLineageCatalog); empty while undifferentiated
## Genes to use instead of the catalog ones (the balance tuner tries scaled copies without touching the catalog).
var override_genes: Dictionary = {}


func _gene(id: StringName) -> BioGene:
	return override_genes.get(id, null) if override_genes.has(id) else BioGeneCatalog.get_gene(id)


func has_gene(id: StringName) -> bool:
	return equipped.has(id)


## Combined value of a stat: product of multipliers, or the sum for additive stats.
func stat(key: StringName) -> float:
	var additive := BioGene.is_additive(key)
	var total := 0.0 if additive else 1.0
	var lineage_mods := BioLineageCatalog.mods_of(lineage)
	if lineage_mods.has(key):
		total = (total + lineage_mods[key]) if additive else (total * lineage_mods[key])
	for id in equipped:
		var mods: Dictionary = _gene(id).mods
		if not mods.has(key):
			continue
		if additive:
			total += mods[key]
		else:
			total *= mods[key]
	return total


## How far this cell has risen towards its final form: the share (of ASCENSION_GENES) of its own class's
## mutations (0 for the newborn and the progenitors, 1 when all three are the class's own). At full the body stands up.
func ascension() -> float:
	if lineage == &"" or BioLineageCatalog.mods_of(lineage).is_empty():
		return 0.0
	var own := 0
	for id in equipped:
		if BioGeneCatalog.get_gene(id).requires_lineage == lineage:
			own += 1
	return clampf(own / float(ASCENSION_GENES), 0.0, 1.0)


## What the expressed genes do to one class ability, combined: multipliers multiply, "+name" additions add.
func perk(ability: StringName) -> Dictionary:
	var out := {}
	for id in equipped:
		var all: Dictionary = _gene(id).perks
		if not all.has(ability):
			continue
		for key in all[ability]:
			var k := str(key)
			if k.begins_with("+"):
				out[k] = float(out.get(k, 0.0)) + float(all[ability][key])
			else:
				out[k] = float(out.get(k, 1.0)) * float(all[ability][key])
	return out

func transformations(ability: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in equipped:
		var gene := _gene(id)
		if gene.requires_lineage != &"" and gene.requires_lineage != lineage: continue
		var trigger := str(gene.transformation.get("ability", ""))
		if trigger == String(ability) or (trigger == "*" and BioAbilityCatalog.has(ability)):
			var effect := gene.transformation.duplicate(true)
			effect["gene"] = String(id)
			out.append(effect)
	return out


## An ability's parameters as THIS genome performs them: its perks, then the general stats on top. Damage, cost and
## cooldown are not here: they live in the attack definition (see modify) so the domain actor validates them.
func tune(ability: StringName, params: Dictionary) -> Dictionary:
	var out := params.duplicate()
	var perks := perk(ability)
	var power := stat(BioGene.ABILITY_POWER)
	var reach := stat(BioGene.ABILITY_RANGE)
	for key in out:
		if typeof(out[key]) != TYPE_FLOAT and typeof(out[key]) != TYPE_INT:
			continue
		var k := str(key)
		if k in ["damage", "cooldown", "cost", "cost"]:
			continue
		var v := float(out[key])
		if perks.has(k):
			v *= float(perks[k])
		if k in ["tick", "burst", "amount", "heal", "regen_atp", "regen_membrane"]:
			v *= power
		elif k in ["radius", "reach", "range", "distance"]:
			v *= reach
		out[key] = v if typeof(out[key]) == TYPE_FLOAT else int(roundf(v))
	for key in perks:
		var k := str(key)
		if k.begins_with("+") and out.has(k.substr(1)):
			out[k.substr(1)] = float(out[k.substr(1)]) + float(perks[key]) if typeof(out[k.substr(1)]) == TYPE_FLOAT else int(out[k.substr(1)]) + int(perks[key])
	return out


## Adds a gene; when every slot is taken the oldest one is reabsorbed. Returns the replaced id (or &"").
func equip(id: StringName) -> StringName:
	if equipped.has(id):
		return &""
	var replaced: StringName = &""
	if equipped.size() >= SLOTS:
		replaced = equipped[0]
		equipped.remove_at(0)
	equipped.append(id)
	return replaced


## Applies the genome to an attack definition, returning a new one (the catalog is never mutated).
func modify(def: BioAttackDef) -> BioAttackDef:
	var damage := def.damage
	var cost := def.atp_cost
	var cooldown := def.cooldown
	var reach := def.range_units
	match def.id:
		BioAttackCatalog.FLAGELLUM_LASH:
			damage *= stat(BioGene.LASH_DAMAGE)
			reach *= stat(BioGene.LASH_RANGE)
		BioAttackCatalog.TOXIN_SPIT:
			damage *= stat(BioGene.SPIT_DAMAGE)
			cost *= stat(BioGene.SPIT_COST)
		BioAttackCatalog.MEMBRANE_DASH:
			cooldown *= stat(BioGene.DASH_COOLDOWN)
		_:
			if BioAbilityCatalog.has(def.id):  # a class ability: general stats plus this ability's own perks
				var perks := perk(def.id)
				damage *= stat(BioGene.ABILITY_POWER) * float(perks.get("damage", 1.0))
				cost *= stat(BioGene.ABILITY_COST) * float(perks.get("cost", 1.0))
				cooldown *= stat(BioGene.ABILITY_COOLDOWN) * float(perks.get("cooldown", 1.0))
				reach *= stat(BioGene.ABILITY_RANGE) * float(perks.get("range", 1.0))
	return BioAttackDef.new(def.id, cost, damage, cooldown, reach, def.knockback, def.invulnerable_seconds)


func to_dict() -> Dictionary:
	return {"equipped": equipped.map(func(id: StringName) -> String: return String(id)), "lineage": String(lineage)}


## Unknown or duplicated gene ids (e.g. from an old save) are dropped; extra ones beyond the slots too.
static func from_dict(data: Dictionary) -> BioGenome:
	var genome := BioGenome.new()
	genome.lineage = StringName(str(data.get("lineage", "")))
	var known := BioGeneCatalog.all_ids()
	for raw in data.get("equipped", []):
		var id := StringName(str(raw))
		if known.has(id) and not genome.equipped.has(id) and genome.equipped.size() < SLOTS:
			genome.equipped.append(id)
	return genome
