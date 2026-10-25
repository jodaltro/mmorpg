extends TestCase

var world: BioWorld

func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	await tree.physics_frame

func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func _enemy(at: Vector2) -> BioCellActor:
	var brain := BioFactory.spawn_virus(world, at, world.player)
	brain.set_process(false)
	var enemy := brain.get_parent() as BioCellActor
	enemy.set_physics_process(false)
	enemy.combatant.actor.vitals.max_membrane = 1000
	enemy.combatant.actor.vitals.membrane = 1000
	return enemy

func _equip(lineage: StringName, genes: Array[StringName]) -> void:
	var genome := BioGenome.new()
	genome.lineage = lineage
	genome.equipped = genes
	world.genome = genome
	world.player.combatant.set_genome(genome)

func _zones() -> Array:
	return world.get_children().filter(func(node: Node) -> bool: return node is BioAbilityZone)

func test_every_class_has_a_transform_and_foreign_genes_do_not_trigger() -> void:
	for lineage in BioWorld.DEBUG_CLASSES:
		var count := 0
		for id in BioGeneCatalog.class_ids(lineage):
			var gene := BioGeneCatalog.get_gene(id)
			if not gene.transformation.is_empty():
				count += 1
				assert_true(gene.summary().begins_with(str(gene.transformation.description)), "mechanic before percentages")
		assert_true(count > 0, "class has a mechanical progression reward: " + String(lineage))
	_equip(&"neutrofilo", [&"fagossomo_profundo"])
	assert_true(world.genome.transformations(&"engolir").is_empty())
	assert_eq(BioMutationTracker.THRESHOLD, 120)

func test_paid_toxin_cast_adds_two_projectiles_without_extra_payment_and_cannot_repeat_on_cooldown() -> void:
	_equip(&"", [&"vesicula_toxica"])
	var executor := world.player.get_node_or_null("Attacks") as BioAttackExecutor
	if executor == null:
		for child in world.player.get_children():
			if child is BioAttackExecutor: executor = child
	var before := world.player.combatant.actor.vitals.atp
	var definition := world.player.combatant.actor.attack_def(BioAttackCatalog.TOXIN_SPIT)
	assert_eq(executor.perform(BioAttackCatalog.TOXIN_SPIT, Vector2.RIGHT), BioActor.AttackStatus.STARTED)
	await tree.process_frame
	var bolts := world.get_children().filter(func(node: Node) -> bool: return node is BioAbilityBolt)
	assert_eq(bolts.size(), 2)
	assert_near(world.player.combatant.actor.vitals.atp, before - definition.atp_cost, 0.5)
	assert_near((bolts[0] as BioAbilityBolt)._def.damage, definition.damage * 0.45)
	assert_eq(executor.perform(BioAttackCatalog.TOXIN_SPIT, Vector2.RIGHT), BioActor.AttackStatus.ON_COOLDOWN)
	await tree.process_frame
	assert_eq(world.get_children().filter(func(node: Node) -> bool: return node is BioAbilityBolt).size(), 2)

func test_acid_pool_has_real_damage_slow_and_preview_has_no_gameplay() -> void:
	_equip(&"macrofago", [&"fagossomo_profundo"])
	var enemy := _enemy(world.player.position + Vector2.RIGHT * 2 * BioArt.UNIT)
	await tree.physics_frame
	var before := enemy.combatant.actor.vitals.membrane
	BioGeneEffects.preview(world.player, &"engolir", Vector2.RIGHT)
	assert_eq(_zones().size(), 0)
	assert_eq(enemy.combatant.actor.vitals.membrane, before)
	BioGeneEffects.apply(world.player, &"engolir", Vector2.RIGHT, world.player.combatant.actor.attack_def(&"engolir"))
	assert_eq(_zones().size(), 1)
	var zone := _zones()[0] as BioAbilityZone
	assert_eq(zone.style, "acid")
	zone._pulse()
	assert_true(enemy.combatant.actor.vitals.membrane < before)
	assert_true(enemy.is_slowed())

func test_chain_hits_at_most_three_enemies_once() -> void:
	_equip(&"dendritica", [&"dendritos_sensores"])
	var enemies: Array[BioCellActor] = []
	for i in 4:
		enemies.append(_enemy(world.player.position + Vector2(1 + i * 0.6, 0) * BioArt.UNIT))
	await tree.physics_frame
	BioGeneEffects.apply(world.player, &"dendritos_em_chicote", Vector2.RIGHT, world.player.combatant.actor.attack_def(&"dendritos_em_chicote"))
	var hits := 0
	for enemy in enemies:
		if enemy.combatant.actor.vitals.membrane < 1000: hits += 1
	assert_eq(hits, 3)

func test_free_casts_do_not_multiply_gene_effects() -> void:
	_equip(&"macrofago", [&"fagossomo_profundo"])
	world.abilities.learn(&"engolir")
	world.abilities.perform_free(&"engolir")
	assert_eq(_zones().size(), 0, "free echoes do not create another paid-cast reward")
	world.abilities.perform_id(&"engolir")
	assert_eq(_zones().size(), 1)

func test_rupture_waits_and_does_not_explode_after_death() -> void:
	_equip(&"t_citotoxico", [&"granzima_b"])
	var enemy := _enemy(world.player.position + Vector2.RIGHT * 2 * BioArt.UNIT)
	await tree.physics_frame
	BioGeneEffects.apply(world.player, &"perforina", Vector2.RIGHT, world.player.combatant.actor.attack_def(&"perforina"))
	assert_eq(enemy.combatant.actor.vitals.membrane, 1000.0)
	await tree.create_timer(0.55).timeout
	assert_true(enemy.combatant.actor.vitals.membrane < 1000)
	var before := enemy.combatant.actor.vitals.membrane
	BioGeneEffects.apply(world.player, &"perforina", Vector2.RIGHT, world.player.combatant.actor.attack_def(&"perforina"))
	world.player.set_active(false)
	await tree.create_timer(0.55).timeout
	assert_eq(enemy.combatant.actor.vitals.membrane, before)

func test_gene_guard_has_own_cooldown_and_mend_does_not_heal_enemies() -> void:
	_equip(&"", [&"nucleo_reativo"])
	var def := world.player.combatant.actor.attack_def(BioAttackCatalog.MEMBRANE_DASH)
	BioGeneEffects.apply(world.player, BioAttackCatalog.MEMBRANE_DASH, Vector2.RIGHT, def)
	var ready: Dictionary = world.player.get_meta("gene_ready_at")
	var before: float = ready.nucleo_reativo
	BioGeneEffects.apply(world.player, BioAttackCatalog.MEMBRANE_DASH, Vector2.RIGHT, def)
	assert_eq(ready.nucleo_reativo, before)
	_equip(&"t_auxiliar", [&"interleucina_2"])
	world.player.combatant.actor.vitals.membrane = 20
	var enemy := _enemy(world.player.position + Vector2.RIGHT * BioArt.UNIT)
	enemy.combatant.actor.vitals.membrane = 50
	BioGeneEffects.apply(world.player, &"chamado_aos_auxiliares", Vector2.RIGHT, world.player.combatant.actor.attack_def(&"chamado_aos_auxiliares"))
	assert_eq(world.player.combatant.actor.vitals.membrane, 44.0)
	assert_eq(enemy.combatant.actor.vitals.membrane, 50.0)

func test_gene_reward_call_opens_library_without_forcing_a_choice() -> void:
	world.sync._last_seq = 0
	world.sync._apply_events([{"seq":1, "kind":"gene-acquired", "text":"Núcleo Reativo conquistado"}])
	assert_true(world.tray._chips.has("gene-reward"))
	assert_true(not world.body_panel.is_open())
	world._open_from_chip("gene-reward")
	assert_eq(world.body_panel.tab, BioBodyPanel.GENES)
	assert_true(not world.tray._chips.has("gene-reward"))

func test_mutation_preview_explains_full_effect_without_committing_choice() -> void:
	world.panel.show_offer([&"vesicula_toxica", &"nucleo_reativo"])
	world.body_panel.open(BioBodyPanel.GENES)
	world.body_panel.preview_mutation(0)
	assert_eq(world.body_panel._mutation_preview, "vesicula_toxica")
	var text: String = world.body_panel.content_text()
	assert_true(text.contains("45%"))
	assert_true(text.contains("AGORA → DEPOIS"))
	assert_true(world.genome.equipped.is_empty())
	assert_eq(world.panel.entries().size(), 2)

func test_local_world_reset_clears_reward_and_gene_cooldowns() -> void:
	world.tray.set_call("gene-reward", "mutation", "Gene", "Conquistado")
	world.player.set_meta("gene_ready_at", {"nucleo_reativo":999999})
	await world.restart_world(false)
	assert_true(not world.tray._chips.has("gene-reward"))
	assert_true(not world.player.has_meta("gene_ready_at"))
