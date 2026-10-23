extends SceneTree
## The basic lash of every form, with and without a ferocious/agile look (real renderer):
## godot --path clients/hospedeiro --script res://tests/capture_body.gd -- <output_dir>

const FORMS := [&"esfera", &"macrofago", &"dendritica", &"t_auxiliar"]


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
	world.camera.zoom = Vector2.ONE * 3.4
	var ctrl := world.player.get_node("Controller") as BioCellController
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	ctrl.set_aim(Vector2.RIGHT)
	var body: BioCellBody
	for child in world.player.get_children():
		if child is BioCellBody:
			body = child
	for look_name in ["plain"]:
		for form in FORMS:
			world.genome.lineage = form if form != &"esfera" else &""
			world.player.combatant.set_genome(world.genome)
			if look_name == "fierce":
				body.set_look({"ferocidade": 90, "agilidade": 70, "robustez": 60, "metabolismo": 40, "sociabilidade": 50, "misterio": 30})
				body.look_now = body.look_target.duplicate()
			else:
				body.clear_look()
			await create_timer(1.2).timeout
			world.player.combatant.reset_vitals()
			ctrl.lash()
			for i in 3:
				await create_timer(0.05).timeout
				root.get_texture().get_image().save_png("%s/lash_%s_%s_%d.png" % [out_dir, look_name, form, i])
			await create_timer(0.8).timeout
	quit()
