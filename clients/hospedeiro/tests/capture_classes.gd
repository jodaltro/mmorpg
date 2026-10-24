extends SceneTree
## The four newer classes, plain and risen (wearing four of their own genes), and each one casting its signature abilities at a few
## enemies (real renderer):  godot --path clients/hospedeiro --script res://tests/capture_classes.gd -- <output_dir>

var world: BioWorld
var out_dir := "."

const CLASSES := [&"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]
const CASTS := {
	&"mastocito": [&"chuva_de_granulos", &"edema", &"choque_anafilatico", &"alarme_de_mastocito"],
	&"eosinofilo": [&"granulo_caustico", &"nuvem_de_peroxidase", &"marca_de_ige", &"proteina_basica"],
	&"celula_nk": [&"golpe_natural", &"cadeia_letal", &"ausencia_de_mhc", &"explosao_de_interferon"],
	&"t_regulador": [&"supressao_celular", &"zona_de_tolerancia", &"muro_de_tolerancia", &"silencio_imunologico"],
}


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
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)
	for lineage in CLASSES:
		world.debug_become(lineage)
		world.camera.zoom = Vector2.ONE * 2.4
		await create_timer(0.9).timeout
		await _shot("class_%s_plain" % lineage)
		world.genome.equipped = []
		for id in BioGeneCatalog.class_ids(lineage).slice(0, 4):
			world.genome.equip(id)
		world.player.combatant.set_genome(world.genome)
		await create_timer(1.6).timeout
		await _shot("class_%s_risen" % lineage)
		world.genome.equipped = []
		world.player.combatant.set_genome(world.genome)
		world.camera.zoom = Vector2.ONE * 1.1
		var foes: Array[BioCellActor] = []
		for k in 4:
			var def := BioDungeonPlan.enemy(&"cilindro_hialino").duplicate()
			def["hp"] = 900.0
			def["speed"] = 0.0
			var brain := BioFactory.spawn_enemy(world, world.player.global_position + Vector2(3.0 + k * 1.4, -3.0 + k * 2.0) * BioArt.UNIT, world.player, def, 1.0, "viruses")
			(brain as Node).set_process(false)
			foes.append(brain.get_parent() as BioCellActor)
		await create_timer(0.3).timeout
		var step := 0
		for ability in CASTS[lineage]:
			world.player.combatant.actor._ready_at.clear()
			world.player.combatant.actor.vitals.atp = world.player.combatant.actor.vitals.max_atp
			world.abilities.perform_id(ability)
			await create_timer(0.55).timeout
			await _shot("cast_%s_%d_%s" % [lineage, step, ability])
			step += 1
			await create_timer(0.3).timeout
		for f in foes:
			f.queue_free()
		for c in world.get_children():
			if c is BioClot or c is BioAbilityZone:
				c.queue_free()
		await create_timer(0.4).timeout
	quit()


func _shot(name: String) -> void:
	await create_timer(0.15).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
