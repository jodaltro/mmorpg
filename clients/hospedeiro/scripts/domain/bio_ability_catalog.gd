class_name BioAbilityCatalog
extends RefCounted
## The 24 class abilities (4 per class). The engine decides who knows what (starter, quest, discovery,
## awakening by the advisor); this catalogue says what each one does in play. Values are authoritative here:
## damage, cost and cooldown reach the domain actor through attack_def(), like every other attack.
## Ids use underscores (the engine uses hyphens). Distances are world units.
##
## kind: devour, nova, cone, pierce, bolt, volley, dash_strike, mark, mark_all, execute, zone, heal, aura, summon.

static var _defs: Dictionary = {}


static func normalise(engine_id: String) -> StringName:
	return StringName(engine_id.replace("-", "_"))


static func has(id: StringName) -> bool:
	_ensure()
	return _defs.has(id)


static func get_ability(id: StringName) -> Dictionary:
	_ensure()
	return _defs.get(id, {})


static func ids_of_class(lineage: StringName) -> Array:
	_ensure()
	return _defs.keys().filter(func(id: StringName) -> bool: return _defs[id]["class"] == lineage)


## The domain definition (cost, damage, cooldown, reach) of an ability, so actors validate it like any attack.
static func attack_def(id: StringName) -> BioAttackDef:
	_ensure()
	var a: Dictionary = _defs[id]
	return BioAttackDef.new(id, float(a["cost"]), float(a.get("damage", 0.0)), float(a["cooldown"]), float(a.get("range", a.get("radius", 3.0))), float(a.get("knockback", 0.0)), float(a.get("iframes", 0.0)))


static func _ensure() -> void:
	if not _defs.is_empty():
		return
	var rose := Color(1.0, 0.38, 0.55)
	var acid := Color(0.65, 1.0, 0.2)
	var snow := Color(0.85, 0.95, 1.0)
	var violet := Color(0.65, 0.45, 1.0)
	var antibody := Color(1.0, 0.7, 0.95)
	var blood := Color(1.0, 0.2, 0.3)
	var gold := Color(1.0, 0.82, 0.35)
	# --- Macrófago, o Devorador -------------------------------------------------------------
	_a(&"engolir", &"macrofago", "devour", rose, 14, 3.0, {"damage": 22.0, "range": 2.3, "half": 60.0, "heal": 0.7})
	_a(&"onda_de_pseudopodes", &"macrofago", "nova", rose, 22, 7.0, {"damage": 18.0, "radius": 3.3, "knockback": 11.0})
	_a(&"lisossomo_acido", &"macrofago", "zone", acid, 20, 8.0, {"style": "acid", "reach": 5.0, "radius": 2.0, "duration": 5.0, "tick": 5.0, "slow": 0.0})
	_a(&"muralha_de_carne", &"macrofago", "aura", rose, 25, 14.0, {"style": "shield", "duration": 4.0, "taken": 0.3})
	# --- Neutrófilo, o Armadilheiro ---------------------------------------------------------
	_a(&"rede_de_dna", &"neutrofilo", "zone", snow, 14, 6.0, {"style": "net", "reach": 4.0, "radius": 2.4, "duration": 3.5, "tick": 2.0, "slow": 0.35})
	_a(&"explosao_neutrofilica", &"neutrofilo", "dash_strike", snow, 18, 5.0, {"damage": 20.0, "distance": 5.0, "iframes": 0.3})
	_a(&"netose", &"neutrofilo", "zone", Color(0.8, 1.0, 1.0), 20, 9.0, {"style": "trap", "reach": 2.2, "radius": 2.6, "duration": 3.5, "delay": 1.2, "burst": 34.0})
	_a(&"degranulacao", &"neutrofilo", "zone", Color(0.8, 1.0, 0.4), 22, 10.0, {"style": "poison", "reach": 0.0, "radius": 2.8, "duration": 3.5, "tick": 7.0, "slow": 0.0})
	# --- Célula dendrítica, a Cartógrafa ----------------------------------------------------
	_a(&"apresentar_antigeno", &"dendritica", "mark", violet, 12, 5.0, {"range": 7.0, "mult": 1.4, "seconds": 6.0})
	_a(&"dendritos_em_chicote", &"dendritica", "cone", violet, 16, 4.0, {"damage": 20.0, "range": 3.3, "half": 50.0})
	_a(&"chuva_de_esporos", &"dendritica", "zone", Color(0.85, 0.7, 1.0), 18, 12.0, {"style": "spores", "reach": 0.0, "radius": 3.0, "duration": 5.0, "regen_atp": 7.0, "regen_membrane": 2.5})
	_a(&"mapa_quimico", &"dendritica", "mark_all", Color(0.5, 0.95, 1.0), 24, 15.0, {"radius": 9.0, "mult": 1.25, "seconds": 6.0})
	# --- Linfócito B, o Anticorpomante ------------------------------------------------------
	_a(&"anticorpo_y", &"linfocito_b", "bolt", antibody, 10, 1.2, {"damage": 14.0, "range": 10.0, "speed": 11.0, "homing": true})
	_a(&"salva_de_anticorpos", &"linfocito_b", "volley", antibody, 22, 6.0, {"damage": 9.0, "range": 8.0, "speed": 12.0, "count": 5, "spread": 50.0})
	_a(&"opsonizacao", &"linfocito_b", "mark", antibody, 16, 8.0, {"range": 7.0, "mult": 1.3, "seconds": 5.0, "slow": 0.5})
	_a(&"explosao_de_plasmocito", &"linfocito_b", "nova", antibody, 32, 14.0, {"damage": 30.0, "radius": 4.5, "knockback": 12.0, "charge": 0.45})
	# --- Linfócito T citotóxico, o Executor -------------------------------------------------
	_a(&"perforina", &"t_citotoxico", "pierce", blood, 10, 2.2, {"damage": 18.0, "range": 3.4, "width": 0.9, "execute_below": 0.4, "execute_mult": 2.0})
	_a(&"golpe_litico", &"t_citotoxico", "dash_strike", blood, 20, 6.0, {"damage": 28.0, "distance": 5.5, "iframes": 0.3})
	_a(&"apoptose", &"t_citotoxico", "execute", blood, 22, 10.0, {"damage": 8.0, "range": 6.0, "below": 0.35})
	_a(&"sinal_de_morte", &"t_citotoxico", "mark", blood, 20, 12.0, {"range": 8.0, "mult": 1.8, "seconds": 6.0})
	# --- Linfócito T auxiliar, o Maestro das Citocinas --------------------------------------
	_a(&"citocina_curativa", &"t_auxiliar", "heal", gold, 16, 9.0, {"amount": 36.0, "seconds": 4.0})
	_a(&"canto_de_citocinas", &"t_auxiliar", "aura", gold, 18, 12.0, {"style": "song", "duration": 6.0, "speed": 1.25, "regen_atp": 6.0})
	_a(&"chamado_a_linfa", &"t_auxiliar", "summon", gold, 26, 16.0, {"count": 3, "duration": 8.0, "tick": 6.0})
	_a(&"febre_dirigida", &"t_auxiliar", "zone", Color(1.0, 0.55, 0.25), 24, 12.0, {"style": "heat", "reach": 4.5, "radius": 2.8, "duration": 5.0, "tick": 9.0, "slow": 0.6})


static func _a(id: StringName, lineage: StringName, kind: String, color: Color, cost: float, cooldown: float, extra: Dictionary) -> void:
	var d := {"class": lineage, "kind": kind, "color": color, "cost": cost, "cooldown": cooldown, "name": _names().get(id, String(id))}
	d.merge(extra)
	_defs[id] = d


static func _names() -> Dictionary:
	return {
		&"engolir": "Engolir", &"onda_de_pseudopodes": "Onda de Pseudópodes", &"lisossomo_acido": "Lisossomo Ácido", &"muralha_de_carne": "Muralha de Carne",
		&"rede_de_dna": "Rede de DNA", &"explosao_neutrofilica": "Explosão Neutrofílica", &"netose": "NETose", &"degranulacao": "Degranulação",
		&"apresentar_antigeno": "Apresentar Antígeno", &"dendritos_em_chicote": "Dendritos em Chicote", &"chuva_de_esporos": "Chuva de Esporos", &"mapa_quimico": "Mapa Químico",
		&"anticorpo_y": "Anticorpo Y", &"salva_de_anticorpos": "Salva de Anticorpos", &"opsonizacao": "Opsonização", &"explosao_de_plasmocito": "Explosão de Plasmócito",
		&"perforina": "Perforina", &"golpe_litico": "Golpe Lítico", &"apoptose": "Apoptose", &"sinal_de_morte": "Sinal de Morte",
		&"citocina_curativa": "Citocina Curativa", &"canto_de_citocinas": "Canto de Citocinas", &"chamado_a_linfa": "Chamado à Linfa", &"febre_dirigida": "Febre Dirigida",
	}
