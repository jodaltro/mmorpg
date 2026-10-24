extends SceneTree
## Records frames of every class ability in slow motion (real renderer) for GIFs:
## godot --path clients/hospedeiro --script res://tests/capture_gifs.gd -- <output_dir> [ability ids...]

const CASES := {
	&"macrofago": [[&"engolir", 1.6], [&"onda_de_pseudopodes", 2.0], [&"contragolpe", 0.0], [&"polarizacao", 0.0]],
	&"neutrofilo": [[&"rede_de_dna", 3.2], [&"explosao_neutrofilica", 2.4], [&"diapedese", 1.0], [&"surto_oxidativo", 0.0]],
	&"dendritica": [[&"varredura", 3.0], [&"dendritos_em_chicote", 2.2], [&"maturacao", 0.0], [&"passagem_linfatica", 0.0]],
	&"linfocito_b": [[&"anticorpo_y", 4.0], [&"complemento", 3.0], [&"memoria_imunologica", 2.0], [&"fabrica_de_plasmocito", 4.0]],
	&"t_citotoxico": [[&"perforina", 2.6], [&"salto_letal", 5.5], [&"sinapse_letal", 3.0], [&"lise_em_massa", 4.0]],
	&"t_auxiliar": [[&"febre_contagiosa", 3.0], [&"chamado_aos_auxiliares", 0.0], [&"segunda_chance", 0.0], [&"transfusao", 0.0]],
}
const FRAMES := 44
const STEP := 0.075


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "."
	var only: Array = args.slice(1)
	var world := load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	root.add_child(world)
	await create_timer(0.6).timeout
	world.camera.zoom = Vector2.ONE * 2.1
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	var ctrl := world.player.get_node("Controller") as BioCellController
	ctrl.set_aim(Vector2.RIGHT)
	for lineage in CASES:
		world.genome.lineage = lineage
		world.genome.equipped = []
		world.player.combatant.set_genome(world.genome)
		await create_timer(1.0).timeout
		for entry in CASES[lineage]:
			var id: StringName = entry[0]
			if not only.is_empty() and not only.has(str(id)):
				continue
			for child in world.get_children():
				if child is BioAbilityZone or child is BioSignature or child is BioAbilityBolt:
					child.queue_free()
			for child in world.player.get_children():
				if child is BioLimb or child is BioMarkGlyph:
					child.queue_free()
			await create_timer(0.3).timeout
			var dir := "%s/%s" % [out_dir, id]
			DirAccess.make_dir_recursive_absolute(dir)
			world.player.combatant.reset_vitals()
			world.player.combatant.actor.vitals.membrane = 55.0
			world.abilities.slots.clear()
			world.abilities.learn(id)
			var victims: Array[BioCellActor] = []
			if float(entry[1]) > 0.0:
				for off in [Vector2(float(entry[1]), 0.0), Vector2(float(entry[1]) + 0.9, -1.0), Vector2(float(entry[1]) + 0.5, 1.1)]:
					var brain := BioFactory.spawn_virus(world, world.player.global_position + off * BioArt.UNIT, world.player)
					brain.set_process(false)
					victims.append(brain.get_parent() as BioCellActor)
				if id == &"sinapse_letal":
					victims[0].combatant.actor.vitals.membrane = 8.0
			await create_timer(0.15).timeout
			Engine.time_scale = 0.45
			world.abilities.perform(0)
			for i in FRAMES:
				await create_timer(STEP, true, false, true).timeout
				root.get_texture().get_image().save_png("%s/f%02d.png" % [dir, i])
			Engine.time_scale = 1.0
			for v in victims:
				if is_instance_valid(v):
					v.queue_free()
			await create_timer(2.0).timeout
	quit()
