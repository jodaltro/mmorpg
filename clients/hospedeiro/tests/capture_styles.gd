extends SceneTree
## The same abilities under each effect style, mid-effect (real renderer), with the debug overlay on in the last frame.
##   godot --path clients/hospedeiro --script res://tests/capture_styles.gd -- <output_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.8).timeout
	world.camera.zoom = Vector2.ONE * 1.1
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"macrofago"
	world.player.combatant.set_genome(world.genome)
	for id in [&"engolir", &"onda_de_pseudopodes", &"lisossomo_acido", &"muralha_de_carne"]:
		world.abilities.learn(id)
	world.hud.visible = false
	var ctrl := world.player.get_node("Controller") as BioCellController
	var names := ["base", "chama", "cristal", "nevoa", "eletrico", "organico"]
	for i in names.size():
		var traits := {} if i == 0 else {"efeito": names[i]}
		world.apply_design(traits, "debug" if i > 0 else "nenhuma")
		world.player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
		world.player.combatant.actor._ready_at.clear()  # fresh cooldowns for every style
		world.abilities.clear()
		for id in [&"engolir", &"onda_de_pseudopodes", &"lisossomo_acido", &"muralha_de_carne"]:
			world.abilities.learn(id)
		await create_timer(0.4).timeout
		ctrl.set_aim(Vector2.RIGHT)
		for slot in [1, 2, 3]:
			world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
			print("perform ", slot, " -> ", world.abilities.perform(slot), " emitted=", BioPfx.emitted)
			await create_timer(0.35).timeout
			root.get_texture().get_image().save_png("%s/%s_%d.png" % [out_dir, names[i], slot])
			await create_timer(0.6).timeout
	world.design_debug.toggle()
	world.hud.visible = true
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out_dir + "/debug_overlay.png")
	print("EMITTED ", BioPfx.emitted, " STYLED ", BioPfx.emitted_styled)
	quit()
