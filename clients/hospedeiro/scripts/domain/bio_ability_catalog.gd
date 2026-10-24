class_name BioAbilityCatalog
extends RefCounted
## The 24 class abilities (4 per class). The engine decides who knows what (starter, quest, discovery,
## awakening by the advisor); this catalogue says what each one does in play. Values are authoritative here:
## damage, cost and cooldown reach the domain actor through attack_def(), like every other attack.
## Ids use underscores (the engine uses hyphens). Distances are world units.
##
## kind: devour, nova, cone, pierce, bolt, volley, dash_strike, mark, mark_all, execute, zone, heal, aura, summon; and, done by the
## kits of the four newer classes (BioKit): mines, sticky, cascade, overload, tether, crystal, grow, roll, blink, prey, cloak, recall, sleep, link, decoy, pull.

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
	var snow := Color(0.85, 0.95, 1.0)
	var violet := Color(0.65, 0.45, 1.0)
	var antibody := Color(1.0, 0.7, 0.95)
	var blood := Color(1.0, 0.2, 0.3)
	var gold := Color(1.0, 0.82, 0.35)
	# --- Macrófago, o Devorador: engole e, quando é atingido, faz o golpe custar caro; muda de forma entre lutar (M1) e curar (M2). ---
	_a(&"engolir", &"macrofago", "devour", rose, 14, 3.0, {"damage": 22.0, "range": 2.3, "half": 60.0, "heal": 0.7})
	_a(&"onda_de_pseudopodes", &"macrofago", "nova", rose, 22, 7.0, {"damage": 18.0, "radius": 3.3, "knockback": 11.0})
	_a(&"contragolpe", &"macrofago", "counter", Color(1.0, 0.6, 0.45), 18, 12.0, {"seconds": 2.2, "taken": 0.35, "reflect": 0.9, "heal": 0.35})
	_a(&"polarizacao", &"macrofago", "stance", Color(1.0, 0.45, 0.5), 10, 6.0, {"seconds": 25.0, "power": 1.0})
	# --- Neutrófilo, o Armadilheiro: o primeiro a chegar. Atravessa corpos e, no auge, queima a si mesmo para correr o dobro. ---
	_a(&"rede_de_dna", &"neutrofilo", "zone", snow, 14, 6.0, {"style": "net", "reach": 4.0, "radius": 2.4, "duration": 3.5, "tick": 2.0, "slow": 0.35})
	_a(&"explosao_neutrofilica", &"neutrofilo", "dash_strike", snow, 18, 5.0, {"damage": 20.0, "distance": 5.0, "iframes": 0.3})
	_a(&"diapedese", &"neutrofilo", "phase", Color(0.8, 1.0, 1.0), 16, 9.0, {"damage": 10.0, "seconds": 2.2, "speed": 1.4, "taken": 0.5})
	_a(&"surto_oxidativo", &"neutrofilo", "frenzy", Color(1.0, 0.8, 0.3), 18, 16.0, {"seconds": 6.0, "rate": 2.0, "burn": 5.0, "speed": 1.12})
	# --- Célula dendrítica, a Cartógrafa: lê a sala. Um feixe que varre, uma maturação que reforça as próximas habilidades, duas portas no tecido. ---
	_a(&"varredura", &"dendritica", "beam", Color(0.5, 0.95, 1.0), 16, 8.0, {"damage": 7.0, "seconds": 2.6, "range": 7.5, "width": 0.45, "turn": 2.2, "every": 0.2})
	_a(&"dendritos_em_chicote", &"dendritica", "cone", violet, 16, 4.0, {"damage": 20.0, "range": 3.3, "half": 50.0})
	_a(&"maturacao", &"dendritica", "empower", Color(0.85, 0.7, 1.0), 14, 14.0, {"charges": 3, "mult": 1.5, "seconds": 10.0})
	_a(&"passagem_linfatica", &"dendritica", "portal", Color(0.8, 0.6, 1.0), 14, 12.0, {"reach": 6.0, "seconds": 10.0})
	# --- Linfócito B, o Anticorpomante: marca com complemento, repete o que fez, vira uma fábrica de anticorpos. ---
	_a(&"anticorpo_y", &"linfocito_b", "bolt", antibody, 10, 1.2, {"damage": 14.0, "range": 10.0, "speed": 11.0, "homing": true})
	_a(&"complemento", &"linfocito_b", "complement", Color(0.9, 0.65, 1.0), 12, 7.0, {"hits": 3, "pct": 0.22, "damage": 6.0, "cap": 70.0, "seconds": 8.0, "range": 7.0})
	_a(&"memoria_imunologica", &"linfocito_b", "replay", Color(1.0, 0.85, 1.0), 10, 18.0, {"echo": 0.85})
	_a(&"fabrica_de_plasmocito", &"linfocito_b", "turret", antibody, 26, 18.0, {"damage": 9.0, "seconds": 5.0, "every": 0.28, "range": 8.0, "taken": 0.7, "speed": 12.0})
	# --- Linfócito T citotóxico, o Executor: salta sobre a multidão, segura um inimigo até o fim, sentencia os quase mortos. ---
	_a(&"perforina", &"t_citotoxico", "pierce", blood, 10, 2.2, {"damage": 18.0, "range": 3.4, "width": 0.9, "execute_below": 0.4, "execute_mult": 2.0})
	_a(&"salto_letal", &"t_citotoxico", "leap", blood, 18, 8.0, {"damage": 26.0, "radius": 2.6, "distance": 6.0, "knockback": 9.0, "air": 0.45})
	_a(&"sinapse_letal", &"t_citotoxico", "hold", Color(1.0, 0.25, 0.3), 22, 11.0, {"damage": 3.0, "step": 1.4, "seconds": 2.0, "range": 4.5, "finish_below": 0.3, "leash": 6.0})
	_a(&"lise_em_massa", &"t_citotoxico", "massacre", Color(1.0, 0.3, 0.4), 28, 20.0, {"damage": 10.0, "radius": 12.0, "base": 0.22, "per_kill": 0.07, "window": 10.0})
	# --- Linfócito T auxiliar, o Maestro: uma febre que pega, auxiliares que lutam, uma segunda chance, a troca do que sobra pelo que falta. ---
	_a(&"febre_contagiosa", &"t_auxiliar", "contagion", Color(1.0, 0.55, 0.25), 14, 8.0, {"damage": 4.0, "seconds": 5.0, "spread": 1.2, "hop": 5.0, "hops": 3, "range": 7.0})
	_a(&"chamado_aos_auxiliares", &"t_auxiliar", "allies", gold, 24, 18.0, {"count": 2, "hp": 45.0, "damage": 9.0, "seconds": 10.0})
	_a(&"segunda_chance", &"t_auxiliar", "lastchance", gold, 20, 30.0, {"seconds": 12.0, "restore": 0.4})
	_a(&"transfusao", &"t_auxiliar", "convert", Color(1.0, 0.7, 0.5), 8, 10.0, {"give": 0.35, "rate": 1.2})
	# --- Mastócito, o Alarmista: o bombardeiro. Deixa granulos pelo caminho, cola bombas, encadeia mortes e sangra numa explosão. ---
	var amber := Color(1.0, 0.62, 0.2)
	_a(&"granulos_latentes", &"mastocito", "mines", amber, 14, 7.0, {"damage": 15.0, "radius": 1.6, "duration": 4.5, "every": 0.5, "max": 7, "arm": 0.5, "life": 12.0})
	_a(&"histamina_instavel", &"mastocito", "sticky", Color(1.0, 0.5, 0.3), 14, 4.0, {"damage": 30.0, "radius": 2.2, "fuse": 2.2, "stack": 0.6, "range": 7.0, "speed": 12.0})
	_a(&"cascata_de_degranulacao", &"mastocito", "cascade", Color(1.0, 0.75, 0.35), 24, 14.0, {"damage": 22.0, "radius": 2.6, "duration": 8.0})
	_a(&"anafilaxia", &"mastocito", "overload", Color(1.0, 0.4, 0.25), 18, 16.0, {"damage": 12.0, "per_hp": 1.9, "radius": 5.5, "bleed": 0.14, "max_time": 2.4, "floor": 0.12})
	# --- Eosinófilo, o Caça-Colossos: prende-se aos grandes, congela monstros em cristal, cresce com cada morte e rola pela sala. ---
	var coral := Color(1.0, 0.32, 0.32)
	_a(&"adesao", &"eosinofilo", "tether", coral, 14, 8.0, {"damage": 3.0, "pct": 0.07, "cap": 26.0, "duration": 4.0, "range": 7.0, "leash": 2.4, "pull": 5.5, "snap": 11.0})
	_a(&"cristal_de_charcot", &"eosinofilo", "crystal", Color(1.0, 0.45, 0.4), 20, 12.0, {"damage": 10.0, "seconds": 2.8, "bank": 1.3, "radius": 2.8, "range": 6.5})
	_a(&"hipertrofia", &"eosinofilo", "grow", Color(1.0, 0.55, 0.4), 22, 18.0, {"seconds": 14.0, "stacks": 5, "dmg_per": 0.10, "size_per": 0.09, "heal_per": 0.05})
	_a(&"rolagem", &"eosinofilo", "roll", Color(1.0, 0.25, 0.3), 24, 14.0, {"damage": 16.0, "seconds": 3.0, "speed": 11.0, "steer": 1.6, "taken": 0.55})
	# --- Célula NK, o Assassino Natural: aparece atrás da presa, caça um alvo por vez, some da vista e volta no tempo. ---
	var steel := Color(0.6, 0.82, 1.0)
	_a(&"passo_sem_identidade", &"celula_nk", "blink", steel, 14, 5.0, {"damage": 20.0, "backstab": 1.7, "range": 7.5, "behind": 1.4, "iframes": 0.35, "distance": 5.0})
	_a(&"predar", &"celula_nk", "prey", Color(0.7, 0.9, 1.0), 14, 12.0, {"range": 8.0, "seconds": 8.0, "refund": 1.2, "atp": 3.0, "speed": 1.18})
	_a(&"camuflagem_de_mhc", &"celula_nk", "cloak", Color(0.7, 0.7, 1.0), 20, 14.0, {"seconds": 4.5, "strike": 2.8, "speed": 1.15})
	_a(&"ancora_de_vigilancia", &"celula_nk", "recall", Color(0.6, 0.9, 1.0), 22, 16.0, {"delay": 3.2, "damage": 26.0, "width": 1.0, "restore": 0.9, "iframes": 0.4})
	# --- Linfócito T regulador, o Pacificador: faz dormir, une inimigos pela dor, lança um isco e puxa a sala para um ponto. ---
	var teal := Color(0.5, 1.0, 0.8)
	_a(&"anergia", &"t_regulador", "sleep", teal, 14, 7.0, {"range": 7.0, "seconds": 3.5, "wake": 1.6, "count": 1})
	_a(&"sinapse_imunologica", &"t_regulador", "link", Color(0.6, 1.0, 0.9), 18, 10.0, {"range": 7.0, "count": 3, "share": 0.5, "seconds": 6.0})
	_a(&"autoantigeno", &"t_regulador", "decoy", Color(0.55, 0.95, 0.85), 22, 14.0, {"reach": 4.0, "hp": 80.0, "seconds": 7.0, "lure": 9.0})
	_a(&"singularidade_de_tolerancia", &"t_regulador", "pull", Color(0.5, 1.0, 0.8), 26, 16.0, {"damage": 20.0, "reach": 4.5, "radius": 5.5, "seconds": 2.2, "pull": 8.0, "core": 2.0})
	_apply_balance()


## The tuned numbers live in data/balance.json (written by tests/balance_tune.gd from BioBalance); they replace the defaults above.
static func _apply_balance() -> void:
	var path := "res://data/balance.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has("abilities"):
		return
	for id in data["abilities"]:
		var key := StringName(str(id))
		if _defs.has(key):
			for param in data["abilities"][id]:
				_defs[key][str(param)] = data["abilities"][id][param]


static func _a(id: StringName, lineage: StringName, kind: String, color: Color, cost: float, cooldown: float, extra: Dictionary) -> void:
	var d := {"class": lineage, "kind": kind, "color": color, "cost": cost, "cooldown": cooldown, "name": _names().get(id, String(id))}
	d.merge(extra)
	_defs[id] = d


static func _names() -> Dictionary:
	return {
		&"engolir": "Engolir", &"onda_de_pseudopodes": "Onda de Pseudópodes", &"contragolpe": "Contragolpe", &"polarizacao": "Polarização M1/M2",
		&"rede_de_dna": "Rede de DNA", &"explosao_neutrofilica": "Explosão Neutrofílica", &"diapedese": "Diapedese", &"surto_oxidativo": "Surto Oxidativo",
		&"varredura": "Varredura", &"dendritos_em_chicote": "Dendritos em Chicote", &"maturacao": "Maturação", &"passagem_linfatica": "Passagem Linfática",
		&"anticorpo_y": "Anticorpo Y", &"complemento": "Complemento", &"memoria_imunologica": "Memória Imunológica", &"fabrica_de_plasmocito": "Fábrica de Plasmócito",
		&"perforina": "Perforina", &"salto_letal": "Salto Letal", &"sinapse_letal": "Sinapse Letal", &"lise_em_massa": "Lise em Massa",
		&"febre_contagiosa": "Febre Contagiosa", &"chamado_aos_auxiliares": "Chamado aos Auxiliares", &"segunda_chance": "Segunda Chance", &"transfusao": "Transfusão",
		&"granulos_latentes": "Grânulos Latentes", &"histamina_instavel": "Histamina Instável", &"cascata_de_degranulacao": "Cascata de Degranulação", &"anafilaxia": "Anafilaxia",
		&"adesao": "Adesão", &"cristal_de_charcot": "Cristal de Charcot-Leyden", &"hipertrofia": "Hipertrofia", &"rolagem": "Rolagem",
		&"passo_sem_identidade": "Passo Sem Identidade", &"predar": "Predar", &"camuflagem_de_mhc": "Camuflagem de MHC", &"ancora_de_vigilancia": "Âncora de Vigilância",
		&"anergia": "Anergia", &"sinapse_imunologica": "Sinapse Imunológica", &"autoantigeno": "Autoantígeno", &"singularidade_de_tolerancia": "Singularidade de Tolerância",
	}
