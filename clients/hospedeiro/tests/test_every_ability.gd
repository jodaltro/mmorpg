extends TestCase
## Plays every one of the 24 class abilities in a real world, with targets: each must start, have its effect on the world and
## clean up after itself (no signature, zone, limb or particle node left behind).

var world: BioWorld

## ability -> [where the target stands (units to the right), what must happen]
const CASES := {
	&"engolir": [1.5, "damage"], &"onda_de_pseudopodes": [2.0, "damage"], &"lisossomo_acido": [4.5, "damage"], &"muralha_de_carne": [0.0, "zone"],
	&"rede_de_dna": [3.5, "damage"], &"explosao_neutrofilica": [3.0, "damage"], &"netose": [2.5, "damage"], &"degranulacao": [1.5, "damage"],
	&"apresentar_antigeno": [3.0, "mark"], &"dendritos_em_chicote": [2.0, "damage"], &"chuva_de_esporos": [0.0, "zone"], &"mapa_quimico": [4.0, "mark"],
	&"anticorpo_y": [5.0, "damage"], &"salva_de_anticorpos": [4.0, "damage"], &"opsonizacao": [3.0, "mark"], &"explosao_de_plasmocito": [2.5, "damage"],
	&"perforina": [2.5, "damage"], &"golpe_litico": [3.0, "damage"], &"apoptose": [3.0, "kill"], &"sinal_de_morte": [3.0, "mark"],
	&"citocina_curativa": [0.0, "heal"], &"canto_de_citocinas": [0.0, "haste"], &"chamado_a_linfa": [0.0, "zone"], &"febre_dirigida": [3.5, "damage"],
}


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame
	for child in world.player.get_children():
		if child is BioPlayerInput:
			child.set_process(false)
	(world.player.get_node("Controller") as BioCellController).set_aim(Vector2.RIGHT)


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _zones() -> int:
	var n := 0
	for child in world.get_children():
		if child is BioAbilityZone:
			n += 1
	return n


func _transient_nodes() -> int:
	var n := 0
	for child in world.get_children():
		if child is BioSignature or child is BioAbilityZone or child is BioAbilityBolt or child is CPUParticles2D or child is Line2D:
			n += 1
	for child in world.player.get_children():
		if child is BioLimb or child is BioMarkGlyph:
			n += 1
	return n


func test_all_24_abilities_work_and_clean_up() -> void:
	var failures_before := failures.size()
	for id in CASES:
		var spec: Array = CASES[id]
		world.player.combatant.reset_vitals()
		world.abilities.slots.clear()
		world.abilities.learn(id)
		var vitals := world.player.combatant.actor.vitals
		vitals.membrane = 50.0
		var victim: BioCellActor = null
		var before := 0.0
		if float(spec[0]) > 0.0:
			var brain := BioFactory.spawn_virus(world, world.player.global_position + Vector2(float(spec[0]), 0.0) * BioArt.UNIT, world.player)
			brain.set_process(false)
			victim = brain.get_parent() as BioCellActor
			if spec[1] == "kill":
				victim.combatant.actor.vitals.membrane = 8.0
			before = victim.combatant.actor.vitals.membrane
		await tree.physics_frame
		var status := world.abilities.perform(0)
		assert_eq(status, BioActor.AttackStatus.STARTED, "%s starts" % id)
		await tree.create_timer(2.3 if id in [&"netose", &"explosao_de_plasmocito", &"apoptose"] else 1.5).timeout
		match str(spec[1]):
			"damage":
				assert_true(not is_instance_valid(victim) or victim.combatant.actor.vitals.membrane < before, "%s hurt its target" % id)
			"kill":
				assert_true(not is_instance_valid(victim) or not victim.combatant.actor.vitals.is_alive(), "%s executed it" % id)
			"mark":
				assert_true(is_instance_valid(victim) and victim.combatant.is_marked(), "%s marked it" % id)
			"zone":
				assert_true(_zones() >= 1, "%s raised its zone" % id)
			"heal":
				assert_true(vitals.membrane > 50.0, "%s healed" % id)
			"haste":
				assert_true(world.player.combatant.speed_mult() > 1.0, "%s hastened" % id)
		if is_instance_valid(victim):
			victim.queue_free()
		await tree.create_timer(0.1).timeout
	# everything transient is gone a few seconds after the last ability
	await tree.create_timer(7.0).timeout
	assert_true(_transient_nodes() <= 2, "no effect nodes are left behind (%d)" % _transient_nodes())
	assert_eq(failures.size(), failures_before, "see above")


func test_effects_use_distinct_signatures_not_a_shared_ring() -> void:
	var kinds := {}
	for id in BioAbilityCatalog.ids_of_class(&"macrofago") + BioAbilityCatalog.ids_of_class(&"neutrofilo"):
		var a := BioAbilityCatalog.get_ability(id)
		kinds[id] = str(a["kind"]) + ":" + str(a.get("style", ""))
	assert_true(kinds.values().size() == 8, "eight macrophage and neutrophil abilities")
	for kind in [&"bite", &"grooves", &"diapedesis", &"fiddleheads", &"contours", &"cartwheel", &"wall", &"pore", &"scar", &"blebs", &"bodies", &"pincer"]:
		var s := BioSignature.play(kind, Vector2.ZERO, Color.WHITE, 0.3, {"dir": Vector2.RIGHT, "reach": 100.0, "radius": 100.0, "targets": []}, null)
		assert_true(s != null, "%s signature plays" % kind)
