class_name BioAbilityFocus
extends RefCounted
## The same risk and reward as the projectile, for every other family of abilities (cones, thrusts, novas, dashes, zones, devouring):
## Jev designs the cell's FOCUS. A wide focus reaches more and is easy to land but hits softly and short; a precise one is narrow, long
## and hits hard. Easy to land pays less, hard to land pays more, so no focus is strictly better. The geometry changes the ability itself
## (its width, radius and reach) and the damage multiplier applies to every hit it lands. Pure: no nodes.

const FOCUS := {
	"amplo": {"damage": 0.8, "width": 1.45, "range": 0.85, "odds": 0.85},
	"medio": {"damage": 1.0, "width": 1.0, "range": 1.0, "odds": 0.7},
	"preciso": {"damage": 1.3, "width": 0.65, "range": 1.2, "odds": 0.55},
}

const KINDS := ["devour", "nova", "cone", "pierce", "dash_strike", "zone"]  # families with a shape and a reach; projectiles have their own design
const WIDTH_KEYS := ["half", "width", "radius", "spread"]
const RANGE_KEYS := ["range", "reach", "distance"]


static func params(traits: Dictionary) -> Dictionary:
	var f: Dictionary = FOCUS.get(str(traits.get("foco", "")), {})
	return f.duplicate()


## True when a hit of this ability is subject to the focus (every non-projectile ability).
static func applies_to(ability_id: StringName) -> bool:
	if not BioAbilityCatalog.has(ability_id):
		return false
	return str(BioAbilityCatalog.get_ability(ability_id)["kind"]) in KINDS


## The ability's parameters with the cell's focus applied (a copy: the catalog is untouched).
static func apply(a: Dictionary, focus: Dictionary) -> Dictionary:
	if focus.is_empty() or not str(a.get("kind", "")) in KINDS:
		return a
	var out := a.duplicate()
	for k in WIDTH_KEYS:
		if out.has(k):
			out[k] = float(out[k]) * float(focus["width"])
	for k in RANGE_KEYS:
		if out.has(k):
			out[k] = float(out[k]) * float(focus["range"])
	return out


static func describe(traits: Dictionary) -> String:
	var f := params(traits)
	if f.is_empty():
		return "normal"
	return "%s · dano x%.2f · largura x%.2f · alcance x%.2f" % [str(traits["foco"]), f["damage"], f["width"], f["range"]]
