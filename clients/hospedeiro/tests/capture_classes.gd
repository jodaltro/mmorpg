extends SceneTree
## The ten classes, plain and risen (wearing four of their own genes), and each of their abilities in the middle of its work
## (real renderer):  godot --path clients/hospedeiro --script res://tests/capture_classes.gd -- <output_dir>

var world: BioWorld
var out_dir := "."

const CLASSES := [&"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador", &"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.8).timeout
	world.debug_god = true
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	for lineage in CLASSES:
		world.debug_become(lineage)
		world.camera.zoom = Vector2.ONE * 2.4
		await create_timer(0.9).timeout
		await _shot("class_%s_plain" % lineage)
		world.genome.equipped = []
		for id in BioGeneCatalog.class_ids(lineage).slice(0, 4):
			world.genome.equip(id)
		world.player.combatant.set_genome(world.genome)
		await create_timer(1.6).timeout
		await _shot("class_%s_risen" % lineage)
		world.genome.equipped = []
		world.player.combatant.set_genome(world.genome)
		world.camera.zoom = Vector2.ONE * 1.25
		var step := 0
		for ability in BioAbilityCatalog.ids_of_class(lineage):
			await _cast(lineage, ability, step)
			step += 1
	quit()


func _foes(hp: float, hunting: bool = false) -> Array[BioCellActor]:
	var foes: Array[BioCellActor] = []
	var spots := [Vector2(4.0, -2.5), Vector2(5.4, 0.2), Vector2(4.2, 2.6), Vector2(7.0, -1.0)]
	for k in spots.size():
		var def := BioDungeonPlan.enemy(&"cilindro_hialino").duplicate()
		def["hp"] = hp
		if not hunting:
			def["speed"] = 0.0
		var brain := BioFactory.spawn_enemy(world, world.player.global_position + (spots[k] as Vector2) * BioArt.UNIT, world.player, def, 1.0, "viruses")
		if not hunting:
			(brain as Node).set_process(false)
		foes.append(brain.get_parent() as BioCellActor)
	return foes


func _blow(foe: BioCellActor, damage: float) -> void:
	foe.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"capture_blow", 0.0, damage, 0.0, 1.0, 0.0, 0.0))


func _recharge() -> void:
	world.player.combatant.actor._ready_at.clear()
	world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
	world.player.combatant.actor.vitals.membrane = world.player.combatant.actor.vitals.max_membrane


## One ability, set up the way it is used, photographed at the moments that show what it does.
func _cast(lineage: StringName, ability: StringName, step: int) -> void:
	var name := "cast_%s_%d_%s" % [lineage, step, ability]
	world.player.global_position = Vector2.ZERO
	world.player.velocity = Vector2.ZERO
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	_recharge()
	var foes := _foes(900.0, ability == &"autoantigeno")
	await create_timer(0.3).timeout
	match ability:
		&"granulos_latentes":
			for f in foes:  # out of the way: a granule goes off the moment an enemy comes near
				f.global_position += Vector2(0.0, 900.0)
			world.abilities.perform_id(ability)
			for k in 16:
				world.player.global_position += Vector2.RIGHT * 0.5 * BioArt.UNIT * (1.0 if k < 8 else 0.0) + Vector2.UP * 0.35 * BioArt.UNIT * (0.0 if k < 8 else 1.0)
				await create_timer(0.14).timeout
			await _shot(name)
			var mine := get_nodes_in_group("bio_mines")[0] as Node2D
			foes[0].global_position = mine.global_position + Vector2(0.4, 0.0) * BioArt.UNIT
			await create_timer(0.3).timeout
			await _shot(name + "_b")
		&"histamina_instavel":
			world.abilities.perform_id(ability)
			await create_timer(0.7).timeout
			_recharge()
			world.abilities.perform_id(ability)
			await create_timer(0.7).timeout
			await _shot(name)
			await create_timer(1.6).timeout
			await _shot(name + "_b")
		&"cascata_de_degranulacao":
			for f in foes:
				f.combatant.actor.vitals.membrane = 12.0
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			await _shot(name)
			_blow(foes[0], 100.0)
			await create_timer(0.35).timeout
			await _shot(name + "_b")
		&"anafilaxia":
			world.abilities.perform_id(ability)
			await create_timer(1.2).timeout
			await _shot(name)
			world.abilities.perform_id(ability)
			await create_timer(0.2).timeout
			await _shot(name + "_b")
		&"adesao":
			world.abilities.perform_id(ability)
			await create_timer(1.4).timeout
			await _shot(name)
		&"cristal_de_charcot":
			world.abilities.perform_id(ability)
			await create_timer(0.5).timeout
			for k in 3:
				_blow(foes[1], 25.0)
			await create_timer(0.4).timeout
			await _shot(name)
			await create_timer(2.5).timeout
			await _shot(name + "_b")
		&"hipertrofia":
			world.abilities.perform_id(ability)
			for f in foes.slice(0, 3):
				_blow(f, 2000.0)
				await create_timer(0.35).timeout
			await create_timer(0.5).timeout
			await _shot(name)
			world.player.scale = Vector2.ONE
		&"rolagem":
			world.abilities.perform_id(ability)
			await create_timer(0.35).timeout
			await _shot(name)
			await create_timer(0.5).timeout
			await _shot(name + "_b")
		&"passo_sem_identidade":
			world.abilities.perform_id(ability)
			await create_timer(0.12).timeout
			await _shot(name)
			await create_timer(0.4).timeout
			await _shot(name + "_b")
		&"predar":
			world.abilities.perform_id(ability)
			await create_timer(0.7).timeout
			await _shot(name)
		&"camuflagem_de_mhc":
			world.abilities.perform_id(ability)
			await create_timer(0.9).timeout
			await _shot(name)
		&"ancora_de_vigilancia":
			world.abilities.perform_id(ability)
			world.player.global_position += Vector2(3.0, -2.0) * BioArt.UNIT
			await create_timer(1.2).timeout
			await _shot(name)
			world.abilities.perform_id(ability)
			await create_timer(0.12).timeout
			await _shot(name + "_b")
		&"anergia":
			world.abilities.perform_id(ability)
			await create_timer(0.8).timeout
			await _shot(name)
		&"sinapse_imunologica":
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			_blow(foes[0], 30.0)
			await create_timer(0.1).timeout
			await _shot(name)
		&"autoantigeno":
			world.abilities.perform_id(ability)
			await create_timer(1.6).timeout
			await _shot(name)
		&"singularidade_de_tolerancia":
			world.abilities.perform_id(ability)
			await create_timer(1.1).timeout
			await _shot(name)
			await create_timer(1.2).timeout
			await _shot(name + "_b")
		&"contragolpe":
			world.abilities.perform_id(ability)
			await create_timer(0.3).timeout
			foes[0].global_position = world.player.global_position + Vector2(1.4, 0.0) * BioArt.UNIT
			await create_timer(0.1).timeout
			world.debug_god = false
			foes[0].combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"capture_blow", 0.0, 30.0, 0.0, 1.0, 0.0, 0.0))
			await create_timer(0.12).timeout
			await _shot(name)
			world.debug_god = true
		&"polarizacao":
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			await _shot(name)
			_recharge()
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			await _shot(name + "_b")
			_recharge()
			world.abilities.perform_id(ability)
		&"diapedese":
			foes[0].global_position = world.player.global_position + Vector2(1.6, 0.0) * BioArt.UNIT
			world.abilities.perform_id(ability)
			for k in 22:
				world.player.set_intent(Vector2.RIGHT)
				await create_timer(0.02).timeout
			await _shot(name)
		&"surto_oxidativo":
			world.abilities.perform_id(ability)
			await create_timer(0.9).timeout
			await _shot(name)
		&"varredura":
			world.abilities.perform_id(ability)
			await create_timer(0.9).timeout
			await _shot(name)
		&"maturacao":
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			await _shot(name)
		&"passagem_linfatica":
			world.abilities.perform_id(ability)
			await create_timer(1.0).timeout
			await _shot(name)
		&"complemento":
			world.abilities.perform_id(ability)
			await create_timer(0.6).timeout
			_blow(foes[1], 8.0)
			await create_timer(0.1).timeout
			await _shot(name)
			_blow(foes[1], 8.0)
			_blow(foes[1], 8.0)
			await create_timer(0.2).timeout
			await _shot(name + "_b")
		&"memoria_imunologica":
			world.abilities.perform_id(&"anticorpo_y")
			await create_timer(0.7).timeout
			world.player.combatant.actor._ready_at.clear()
			world.abilities.perform_id(ability)
			await create_timer(0.5).timeout
			await _shot(name)
		&"fabrica_de_plasmocito":
			world.abilities.perform_id(ability)
			await create_timer(1.2).timeout
			await _shot(name)
		&"salto_letal":
			world.abilities.perform_id(ability)
			await create_timer(0.22).timeout
			await _shot(name)
			await create_timer(0.6).timeout
			await _shot(name + "_b")
		&"sinapse_letal":
			world.abilities.perform_id(ability)
			await create_timer(1.0).timeout
			await _shot(name)
		&"lise_em_massa":
			for f in foes:
				f.combatant.actor.vitals.membrane = 90.0
			foes[0].combatant.actor.vitals.membrane = 20.0
			world.abilities.perform_id(ability)
			await create_timer(0.55).timeout
			await _shot(name)
		&"febre_contagiosa":
			world.abilities.perform_id(ability)
			await create_timer(2.2).timeout
			await _shot(name)
		&"chamado_aos_auxiliares":
			world.abilities.perform_id(ability)
			await create_timer(1.8).timeout
			await _shot(name)
		&"segunda_chance":
			world.abilities.perform_id(ability)
			await create_timer(0.5).timeout
			await _shot(name)
		&"transfusao":
			world.debug_god = false
			world.player.combatant.actor.vitals.membrane = 35.0
			world.abilities.perform_id(ability)
			await create_timer(0.25).timeout
			await _shot(name)
			world.debug_god = true
		_:
			world.abilities.perform_id(ability)
			await create_timer(0.5).timeout
			await _shot(name)
	for f in foes:
		if is_instance_valid(f):
			f.queue_free()
	for c in world.get_children():
		if c is BioPortalPair or c is BioScanBeam or c is BioMine or c is BioGlob or c is BioTether or c is BioSingularity or c is BioSynapse or c is BioAnchor or c is BioHalo or c is BioChargeRing or (c is BioCellActor and (c.name == "Decoy" or c.name == "Auxiliar")):
			c.queue_free()
	world.player.scale = Vector2.ONE
	world.player.modulate.a = 1.0
	world.player.combatant.set_stance(&"", 0.0)
	await create_timer(0.4).timeout


func _shot(name: String) -> void:
	await create_timer(0.15).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
