class_name BioBalance
extends RefCounted
## One yardstick for every ability and every mutation, so that balance is a measurement and not a feeling. Pure rules, no Unity-style
## guesswork hidden in the runtime: the assumptions are the constants below and are the same ones the tests guard.
##
## An ability's VALUE is what one cast is expected to be worth in "points of damage or health" for a typical fight (a few enemies
## near each other, the cell standing roughly where it casts). Its PRICE is what it costs: the ATP plus the time its cooldown takes
## out of the cell's turn. WORTH = value / price. The basic lash defines the floor; class abilities should sit above it by about
## the same margin, so no ability is a trap and none is a must-pick. A mutation's SCORE is the sum of what it gives minus what it
## takes, in the same points, and each rarity has its own target.

const TARGETS := 2.2  # enemies usually near each other when an area ability lands
const BASE_DPS := 31.0  # the basic lash: 14 damage every 0.45 s
const ENEMY_DPS := 14.0  # what a typical fight deals to the cell, per second
const COOLDOWN_PRICE := 1.2  # ATP-equivalent of one second of cooldown (time the slot is not usable)
const TARGET_WORTH := 2.05  # what a class ability is tuned to be worth
const WORTH_TOLERANCE := 0.18  # +/- around it
## Corrections from the empirical duel (tests/balance_duel.gd): the model undervalues contact classes that fight in the middle of
## the pack and overvalues passive zones and summons that hit while the cell does something else, so each class has its own target.
const CLASS_ADJUST := {&"macrofago": 1.3, &"neutrofilo": 1.15, &"dendritica": 1.05, &"linfocito_b": 0.9, &"t_citotoxico": 1.0, &"t_auxiliar": 0.72,
	&"mastocito": 1.0, &"eosinofilo": 1.1, &"celula_nk": 1.0, &"t_regulador": 0.8}
const TYPICAL_HP := 90.0  # the life of a typical enemy, for the abilities that take a share of it
const TYPICAL_MEMBRANE := 100.0  # the cell's own, for the abilities that spend it


static func target_worth(lineage: StringName) -> float:
	return TARGET_WORTH * float(CLASS_ADJUST.get(lineage, 1.0))




## Expected value of one cast, from the ability's parameters (the same dictionary the runner reads).
static func ability_value(id: StringName, a: Dictionary) -> float:
	var kind: String = a["kind"]
	var dmg := float(a.get("damage", 0.0))
	var duration := float(a.get("duration", 0.0))
	match kind:
		"devour":
			return dmg * 2.0 * (1.0 + float(a["heal"]) * 0.8)
		"cone":
			return dmg * 2.0
		"mines":
			return dmg * minf(float(a["max"]), duration / float(a["every"])) * 0.32 * (1.0 + (TARGETS - 1.0) * 0.5)
		"sticky":
			return dmg * (1.0 + (TARGETS - 1.0) * 0.7) * (1.0 + float(a["stack"]) * 0.5)
		"cascade":
			return dmg * (duration / 3.0) * (TARGETS - 0.2) * 0.55
		"overload":
			var spent := float(a["bleed"]) * float(a["max_time"]) * TYPICAL_MEMBRANE
			return (dmg + float(a["per_hp"]) * spent) * TARGETS * 0.75 - spent * 0.6
		"tether":
			return duration / 0.5 * (dmg + minf(float(a["pct"]) * TYPICAL_HP, float(a["cap"])) * 0.5) * 0.8
		"crystal":
			var frozen := float(a["seconds"])
			return (dmg + BASE_DPS * frozen * 0.3 * float(a["bank"])) * (1.0 + (TARGETS - 1.0) * 0.6) * 0.8 + frozen * 5.0
		"grow":
			var kills := float(a["seconds"]) / 3.5
			var stacks := minf(float(a["stacks"]), kills) * 0.6
			return BASE_DPS * float(a["dmg_per"]) * stacks * float(a["seconds"]) * 0.5 + float(a["heal_per"]) * TYPICAL_MEMBRANE * kills
		"roll":
			return dmg * (float(a["seconds"]) / 0.45) * 0.5 * (1.0 + (TARGETS - 1.0) * 0.25) + (1.0 - float(a["taken"])) * ENEMY_DPS * float(a["seconds"]) * 0.8
		"blink":
			return dmg * float(a["backstab"]) * 1.1 + float(a["iframes"]) * 10.0 + 14.0
		"prey":
			var hits := float(a["seconds"]) / 1.2 * 0.6
			return hits * (float(a["refund"]) * COOLDOWN_PRICE + float(a["atp"])) + 20.0 + (float(a["speed"]) - 1.0) * 60.0 * float(a["seconds"]) * 0.15
		"cloak":
			return (float(a["strike"]) - 1.0) * BASE_DPS * 0.9 + float(a["seconds"]) * 5.0 + (float(a["speed"]) - 1.0) * 60.0 * float(a["seconds"]) * 0.15
		"recall":
			return dmg * 1.5 + float(a["restore"]) * 25.0 + float(a["iframes"]) * 10.0 + 8.0
		"sleep":
			return float(a["count"]) * float(a["seconds"]) * ENEMY_DPS * 0.4 + (float(a["wake"]) - 1.0) * BASE_DPS * 1.2
		"link":
			return (float(a["count"]) - 1.0) * float(a["share"]) * BASE_DPS * float(a["seconds"]) * 0.3
		"decoy":
			return minf(float(a["hp"]), ENEMY_DPS * TARGETS * float(a["seconds"]) * 0.5) * 0.55 + float(a["seconds"]) * 3.0
		"pull":
			return dmg * TARGETS * 1.2 + TARGETS * float(a["seconds"]) * ENEMY_DPS * 0.15 + float(a["radius"]) * 3.0
		"pierce":
			return dmg * 1.8 + 0.25 * dmg * (float(a["execute_mult"]) - 1.0) + float(a["execute_below"]) * 6.0
		"nova":
			return dmg * TARGETS + float(a.get("knockback", 0.0)) * 0.6
		"bolt":
			return dmg * (0.9 if bool(a.get("homing", false)) else 0.75)
		"dash_strike":
			return dmg * 1.4 + float(a["distance"]) * 1.2 + float(a.get("iframes", 0.0)) * 10.0
		"counter":
			var raw := ENEMY_DPS * float(a["seconds"]) * TARGETS * 0.5
			return raw * (1.0 - float(a["taken"]) + float(a["reflect"]) + float(a["heal"])) + 10.0
		"stance":
			return 40.0 * float(a["power"])
		"phase":
			return dmg * float(a["seconds"]) / 0.5 * 0.25 + (1.0 - float(a["taken"])) * ENEMY_DPS * float(a["seconds"]) * 0.8 + (float(a["speed"]) - 1.0) * 60.0 * float(a["seconds"]) * 0.15 + 14.0
		"frenzy":
			return (float(a["rate"]) - 1.0) * BASE_DPS * float(a["seconds"]) * 0.5 + (float(a["speed"]) - 1.0) * 60.0 * float(a["seconds"]) * 0.15 - float(a["burn"]) * float(a["seconds"]) * 0.6
		"beam":
			return dmg * (float(a["seconds"]) / float(a["every"])) * 0.55 * (1.0 + (TARGETS - 1.0) * 0.4)
		"empower":
			return (float(a["mult"]) - 1.0) * BASE_DPS * float(a["charges"]) * 2.0 * 0.6 + float(a["charges"]) * 6.0
		"portal":
			return 40.0 + float(a["seconds"]) * 1.5
		"complement":
			return (dmg + minf(float(a["pct"]) * TYPICAL_HP, float(a["cap"]))) * 1.4
		"replay":
			return 70.0 * float(a["echo"])
		"turret":
			return dmg * (float(a["seconds"]) / float(a["every"])) * 0.5 + (1.0 - float(a["taken"])) * ENEMY_DPS * float(a["seconds"]) * 0.8
		"leap":
			return dmg * TARGETS + float(a["knockback"]) * 0.6 + 12.0
		"hold":
			var beats := float(a["seconds"]) / 0.25
			return beats * dmg + float(a["step"]) * beats * (beats + 1.0) / 2.0 + float(a["seconds"]) * ENEMY_DPS * 0.8
		"massacre":
			return dmg * TARGETS + (float(a["base"]) + float(a["per_kill"]) * 2.0) * TYPICAL_HP * TARGETS * 1.2
		"contagion":
			return dmg * (float(a["seconds"]) / 0.5) * (1.0 + minf(float(a["hops"]), TARGETS) * 0.7)
		"allies":
			return float(a["count"]) * dmg * (float(a["seconds"]) / 0.8) * 0.45 + float(a["hp"]) * float(a["count"]) * 0.3
		"lastchance":
			return float(a["restore"]) * TYPICAL_MEMBRANE * 1.5 + float(a["seconds"]) * 0.5
		"convert":
			return float(a["give"]) * float(a["rate"]) * TYPICAL_MEMBRANE * 1.5 - float(a["give"]) * TYPICAL_MEMBRANE * 0.4
		"zone":
			var style := str(a.get("style", ""))
			var slow_value := float(a.get("slow", 0.0)) * duration * 8.0
			return (float(a.get("tick", 0.0)) * (duration / 0.5) * TARGETS * 0.65 + slow_value) * (1.2 if float(a.get("drift", 0.0)) > 0.0 else 1.0)
	return 0.0


static func ability_price(a: Dictionary) -> float:
	return float(a["cost"]) + COOLDOWN_PRICE * float(a["cooldown"])


static func worth(id: StringName, a: Dictionary) -> float:
	return ability_value(id, a) / ability_price(a)


## The parameters of an ability as a given genome performs them, including the damage, cost and cooldown the domain actor sees.
static func performed(id: StringName, genome: BioGenome) -> Dictionary:
	var base := BioAbilityCatalog.get_ability(id)
	var tuned := genome.tune(id, base)
	var def := genome.modify(BioAbilityCatalog.attack_def(id))
	tuned["damage"] = def.damage
	tuned["cost"] = def.atp_cost
	tuned["cooldown"] = def.cooldown
	return tuned


## Points of the benefit of one percent of a stat (negative stats cost the same).
const STAT_WEIGHT := {&"max_membrane": 0.55, &"max_atp": 0.3, &"speed": 0.7, &"lash_damage": 0.5, &"lash_range": 0.25, &"spit_damage": 0.25,
	&"nutrient_yield": 0.08, &"ability_power": 0.9, &"ability_range": 0.3}
## Stats where lower is better (a drop is the benefit).
const LOWER_IS_BETTER := {&"spit_cost": 0.15, &"dash_cooldown": 0.25, &"ability_cooldown": 0.7, &"ability_cost": 0.5}
const REGEN_POINTS_PER_ATP := 4.0  # +1 ATP/s of regeneration
const PERK_POINTS_PER_PERCENT := 0.3  # one percent more worth of one ability (of its class's four)


## Net points of a mutation: what its stats and its perks give, minus what they take.
static func gene_score(id: StringName) -> float:
	var gene := BioGeneCatalog.get_gene(id)
	var score := 0.0
	for stat in gene.mods:
		var v: float = gene.mods[stat]
		if stat == &"atp_regen":
			score += v * REGEN_POINTS_PER_ATP
		elif LOWER_IS_BETTER.has(stat):
			score += (1.0 - v) * 100.0 * float(LOWER_IS_BETTER[stat])
		else:
			score += (v - 1.0) * 100.0 * float(STAT_WEIGHT.get(stat, 0.0))
	score += perk_points(gene)
	return score


## Points the perks give: how much more each reshaped ability is worth, once the mutation is worn.
static func perk_points(gene: BioGene) -> float:
	var total := 0.0
	for ability in gene.perks:
		var before := BioAbilityCatalog.get_ability(ability)
		var genome := BioGenome.new()
		genome.equipped = [gene.id] as Array[StringName]
		genome.override_genes[gene.id] = gene
		var after := performed(ability, genome)
		var gain := worth(ability, after) / worth(ability, before) - 1.0
		total += gain * 100.0 * PERK_POINTS_PER_PERCENT
	return total


## Net-score targets by rarity (the ones the tests hold the whole table to, within a tolerance).
const RARITY_TARGET := {"comum": 5.0, "incomum": 8.0, "rara": 12.0, "epica": 17.0}
const RARITY_TOLERANCE := 0.3


# ---------------------------------------------------------------------------------------------------------------------
# The tuner: solves for the numbers that put every ability at TARGET_WORTH and every mutation at its rarity's target.
# ---------------------------------------------------------------------------------------------------------------------

## The parameters that carry an ability's strength, by kind (and zone style); value grows with each of them.
static func primary_keys(a: Dictionary) -> Array:
	match str(a["kind"]):
		"devour":
			return ["damage", "heal"]
		"cone", "nova", "pierce", "bolt", "dash_strike", "mines", "sticky", "cascade", "roll", "blink", "recall", "pull":
			return ["damage"]
		"overload":
			return ["damage", "per_hp"]
		"tether":
			return ["damage", "pct"]
		"crystal":
			return ["damage", "bank"]
		"grow":
			return ["dmg_per", "heal_per"]
		"prey":
			return ["refund", "atp"]
		"cloak":
			return ["strike"]
		"sleep":
			return ["wake"]
		"link":
			return ["share"]
		"decoy":
			return ["hp"]
		"counter":
			return ["reflect", "heal"]
		"stance":
			return ["power"]
		"phase", "leap", "turret", "beam", "contagion", "allies":
			return ["damage"]
		"frenzy":
			return ["rate"]
		"empower":
			return ["mult"]
		"portal":
			return ["seconds"]
		"complement":
			return ["damage", "pct"]
		"replay":
			return ["echo"]
		"hold":
			return ["damage", "step"]
		"massacre":
			return ["damage", "base"]
		"lastchance":
			return ["restore"]
		"convert":
			return ["give", "rate"]
		"zone":
			match str(a.get("style", "")):
				_:
					return ["tick"]
	return []


## Scales the primary parameters by f (strength: mult and speed scale their excess over 1, taken scales what it lets through).
static func scaled(a: Dictionary, f: float) -> Dictionary:
	var out := a.duplicate()
	var keys := primary_keys(a)
	var each := sqrt(f) if keys.size() > 1 else f
	for k in keys:
		var v := float(a[k])
		match k:
			"mult", "speed", "strike", "wake", "rate":
				out[k] = 1.0 + (v - 1.0) * each
			"restore", "echo":
				out[k] = clampf(v * each, 0.05, 0.95 if k == &"restore" else 1.6)
			"taken":
				out[k] = clampf(1.0 - (1.0 - v) * each, 0.2, 0.9)  # a shield always lets a fifth through
			"duration":
				out[k] = minf(v * each, 8.0)
			_:
				out[k] = v * each
	return out


## The tuned parameters of one ability: price first if the change needed is extreme, then the strength by bisection.
static func tune_ability(id: StringName) -> Dictionary:
	var base := BioAbilityCatalog.get_ability(id).duplicate()
	var a := base.duplicate()
	for _attempt in 3:
		var lo := 0.2
		var hi := 4.0
		for _i in 40:
			var mid := (lo + hi) * 0.5
			if worth(id, scaled(a, mid)) < target_worth(StringName(str(a["class"]))):
				lo = mid
			else:
				hi = mid
		var f := (lo + hi) * 0.5
		if f > 1.9 and _attempt < 2:  # needs far more strength: make it cheaper to use first
			a["cooldown"] = float(a["cooldown"]) * 0.78
			a["cost"] = float(a["cost"]) * 0.9
		elif f < 0.5 and _attempt < 2:
			a["cooldown"] = float(a["cooldown"]) * 1.2
			a["cost"] = float(a["cost"]) * 1.1
		else:
			a = scaled(a, f)
			break
	var changed := {}
	for key in a:
		if typeof(a[key]) == TYPE_FLOAT or typeof(a[key]) == TYPE_INT:
			var v := float(a[key])
			var rounded := snappedf(v, 0.5) if key in ["damage", "tick", "burst", "amount", "regen_atp", "regen_membrane", "cost"] else snappedf(v, 0.01 if key in ["mult", "speed", "taken", "heal"] else 0.5 if key == "cooldown" else 0.01)
			if not is_equal_approx(rounded, float(base.get(key, rounded))):
				changed[key] = rounded
	return changed


## Rarity of every mutation (the generator writes it into the catalog).
static func target_for(rarity: String) -> float:
	return float(RARITY_TARGET.get(rarity, 8.0))


## A copy of a mutation with its benefits scaled by k and its costs by c (counts like "+count" stay whole numbers as designed).
static func gene_scaled(gene: BioGene, k: float, c: float = 1.0) -> BioGene:
	var mods := {}
	for stat in gene.mods:
		var v: float = gene.mods[stat]
		var helps: bool = (v > 0.0) if stat == &"atp_regen" else ((v < 1.0) if LOWER_IS_BETTER.has(stat) else (v > 1.0))
		if stat == &"atp_regen":
			mods[stat] = v * (k if helps else c)
		elif helps:
			mods[stat] = 1.0 + (v - 1.0) * k
		else:
			mods[stat] = 1.0 + (v - 1.0) * c
	var perks := {}
	for ability in gene.perks:
		perks[ability] = {}
		for key in gene.perks[ability]:
			var v: float = float(gene.perks[ability][key])
			if str(key).begins_with("+"):
				perks[ability][key] = v
			elif str(key) in ["cooldown", "cost", "taken"]:
				perks[ability][key] = 1.0 - (1.0 - v) * k  # lower is better
			else:
				perks[ability][key] = 1.0 + (v - 1.0) * k
	return BioGene.new(gene.id, gene.display_name, mods, gene.requires_lineage, perks, gene.mark)


static func score_of(gene: BioGene) -> float:
	var score := 0.0
	for stat in gene.mods:
		var v: float = gene.mods[stat]
		if stat == &"atp_regen":
			score += v * REGEN_POINTS_PER_ATP
		elif LOWER_IS_BETTER.has(stat):
			score += (1.0 - v) * 100.0 * float(LOWER_IS_BETTER[stat])
		else:
			score += (v - 1.0) * 100.0 * float(STAT_WEIGHT.get(stat, 0.0))
	return score + perk_points(gene)


## The tuned stats and perks of a mutation that bring its net score to the target of its rarity. The benefits are scaled first;
## when even the largest sensible benefit cannot reach the target (or the smallest overshoots it), the costs are scaled instead.
static func tune_gene(id: StringName, rarity: String) -> Dictionary:
	var gene := BioGeneCatalog.get_gene(id)
	var target := target_for(rarity)
	var k := 1.0
	var c := 1.0
	if score_of(gene_scaled(gene, 3.0, 1.0)) < target:
		k = 3.0
		var lo := 0.0
		var hi := 1.0
		for _i in 40:
			var mid := (lo + hi) * 0.5
			if score_of(gene_scaled(gene, k, mid)) > target:
				lo = mid
			else:
				hi = mid
		c = (lo + hi) * 0.5
	elif score_of(gene_scaled(gene, 0.05, 1.0)) > target:
		k = 0.05
		var lo := 1.0
		var hi := 5.0
		for _i in 40:
			var mid := (lo + hi) * 0.5
			if score_of(gene_scaled(gene, k, mid)) > target:
				lo = mid
			else:
				hi = mid
		c = (lo + hi) * 0.5
	else:
		var lo := 0.05
		var hi := 3.0
		for _i in 40:
			var mid := (lo + hi) * 0.5
			if score_of(gene_scaled(gene, mid, 1.0)) < target:
				lo = mid
			else:
				hi = mid
		k = (lo + hi) * 0.5
	var tuned := gene_scaled(gene, k, c)
	var mods := {}
	for stat in tuned.mods:
		var v: float = tuned.mods[stat]
		mods[String(stat)] = snappedf(v, 0.5) if stat == &"atp_regen" else snappedf(v, 0.01)
	var perks := {}
	for ability in tuned.perks:
		perks[String(ability)] = {}
		for key in tuned.perks[ability]:
			var v: float = float(tuned.perks[ability][key])
			perks[String(ability)][str(key)] = roundf(v) if str(key).begins_with("+") else snappedf(v, 0.01)
	return {"mods": mods, "perks": perks}
