extends TestCase
## Plays every one of the 24 abilities of the six older classes in a real world, with targets: each must start, have its effect on the world and
## clean up after itself (no signature, zone, limb or particle node left behind).

var world: BioWorld

## ability -> [where the target stands (units to the right), what must happen]
const CASES := {
	&"engolir": [1.5, "damage"], &"onda_de_pseudopodes": [2.0, "damage"], &"contragolpe": [0.0, "counter"], &"polarizacao": [0.0, "stance"],
	&"rede_de_dna": [3.5, "damage"], &"explosao_neutrofilica": [3.0, "damage"], &"diapedese": [0.7, "damage"], &"surto_oxidativo": [0.0, "frenzy"],
	&"varredura": [3.0, "damage"], &"dendritos_em_chicote": [2.0, "damage"], &"maturacao": [0.0, "empower"], &"passagem_linfatica": [0.0, "portal"],
	&"anticorpo_y": [5.0, "damage"], &"complemento": [3.0, "complement"], &"memoria_imunologica": [2.0, "replay"], &"fabrica_de_plasmocito": [4.0, "damage"],
	&"perforina": [2.5, "damage"], &"salto_letal": [5.5, "damage"], &"sinapse_letal": [3.0, "damage"], &"lise_em_massa": [4.0, "damage"],
	&"febre_contagiosa": [3.0, "damage"], &"chamado_aos_auxiliares": [0.0, "allies"], &"segunda_chance": [0.0, "guardian"], &"transfusao": [0.0, "heal"],
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


func test_the_older_24_abilities_work_and_clean_up() -> void:
	var failures_before := failures.size()
	for id in CASES:
		var spec: Array = CASES[id]
		world.player.combatant.reset_vitals()
		world.abilities.slots.clear()
		world.abilities.learn(id)
		if spec[1] == "replay":  # a memory needs something to remember
			world.abilities.learn(&"onda_de_pseudopodes")
			world.abilities.perform_id(&"onda_de_pseudopodes")
		var vitals := world.player.combatant.actor.vitals
		vitals.membrane = 50.0
		var victim: BioCellActor = null
		var before := 0.0
		if float(spec[0]) > 0.0:
			var brain := BioFactory.spawn_virus(world, world.player.global_position + Vector2(float(spec[0]), 0.0) * BioArt.UNIT, world.player)
			brain.set_process(false)
			victim = brain.get_parent() as BioCellActor
			victim.combatant.actor.vitals.membrane = 400.0
			before = victim.combatant.actor.vitals.membrane
		await tree.physics_frame
		var status := world.abilities.perform_id(id)
		assert_eq(status, BioActor.AttackStatus.STARTED, "%s starts" % id)
		await tree.create_timer(2.5 if id in [&"salto_letal", &"sinapse_letal", &"febre_contagiosa"] else 1.5).timeout
		match str(spec[1]):
			"damage":
				assert_true(not is_instance_valid(victim) or victim.combatant.actor.vitals.membrane < before, "%s hurt its target" % id)
			"complement":
				assert_true(is_instance_valid(victim) and victim.combatant.complement_hits() > 0, "%s marked it" % id)
			"replay":
				assert_true(is_instance_valid(victim) and before - victim.combatant.actor.vitals.membrane > float(BioAbilityCatalog.get_ability(&"onda_de_pseudopodes")["damage"]) * 0.9, "%s repeated the wave" % id)
			"counter":
				assert_true(world.player.combatant.is_countering(), "%s is up" % id)
			"stance":
				assert_eq(world.player.combatant.stance_now(), &"m1", "%s changed the form" % id)
			"frenzy":
				assert_true(world.player.combatant.is_frenzied(), "%s started" % id)
			"empower":
				assert_true(world.player.combatant.empower_charges() > 0, "%s gave charges" % id)
			"portal":
				assert_true(is_instance_valid(BioPortalPair.current), "%s opened its doors" % id)
			"allies":
				assert_true(tree.get_nodes_in_group("allies").size() >= 1, "%s called someone" % id)
			"guardian":
				assert_true(world.player.combatant.has_guardian(), "%s is ready" % id)
			"heal":
				assert_true(vitals.membrane > 50.0, "%s healed" % id)
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
