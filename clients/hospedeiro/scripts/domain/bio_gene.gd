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
}

var id: StringName
var display_name: String
var mods: Dictionary


func _init(p_id: StringName, p_display_name: String, p_mods: Dictionary) -> void:
	id = p_id
	display_name = p_display_name
	mods = p_mods


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
	return " · ".join(parts)
