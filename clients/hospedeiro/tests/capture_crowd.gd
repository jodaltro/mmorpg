extends SceneTree
## Screenshot of the anonymous cells of the body (real renderer): one of each kind in a row, near and far detail.
##   godot --path clients/hospedeiro --script res://tests/capture_crowd.gd -- <output_dir>


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
	await create_timer(0.6).timeout
	var centre := BioBodyMap.center_px(&"pulmao")
	world.player.global_position = centre + Vector2(0.0, 6.5) * BioArt.UNIT
	await create_timer(0.5).timeout
	var crowd := world.sync.crowd
	crowd.set_process(false)
	var roles := ["defesa", "limpeza", "vigilancia", "reparo", "amparo", "reciclagem", "depuracao", "filtracao", "simbiose", "transporte", "memoria", "suporte"]
	for i in roles.size():
		var w := BioWorker.new("c%d" % i, roles[i], centre + Vector2(-8.0 + (i % 6) * 3.2, 0.5 + (i / 6) * 3.4) * BioArt.UNIT, 1.0 + i * 0.7)
		w.aim = Vector2.RIGHT
		crowd.workers.append(w)
	crowd.workers[1].state = &"work"
	crowd.workers[1].work = 0.5
	crowd.workers[2].state = &"work"
	crowd.workers[2].work = 0.5
	crowd.queue_redraw()
	await create_timer(1.2).timeout  # the camera has caught up with the cell
	crowd.queue_redraw()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out_dir + "/crowd_roles.png")
	quit()
