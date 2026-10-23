class_name BioDungeonPlan
extends RefCounted
## What is in each room of a dungeon, as a pure function of the seed the engine gave the run, the kind of the room (the engine
## rooms say guard, wall, core or boss) and the modifier the advisor chose. Same seed, same dungeon for everyone. The numbers
## of combat (hp, damage) belong to the game server; the engine never sees them.


## Enemy kinds of the granuloma: hp, speed (units/s), size (units), colours, spikes and how they lunge.
static func enemy(kind: StringName) -> Dictionary:
	match kind:
		&"linfocito":  # a fast, fragile patrol
			return {"name": "Linfócito de guarda", "hp": 18.0, "speed": 3.6, "damage": 0.5, "size": 0.42, "core": Color(0.8, 0.95, 1.0), "edge": Color(0.35, 0.7, 1.0), "spikes": 0, "aggro": 9.0, "lunge": 3.0, "telegraph": 0.65, "recover": 1.3}
		&"macrofago_guarda":  # slow, big and hard to move
			return {"name": "Macrófago da parede", "hp": 85.0, "speed": 1.7, "damage": 0.7, "size": 0.95, "core": Color(1.0, 0.5, 0.65), "edge": Color(0.85, 0.2, 0.4), "spikes": 0, "aggro": 9.0, "lunge": 3.6, "telegraph": 0.9, "recover": 1.4}
		&"celula_gigante":  # fused giant cell with pseudopod spikes
			return {"name": "Célula gigante", "hp": 130.0, "speed": 1.4, "damage": 0.85, "size": 1.25, "core": Color(0.8, 0.6, 1.0), "edge": Color(0.55, 0.25, 0.9), "spikes": 7, "aggro": 9.0, "lunge": 4.0, "telegraph": 1.0, "recover": 1.5}
		&"bacilo":  # small rod bacteria in quorum
			return {"name": "Bacilo em quórum", "hp": 28.0, "speed": 3.0, "damage": 0.55, "size": 0.38, "core": Color(0.8, 1.0, 0.4), "edge": Color(0.45, 0.8, 0.15), "spikes": 5, "aggro": 12.0, "lunge": 3.0, "telegraph": 0.55, "recover": 0.9}
		&"emissor":  # a quorum emitter: still, it makes the others faster while it lives
			return {"name": "Emissor de quórum", "hp": 55.0, "speed": 0.0, "size": 0.55, "core": Color(0.95, 1.0, 0.5), "edge": Color(0.6, 0.9, 0.2), "spikes": 10, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0}
		&"bacilo_mestre":  # the boss: the bacillus the granuloma held for years
			return {"name": "O Bacilo", "hp": 300.0, "speed": 2.0, "damage": 0.9, "size": 1.7, "core": Color(0.75, 1.0, 0.3), "edge": Color(0.35, 0.65, 0.1), "spikes": 11, "aggro": 20.0, "lunge": 5.0, "telegraph": 0.8, "recover": 1.1}
	return {}


## The effect of a modifier on the run: enemy speed, a drain on the player, ATP regeneration, how often the core spawns a
## new bacillus (0 = never), whether quorum emitters speed up the enemies, and the head count of the first and later rooms.
static func rules(modifier: String) -> Dictionary:
	var r := {"speed_mult": 1.0, "drain": 0.0, "regen_mult": 1.0, "respawn_every": 0.0, "quorum": false, "front_mult": 1.0, "back_mult": 1.0}
	match modifier:
		"em-febre":
			r.merge({"speed_mult": 1.15, "drain": 0.4}, true)
		"necrose-viva":
			r.merge({"respawn_every": 7.0}, true)
		"guarda-redobrada":
			r.merge({"front_mult": 2.0, "back_mult": 0.6}, true)
		"ar-rarefeito":
			r.merge({"regen_mult": 0.45}, true)
		"quorum-ativo":
			r.merge({"quorum": true}, true)
	return r


## The room: chamber radius (units) and its enemies as {type, angle, radius (0..1 of the chamber)}.
static func room(seed_value: int, index: int, kind: String, modifier: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 7919
	var rule := rules(modifier)
	var count_mult: float = rule["front_mult"] if index < 2 else rule["back_mult"]
	var mix: Array = []  # [type, count]
	var radius := 8.0
	match kind:
		"guard":
			mix = [[&"linfocito", 3]]
			radius = 9.0
		"wall":
			mix = [[&"macrofago_guarda", 2], [&"linfocito", 2]] if index < 2 else [[&"celula_gigante", 2], [&"macrofago_guarda", 2]]
			radius = 8.0
		"core":
			mix = [[&"bacilo", 5 + (3 if modifier == "necrose-viva" else 0)], [&"emissor", 2]]
			radius = 7.5
		"boss":
			mix = [[&"bacilo_mestre", 1], [&"emissor", 2]]
			radius = 9.5
	var enemies: Array[Dictionary] = []
	for entry in mix:
		var n := int(entry[1])
		var fixed: bool = entry[0] == &"bacilo_mestre" or entry[0] == &"emissor"
		if not fixed:
			n = maxi(1, roundi(n * count_mult))
		for i in n:
			enemies.append({"type": entry[0], "angle": rng.randf() * TAU, "radius": 0.0 if entry[0] == &"bacilo_mestre" else rng.randf_range(0.35, 0.85)})
	return {"radius": radius, "enemies": enemies, "kind": kind}
