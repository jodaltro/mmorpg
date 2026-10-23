class_name BioDesign
extends RefCounted
## What the options Jev chooses between mean for the client: which nucleus shape, which glow colour. Pure lookups, so every option the
## engine offers is guaranteed to have a drawing (a test walks the universe's list against these tables).

const NUCLEUS := {
	"feijao": &"mieloide", "rim": &"macrofago", "flor": &"dendritica", "esfera": &"linfocito_b",
	"hexagono": &"t_citotoxico", "trevo": &"t_auxiliar", "lobulos": &"neutrofilo", "estrela": &"estrela",
}
const GLOW := {
	"ambar": Color(1.0, 0.72, 0.25), "jade": Color(0.35, 1.0, 0.6), "magenta": Color(0.95, 0.25, 0.85),
	"ciano": Color(0.3, 0.9, 1.0), "carmim": Color(1.0, 0.2, 0.3), "violeta": Color(0.62, 0.42, 1.0),
}
const MEMBRANES := ["lisa", "ondulada", "espinhosa", "contas", "dupla"]
const ORGANELLES := ["mitocondrias", "lisossomos", "vesiculas", "tubulos", "vacuolos", "granulos"]


## The form the nucleus is drawn in: the designed one, else the class's own.
static func nucleus_form(option: String, fallback: StringName) -> StringName:
	return NUCLEUS.get(option, fallback)


## The glow colour (alpha 0 when none was designed).
static func glow(option: String) -> Color:
	return GLOW.get(option, Color(0, 0, 0, 0))


const LOBES := {"l3": 3, "l4": 4, "l5": 5, "l6": 6, "l7": 7, "l8": 8}
const CUTS := ["liso", "entalhe", "serrilhado"]
const NUCLEOLI := ["nenhum", "brilhante", "anel", "constelacao"]
const DENSITY := {"rala": 0.6, "media": 1.0, "densa": 1.6}
const TRAIL := {"curto": 0.7, "medio": 1.0, "longo": 1.5}
const TEMPO := {"lento": 0.75, "firme": 1.0, "veloz": 1.35}


## Particle multipliers {density, trail, tempo} for the traits Jev designed (1.0 each when none).
static func feel(traits: Dictionary) -> Dictionary:
	return {
		"density": float(DENSITY.get(str(traits.get("densidade", "")), 1.0)),
		"trail": float(TRAIL.get(str(traits.get("rastro", "")), 1.0)),
		"tempo": float(TEMPO.get(str(traits.get("ritmo", "")), 1.0)),
	}
