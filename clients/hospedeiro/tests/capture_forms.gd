extends SceneTree
## Each class at rest and at three steps of ascension (the single ghostly silhouette), real renderer:
## godot --path clients/hospedeiro --script res://tests/capture_forms.gd -- <output_dir>

const FORMS := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar"]
const STAGES := [0.0, 0.34, 0.67, 1.0]


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
	world.camera.zoom = Vector2.ONE * 2.4
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	for form in FORMS:
		world.genome.lineage = form
		world.genome.equipped = []
		world.player.combatant.set_genome(world.genome)
		for i in STAGES.size():
			body._ascend_target = STAGES[i]
			body._ascend = STAGES[i]
			await create_timer(1.6 if i == 0 else 0.9).timeout
			root.get_texture().get_image().save_png("%s/form_%s_%d.png" % [out_dir, form, i])
	quit()
