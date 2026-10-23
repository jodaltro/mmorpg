extends SceneTree
## Every form at rest (nucleus and silhouette) and at full ascension (humanoid), real renderer:
## godot --path clients/hospedeiro --script res://tests/capture_forms.gd -- <output_dir>

const FORMS := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]


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
	world.camera.zoom = Vector2.ONE * 2.0
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	for form in FORMS:
		for stage in ["rest", "max"]:
			world.genome.lineage = form if form != &"esfera" else &""
			world.genome.equipped = []
			if stage == "max" and BioGeneCatalog.class_ids(form).size() >= 3:
				var ids := BioGeneCatalog.class_ids(form)
				for i in 3:
					world.genome.equip(ids[i])
			world.player.combatant.set_genome(world.genome)
			body._ascend = world.genome.ascension()
			await create_timer(1.8).timeout
			root.get_texture().get_image().save_png("%s/form_%s_%s.png" % [out_dir, form, stage])
	quit()
