extends SceneTree
## Organelles under the microscope (real renderer): an atlas of every kind at a large size, and frames of classes wearing their
## six mutations with the organelles drifting inside the membrane (for a GIF).
##   godot --path clients/hospedeiro --script res://tests/capture_organelles.gd -- <output_dir>

const KINDS := ["mitochondria", "golgi", "er", "microtubules", "centriole", "vesicles", "vacuole", "crystal", "tubules", "autophagosome", "droplets", "ribosomes", "lysosome", "peroxisome"]
const COLORS := ["#ffb347", "#6ff2ff", "#7ab8ff", "#ff9aa5", "#8fe9ff", "#ff7a9c", "#c4ff3a", "#c9a7ff", "#9fe8ff", "#ff5c8a", "#ffe08a", "#ffb8f0", "#b6ff3a", "#ffd0a0"]
const CLASSES := [&"macrofago", &"dendritica", &"linfocito_b"]
const FRAMES := 60
const STEP := 0.09


class Atlas:
	extends Node2D
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.05))
		for i in 14:
			var at := Vector2(130 + (i % 5) * 255, 130 + (i / 5) * 230)
			draw_circle(at, 95.0, Color(0.1, 0.25, 0.6, 0.18))
			draw_arc(at, 95.0, 0.0, TAU, 48, Color(0.3, 0.55, 1.0, 0.6), 3.0, true)
			var mark := {"kind": KINDS[i], "color": COLORS[i], "count": 4}
			BioOrganelles.draw_organelle(self, mark, at, 52.0, t, t * 0.1, i * 1.3)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var atlas := Atlas.new()
	root.add_child(atlas)
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("%s/atlas.png" % out_dir)
	atlas.queue_free()
	await process_frame
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.6).timeout
	world.camera.zoom = Vector2.ONE * 3.4
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	for lineage in CLASSES:
		world.genome.lineage = lineage
		world.genome.equipped = []
		for id in BioGeneCatalog.class_ids(lineage):
			world.genome.equip(id)
		world.player.combatant.set_genome(world.genome)
		DirAccess.make_dir_recursive_absolute("%s/%s" % [out_dir, lineage])
		await create_timer(1.0).timeout
		for i in FRAMES:
			await create_timer(STEP).timeout
			root.get_texture().get_image().save_png("%s/%s/f%02d.png" % [out_dir, lineage, i])
	quit()
