class_name BioAbilityMode
extends RefCounted
## How each family of abilities BEHAVES, designed by Jev per cell (traits "modo_cone", "modo_nova", "modo_estocada", "modo_investida",
## "modo_zona", "modo_devorar"). The mode changes what the ability does, not only its size: a cone can close on its victims or whip
## twice, a nova can pulse or throw enemies out, a thrust can harpoon, a dash can strike again, a zone can wander after enemies, a
## devouring can suck prey in. Each mode trades some direct damage for its own gain, so nothing is strictly better (`worth` is what the
## balance test holds to one yardstick). Pure: no nodes.
##
## Fields: direct (multiplier on the blow), repeat [delay, share of the base damage, count], pull (impulse towards the caster),
## knock (impulse away), drift (zone speed in units/s), radius (multiplier), extra (worth of what the mode buys, for the test).

const FAMILIES := {
	"cone": ["padrao", "fecha", "chicoteia"],
	"nova": ["padrao", "pulsos", "repele"],
	"pierce": ["padrao", "arpao"],
	"dash_strike": ["padrao", "dupla"],
	"zone": ["padrao", "migra"],
	"devour": ["padrao", "suga"],
}

## The trait that designs the mode of each family.
const TRAIT_OF := {"cone": "modo_cone", "nova": "modo_nova", "pierce": "modo_estocada", "dash_strike": "modo_investida", "zone": "modo_zona", "devour": "modo_devorar"}

const MODES := {
	"padrao": {"direct": 1.0},
	"fecha": {"direct": 0.9, "pull": 9.0, "extra": 0.1},  # the cone closes on its victims and drags them to the caster
	"chicoteia": {"direct": 0.7, "repeat": [0.35, 0.5, 1]},  # the whips come back: a second lash after a beat
	"pulsos": {"direct": 0.48, "repeat": [0.3, 0.32, 2]},  # the nova beats three times instead of once
	"repele": {"direct": 0.9, "knock": 14.0, "extra": 0.1},  # the nova throws everything away from the caster
	"arpao": {"direct": 0.9, "pull": 14.0, "extra": 0.1},  # the thrust harpoons and reels the victim in
	"dupla": {"direct": 0.65, "repeat": [0.4, 0.55, 1]},  # the dash strikes again at the end
	"migra": {"direct": 0.85, "drift": 1.3, "radius": 0.9, "extra": 0.25},  # the zone wanders towards the nearest enemy
	"suga": {"direct": 0.9, "pull": 10.0, "extra": 0.1},  # the devouring sucks prey in
}

const REPEAT_ODDS := 0.85  # the share of repeated blows that still find the victim


## The family of an ability id ("" for anything that has no modes: the lash, projectiles, marks, heals, auras...).
static func family_of(ability_id: StringName) -> String:
	if not BioAbilityCatalog.has(ability_id):
		return ""
	var kind := str(BioAbilityCatalog.get_ability(ability_id)["kind"])
	return kind if FAMILIES.has(kind) else ""


## The designed mode of each family for these traits: {family: mode}.
static func from_traits(traits: Dictionary) -> Dictionary:
	var out := {}
	for family in TRAIT_OF:
		var m := str(traits.get(TRAIT_OF[family], ""))
		if m != "" and (FAMILIES[family] as Array).has(m):
			out[family] = m
	return out


static func mode(family: String, modes: Dictionary) -> Dictionary:
	return MODES.get(str(modes.get(family, "padrao")), MODES["padrao"])


static func direct(family: String, modes: Dictionary) -> float:
	return float(mode(family, modes).get("direct", 1.0))


## What the mode is worth as a share of the plain blow (the balance yardstick).
static func worth(mode_id: String) -> float:
	var m: Dictionary = MODES[mode_id]
	var total := float(m.get("direct", 1.0))
	if m.has("repeat"):
		var r: Array = m["repeat"]
		total += float(r[1]) * int(r[2]) * REPEAT_ODDS
	return total + float(m.get("extra", 0.0))


## The ability's parameters with the family's mode applied (geometry and zone drift); a copy.
static func apply(a: Dictionary, family: String, modes: Dictionary) -> Dictionary:
	var m := mode(family, modes)
	if not m.has("radius") and not m.has("drift"):
		return a
	var out := a.duplicate()
	if m.has("radius"):
		for k in ["radius", "half", "width"]:
			if out.has(k):
				out[k] = float(out[k]) * float(m["radius"])
	if m.has("drift"):
		out["drift"] = float(m["drift"])
	return out


static func describe(modes: Dictionary) -> String:
	if modes.is_empty():
		return "todas no modo padrão"
	var parts: Array[String] = []
	for family in modes:
		parts.append("%s=%s" % [family, modes[family]])
	return ", ".join(parts)
