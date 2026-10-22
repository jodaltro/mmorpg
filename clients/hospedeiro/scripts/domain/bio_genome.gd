class_name BioGenome
extends RefCounted
## The genes a cell currently expresses. There are no levels: power comes only from the chosen
## mutations, and every slot is a trade-off.

const SLOTS := 3

var equipped: Array[StringName] = []


func has_gene(id: StringName) -> bool:
	return equipped.has(id)


## Combined value of a stat: product of multipliers, or the sum for additive stats.
func stat(key: StringName) -> float:
	var additive := BioGene.is_additive(key)
	var total := 0.0 if additive else 1.0
	for id in equipped:
		var mods: Dictionary = BioGeneCatalog.get_gene(id).mods
		if not mods.has(key):
			continue
		if additive:
			total += mods[key]
		else:
			total *= mods[key]
	return total


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
	return BioAttackDef.new(def.id, cost, damage, cooldown, reach, def.knockback, def.invulnerable_seconds)


func to_dict() -> Dictionary:
	return {"equipped": equipped.map(func(id: StringName) -> String: return String(id))}


## Unknown or duplicated gene ids (e.g. from an old save) are dropped; extra ones beyond the slots too.
static func from_dict(data: Dictionary) -> BioGenome:
	var genome := BioGenome.new()
	var known := BioGeneCatalog.all_ids()
	for raw in data.get("equipped", []):
		var id := StringName(str(raw))
		if known.has(id) and not genome.equipped.has(id) and genome.equipped.size() < SLOTS:
			genome.equipped.append(id)
	return genome
