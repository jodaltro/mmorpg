extends TestCase
## The work of the terrain: props that answer the gesture of the calling's abilities, so the recommended calling is the one that can do the job.

var world: BioWorld

const CLASS_ROLE := {
	&"neutrofilo": "combate", &"t_citotoxico": "combate", &"celula_nk": "combate",
	&"macrofago": "limpeza", &"eosinofilo": "limpeza",
	&"t_auxiliar": "cura", &"mastocito": "cura",
	&"t_regulador": "controle",
	&"linfocito_b": "marcacao", &"dendritica": "marcacao",
}


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _skin_crisis(severity: int = 50) -> Dictionary:
	return {"tick": 10, "quests": [], "others": [], "signs": [], "beliefs": [], "events": [], "skills": [], "society": [],
		"conflicts": {"revision": 1, "focus": "c1", "active": [{"id": "c1", "def": "ferida-na-pele", "title": "Ferida na pele", "phase": "active",
			"region": "pele", "revision": 1, "since": 5, "severity": severity, "peak": 60, "metrics": []}], "recent": []}}


func _prepare() -> void:
	world.player.global_position = BioBodyMap.center_px(&"pele")
	for i in 4:
		await tree.process_frame
	world.sync.apply_view(_skin_crisis())
	world.terrain._look_in = 0.0
	await tree.process_frame
	await tree.process_frame


func test_every_ability_does_something_in_the_terrain_and_every_class_does_its_roles_work() -> void:
	for id in BioAbilityCatalog._defs.keys():
		var kind := str(BioAbilityCatalog.get_ability(id)["kind"])
		assert_true(not BioTerrainRules.verbs_of_kind(kind).is_empty(), "%s (%s) has a use in the terrain" % [id, kind])
	for form in CLASS_ROLE:
		var role: String = CLASS_ROLE[form]
		var able := {}
		for id in BioAbilityCatalog.ids_of_class(form):
			for v in BioTerrainRules.verbs_of_kind(str(BioAbilityCatalog.get_ability(id)["kind"])):
				if BioTerrainRules.can(v, role):
					able[v] = true
		for v in BioTerrainRules.verbs_of_role(role):
			assert_true(able.has(v), "%s (%s) has a gesture that does %s" % [form, role, v])


func test_every_crisis_has_props_named_for_its_organ() -> void:
	for def in BioConflictFocus.ORGAN:
		var verbs := BioTerrainRules.verbs_for(def)
		assert_true(verbs.size() >= 2, "%s has at least two kinds of terrain work" % def)
		for v in verbs:
			assert_eq(BioTerrainRules.action(v, def), "terreno-%s-%s" % [v, def], "the engine action")
			assert_true(BioTerrainRules.prop_name(def, v) != str(BioTerrainRules.info(v)["name"]), "%s/%s has its own name" % [def, v])


func test_the_calling_that_owns_the_verb_breaks_the_barricade_and_the_deed_is_confirmed() -> void:
	await _prepare()
	assert_eq(world.terrain.current_def(), "ferida-na-pele", "the crisis has its props")
	var p: Dictionary = world.terrain.prop_of("romper")
	assert_true(not p.is_empty(), "a barricade lies in the organ")
	var deeds: Array = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	world._calling = {"role": "combate", "current": "neutrofilo"}
	world.player.global_position = (p["pos"] as Vector2) + Vector2(-BioArt.UNIT * 1.5, 0)
	world.abilities.last_aim = Vector2.RIGHT
	for i in 4:
		world.abilities.performed.emit(&"explosao_neutrofilica")
	assert_eq(deeds, ["terreno-romper-ferida-na-pele"], "breaking it is the confirmed deed of the role")
	assert_eq(str(p["state"]), "done", "and it is gone")


func test_another_calling_cannot_do_it_and_the_wrong_gesture_does_nothing() -> void:
	await _prepare()
	var p: Dictionary = world.terrain.prop_of("romper")
	var deeds: Array = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	world.player.global_position = (p["pos"] as Vector2) + Vector2(-BioArt.UNIT * 1.5, 0)
	world.abilities.last_aim = Vector2.RIGHT
	world._calling = {"role": "cura", "current": "t-auxiliar"}
	for i in 4:
		world.abilities.performed.emit(&"explosao_neutrofilica")  # a strong strike, but not their calling's
	assert_eq(float(p["progress"]), 0.0, "the wrong calling does not break it")
	world._calling = {"role": "combate", "current": "neutrofilo"}
	for i in 4:
		world.abilities.performed.emit(&"rede_de_dna")  # a net holds enemies, it does not break a barricade
	assert_eq(float(p["progress"]), 0.0, "and the wrong gesture does nothing")
	assert_true(deeds.is_empty(), "nothing is confirmed")


func test_a_block_is_pushed_away_from_the_caster_until_it_reaches_its_groove() -> void:
	await _prepare()
	world._calling = {"role": "controle", "current": "t-regulador"}
	var p: Dictionary = world.terrain.prop_of("empurrar")
	assert_true(not p.is_empty(), "the skin has a block to push")
	var deeds: Array = []
	world.organ_deed.connect(func(action: String) -> void: deeds.append(action))
	p["slot"] = (p["pos"] as Vector2) + Vector2(BioArt.UNIT * 6.0, 0)  # a groove to the right
	world.player.global_position = (p["pos"] as Vector2) + Vector2(-BioArt.UNIT * 2.0, 0)
	world.abilities.last_aim = Vector2.RIGHT
	world.abilities.performed.emit(&"singularidade_de_tolerancia")  # a pull draws toward the caster...
	assert_true((p["vel"] as Vector2).x < 0.0, "a pull brings it toward the caster")
	p["vel"] = Vector2.ZERO
	world._calling = {"role": "combate", "current": "neutrofilo"}
	world.abilities.performed.emit(&"explosao_neutrofilica")  # ...a strike pushes it away
	assert_true((p["vel"] as Vector2).x > 0.0, "a strike pushes it away from the caster")
	for i in 120:
		await tree.physics_frame
		if str(p["state"]) == "done":
			break
	assert_eq(deeds.filter(func(d: String) -> bool: return d.begins_with("terreno-empurrar")).size(), 1, "reaching the groove is the deed")


func test_healing_reaches_the_wounded_cells_and_marks_the_hurt_ones() -> void:
	await _prepare()
	world._calling = {"role": "cura", "current": "t-auxiliar"}
	var p: Dictionary = world.terrain.prop_of("curar")
	world.player.global_position = (p["pos"] as Vector2) + Vector2(-BioArt.UNIT * 1.2, 0)
	world.abilities.last_aim = Vector2.RIGHT
	world.abilities.performed.emit(&"chamado_aos_auxiliares")
	assert_true(float(p["progress"]) > 0.0, "the wounded cells mend")
	var w := BioWorker.new("neutrofilos_pele", "defesa", world.player.global_position, 1.0)
	w.hp = 5.0
	world.sync.crowd.workers.append(w)
	var helped: int = world.sync.crowd.heal_near(world.player.global_position, BioArt.UNIT * 4.0, 14.0)
	assert_eq(helped, 1, "the cell of the body is helped")
	assert_eq(w.hp, 19.0, "and mends by the amount")
	world.sync.crowd.workers.erase(w)
