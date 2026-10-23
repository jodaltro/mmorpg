extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.6).timeout
	world.camera.zoom = Vector2.ONE * 4.5
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"neutrofilo"
	for id in BioGeneCatalog.class_ids(&"neutrofilo"):
		world.genome.equip(id)
	world.player.combatant.set_genome(world.genome)
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png("%s/neutro_close.png" % out_dir)
	quit()
