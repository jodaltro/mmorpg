class_name BioCargoRules
extends RefCounted
## Carrying help to a crisis: each crisis has something the player can pick up in its organ and a place in the tissue where it is
## needed (fibrin to the breach of the skin, lactate to a starving neuron). The game server confirms the delivery with the crisis's
## `action`; the engine moves the numbers and credits the carrier. The place is part of the tissue and shows the crisis healing.
## Pure: the world places and draws them.

## crisis def -> what is carried and where it goes. `site_shape` says how the place is drawn (see BioCargoSite).
const CRISES := {
	"ferida-na-pele": {"cargo": "fibrina", "cargo_color": Color(1.0, 0.82, 0.55), "site": "Brecha da pele", "site_shape": &"breach", "action": "entregar-fibrina"},
	"infeccao-pulmonar": {"cargo": "surfactante", "cargo_color": Color(0.7, 0.95, 1.0), "site": "Alvéolo inflamado", "site_shape": &"alveolus", "action": "entregar-surfactante"},
	"medula-esgotada": {"cargo": "ferro", "cargo_color": Color(1.0, 0.55, 0.35), "site": "Nicho de células-tronco", "site_shape": &"niche", "action": "entregar-ferro"},
	"sobrecarga-hepatica": {"cargo": "albumina", "cargo_color": Color(0.95, 0.95, 0.7), "site": "Hepatócito sobrecarregado", "site_shape": &"cell", "action": "entregar-albumina"},
	"congestao-esplenica": {"cargo": "hemácia velha", "cargo_color": Color(0.85, 0.35, 0.45), "site": "Macrófago da polpa", "site_shape": &"cell", "action": "entregar-hemacia-velha"},
	"disbiose-intestinal": {"cargo": "fibra", "cargo_color": Color(0.7, 1.0, 0.5), "site": "Colônia da flora", "site_shape": &"colony", "action": "entregar-fibra"},
	"tumor-intestinal": {"cargo": "perforina", "cargo_color": Color(1.0, 0.45, 0.4), "site": "Massa tumoral", "site_shape": &"mass", "action": "entregar-perforina"},
	"sobrecarga-renal": {"cargo": "cristal de ureia", "cargo_color": Color(0.8, 1.0, 0.95), "site": "Túbulo do néfron", "site_shape": &"tubule", "action": "entregar-cristal"},
	"reacao-exagerada": {"cargo": "sinal calmante", "cargo_color": Color(0.7, 0.8, 1.0), "site": "Folículo agitado", "site_shape": &"colony", "action": "entregar-il10"},
	"sofrimento-cerebral": {"cargo": "lactato", "cargo_color": Color(1.0, 0.85, 0.4), "site": "Neurônio sem energia", "site_shape": &"neuron", "action": "entregar-lactato"},
}
const ITEMS := 3  # how many loads lie around the organ at once
const DELIVER_UNITS := 2.4  # this close to the place, a carried load is delivered
const PICK_UNITS := 1.2  # this close to a load, the cell picks it up
const SOURCE_MIN_UNITS := 10.0  # a load lies at least this far from its place: carrying is a short walk


static func has(def: String) -> bool:
	return CRISES.has(def)


static func of(def: String) -> Dictionary:
	return CRISES.get(def, {})


## The place of a crisis in its organ (px): fixed, the same for everyone.
static func site_px(def: String, region: StringName) -> Vector2:
	return BioBodyMap.niche_px("site:" + def, region)


## Where load `index` lies (px): spread around the organ, never on the place itself.
static func source_px(def: String, region: StringName, index: int, salt: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [def, index, salt])
	var site := site_px(def, region)
	for i in 8:
		var p := BioBodyMap.random_point_near_px(rng, region, site, 22.0, SOURCE_MIN_UNITS)
		if p.distance_to(site) >= SOURCE_MIN_UNITS * BioArt.UNIT:
			return p
	return BioBodyMap.random_point_px(rng, region, site, SOURCE_MIN_UNITS)


## The line for the crisis card: what to carry and where.
static func hint(def: String) -> String:
	var c := of(def)
	if c.is_empty():
		return ""
	return "Ou carregue %s até: %s." % [str(c["cargo"]), str(c["site"])]


## How healed the place looks (0 = as bad as the crisis got, 1 = calm), from the crisis's severity and its peak.
static func healed(conflict: Dictionary) -> float:
	var peak := maxf(1.0, float(conflict.get("peak", 1)))
	var phase := str(conflict.get("phase", ""))
	if phase == "resolved" or phase == "recovering":
		return 1.0
	return clampf(1.0 - float(conflict.get("severity", 0)) / peak, 0.0, 1.0)
