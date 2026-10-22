extends SceneTree
## Visual check (needs a real renderer): godot --path clients/hospedeiro --script res://tests/capture.gd -- <output_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "."
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""  # never touch the player's real save
	world.engine_url = ""
	root.add_child(world)
	await create_timer(0.8).timeout
	_shot(out_dir, "01_idle")

	var ctrl := world.player.get_node("Controller") as BioCellController
	var virus := BioFactory.spawn_virus(world, Vector2(3.5, 0.5) * BioArt.UNIT, world.player)
	ctrl.move(Vector2(0.4, 0.2))
	await create_timer(0.55).timeout
	_shot(out_dir, "02_virus_telegraph")

	ctrl.set_aim(Vector2.RIGHT)
	ctrl.move(Vector2.ZERO)
	ctrl.lash()
	ctrl.spit()
	await create_timer(0.07).timeout
	_shot(out_dir, "03a_lash_early")
	await create_timer(0.06).timeout
	_shot(out_dir, "03_lash_and_spit")
	await create_timer(0.07).timeout
	_shot(out_dir, "03b_lash_late")

	await create_timer(0.6).timeout
	ctrl.move(Vector2(1, 0))
	ctrl.dash()
	await create_timer(0.1).timeout
	_shot(out_dir, "04_dash")
	world.virus_count = 0
	for v in world.viruses():
		v.queue_free()
	world.player.combatant.reset_vitals()
	ctrl.move(Vector2.RIGHT)
	await create_timer(0.6).timeout
	world.camera.zoom = Vector2.ONE * 3.5
	await create_timer(0.3).timeout
	_shot(out_dir, "05_closeup_moving")
	ctrl.move(Vector2.ZERO)
	await create_timer(1.2).timeout
	_shot(out_dir, "06_closeup_rest")
	ctrl.set_aim(Vector2.RIGHT)
	print("lash status ", ctrl.lash())
	for i in 3:
		await create_timer(0.06).timeout
		_shot(out_dir, "07_closeup_lash_%d" % i)

	# Monsters come back for the final full-scene shot.
	world.camera.zoom = Vector2.ONE * 1.35
	world.virus_count = 6
	for p in [Vector2(4, 1), Vector2(-5, -3), Vector2(2, 5)]:
		BioFactory.spawn_virus(world, p * BioArt.UNIT, world.player)
	await create_timer(0.6).timeout
	_shot(out_dir, "08_with_viruses")
	# One shot per build, to read the genes on the body.
	world.virus_count = 0
	for v in world.viruses():
		v.queue_free()
	await create_timer(0.3).timeout
	world.camera.zoom = Vector2.ONE * 3.0
	var builds := {
		"11_body_bare": [],
		"12_body_combat": [&"flagelo_calejado", &"cauda_longa", &"vesicula_toxica"],
		"13_body_swift": [&"cilios_ageis", &"nucleo_reativo", &"membrana_espessa"],
		"14_body_metabolic": [&"mitocondria_avida", &"enzima_voraz", &"cilios_ageis"],
	}
	for key in builds:
		var g := BioGenome.new()
		for id in builds[key]:
			g.equip(id)
		world.player.combatant.set_genome(g)
		world.player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
		await create_timer(0.7).timeout
		_shot(out_dir, key)
	# Three players, three bodies: the look comes from the engine, so only axes differ here.
	var looks := {
		"15_look_cacador": {"ferocidade": 90, "agilidade": 30, "robustez": 30, "metabolismo": 10, "sociabilidade": 5, "misterio": 5},
		"16_look_andarilho": {"ferocidade": 10, "agilidade": 95, "robustez": 10, "metabolismo": 20, "sociabilidade": 10, "misterio": 30},
		"17_look_erudito": {"ferocidade": 5, "agilidade": 25, "robustez": 20, "metabolismo": 10, "sociabilidade": 30, "misterio": 95},
		"18_look_banqueteiro": {"ferocidade": 15, "agilidade": 15, "robustez": 70, "metabolismo": 95, "sociabilidade": 20, "misterio": 5},
	}
	for key in looks:
		world.player.combatant.set_genome(BioGenome.new())
		world.sync.apply_view({"look": {"variant": key, "name": key, "axes": looks[key]}})
		for child in world.player.get_children():
			if child is BioCellBody:
				(child as BioCellBody).look_now = looks[key].duplicate()
				(child as BioCellBody)._ease_look(0.0)
		await create_timer(0.8).timeout
		_shot(out_dir, key)
	world.camera.zoom = Vector2.ONE * 1.35
	world.player.combatant.set_genome(BioGenome.new())
	world.add_pressure(BioMutationTracker.THRESHOLD)
	await create_timer(0.2).timeout
	_shot(out_dir, "09_mutation_offer")
	world.pick_mutation(0)
	await create_timer(0.2).timeout
	_shot(out_dir, "10_mutation_picked")
	quit()


func _shot(out_dir: String, name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name, " ", image.get_size())
