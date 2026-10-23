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
		# The liver's cords: a chronic lesion of the liver.
		&"celula_estrelada":  # stellate cell: small, quick, spiky; it makes the scar
			return {"name": "Célula estrelada", "hp": 22.0, "speed": 3.4, "damage": 0.5, "size": 0.42, "core": Color(1.0, 0.85, 0.4), "edge": Color(0.9, 0.55, 0.15), "spikes": 6, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.6, "recover": 1.2}
		&"hepatocito_doente":  # swollen hepatocyte: slow and sturdy
			return {"name": "Hepatócito doente", "hp": 95.0, "speed": 1.5, "damage": 0.7, "size": 1.0, "core": Color(0.75, 0.5, 0.25), "edge": Color(0.5, 0.3, 0.1), "spikes": 0, "aggro": 9.0, "lunge": 3.4, "telegraph": 0.9, "recover": 1.4}
		&"gota_de_gordura":  # lipid droplet: a big pale tank that barely moves
			return {"name": "Gota de gordura", "hp": 125.0, "speed": 1.2, "damage": 0.6, "size": 1.2, "core": Color(1.0, 0.95, 0.6), "edge": Color(0.95, 0.8, 0.3), "spikes": 0, "aggro": 8.0, "lunge": 3.8, "telegraph": 1.0, "recover": 1.6}
		&"foco_toxico":  # a toxic focus: still, it speeds the others up while it lives
			return {"name": "Foco tóxico", "hp": 55.0, "speed": 0.0, "size": 0.55, "core": Color(0.75, 1.0, 0.3), "edge": Color(0.45, 0.75, 0.1), "spikes": 10, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0}
		&"nodulo_cirrotico":  # the boss: the hard nodule the liver built to protect itself
			return {"name": "O Nódulo", "hp": 340.0, "speed": 1.9, "damage": 0.9, "size": 1.8, "core": Color(0.8, 0.55, 0.2), "edge": Color(0.45, 0.25, 0.05), "spikes": 12, "aggro": 20.0, "lunge": 5.0, "telegraph": 0.85, "recover": 1.1, "boss": true}
		# Granuloma: the new specialists (a spitter, a nest).
		&"bacilo_cuspidor":  # a rod that keeps its distance and spits acid
			return {"name": "Bacilo cuspidor", "hp": 30.0, "speed": 1.3, "damage": 0.6, "size": 0.46, "core": Color(0.85, 1.0, 0.45), "edge": Color(0.5, 0.8, 0.1), "spikes": 4, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.75, "recover": 1.4, "behavior": "ranged"}
		&"colonia_de_bacilos":  # a nest: still, it keeps making bacilli until it is broken
			return {"name": "Colônia de bacilos", "hp": 115.0, "speed": 0.0, "size": 0.9, "core": Color(0.7, 1.0, 0.3), "edge": Color(0.35, 0.65, 0.1), "spikes": 13, "spike_len": 0.22, "spin": 0.08, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0, "behavior": "nest", "spawns": {"kind": &"bacilo", "every": 4.5, "cap": 4}}
		# The liver's cords: the new specialists.
		&"esporo_de_bile":  # a spore that floats away from you and throws bile
			return {"name": "Esporo de bile", "hp": 26.0, "speed": 1.4, "damage": 0.55, "size": 0.44, "core": Color(1.0, 0.85, 0.35), "edge": Color(0.85, 0.5, 0.1), "spikes": 5, "spike_len": 0.24, "spin": 0.2, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.7, "recover": 1.4, "behavior": "ranged"}
		&"plasmodio":  # a parasite that splits in two when it dies
			return {"name": "Plasmódio", "hp": 62.0, "speed": 1.9, "damage": 0.65, "size": 0.85, "core": Color(1.0, 0.6, 0.55), "edge": Color(0.8, 0.25, 0.3), "spikes": 0, "aggro": 10.0, "lunge": 3.4, "telegraph": 0.7, "recover": 1.2, "split": {"kind": &"merozoito", "count": 2}}
		&"merozoito":
			return {"name": "Merozoíto", "hp": 12.0, "speed": 3.4, "damage": 0.4, "size": 0.32, "core": Color(1.0, 0.75, 0.7), "edge": Color(0.9, 0.35, 0.4), "spikes": 0, "aggro": 12.0, "lunge": 2.8, "telegraph": 0.4, "recover": 0.8}
		&"cisto_hidatidico":  # a cyst: still, it spits out stellate cells until it is broken
			return {"name": "Cisto", "hp": 135.0, "speed": 0.0, "size": 0.95, "core": Color(1.0, 0.95, 0.7), "edge": Color(0.9, 0.7, 0.3), "spikes": 0, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0, "behavior": "nest", "spawns": {"kind": &"celula_estrelada", "every": 5.0, "cap": 4}}
		# The wild ones: what lives in each organ even outside a dungeon (see BioBestiary).
		&"trombo":  # the heart: a slow, heavy clot
			return {"name": "Trombo", "hp": 70.0, "speed": 1.5, "damage": 0.8, "size": 1.0, "core": Color(0.55, 0.1, 0.2), "edge": Color(0.9, 0.2, 0.3), "spikes": 0, "aggro": 9.0, "lunge": 3.6, "telegraph": 0.95, "recover": 1.5}
		&"pneumococo":  # the lungs: a pair of small, fast cocci
			return {"name": "Pneumococo", "hp": 18.0, "speed": 3.3, "damage": 0.45, "size": 0.36, "core": Color(0.8, 0.95, 1.0), "edge": Color(0.4, 0.75, 1.0), "spikes": 0, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.5, "recover": 0.9, "group": 2}
		&"esporo_fungico":  # the lungs: a fungal spore that keeps away and throws spores
			return {"name": "Esporo fúngico", "hp": 30.0, "speed": 1.2, "damage": 0.55, "size": 0.5, "core": Color(0.85, 0.95, 0.6), "edge": Color(0.55, 0.75, 0.3), "spikes": 8, "spike_len": 0.16, "spin": 0.1, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.8, "recover": 1.5, "behavior": "ranged"}
		&"placa":  # the artery: an atheroma plaque, yellow and hard
			return {"name": "Placa de ateroma", "hp": 95.0, "speed": 1.3, "damage": 0.7, "size": 1.1, "core": Color(1.0, 0.9, 0.5), "edge": Color(0.85, 0.65, 0.2), "spikes": 3, "spike_len": 0.6, "spin": 0.15, "aggro": 8.0, "lunge": 3.6, "telegraph": 1.0, "recover": 1.6}
		&"embolo":  # the artery: a clot torn loose, it charges from far away
			return {"name": "Êmbolo", "hp": 36.0, "speed": 2.6, "damage": 1.0, "size": 0.55, "core": Color(1.0, 0.85, 0.85), "edge": Color(1.0, 0.45, 0.5), "spikes": 6, "spike_len": 0.7, "spin": 2.4, "aggro": 12.0, "lunge": 6.5, "telegraph": 0.5, "recover": 1.4}
	# --- The spleen's germinal centre: clones that escaped the selection.
		&"linfoblasto":
			return {"name": "Linfoblasto", "hp": 20.0, "speed": 3.5, "damage": 0.5, "size": 0.4, "core": Color(0.8, 0.7, 1.0), "edge": Color(0.55, 0.35, 0.95), "spikes": 0, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.6, "recover": 1.2}
		&"centroblasto":
			return {"name": "Centroblasto", "hp": 100.0, "speed": 1.5, "damage": 0.75, "size": 1.05, "core": Color(0.65, 0.5, 0.95), "edge": Color(0.4, 0.2, 0.8), "spikes": 0, "aggro": 9.0, "lunge": 3.5, "telegraph": 0.9, "recover": 1.4}
		&"macrofago_da_polpa":
			return {"name": "Macrófago da polpa", "hp": 120.0, "speed": 1.3, "damage": 0.7, "size": 1.2, "core": Color(0.9, 0.45, 0.6), "edge": Color(0.6, 0.2, 0.4), "spikes": 0, "aggro": 9.0, "lunge": 3.8, "telegraph": 1.0, "recover": 1.6}
		&"plasmoblasto":  # throws antibodies from behind the columns
			return {"name": "Plasmoblasto", "hp": 28.0, "speed": 1.3, "damage": 0.55, "size": 0.46, "core": Color(1.0, 0.7, 0.95), "edge": Color(0.8, 0.4, 0.9), "spikes": 6, "spike_len": 0.2, "spin": 0.2, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.75, "recover": 1.4, "behavior": "ranged"}
		&"foliculo_hiperplasico":
			return {"name": "Folículo hiperplásico", "hp": 125.0, "speed": 0.0, "size": 0.95, "core": Color(0.85, 0.75, 1.0), "edge": Color(0.55, 0.4, 0.9), "spikes": 0, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0, "behavior": "nest", "spawns": {"kind": &"linfoblasto", "every": 4.5, "cap": 4}}
		&"foco_de_ativacao":
			return {"name": "Foco de ativação", "hp": 55.0, "speed": 0.0, "size": 0.55, "core": Color(0.9, 0.8, 1.0), "edge": Color(0.6, 0.4, 1.0), "spikes": 10, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0}
		&"blasto_em_mitose":  # it divides when it dies
			return {"name": "Blasto em mitose", "hp": 58.0, "speed": 1.9, "damage": 0.6, "size": 0.8, "core": Color(0.85, 0.6, 1.0), "edge": Color(0.5, 0.25, 0.9), "spikes": 0, "aggro": 10.0, "lunge": 3.4, "telegraph": 0.7, "recover": 1.2, "split": {"kind": &"linfoblasto", "count": 2}}
		&"clone_maligno":
			return {"name": "O Clone", "hp": 360.0, "speed": 1.9, "damage": 0.9, "size": 1.8, "core": Color(0.55, 0.3, 0.9), "edge": Color(0.3, 0.1, 0.6), "spikes": 12, "spike_len": 0.35, "aggro": 20.0, "lunge": 5.0, "telegraph": 0.85, "recover": 1.1, "boss": true}
		&"meningococo":  # wild, in the spleen: a trio of small cocci
			return {"name": "Meningococo", "hp": 16.0, "speed": 3.4, "damage": 0.45, "size": 0.34, "core": Color(0.9, 0.85, 1.0), "edge": Color(0.6, 0.55, 0.95), "spikes": 0, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.5, "recover": 0.9, "group": 3}
		&"bacteria_encapsulada":  # wild, in the spleen: wrapped in a capsule, slow and hard to chew
			return {"name": "Bactéria encapsulada", "hp": 105.0, "speed": 1.1, "damage": 0.7, "size": 1.15, "core": Color(0.8, 0.75, 0.6), "edge": Color(0.55, 0.5, 0.3), "spikes": 0, "aggro": 8.0, "lunge": 3.6, "telegraph": 1.0, "recover": 1.6}
		# --- The intestine's deep crypts: a biofilm and what feeds on it.
		&"bacteria_enterica":
			return {"name": "Bactéria entérica", "hp": 22.0, "speed": 3.2, "damage": 0.5, "size": 0.4, "core": Color(0.7, 1.0, 0.5), "edge": Color(0.35, 0.75, 0.2), "spikes": 4, "spike_len": 0.2, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.6, "recover": 1.1, "group": 2}
		&"verme_intestinal":  # long lunge
			return {"name": "Verme intestinal", "hp": 105.0, "speed": 1.6, "damage": 0.7, "size": 1.0, "core": Color(1.0, 0.7, 0.65), "edge": Color(0.8, 0.4, 0.4), "spikes": 0, "aggro": 10.0, "lunge": 4.6, "telegraph": 0.9, "recover": 1.4}
		&"cisto_de_giardia":
			return {"name": "Cisto de giárdia", "hp": 130.0, "speed": 1.2, "damage": 0.65, "size": 1.15, "core": Color(0.95, 0.9, 0.6), "edge": Color(0.7, 0.6, 0.2), "spikes": 0, "aggro": 8.0, "lunge": 3.6, "telegraph": 1.0, "recover": 1.6}
		&"esporo_de_clostridio":
			return {"name": "Esporo de clostrídio", "hp": 28.0, "speed": 1.3, "damage": 0.55, "size": 0.46, "core": Color(0.8, 0.85, 0.4), "edge": Color(0.5, 0.55, 0.15), "spikes": 7, "spike_len": 0.2, "spin": 0.15, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.75, "recover": 1.4, "behavior": "ranged"}
		&"biofilme":
			return {"name": "Biofilme", "hp": 120.0, "speed": 0.0, "size": 0.95, "core": Color(0.8, 1.0, 0.5), "edge": Color(0.45, 0.75, 0.2), "spikes": 14, "spike_len": 0.2, "spin": 0.08, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0, "behavior": "nest", "spawns": {"kind": &"bacteria_enterica", "every": 4.5, "cap": 4}}
		&"foco_de_toxina":
			return {"name": "Foco de toxina", "hp": 55.0, "speed": 0.0, "size": 0.55, "core": Color(0.6, 1.0, 0.4), "edge": Color(0.3, 0.7, 0.1), "spikes": 10, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0}
		&"ameba":  # divides when it dies
			return {"name": "Ameba", "hp": 60.0, "speed": 1.8, "damage": 0.6, "size": 0.85, "core": Color(0.9, 0.9, 0.6), "edge": Color(0.7, 0.7, 0.3), "spikes": 0, "aggro": 10.0, "lunge": 3.4, "telegraph": 0.7, "recover": 1.2, "split": {"kind": &"ameba_filha", "count": 2}}
		&"ameba_filha":
			return {"name": "Ameba filha", "hp": 13.0, "speed": 3.2, "damage": 0.4, "size": 0.32, "core": Color(0.95, 0.95, 0.7), "edge": Color(0.75, 0.75, 0.35), "spikes": 0, "aggro": 12.0, "lunge": 2.8, "telegraph": 0.4, "recover": 0.8}
		&"a_tenia":
			return {"name": "A Tênia", "hp": 380.0, "speed": 1.7, "damage": 0.95, "size": 1.9, "core": Color(0.95, 0.8, 0.7), "edge": Color(0.7, 0.5, 0.4), "spikes": 8, "spike_len": 0.2, "aggro": 20.0, "lunge": 5.2, "telegraph": 0.85, "recover": 1.1, "boss": true}
		# --- The kidney's nephrons: crystals and stones.
		&"cristal_de_urato":
			return {"name": "Cristal de urato", "hp": 24.0, "speed": 3.0, "damage": 0.5, "size": 0.38, "core": Color(1.0, 0.95, 0.75), "edge": Color(0.9, 0.75, 0.35), "spikes": 6, "spike_len": 0.55, "spin": 1.0, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.55, "recover": 1.1, "group": 3}
		&"bacilo_urinario":
			return {"name": "Bacilo urinário", "hp": 22.0, "speed": 2.8, "damage": 0.5, "size": 0.4, "core": Color(0.6, 1.0, 0.8), "edge": Color(0.2, 0.7, 0.55), "spikes": 3, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.6, "recover": 1.1}
		&"calculo_renal":
			return {"name": "Cálculo renal", "hp": 130.0, "speed": 1.0, "damage": 0.75, "size": 1.2, "core": Color(0.8, 0.75, 0.65), "edge": Color(0.5, 0.45, 0.35), "spikes": 5, "spike_len": 0.3, "spin": 0.1, "aggro": 8.0, "lunge": 3.6, "telegraph": 1.0, "recover": 1.6}
		&"cilindro_hialino":
			return {"name": "Cilindro hialino", "hp": 100.0, "speed": 1.5, "damage": 0.65, "size": 1.0, "core": Color(0.8, 0.95, 1.0), "edge": Color(0.45, 0.7, 0.85), "spikes": 0, "aggro": 9.0, "lunge": 4.0, "telegraph": 0.9, "recover": 1.4}
		&"espiculo_de_oxalato":
			return {"name": "Espícula de oxalato", "hp": 26.0, "speed": 1.3, "damage": 0.55, "size": 0.46, "core": Color(0.9, 1.0, 0.9), "edge": Color(0.5, 0.85, 0.6), "spikes": 9, "spike_len": 0.45, "spin": 0.3, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.75, "recover": 1.4, "behavior": "ranged"}
		&"foco_de_pielonefrite":
			return {"name": "Foco de pielonefrite", "hp": 125.0, "speed": 0.0, "size": 0.95, "core": Color(0.6, 1.0, 0.8), "edge": Color(0.2, 0.7, 0.55), "spikes": 12, "spike_len": 0.22, "spin": 0.08, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0, "behavior": "nest", "spawns": {"kind": &"bacilo_urinario", "every": 4.5, "cap": 4}}
		&"foco_de_acido_urico":
			return {"name": "Foco de ácido úrico", "hp": 55.0, "speed": 0.0, "size": 0.55, "core": Color(1.0, 0.9, 0.4), "edge": Color(0.8, 0.6, 0.1), "spikes": 10, "aggro": 0.0, "lunge": 0.0, "telegraph": 0.0, "recover": 0.0}
		&"cristal_que_racha":  # splits into urate crystals when it breaks
			return {"name": "Cristal que racha", "hp": 56.0, "speed": 1.8, "damage": 0.6, "size": 0.8, "core": Color(0.9, 1.0, 1.0), "edge": Color(0.5, 0.8, 0.9), "spikes": 7, "spike_len": 0.4, "spin": 0.6, "aggro": 10.0, "lunge": 3.4, "telegraph": 0.7, "recover": 1.2, "split": {"kind": &"cristal_de_urato", "count": 2}}
		&"o_calculo":
			return {"name": "O Cálculo", "hp": 380.0, "speed": 1.7, "damage": 0.95, "size": 1.85, "core": Color(0.85, 0.8, 0.6), "edge": Color(0.5, 0.4, 0.2), "spikes": 13, "spike_len": 0.3, "aggro": 20.0, "lunge": 5.0, "telegraph": 0.85, "recover": 1.1, "boss": true}
	return {}


## What a dungeon draws its rooms from: who is the fodder, the bruiser, the one that shoots, the nest, the one that stands still and speeds
## the others up, the one that splits and the boss. Each organ has its own cast, so the rooms of one do not look like the rooms of another.
static func family(dungeon: String) -> Dictionary:
	match dungeon:
		"cordoes-hepaticos":
			return {"fodder": [&"celula_estrelada"], "swarm": &"celula_estrelada", "bruiser": [&"hepatocito_doente", &"gota_de_gordura"], "ranged": &"esporo_de_bile",
				"nest": &"cisto_hidatidico", "emitter": &"foco_toxico", "splitter": &"plasmodio", "boss": &"nodulo_cirrotico", "hazard": Color(0.95, 0.65, 0.2),
				"colors": {"guard": Color(0.95, 0.65, 0.2), "wall": Color(0.95, 0.65, 0.2), "deep": Color(0.75, 0.9, 0.2)}}
		"centro-germinativo":
			return {"fodder": [&"linfoblasto"], "swarm": &"linfoblasto", "bruiser": [&"centroblasto", &"macrofago_da_polpa"], "ranged": &"plasmoblasto",
				"nest": &"foliculo_hiperplasico", "emitter": &"foco_de_ativacao", "splitter": &"blasto_em_mitose", "boss": &"clone_maligno", "hazard": Color(0.75, 0.4, 0.95),
				"colors": {"guard": Color(0.7, 0.55, 1.0), "wall": Color(0.62, 0.42, 0.95), "deep": Color(0.95, 0.4, 0.75)}}
		"criptas-profundas":
			return {"fodder": [&"bacteria_enterica"], "swarm": &"bacteria_enterica", "bruiser": [&"verme_intestinal", &"cisto_de_giardia"], "ranged": &"esporo_de_clostridio",
				"nest": &"biofilme", "emitter": &"foco_de_toxina", "splitter": &"ameba", "boss": &"a_tenia", "hazard": Color(0.85, 0.95, 0.3),
				"colors": {"guard": Color(0.6, 0.95, 0.5), "wall": Color(0.5, 0.88, 0.4), "deep": Color(0.95, 0.8, 0.3)}}
		"nefrons":
			return {"fodder": [&"cristal_de_urato", &"bacilo_urinario"], "swarm": &"cristal_de_urato", "bruiser": [&"calculo_renal", &"cilindro_hialino"], "ranged": &"espiculo_de_oxalato",
				"nest": &"foco_de_pielonefrite", "emitter": &"foco_de_acido_urico", "splitter": &"cristal_que_racha", "boss": &"o_calculo", "hazard": Color(1.0, 0.85, 0.3),
				"colors": {"guard": Color(0.5, 0.95, 0.9), "wall": Color(0.3, 0.88, 0.82), "deep": Color(1.0, 0.85, 0.4)}}
	return {"fodder": [&"linfocito", &"bacilo"], "swarm": &"bacilo", "bruiser": [&"macrofago_guarda", &"celula_gigante"], "ranged": &"bacilo_cuspidor", "nest": &"colonia_de_bacilos",
		"emitter": &"emissor", "splitter": &"", "boss": &"bacilo_mestre", "hazard": Color(0.6, 0.95, 0.3),
		"colors": {"guard": Color(0.55, 0.8, 1.0), "wall": Color(1.0, 0.45, 0.62), "deep": Color(0.6, 0.95, 0.3)}}


## Who stands still and speeds the others up, and who is sent as reinforcement, for each dungeon.
static func emitter_of(dungeon: String) -> StringName:
	return family(dungeon)["emitter"]


static func reinforcement_of(dungeon: String) -> StringName:
	return family(dungeon)["swarm"]


## The effect of a modifier on the run: enemy speed, a drain on the player, ATP regeneration, how often the core spawns a
## new bacillus (0 = never), whether quorum emitters speed up the enemies, and the head count of the first and later rooms.
static func rules(modifier: String) -> Dictionary:
	var r := {"speed_mult": 1.0, "drain": 0.0, "regen_mult": 1.0, "respawn_every": 0.0, "quorum": false, "front_mult": 1.0, "back_mult": 1.0, "hp_mult": 1.0}
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
		"bile-acida":
			r.merge({"drain": 0.5}, true)
		"fibrose-ativa":
			r.merge({"respawn_every": 8.0}, true)
		"toxinas-altas":
			r.merge({"speed_mult": 1.2}, true)
		"glicogenio-cheio":
			r.merge({"regen_mult": 1.5}, true)
		"kupffer-aliadas":
			r.merge({"hp_mult": 0.75}, true)
		"hipermutacao", "peristaltismo", "pressao-alta":
			r.merge({"speed_mult": 1.2}, true)
		"selecao-rigida":
			r.merge({"hp_mult": 1.25}, true)
		"tolerancia", "microbiota-forte", "diurese":
			r.merge({"hp_mult": 0.75}, true)
		"baco-congestionado", "jejum", "ureia-alta":
			r.merge({"drain": 0.5}, true)
		"polpa-limpa", "refeicao-farta", "rim-limpo":
			r.merge({"regen_mult": 1.5}, true)
		"disbiose-ativa", "cristalizacao":
			r.merge({"respawn_every": 8.0}, true)
	return r


## How far the wall of a chamber is from its centre, in the direction `angle` (world units). A chamber is not always a circle: it can be
## stretched into an oval (a hall) or lobed (a cavern with bays).
static func wall_radius(shape: Dictionary, base: float, angle: float) -> float:
	var turned := angle - float(shape.get("turn", 0.0))
	match str(shape.get("kind", "round")):
		"oval":
			var a := base * float(shape.get("stretch", 1.0))
			var b := base / float(shape.get("stretch", 1.0))
			return a * b / sqrt(pow(b * cos(turned), 2.0) + pow(a * sin(turned), 2.0))
		"lobed":
			return base * (1.0 + float(shape.get("depth", 0.15)) * cos(float(shape.get("lobes", 3)) * turned))
	return base


## The room: its shape and size, the pillars and hazards on its floor, and its enemies as {type, angle, radius (0..1 of the wall)}.
## Everything is drawn from the seed of the run and the index of the room, so two runs differ and everyone in one run sees the same.
## `kind` is what the engine says (guard, wall, core, boss, and the ones a procedural dungeon draws: ambush, pillars, nest, hazard).
static func room(seed_value: int, index: int, kind: String, modifier: String, dungeon: String = "granuloma") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 7919
	var rule := rules(modifier)
	var cast := family(dungeon)
	var count_mult: float = rule["front_mult"] if index < 2 else rule["back_mult"]
	var radius := _base_radius(kind) + (0.0 if kind == "boss" else rng.randf_range(-0.8, 0.8))
	var shape := _shape(rng, kind)
	var enemies: Array[Dictionary] = []
	var scaled := func(a: int, b: int) -> int: return maxi(1, roundi(rng.randi_range(a, b) * count_mult))
	var fodder: Array = cast["fodder"]
	var bruisers: Array = cast["bruiser"]
	var obstacles: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var grace := 3.5
	match kind:
		"guard":
			_add(enemies, rng, fodder, scaled.call(2, 4))
		"wall":
			_add(enemies, rng, [bruisers[rng.randi() % bruisers.size()]], rng.randi_range(1, 2))
			_add(enemies, rng, fodder, scaled.call(1, 3))
			if index >= 2 and rng.randf() < 0.5:
				_add(enemies, rng, [cast["ranged"]], 1)
		"core":
			var extra := 3 if rule["respawn_every"] > 0.0 else 0
			_add(enemies, rng, [cast["swarm"]], scaled.call(4, 6) + extra)
			_add(enemies, rng, [cast["emitter"]], rng.randi_range(1, 2))
			if cast["splitter"] != &"" and rng.randf() < 0.6:
				_add(enemies, rng, [cast["splitter"]], 1)
		"boss":
			_add(enemies, rng, [cast["boss"]], 1)
			_add(enemies, rng, [cast["emitter"]], 2)
		"ambush":  # they all arrive at once, from the walls, and do not wait
			_add(enemies, rng, fodder, scaled.call(5, 7), 0.72, 0.88)
			grace = 1.2
		"pillars":
			_scatter(obstacles, rng, rng.randi_range(5, 8), 0.2, 0.78, 0.7, 1.3)
			_add(enemies, rng, [cast["ranged"]], rng.randi_range(2, 3))
			_add(enemies, rng, fodder, scaled.call(1, 2))
		"nest":
			_add(enemies, rng, [cast["nest"]], rng.randi_range(1, 2), 0.2, 0.55)
			_add(enemies, rng, fodder, scaled.call(2, 3))
		"hazard":
			_scatter(hazards, rng, rng.randi_range(6, 10), 0.15, 0.8, 0.8, 1.2)
			_add(enemies, rng, [bruisers[rng.randi() % bruisers.size()]], 1)
			_add(enemies, rng, fodder, scaled.call(2, 3))
			if cast["splitter"] != &"" and rng.randf() < 0.7:
				_add(enemies, rng, [cast["splitter"]], 1)
	return {"radius": radius, "enemies": enemies, "kind": kind, "shape": shape, "obstacles": obstacles, "hazards": hazards, "grace": grace}


static func _base_radius(kind: String) -> float:
	match kind:
		"guard", "ambush":
			return 9.0
		"wall":
			return 8.0
		"core":
			return 7.5
		"boss":
			return 9.5
		"pillars":
			return 10.5
		"nest":
			return 8.5
		"hazard":
			return 9.5
	return 8.0


## The outline of the chamber: a hall (oval) for ambushes, a cavern (lobed) for hazards and nests, a round room otherwise, sometimes the
## other way round, so the same kind of room is not always the same place.
static func _shape(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var roll := rng.randf()
	var turn := rng.randf() * TAU
	if kind == "boss":
		return {"kind": "round", "turn": 0.0}
	var oval := {"kind": "oval", "stretch": rng.randf_range(1.25, 1.5), "turn": turn}
	var lobed := {"kind": "lobed", "lobes": rng.randi_range(3, 5), "depth": rng.randf_range(0.1, 0.2), "turn": turn}
	match kind:
		"ambush":
			return oval if roll < 0.75 else lobed
		"hazard", "nest":
			return lobed if roll < 0.7 else oval
		"pillars":
			return {"kind": "round", "turn": 0.0} if roll < 0.7 else lobed
	return {"kind": "round", "turn": 0.0} if roll < 0.5 else (oval if roll < 0.75 else lobed)


## `count` enemies of the given types (drawn at random from them) at angles around the chamber, between two fractions of the wall.
static func _add(into: Array[Dictionary], rng: RandomNumberGenerator, types: Array, count: int, from: float = 0.35, to: float = 0.85) -> void:
	for i in count:
		var type: StringName = types[rng.randi() % types.size()]
		var boss := bool(enemy(type).get("boss", false))
		into.append({"type": type, "angle": rng.randf() * TAU, "radius": 0.0 if boss else rng.randf_range(from, to)})


## Pillars or pools on the floor: never on top of each other nor at the door, where the cell comes in (the bottom, at 0.8 of the wall).
static func _scatter(into: Array[Dictionary], rng: RandomNumberGenerator, count: int, from: float, to: float, smallest: float, largest: float) -> void:
	var tries := 0
	while into.size() < count and tries < 60:
		tries += 1
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(from, to)
		var size := rng.randf_range(smallest, largest)
		var at := Vector2.from_angle(angle) * radius
		if at.distance_to(Vector2(0.0, 0.8)) < 0.4:
			continue
		var clear := true
		for other in into:
			if (Vector2.from_angle(float(other["angle"])) * float(other["radius"])).distance_to(at) < 0.2:
				clear = false
		if clear:
			into.append({"angle": angle, "radius": radius, "size": size})
