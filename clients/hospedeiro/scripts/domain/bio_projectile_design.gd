class_name BioProjectileDesign
extends RefCounted
## The projectile itself, designed by Jev: how it flies (trajectory), how big and fast it is (calibre) and what it does when it
## arrives (impact). Unlike the flavour of the effects, this changes the shot: where it can hit, how many it can hit, what it leaves
## behind. Each option trades a lower direct blow for its own reach, so a design makes a cell shoot differently without making it
## stronger (`worth` is what the balance test holds to one yardstick). Pure: no nodes.

const TRAJECTORIES := ["reta", "ondulada", "espiral", "arco", "teleguiada"]

## Hit radius (units), speed and range multipliers, and a damage multiplier that pays for being easier or harder to land.
const CALIBRE := {
	"fino": {"radius": 0.12, "speed": 1.25, "range": 1.1, "damage": 1.12},
	"medio": {"radius": 0.2, "speed": 1.0, "range": 1.0, "damage": 1.0},
	"grosso": {"radius": 0.45, "speed": 0.8, "range": 0.9, "damage": 0.9},
}

const IMPACTS := {
	"simples": {"direct": 1.0},
	"perfurante": {"direct": 0.8, "pierce": 3, "falloff": 0.75},  # goes through up to three enemies, a little weaker each time
	"explosivo": {"direct": 0.78, "radius": 2.2, "share": 0.55},  # bursts: everyone near the impact takes a share
	"fragmenta": {"direct": 0.72, "count": 3, "share": 0.3, "range": 3.0},  # bursts into three fragments that fly on
	"grudento": {"direct": 0.8, "dot_share": 0.4, "dot_seconds": 3.0},  # sticks to the target and keeps hurting
}

const TEMPO := {"lento": 0.8, "firme": 1.0, "veloz": 1.3}  # trait "ritmo": the shot flies slower or faster


static func is_designed(traits: Dictionary) -> bool:
	return traits.has("trajetoria") or traits.has("calibre") or traits.has("impacto")


## Everything the bolt needs for these traits. Empty traits give the plain bolt.
static func params(traits: Dictionary) -> Dictionary:
	var c: Dictionary = CALIBRE.get(str(traits.get("calibre", "medio")), CALIBRE["medio"])
	var imp: Dictionary = IMPACTS.get(str(traits.get("impacto", "simples")), IMPACTS["simples"])
	var path := str(traits.get("trajetoria", ""))
	var tempo := float(TEMPO.get(str(traits.get("ritmo", "")), 1.0))
	return {
		"path": path if TRAJECTORIES.has(path) else "",
		"radius_units": float(c["radius"]),
		"speed": float(c["speed"]) * tempo,
		"range": float(c["range"]),
		"damage": float(c["damage"]) * float(imp["direct"]),
		"impact": str(traits.get("impacto", "simples")) if IMPACTS.has(str(traits.get("impacto", "simples"))) else "simples",
		"pierce": int(imp.get("pierce", 0)),
		"falloff": float(imp.get("falloff", 1.0)),
		"aoe_radius": float(imp.get("radius", 0.0)),
		"aoe_share": float(imp.get("share", 0.0)) if imp.has("radius") else 0.0,
		"frag_count": int(imp.get("count", 0)),
		"frag_share": float(imp.get("share", 0.0)) if imp.has("count") else 0.0,
		"frag_range": float(imp.get("range", 0.0)),
		"dot_share": float(imp.get("dot_share", 0.0)),
		"dot_seconds": float(imp.get("dot_seconds", 0.0)),
	}


## What the extras of an impact are worth, as a share of the damage dealt on the first target (the balance yardstick): how much of
## a blow comes back through the others it reaches, the fragments that find someone, or the damage over time.
static func extra_worth(impact: String, dealt: float) -> float:
	match impact:
		"perfurante":
			return dealt * 0.75 * 0.6  # on average a bit over half of a second target
		"explosivo":
			return dealt * 0.55 * 0.8
		"fragmenta":
			return dealt * 0.3 * 3.0 * 0.45  # of three fragments, a bit under half find someone
		"grudento":
			return dealt * 0.4
		_:
			return 0.0


static func describe(traits: Dictionary) -> String:
	if not is_designed(traits):
		return "projétil normal"
	var p := params(traits)
	return "trajetória %s · calibre %s (raio %.2f u) · impacto %s · dano x%.2f · velocidade x%.2f" % [
		str(traits.get("trajetoria", "reta")), str(traits.get("calibre", "medio")), p["radius_units"], p["impact"], p["damage"], p["speed"]]
