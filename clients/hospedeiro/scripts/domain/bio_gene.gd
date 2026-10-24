class_name BioGene
extends RefCounted
## A mutation. Every gene trades something: `mods` holds stat multipliers (1.0 = neutral), except
## ATP_REGEN which is additive (ATP per second).

const SPEED := &"speed"
const MAX_MEMBRANE := &"max_membrane"
const MAX_ATP := &"max_atp"
const ATP_REGEN := &"atp_regen"
const LASH_DAMAGE := &"lash_damage"
const LASH_RANGE := &"lash_range"
const SPIT_DAMAGE := &"spit_damage"
const SPIT_COST := &"spit_cost"
const DASH_COOLDOWN := &"dash_cooldown"
const NUTRIENT_YIELD := &"nutrient_yield"
## Class abilities: every mutation can push all of them (power, cooldown, cost, reach) or one in particular (perks).
const ABILITY_POWER := &"ability_power"
const ABILITY_COOLDOWN := &"ability_cooldown"
const ABILITY_COST := &"ability_cost"
const ABILITY_RANGE := &"ability_range"

const LABELS := {
	SPEED: "velocidade",
	MAX_MEMBRANE: "membrana máx.",
	MAX_ATP: "ATP máx.",
	LASH_DAMAGE: "dano do chicote",
	LASH_RANGE: "alcance do chicote",
	SPIT_DAMAGE: "dano da toxina",
	SPIT_COST: "custo da toxina",
	DASH_COOLDOWN: "recarga do impulso",
	NUTRIENT_YIELD: "ganho de nutrientes",
	ABILITY_POWER: "poder das habilidades",
	ABILITY_COOLDOWN: "recarga das habilidades",
	ABILITY_COST: "custo das habilidades",
	ABILITY_RANGE: "alcance das habilidades",
}

var id: StringName
var display_name: String
var mods: Dictionary
var requires_lineage: StringName = &""  # class mutation: only offered to that lineage
## What it does to one class ability: {ability id: {param: multiplier, "+param": addition}} (see BioGenome.tune).
var perks: Dictionary = {}
## How it shows on the body: {kind, color, count...} drawn by BioOrganelles. Empty: drawn by hand elsewhere.
var mark: Dictionary = {}


func _init(p_id: StringName, p_display_name: String, p_mods: Dictionary, p_requires_lineage: StringName = &"", p_perks: Dictionary = {}, p_mark: Dictionary = {}) -> void:
	id = p_id
	display_name = p_display_name
	mods = p_mods
	requires_lineage = p_requires_lineage
	perks = p_perks
	mark = p_mark


static func is_additive(stat: StringName) -> bool:
	return stat == ATP_REGEN


## Human readable trade-off, e.g. "+25% dano do chicote · -8% velocidade".
func summary() -> String:
	var parts: Array[String] = []
	for stat in mods:
		var value: float = mods[stat]
		if is_additive(stat):
			parts.append("%+d ATP/s" % int(roundf(value)))
		else:
			parts.append("%+d%% %s" % [int(roundf((value - 1.0) * 100.0)), LABELS[stat]])
	for ability in perks:
		parts.append("%s: %s" % [BioAbilityCatalog.get_ability(ability).get("name", ability), _perk_bits(perks[ability])])
	return " · ".join(parts)


const PARAM_LABELS := {"damage": "dano", "radius": "raio", "reach": "alcance", "range": "alcance", "duration": "duração", "tick": "dano contínuo",
	"slow": "lentidão", "mult": "amplificação", "seconds": "duração", "heal": "cura", "amount": "cura", "count": "unidades", "speed": "velocidade",
	"distance": "distância", "cooldown": "recarga", "cost": "custo", "burst": "explosão", "regen_atp": "ATP/s", "regen_membrane": "reparo",
	"execute_below": "limiar", "execute_mult": "bônus de execução", "below": "limiar", "half": "abertura", "width": "largura", "taken": "dano recebido",
	"knockback": "empurrão", "spread": "abertura", "pct": "fração da vida", "cap": "teto", "drift": "perseguição", "max": "unidades máx.", "every": "intervalo", "arm": "armação", "life": "vida útil", "fuse": "pavio", "stack": "bônus por pilha", "per_hp": "dano por vida gasta", "bleed": "sangria", "max_time": "tempo máx.", "floor": "piso", "leash": "laço", "pull": "atração", "snap": "ruptura", "bank": "acúmulo", "stacks": "pilhas", "dmg_per": "dano por pilha", "size_per": "crescimento", "heal_per": "cura por morte", "steer": "controle", "backstab": "golpe nas costas", "behind": "distância atrás", "iframes": "invulnerabilidade", "refund": "devolução", "atp": "ATP por golpe", "strike": "emboscada", "delay": "demora", "restore": "recuperação", "wake": "dano ao acordar", "share": "partilha", "hp": "vida do isco", "lure": "alcance do isco", "core": "núcleo"}


static func _perk_bits(params: Dictionary) -> String:
	var bits: Array[String] = []
	for key in params:
		var k := str(key)
		if k.begins_with("+"):
			bits.append("+%d %s" % [int(params[key]), PARAM_LABELS.get(k.substr(1), k)])
		else:
			bits.append("%+d%% %s" % [int(roundf((float(params[key]) - 1.0) * 100.0)), PARAM_LABELS.get(k, k)])
	return ", ".join(bits)
