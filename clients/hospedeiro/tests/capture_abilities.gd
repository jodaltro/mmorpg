extends SceneTree
## Visual check of every class ability (real renderer):
## godot --path clients/hospedeiro --script res://tests/capture_abilities.gd -- <output_dir>

const ONLY := []
const SHOTS := [
	["macrofago", [&"engolir", &"onda_de_pseudopodes", &"lisossomo_acido", &"muralha_de_carne"]],
	["neutrofilo", [&"rede_de_dna", &"explosao_neutrofilica", &"netose", &"degranulacao"]],
	["dendritica", [&"apresentar_antigeno", &"dendritos_em_chicote", &"chuva_de_esporos", &"mapa_quimico"]],
	["linfocito_b", [&"anticorpo_y", &"salva_de_anticorpos", &"opsonizacao", &"explosao_de_plasmocito"]],
	["t_citotoxico", [&"perforina", &"golpe_litico", &"apoptose", &"sinal_de_morte"]],
	["t_auxiliar", [&"citocina_curativa", &"canto_de_citocinas", &"chamado_a_linfa", &"febre_dirigida"]],
]


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
	world.camera.zoom = Vector2.ONE * 1.9
	var ctrl := world.player.get_node("Controller") as BioCellController
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)  # the mouse would overwrite the aim
	ctrl.set_aim(Vector2.RIGHT)
	for entry in SHOTS:
		for id in entry[1]:
			if not ONLY.is_empty() and not ONLY.has(id):
				continue
			world.genome.lineage = StringName(entry[0])
			world.player.combatant.set_genome(world.genome)
			await create_timer(1.0).timeout
			world.abilities.slots.clear()
			world.abilities.learn(id)
			world.player.combatant.reset_vitals()
			world.player.combatant.actor.vitals.membrane = 60.0
			var victims: Array[BioCellActor] = []
			for off in [Vector2(2.6, -0.6), Vector2(3.4, 0.8), Vector2(4.6, -0.2)]:
				var brain := BioFactory.spawn_virus(world, world.player.global_position + off * BioArt.UNIT, world.player)
				brain.set_process(false)
				victims.append(brain.get_parent() as BioCellActor)
			await create_timer(0.1).timeout
			var status := world.abilities.perform(0)
			print(id, " status ", status)
			for i in 3:
				await create_timer(0.1 if i < 2 else 0.45).timeout
				_shot(out_dir, "%s_%d" % [id, i])
			await create_timer(1.5).timeout
			for v in victims:
				if is_instance_valid(v):
					v.queue_free()
			await create_timer(0.2).timeout
	quit()


func _shot(out_dir: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
