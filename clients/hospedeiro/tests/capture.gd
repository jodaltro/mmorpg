extends SceneTree
## Visual check (needs a real renderer): godot --path clients/hospedeiro --script res://tests/capture.gd -- <output_dir>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "."
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""  # never touch the player's real save
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
