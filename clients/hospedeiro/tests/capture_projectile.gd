extends SceneTree
## A B cell shooting its antibody with different projectile designs at a pack of virions (real renderer).
##   godot --path clients/hospedeiro --script res://tests/capture_projectile.gd -- <output_dir>

const DESIGNS := [
	{"name": "base", "traits": {}},
	{"name": "perfurante_reta", "traits": {"impacto": "perfurante", "trajetoria": "reta", "calibre": "fino"}},
	{"name": "explosivo_arco", "traits": {"impacto": "explosivo", "trajetoria": "arco", "calibre": "grosso"}},
	{"name": "fragmenta_espiral", "traits": {"impacto": "fragmenta", "trajetoria": "espiral", "calibre": "medio"}},
	{"name": "grudento_ondulada", "traits": {"impacto": "grudento", "trajetoria": "ondulada", "calibre": "medio"}},
]


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
	world.camera.zoom = Vector2.ONE * 1.0
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"linfocito_b"
	world.player.combatant.set_genome(world.genome)
	for id in [&"anticorpo_y", &"fabrica_de_plasmocito"]:
		world.abilities.learn(id)
	world.hud.visible = false
	var ctrl := world.player.get_node("Controller") as BioCellController
	for d in DESIGNS:
		world.apply_design(d["traits"], "debug" if not d["traits"].is_empty() else "nenhuma")
		world.player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
		world.player.combatant.actor._ready_at.clear()
		var dummies: Array[BioCellActor] = []
		for pos in [Vector2(4, 0), Vector2(6, 0.4), Vector2(8, -0.3), Vector2(6.5, 2.4), Vector2(9, 1.8)]:
			BioFactory.spawn_virus(world, world.player.global_position + pos * BioArt.UNIT, world.player)
			var v := world.viruses().back() as BioCellActor
			for c in v.get_children():
				if c is BioVirusBrain:
					c.queue_free()
			v.max_speed_units = 0.0
			v.combatant.actor.vitals.max_membrane = 400.0
			v.combatant.actor.vitals.membrane = 400.0
			dummies.append(v)
		await create_timer(0.3).timeout
		ctrl.set_aim(Vector2.RIGHT)
		world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
		world.abilities.perform(0)
		for k in 3:
			await create_timer(0.3).timeout
			root.get_texture().get_image().save_png("%s/%s_%d.png" % [out_dir, d["name"], k])
		var lost := dummies.map(func(v: BioCellActor) -> int: return int(400.0 - v.combatant.actor.vitals.membrane))
		print("RESULT ", d["name"], " damage per virion: ", lost)
		for v in dummies:
			if is_instance_valid(v):
				v.queue_free()
		await create_timer(0.6).timeout
	quit()
