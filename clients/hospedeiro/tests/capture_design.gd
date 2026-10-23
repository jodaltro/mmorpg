extends SceneTree
## Cells with different Jev designs, and the same ability in each flavour (real renderer).
##   godot --path clients/hospedeiro --script res://tests/capture_design.gd -- <output_dir>

const DESIGNS := [
	{"name": "lutador", "traits": {"nucleo": "estrela", "membrana": "espinhosa", "organelas": "granulos", "brilho": "carmim", "efeito": "chama"}},
	{"name": "andarilho", "traits": {"nucleo": "feijao", "membrana": "espinhosa", "organelas": "vacuolos", "brilho": "carmim", "efeito": "organico"}},
	{"name": "cristalino", "traits": {"nucleo": "esfera", "membrana": "dupla", "organelas": "vesiculas", "brilho": "ciano", "efeito": "cristal"}},
	{"name": "eletrico", "traits": {"nucleo": "trevo", "membrana": "contas", "organelas": "tubulos", "brilho": "violeta", "efeito": "eletrico"}},
	{"name": "nevoa", "traits": {"nucleo": "flor", "membrana": "ondulada", "organelas": "mitocondrias", "brilho": "jade", "efeito": "nevoa"}},
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
	world.camera.zoom = Vector2.ONE * 2.0
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	world.genome.lineage = &"t_citotoxico"
	world.player.combatant.set_genome(world.genome)
	for id in [&"perforina", &"golpe_litico", &"apoptose", &"sinal_de_morte"]:
		world.abilities.learn(id)
	var ctrl := world.player.get_node("Controller") as BioCellController
	for d in DESIGNS:
		world.apply_engine_look({"traits": d["traits"]})
		world.player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
		await create_timer(0.7).timeout
		world.hud.visible = false
		root.get_texture().get_image().save_png("%s/body_%s.png" % [out_dir, d["name"]])
		ctrl.set_aim(Vector2.RIGHT)
		world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
		world.abilities.perform(0)
		await create_timer(0.16).timeout
		root.get_texture().get_image().save_png("%s/fx_%s.png" % [out_dir, d["name"]])
		world.abilities.perform(1)
		await create_timer(0.2).timeout
		root.get_texture().get_image().save_png("%s/fx2_%s.png" % [out_dir, d["name"]])
		await create_timer(1.0).timeout
	quit()
