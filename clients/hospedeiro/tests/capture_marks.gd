extends SceneTree
## Each class wearing three of its own mutations, plus a mutation offer card (real renderer):
## godot --path clients/hospedeiro --script res://tests/capture_marks.gd -- <output_dir>

const CLASSES := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.6).timeout
	world.camera.zoom = Vector2.ONE * 3.0
	for lineage in CLASSES:
		world.genome.lineage = lineage
		world.genome.equipped = []
		var ids := BioGeneCatalog.class_ids(lineage)
		for i in 3:
			world.genome.equip(ids[2 + i])
		world.player.combatant.set_genome(world.genome)
		await create_timer(1.6).timeout
		root.get_texture().get_image().save_png("%s/marks_%s.png" % [out_dir, lineage])
	world.genome.equipped = []
	world.player.combatant.set_genome(world.genome)
	world.panel.show_offer(BioGeneCatalog.class_ids(&"t_citotoxico").slice(2, 5), &"receptor_fas")
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/offer_card.png" % out_dir)
	quit()
