class_name BioEnemyCatalog
extends RefCounted
## The creatures of the body: hp, speed (units/s), size (units), colours, spikes and how they fight (they lunge, shoot from afar,
## split, or are a nest). The wild ones of each organ are listed in BioBestiary; the numbers of combat belong to the game server and
## the engine never sees them.

## One kind by name: hp, speed (units/s), size (units), colours, spikes and how they lunge.
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
		# The wild ones: what lives in each organ (see BioBestiary).
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
		# --- The three newest places of the body: skin, lymph node and brain.
		&"estafilococo":  # the skin: a small cluster of cocci that comes in a pair
			return {"name": "Estafilococo", "hp": 20.0, "speed": 3.1, "damage": 0.45, "size": 0.38, "core": Color(1.0, 0.95, 0.6), "edge": Color(0.95, 0.75, 0.25), "spikes": 0, "aggro": 10.0, "lunge": 3.0, "telegraph": 0.5, "recover": 0.9, "group": 2}
		&"fungo_da_pele":  # the skin: a fungus that keeps away and throws spores
			return {"name": "Fungo da pele", "hp": 32.0, "speed": 1.2, "damage": 0.5, "size": 0.5, "core": Color(0.95, 0.85, 0.7), "edge": Color(0.75, 0.55, 0.35), "spikes": 6, "spike_len": 0.18, "spin": 0.1, "aggro": 13.0, "lunge": 8.0, "telegraph": 0.8, "recover": 1.5, "behavior": "ranged"}
		&"micobacteria_do_no":  # the lymph node: slow, sturdy, wrapped in wax
			return {"name": "Micobactéria do nódulo", "hp": 110.0, "speed": 1.2, "damage": 0.7, "size": 1.1, "core": Color(0.85, 0.8, 0.55), "edge": Color(0.55, 0.5, 0.25), "spikes": 0, "aggro": 8.0, "lunge": 3.6, "telegraph": 1.0, "recover": 1.6}
		&"celula_metastatica":  # the lymph node: a tumour cell carried in the lymph, quick and ragged
			return {"name": "Célula metastática", "hp": 26.0, "speed": 3.3, "damage": 0.55, "size": 0.44, "core": Color(0.95, 0.5, 0.8), "edge": Color(0.7, 0.2, 0.55), "spikes": 5, "spike_len": 0.3, "spin": 0.4, "aggro": 11.0, "lunge": 3.4, "telegraph": 0.55, "recover": 1.0}
		&"ameba_cerebral":  # the brain: it divides when it dies
			return {"name": "Ameba cerebral", "hp": 60.0, "speed": 1.8, "damage": 0.65, "size": 0.85, "core": Color(0.85, 0.7, 1.0), "edge": Color(0.55, 0.35, 0.85), "spikes": 0, "aggro": 10.0, "lunge": 3.4, "telegraph": 0.7, "recover": 1.2, "split": {"kind": &"ameba_filha", "count": 2}}
		&"agregado_amiloide":  # the brain: a hard plaque that barely moves
			return {"name": "Agregado amiloide", "hp": 120.0, "speed": 1.0, "damage": 0.7, "size": 1.15, "core": Color(0.8, 0.75, 0.9), "edge": Color(0.5, 0.4, 0.65), "spikes": 4, "spike_len": 0.3, "spin": 0.1, "aggro": 8.0, "lunge": 3.8, "telegraph": 1.0, "recover": 1.6}
	return {}
