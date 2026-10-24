class_name BioLimbStyle
extends RefCounted
## What the body grows when it reaches out: a pure function of the form (class), the procedural look the engine
## decided from how the player lives (axes 0-100) and the expressed genes. Nothing here is hand-drawn per player:
## the same function gives a blunt pseudopod to a newborn ball, a rigid barbed lance to a ferocious killer cell and a
## branching net of fine dendrites to a sociable cartographer.
##
## Keys: tip (blob, cup, spear, fork, bulb, y), length (x reach), base, tip_w (px), barbs, bumps, branches,
## wave (how much it undulates), stiffness (0 limp .. 1 rigid), speed (grow speed multiplier), motes (sheds light),
## half_angle (degrees: how wide the basic lash reaches), count (limbs of the basic lash), sweep (degrees swept).


static func for_body(form: StringName, look: Dictionary, genes: Array) -> Dictionary:
	var s := _base(form)
	var f := float(look.get("ferocidade", 0.0)) / 100.0
	var a := float(look.get("agilidade", 0.0)) / 100.0
	var r := float(look.get("robustez", 0.0)) / 100.0
	var m := float(look.get("metabolismo", 0.0)) / 100.0
	var so := float(look.get("sociabilidade", 0.0)) / 100.0
	var q := float(look.get("misterio", 0.0)) / 100.0
	s["barbs"] += roundi(f * 5.0)
	s["tip_w"] *= 1.0 - 0.35 * f
	s["base"] *= 1.0 + 0.2 * f
	s["length"] *= 1.0 + 0.45 * a
	s["base"] *= 1.0 - 0.25 * a
	s["speed"] *= 1.0 + 0.6 * a
	s["wave"] *= 1.0 + 0.5 * a
	s["base"] *= 1.0 + 0.5 * r
	s["tip_w"] *= 1.0 + 0.3 * r
	s["stiffness"] = clampf(s["stiffness"] + 0.2 * r, 0.0, 1.0)
	s["bumps"] += roundi(m * 4.0)
	s["branches"] += roundi(so * 3.0)
	s["count"] += roundi(so * 2.0)
	s["motes"] = s["motes"] or q > 0.35
	if genes.has(&"pseudopodes_gigantes"):
		s["length"] *= 1.25
		s["base"] *= 1.25
	if genes.has(&"agulha_litica"):
		s["length"] *= 1.35
		s["tip_w"] *= 0.7
	if genes.has(&"dendritos_ramificados"):
		s["branches"] += 2
		s["count"] += 1
	if genes.has(&"anticorpos_em_y"):
		s["tip"] = &"y"
		s["length"] *= 1.1
	if genes.has(&"flagelo_calejado"):
		s["barbs"] += 1
		s["stiffness"] = clampf(s["stiffness"] + 0.15, 0.0, 1.0)
	if genes.has(&"vesicula_toxica"):
		s["bumps"] += 2
	s["count"] = clampi(s["count"], 1, 7)
	return s


static func _base(form: StringName) -> Dictionary:
	var s := {"tip": &"blob", "length": 1.0, "base": 15.0, "tip_w": 13.0, "barbs": 0, "bumps": 0, "branches": 0, "wave": 0.25,
		"stiffness": 0.5, "speed": 1.0, "motes": false, "half_angle": 60.0, "count": 1, "sweep": 0.0}
	match form:
		&"mieloide":  # lobes that jab, alternating sides
			s.merge({"base": 17.0, "bumps": 2, "half_angle": 62.0, "sweep": 20.0}, true)
		&"linfoide":
			s.merge({"tip": &"fork", "base": 8.0, "tip_w": 4.0, "branches": 1, "wave": 0.4, "stiffness": 0.35, "half_angle": 45.0}, true)
		&"macrofago":  # one huge scooping arm that sweeps like a hand
			s.merge({"tip": &"cup", "length": 1.05, "base": 27.0, "tip_w": 30.0, "bumps": 3, "wave": 0.15, "stiffness": 0.4, "half_angle": 80.0, "sweep": 70.0, "speed": 0.9}, true)
		&"neutrofilo":  # a whip: thin, limp, quick
			s.merge({"base": 11.0, "tip_w": 6.0, "wave": 0.7, "stiffness": 0.12, "speed": 1.3, "half_angle": 70.0, "sweep": 60.0}, true)
		&"dendritica":  # a fan of fine branching dendrites
			s.merge({"tip": &"fork", "base": 8.0, "tip_w": 4.0, "branches": 2, "wave": 0.55, "stiffness": 0.2, "half_angle": 70.0, "count": 3, "sweep": 30.0}, true)
		&"linfocito_b":  # a long filament that ends in an antibody
			s.merge({"tip": &"y", "length": 1.1, "base": 6.0, "tip_w": 6.0, "wave": 0.2, "stiffness": 0.65, "half_angle": 28.0}, true)
		&"t_citotoxico":  # a rigid lance
			s.merge({"tip": &"spear", "length": 1.15, "base": 12.0, "tip_w": 2.0, "barbs": 2, "wave": 0.03, "stiffness": 0.97, "speed": 1.5, "half_angle": 24.0}, true)
		&"t_auxiliar":  # a soft glowing tendril
			s.merge({"tip": &"bulb", "base": 10.0, "tip_w": 13.0, "wave": 0.6, "stiffness": 0.3, "motes": true, "half_angle": 55.0, "sweep": 40.0}, true)
		&"mastocito":  # short blunt stubs, packed with granules
			s.merge({"tip": &"bulb", "length": 0.85, "base": 14.0, "tip_w": 17.0, "bumps": 3, "wave": 0.35, "stiffness": 0.3, "half_angle": 70.0, "count": 3, "sweep": 30.0}, true)
		&"eosinofilo":  # one thick cup of an arm that melts what it holds
			s.merge({"tip": &"cup", "length": 0.95, "base": 22.0, "tip_w": 24.0, "bumps": 2, "wave": 0.15, "stiffness": 0.5, "half_angle": 65.0, "sweep": 55.0, "speed": 0.9}, true)
		&"celula_nk":  # a thin, quick, rigid needle
			s.merge({"tip": &"spear", "length": 1.2, "base": 7.0, "tip_w": 3.0, "barbs": 1, "wave": 0.12, "stiffness": 0.8, "speed": 1.6, "half_angle": 35.0}, true)
		&"t_regulador":  # a soft, slow tendril that calms what it touches
			s.merge({"tip": &"bulb", "base": 9.0, "tip_w": 11.0, "wave": 0.5, "stiffness": 0.22, "motes": true, "half_angle": 50.0, "count": 2, "sweep": 30.0}, true)
	return s
