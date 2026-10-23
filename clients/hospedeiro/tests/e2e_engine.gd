extends SceneTree
## End-to-end check against a running engine (needs a real renderer for the screenshots):
##   godot --path clients/hospedeiro --script res://tests/e2e_engine.gd -- <engine_url> <output_dir>
## Prints STEP lines and exits 1 at the first step that does not happen in time.

var world: BioWorld
var out_dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url: String = args[0] if args.size() > 0 else "http://127.0.0.1:8096"
	out_dir = args[1] if args.size() > 1 else "."
	world = load("res://scenes/main.tscn").instantiate() as BioWorld
	world.save_path = ""
	world.engine_url = url
	world.identity_path = "user://e2e_identity_%d.json" % Time.get_ticks_usec()
	world.virus_count = 0  # a quiet body: the scripted cell is not attacked while it runs the steps
	root.add_child(world)

	if not await _until(func() -> bool: return world.sync.link.online, 20.0):
		return _fail("connect")
	_step("connected as %s" % world.sync.link.player_id)

	# A real deed: a nutrient placed on the cell is absorbed through the normal combat path.
	BioFactory.spawn_nutrient(world, world.player.global_position, BioNutrientRules.Kind.GLUCOSE)
	if not await _until(func() -> bool: return int(_self_num().get("nutrientes", 0)) >= 1, 10.0):
		return _fail("nutrient confirmed to the engine")
	_step("nutrient absorbed and confirmed")

	if not await _until(func() -> bool: return world.sync.system.offer_key.begins_with("primeiro-mergulho"), 30.0):
		return _fail("the stroma calls (offer primeiro-mergulho)")
	_step("offer shown: %s" % world.sync.system.offer_text().get_slice("\n", 1))
	await _shot("e2e_01_offer")
	world.sync._answer_offer(true)
	if not await _until(func() -> bool: return _quest_state("primeiro-mergulho") == "active", 10.0):
		return _fail("quest accepted")
	_step("quest accepted")

	world.player.global_position = BioBodyMap.center_px(BioBodyMap.SANGUE)
	if not await _until(func() -> bool: return _quest_state("primeiro-mergulho") == "done", 15.0):
		return _fail("diving into the blood completes the quest")
	_step("entered the blood: quest done")
	await _shot("e2e_02_blood")

	world.virus_destroyed.emit()  # as the combat server would after a kill
	if not await _until(func() -> bool: return _believes("assinatura", "virion"), 10.0):
		return _fail("seeing a virion teaches its signature")
	_step("knows the virion's signature")

	await world.sync.open_menu()
	var pick := -1
	for i in world.sync.system.menu_items.size():
		var item: Dictionary = world.sync.system.menu_items[i]
		var item_args: Dictionary = item.get("args", {})
		if item.get("action", "") == "contar" and str(item_args.get("npc", "")) == "dendra" and str(item_args.get("p", "")) == "assinatura":
			pick = i
	await _shot("e2e_03_menu")
	if pick < 0:
		return _fail("menu offers telling Dendra (got %s)" % str(world.sync.system.menu_items))
	await world.sync.choose(pick)
	if not await _until(func() -> bool: return world.sync.system.feed_text().contains("antígeno"), 20.0):
		return _fail("Dendra arms the defense")
	_step("Dendra armed the defense")
	await _shot("e2e_04_defense")

	# Evolution: confirmed kills build pressure in the engine; the advisor picks where the body leans.
	for i in 3:
		world.virus_destroyed.emit()
	if not await _until(func() -> bool: return not world.engine_offer.is_empty(), 20.0):
		return _fail("the engine offers a mutation once the pressure overflows")
	_step("mutation offer from the engine, the body leans to %s (offer %s)" % [world.engine_featured, str(world.engine_offer)])
	await _shot("e2e_05_evolution")
	var featured := world.engine_featured
	world.pick_mutation(0)
	if not await _until(func() -> bool: return world.genome.has_gene(StringName(featured.replace("-", "_"))), 10.0):
		return _fail("choosing expresses the gene")
	_step("expressed %s" % featured)

	# Differentiation: maturity from deeds opens the first tier; the advisor says where the body leans.
	for i in 5:
		world.virus_destroyed.emit()
	if not await _until(func() -> bool: return not world.engine_lineage_offer.is_empty(), 25.0):
		return _fail("the engine offers a lineage once the cell is mature")
	_step("lineage offer, the body leans to %s (of %d)" % [world.engine_lineage_featured, world.engine_lineage_offer.size()])
	await _shot("e2e_05b_lineage")
	var picked_lineage := str(world.engine_lineage_offer[0].get("id", ""))
	world.pick_mutation(0)
	if not await _until(func() -> bool: return world.lineage_id == BioLineageCatalog.normalise(picked_lineage), 10.0):
		return _fail("choosing differentiates")
	_step("differentiated into %s: the body is now a %s" % [picked_lineage, world.sync._world.player.get_child(2).form if false else str(world.lineage_id)])

	# The second tier is the class: more deeds, a second offer, and the class starter ability comes with it.
	for i in 40:
		world.virus_destroyed.emit()
		await create_timer(0.05).timeout
	if not await _until(func() -> bool: return not world.engine_lineage_offer.is_empty(), 40.0):
		return _fail("the engine offers a class once the cell is more mature")
	_step("class offer: %s" % str(world.engine_lineage_offer.map(func(o: Dictionary) -> String: return str(o.get("id", "")))))
	world.pick_mutation(0)
	if not await _until(func() -> bool: return BioAbilityCatalog.ids_of_class(world.lineage_id).size() > 0, 10.0):
		return _fail("choosing a class differentiates")
	_step("class: %s" % str(world.lineage_id))
	# Each class is born with one ability; the rest comes by deeds, quests and the advisor's awakening.
	if not await _until(func() -> bool: return world.abilities.known().size() >= 1, 10.0):
		return _fail("the class starter ability reaches the client")
	_step("born with %s" % str(world.abilities.known()))
	world.abilities.set_known(world.abilities.known())
	var first := world.abilities.slot_id(0)
	world.player.combatant.reset_vitals()
	var status := world.abilities.perform(0)
	if status != BioActor.AttackStatus.STARTED and status != BioAbilityRunner.NO_TARGET:
		return _fail("the starter performs (status %d)" % status)
	_step("performed %s (status %d)" % [first, status])
	await _shot("e2e_05c_ability")

	# Behaviour reported in the background shapes the body; the advisor decides it.
	for i in 25:
		world.sync._used[BioAttackCatalog.FLAGELLUM_LASH] = true
		world.sync._report_in = 0.0
		world.sync._track_behaviour(0.016)
		await create_timer(0.15).timeout
	if not await _until(func() -> bool: return world.look_name != "", 260.0):
		return _fail("the advisor decides a body from the reported behaviour")
	_step("body decided by the advisor: %s" % world.look_name)
	await _shot("e2e_06_body")
	if await _until(func() -> bool: return world.abilities.known().size() >= 2, 300.0):
		_step("a new ability was acquired while playing: %s" % str(world.abilities.known()))
	else:
		print("NOTE: no second ability within 300s (deeds/quests/awakening need more play)")
	print("E2E OK")
	quit(0)


func _self_num() -> Dictionary:
	return world.sync.link.view.get("self", {}).get("num", {})


func _quest_state(def: String) -> String:
	for q in world.sync.link.view.get("quests", []):
		if str(q.get("def", "")) == def:
			return str(q.get("state", ""))
	return ""


func _believes(p: String, s: String) -> bool:
	for b in world.sync.link.view.get("beliefs", []):
		if b.get("p", "") == p and str(b.get("s", "")) == s and b.get("holds", false):
			return true
	return false


func _until(cond: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.2).timeout
	return false


func _step(text: String) -> void:
	print("STEP ok: ", text)


func _fail(what: String) -> void:
	print("STEP FAILED: ", what)
	quit(1)


func _shot(name: String) -> void:
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
