class_name BioTerrainRules
extends RefCounted
## The work of the terrain: besides carrying (anyone can) each calling has its own way to help a crisis in the tissue itself. A barricade
## is broken by strong strikes, a block is pushed to its groove, debris is swallowed, wounded cells are healed, a hot spot is cooled and a
## hidden sign is marked. What works is the KIND of the ability cast (its gesture) and the engine only pays it to the calling that owns the
## verb (`terreno-<verb>-<crisis>` requires the role tag), so the recommended calling is the one that can do the job. Pure: the director
## places and draws the props.

## verb -> who does it, what it looks like, which gestures work. `kinds` are ability kinds (BioAbilityCatalog).
const VERBS := {
	"romper": {"name": "Romper", "roles": ["combate"], "color": Color(0.9, 0.35, 0.3), "how": "golpes fortes",
		"kinds": ["dash_strike", "phase", "frenzy", "pierce", "leap", "hold", "massacre", "blink", "recall", "prey", "cloak"]},
	"empurrar": {"name": "Empurrar", "roles": ["combate", "controle"], "color": Color(0.75, 0.8, 0.9), "how": "impulso ou puxão",
		"kinds": ["dash_strike", "leap", "phase", "blink", "recall", "roll", "nova", "pull", "tether", "decoy"]},
	"limpar": {"name": "Limpar", "roles": ["limpeza"], "color": Color(0.85, 0.8, 0.35), "how": "engolir e dissolver",
		"kinds": ["devour", "nova", "counter", "stance", "tether", "crystal", "grow", "roll", "zone"]},
	"curar": {"name": "Curar", "roles": ["cura"], "color": Color(0.45, 1.0, 0.65), "how": "pulsos de reparo",
		"kinds": ["allies", "lastchance", "convert", "contagion", "mines", "cascade", "sticky", "overload"]},
	"acalmar": {"name": "Acalmar", "roles": ["controle"], "color": Color(0.55, 0.8, 1.0), "how": "sono, elo ou isca",
		"kinds": ["sleep", "link", "decoy", "pull", "zone"]},
	"marcar": {"name": "Marcar", "roles": ["marcacao"], "color": Color(0.8, 0.6, 1.0), "how": "marcas e feixes",
		"kinds": ["bolt", "complement", "replay", "turret", "beam", "cone", "empower", "portal"]},
}
const ORDER := ["romper", "empurrar", "limpar", "curar", "acalmar", "marcar"]

## The kinds that are aimed (they reach the front of the cell); the others spread around it.
const DIRECTIONAL := ["dash_strike", "pierce", "leap", "hold", "blink", "recall", "bolt", "cone", "beam", "pull", "tether", "sleep", "complement", "crystal", "turret", "sticky", "devour", "decoy", "roll", "prey", "portal"]

## crisis -> verb -> the thing in that organ (the same verb reads differently in each place).
const PROPS := {
	"ferida-na-pele": {"curar": "Células ressecadas", "romper": "Crosta de coágulo", "empurrar": "Tampão de plaquetas", "limpar": "Sujeira da ferida"},
	"congestao-esplenica": {"limpar": "Pilha de hemácias velhas", "marcar": "Hemácia danificada", "acalmar": "Polpa inflamada", "empurrar": "Aglomerado de ferro"},
	"sobrecarga-hepatica": {"limpar": "Bolsa de toxinas", "curar": "Hepatócitos intoxicados"},
	"disbiose-intestinal": {"curar": "Flora enfraquecida", "limpar": "Resíduo fermentado", "romper": "Biofilme de patógenos", "empurrar": "Massa de fibra"},
	"infeccao-pulmonar": {"romper": "Muco espesso", "empurrar": "Tampão de secreção", "limpar": "Restos de bactérias", "marcar": "Foco bacteriano oculto"},
	"medula-esgotada": {"curar": "Células-tronco exaustas", "acalmar": "Nicho em estresse", "empurrar": "Bloco de ferro"},
	"sobrecarga-renal": {"limpar": "Cristais de ureia", "curar": "Células do túbulo", "acalmar": "Filtro congestionado", "empurrar": "Cálculo renal"},
	"reacao-exagerada": {"acalmar": "Folículo em brasa", "empurrar": "Barreira de citocinas", "marcar": "Antígeno escondido"},
	"sofrimento-cerebral": {"curar": "Neurônios apagados", "limpar": "Placas de resíduos", "acalmar": "Sinapse em descarga", "empurrar": "Coágulo capilar"},
	"tumor-intestinal": {"romper": "Casca do tumor", "empurrar": "Fragmento tumoral", "marcar": "Célula alterada oculta", "curar": "Tecido vizinho ferido"},
	"organ-pele": {"curar": "Células ressecadas", "romper": "Crosta endurecida", "empurrar": "Tampão de plaquetas", "limpar": "Sujeira da superfície"},
	"organ-medula": {"curar": "Células-tronco cansadas", "acalmar": "Nicho agitado", "empurrar": "Bloco de ferro"},
	"organ-sangue": {"limpar": "Detritos do plasma", "romper": "Coágulo solto", "empurrar": "Aglomerado de plaquetas", "marcar": "Invasor camuflado"},
	"organ-coracao": {"acalmar": "Ritmo irregular", "empurrar": "Válvula emperrada", "curar": "Fibras cansadas"},
	"organ-pulmao": {"romper": "Muco endurecido", "empurrar": "Tampão de secreção", "limpar": "Poeira nos alvéolos", "marcar": "Foco bacteriano oculto"},
	"organ-aorta": {"limpar": "Placa na parede", "acalmar": "Parede em tensão", "empurrar": "Êmbolo solto", "romper": "Calcificação"},
	"organ-figado": {"limpar": "Bolsa de toxinas", "curar": "Hepatócitos cansados"},
	"organ-baco": {"limpar": "Pilha de hemácias velhas", "marcar": "Hemácia danificada", "acalmar": "Polpa agitada", "empurrar": "Aglomerado de ferro"},
	"organ-intestino": {"curar": "Flora enfraquecida", "limpar": "Resíduo fermentado", "romper": "Biofilme", "empurrar": "Massa de fibra"},
	"organ-rim": {"limpar": "Cristais de ureia", "curar": "Células do túbulo", "acalmar": "Filtro congestionado", "empurrar": "Cálculo renal"},
	"organ-linfonodo": {"acalmar": "Folículo agitado", "empurrar": "Barreira de citocinas", "marcar": "Antígeno escondido"},
	"organ-cerebro": {"curar": "Neurônios cansados", "limpar": "Resíduos entre neurônios", "acalmar": "Sinapse em descarga", "empurrar": "Coágulo capilar"},
}


static func verbs() -> Array:
	return ORDER


static func info(verb: String) -> Dictionary:
	return VERBS.get(verb, {})


## The verbs a crisis has props for, in the order of ORDER.
static func verbs_for(def: String) -> Array:
	var out: Array = []
	var props: Dictionary = PROPS.get(def, {})
	for v in ORDER:
		if props.has(v):
			out.append(v)
	return out


static func prop_name(def: String, verb: String) -> String:
	return str(PROPS.get(def, {}).get(verb, str(info(verb).get("name", verb))))


## The engine action that confirms the work.
static func action(verb: String, def: String) -> String:
	return "terreno-%s-%s" % [verb, def]


## Whether a calling's role can do the verb (the engine checks the same).
static func can(verb: String, role: String) -> bool:
	return role != "" and (info(verb).get("roles", []) as Array).has(role)


## The verbs a role does.
static func verbs_of_role(role: String) -> Array:
	var out: Array = []
	for v in ORDER:
		if can(v, role):
			out.append(v)
	return out


## Which verbs an ability's gesture can do.
static func verbs_of_kind(kind: String) -> Array:
	var out: Array = []
	for v in ORDER:
		if (info(v)["kinds"] as Array).has(kind):
			out.append(v)
	return out


static func role_text(verb: String) -> String:
	var names: Array = []
	for r in info(verb).get("roles", []):
		names.append(BioCallingRules.role_name(str(r)))
	return " ou ".join(names)


## How far the gesture reaches (world units).
static func reach_units(a: Dictionary) -> float:
	var r := 0.0
	for k in ["range", "reach", "radius", "distance"]:
		r = maxf(r, float(a.get(k, 0.0)))
	return clampf(r if r > 0.0 else 3.5, 2.8, 9.0)


## Whether a gesture from `origin` (aimed at `aim`) reaches a thing at `target` (px) of `size_units` radius.
static func reaches(kind: String, a: Dictionary, origin: Vector2, aim: Vector2, target: Vector2, size_units: float) -> bool:
	var d := origin.distance_to(target) / BioArt.UNIT
	if d > reach_units(a) + size_units:
		return false
	if not DIRECTIONAL.has(kind) or d <= 2.0 + size_units:
		return true
	return aim.normalized().dot((target - origin).normalized()) > 0.45


## How much one cast does of what a prop takes (0..1 of its total).
static func power(verb: String, kind: String, a: Dictionary) -> float:
	match verb:
		"romper":
			var dmg := maxf(float(a.get("damage", 12.0)), 10.0)
			return clampf(dmg / 45.0, 0.3, 0.9)
		"marcar":
			return 0.5
		"curar":
			return 0.55
		_:
			return 0.4


## The hint of the crisis card: what the terrain of this crisis asks and from whom; the player's own role first.
static func hint(def: String, role: String) -> String:
	var mine: Array = []
	var others: Array = []
	for v in verbs_for(def):
		var line := "%s (%s)" % [prop_name(def, v), role_text(v)]
		if can(v, role):
			mine.append(line)
		else:
			others.append(line)
	if mine.is_empty() and others.is_empty():
		return ""
	if not mine.is_empty():
		return "No terreno, seu chamado faz: %s." % ", ".join(mine)
	return "No terreno: %s." % ", ".join(others)
