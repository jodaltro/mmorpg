extends SceneTree
## The procedural rooms of both dungeons and the wild things of each organ (real renderer):
##   godot --path clients/hospedeiro --script res://tests/capture_rooms.gd -- <output_dir>

var world: BioWorld
var out_dir := "."

const NATIVES := [&"trombo", &"pneumococo", &"esporo_fungico", &"placa", &"embolo", &"plasmodio", &"esporo_de_bile"]
const NEW_NATIVES := [&"meningococo", &"bacteria_encapsulada", &"bacteria_enterica", &"verme_intestinal", &"esporo_de_clostridio", &"cristal_de_urato", &"calculo_renal", &"espiculo_de_oxalato"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	out_dir = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.8).timeout
	world.debug_god = true
	var n := 0
	for dungeon in ["granuloma", "cordoes-hepaticos", "centro-germinativo", "criptas-profundas", "nefrons"]:
		for kind in ["ambush", "pillars", "nest", "hazard"]:
			n += 1
			world.dungeon.start({"dungeon": dungeon, "name": dungeon, "state": "active", "seed": 1000 + n * 37, "room": 0, "rooms": [{"id": "x", "name": "x", "kind": kind}], "modifier": null})
			world.camera.zoom = Vector2.ONE * 0.75
			await create_timer(1.4).timeout
			await _shot("room_%s_%s" % [dungeon, kind])
			world.dungeon.finish(false)
			await create_timer(0.2).timeout
	world.dungeon.finish(false)
	world.camera.zoom = Vector2.ONE * 1.6
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.FIGADO)
	await create_timer(0.5).timeout
	for i in NATIVES.size():
		var def := BioDungeonPlan.enemy(NATIVES[i])
		var brain := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(-9.0 + i * 3.0, -4.0) * BioArt.UNIT, world.player, def, 0.0, "viruses")
		(brain as Node).set_process(false)
	await create_timer(0.8).timeout
	await _shot("natives")
	for e in world.get_tree().get_nodes_in_group("viruses"):
		e.queue_free()
	world.player.global_position = BioBodyMap.center_px(BioBodyMap.RIM)
	await create_timer(0.5).timeout
	for i in NEW_NATIVES.size():
		var def2 := BioDungeonPlan.enemy(NEW_NATIVES[i])
		var brain2 := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(-10.5 + i * 3.0, -4.0) * BioArt.UNIT, world.player, def2, 0.0, "viruses")
		(brain2 as Node).set_process(false)
	await create_timer(0.8).timeout
	await _shot("natives_2")
	quit()


func _shot(name: String) -> void:
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
