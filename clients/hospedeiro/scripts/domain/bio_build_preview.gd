class_name BioBuildPreview
extends RefCounted
## What a set of genes would do to the body, before it is chosen: the stats of a class with those genes, and the difference
## against what is expressed now. The player sees the result of a swap or a saved build before committing to it.

## The order the stats are listed in (the ones that matter first).
const ORDER := [BioGene.MAX_MEMBRANE, BioGene.MAX_ATP, BioGene.ATP_REGEN, BioGene.SPEED, BioGene.LASH_DAMAGE, BioGene.LASH_RANGE,
	BioGene.SPIT_DAMAGE, BioGene.SPIT_COST, BioGene.DASH_COOLDOWN, BioGene.NUTRIENT_YIELD, BioGene.ABILITY_POWER, BioGene.ABILITY_COOLDOWN,
	BioGene.ABILITY_COST, BioGene.ABILITY_RANGE]
## For these a lower number is the better one.
const LOWER_IS_BETTER := [BioGene.SPIT_COST, BioGene.DASH_COOLDOWN, BioGene.ABILITY_COOLDOWN, BioGene.ABILITY_COST]


static func genome_of(lineage: StringName, genes: Array) -> BioGenome:
	var g := BioGenome.new()
	g.lineage = lineage
	var known := BioGeneCatalog.all_ids()
	for id in genes:
		var gene_id := StringName(str(id))
		if known.has(gene_id) and not g.equipped.has(gene_id):
			g.equipped.append(gene_id)
	return g


## The value of every stat for this class wearing these genes.
static func stats(lineage: StringName, genes: Array) -> Dictionary:
	var g := genome_of(lineage, genes)
	var out := {}
	for key in ORDER:
		out[key] = g.stat(key)
	return out


## "+12%" for a multiplier, "+2 ATP/s" for the additive stat.
static func text_of(key: StringName, value: float) -> String:
	if BioGene.is_additive(key):
		return "%+.1f ATP/s" % value
	return "%+d%%" % int(roundf((value - 1.0) * 100.0))


## The rows of a comparison, only for the stats that are not neutral in either set:
## {label, now, then, delta, better: 1 better / -1 worse / 0 same}.
static func rows(lineage: StringName, current: Array, previewed: Array) -> Array[Dictionary]:
	var a := stats(lineage, current)
	var b := stats(lineage, previewed)
	var out: Array[Dictionary] = []
	for key in ORDER:
		var neutral := 0.0 if BioGene.is_additive(key) else 1.0
		var va: float = a[key]
		var vb: float = b[key]
		if is_equal_approx(va, neutral) and is_equal_approx(vb, neutral):
			continue
		var change := vb - va
		var better := 0
		if absf(change) > 0.0005:
			better = 1 if (change < 0.0) == (key in LOWER_IS_BETTER) else -1
		out.append({"key": key, "label": BioGene.LABELS[key] if BioGene.LABELS.has(key) else "ATP/s", "now": text_of(key, va), "then": text_of(key, vb), "better": better})
	return out


## The passive trade-offs of a class as readable lines.
static func lineage_lines(lineage: StringName) -> Array[String]:
	var out: Array[String] = []
	var mods := BioLineageCatalog.mods_of(lineage)
	for key in ORDER:
		if mods.has(key):
			out.append(text_of(key, float(mods[key])) if BioGene.is_additive(key) else "%s %s" % [text_of(key, float(mods[key])), BioGene.LABELS.get(key, "")])
	return out
