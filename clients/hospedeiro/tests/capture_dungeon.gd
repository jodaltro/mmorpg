extends SceneTree
## Frames of the granuloma for a GIF (real renderer): the first room and the boss room, with a cell fighting with its abilities.
##   godot --path clients/hospedeiro --script res://tests/capture_dungeon.gd -- <output_dir>

const ROOMS := [
	{"id": "guarda-de-linfocitos", "name": "A guarda de linfócitos", "kind": "guard"},
	{"id": "parede-de-macrofagos", "name": "A parede de macrófagos", "kind": "wall"},
	{"id": "anel-interno", "name": "O anel interno", "kind": "wall"},
	{"id": "nucleo-necrotico", "name": "O núcleo necrótico", "kind": "core"},
	{"id": "bacilo", "name": "O bacilo", "kind": "boss"},
]
const FRAMES := 70
const STEP := 0.08


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
	world.camera.zoom = Vector2.ONE * 1.35
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"t_citotoxico"
	world.player.combatant.set_genome(world.genome)
	for id in [&"perforina", &"salto_letal", &"sinapse_letal", &"lise_em_massa"]:
		world.abilities.learn(id)
	var ctrl := world.player.get_node("Controller") as BioCellController
	for pass_name in ["room1", "boss"]:
		var index := 0 if pass_name == "room1" else 4
		world.player.combatant.reset_vitals()
		world.dungeon.finish(false)
		world.dungeon.start({"state": "active", "seed": 424242, "room": index, "rooms": ROOMS, "modifier": {"id": "necrose-viva", "name": "Necrose viva", "desc": ""}})
		DirAccess.make_dir_recursive_absolute("%s/%s" % [out_dir, pass_name])
		await create_timer(0.5).timeout
		Engine.time_scale = 0.6
		for i in FRAMES:
			var target: BioCellActor = null
			var best := INF
			for e in world.dungeon.enemies():
				var d := (e as BioCellActor).global_position.distance_to(world.player.global_position)
				if d < best:
					best = d
					target = e
			if target != null:
				var to := target.global_position - world.player.global_position
				ctrl.set_aim(to)
				ctrl.move(to.normalized() * (0.0 if best < 2.6 * BioArt.UNIT else 0.6) if best > 4.0 * BioArt.UNIT else -to.normalized() * 0.3)
				ctrl.lash()
				if i % 4 == 0:
					world.abilities.perform((i / 4) % 4)
			world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
			await create_timer(STEP, true, false, true).timeout
			root.get_texture().get_image().save_png("%s/%s/f%02d.png" % [out_dir, pass_name, i])
		Engine.time_scale = 1.0
	quit()
