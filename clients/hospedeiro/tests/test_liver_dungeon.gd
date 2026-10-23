extends TestCase
## The cords of the liver (E3): its enemies, its modifiers (tied to the liver's state), its entrance and the run through the engine's view.

var world: BioWorld

const ROOMS := [
	{"id": "sinusoides-vigiados", "name": "Os sinusoides vigiados", "kind": "guard"},
	{"id": "cordao-de-hepatocitos", "name": "O cordão de hepatócitos", "kind": "wall"},
	{"id": "faixa-de-fibrose", "name": "A faixa de fibrose", "kind": "wall"},
	{"id": "foco-toxico", "name": "O foco tóxico", "kind": "core"},
	{"id": "nodulo", "name": "O nódulo cirrótico", "kind": "boss"},
]


func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	await tree.physics_frame


func after_each() -> void:
	world.queue_free()
	await tree.process_frame
	await tree.process_frame


func _run(room: int = 0, modifier: String = "") -> Dictionary:
	var mod: Variant = {"id": modifier, "name": modifier, "desc": ""} if modifier != "" else null
	return {"dungeon": "cordoes-hepaticos", "name": "Os Cordões Hepáticos", "state": "active", "seed": 777, "room": room, "rooms": ROOMS, "modifier": mod}


func _types(room: Dictionary) -> Array:
	return (room["enemies"] as Array).map(func(e: Dictionary) -> StringName: return e["type"])


func test_the_cords_have_their_own_enemies_in_every_room() -> void:
	var plan := func(i: int, kind: String) -> Dictionary: return BioDungeonPlan.room(5, i, kind, "", "cordoes-hepaticos")
	assert_eq(_types(plan.call(0, "guard")).filter(func(t: StringName) -> bool: return t == &"celula_estrelada").size(), 3, "three stellate cells at the door")
	assert_true(_types(plan.call(1, "wall")).has(&"hepatocito_doente"), "sick hepatocytes in the cord")
	assert_true(_types(plan.call(2, "wall")).has(&"gota_de_gordura"), "fat in the scar")
	assert_true(_types(plan.call(3, "core")).has(&"foco_toxico"), "toxic foci in the core")
	var boss := _types(plan.call(4, "boss"))
	assert_eq(boss.filter(func(t: StringName) -> bool: return t == &"nodulo_cirrotico").size(), 1, "one nodule")
	assert_true(bool(BioDungeonPlan.enemy(&"nodulo_cirrotico").get("boss", false)) and float(BioDungeonPlan.enemy(&"nodulo_cirrotico")["hp"]) > 300.0, "a tough boss")
	assert_eq(str(plan.call(0, "guard")["enemies"]), str(BioDungeonPlan.room(5, 0, "guard", "", "cordoes-hepaticos")["enemies"]), "same seed, same room")
	assert_eq(_types(BioDungeonPlan.room(5, 0, "guard", "")), [&"linfocito", &"linfocito", &"linfocito"] as Array, "the granuloma is untouched")


func test_the_liver_modifiers_change_the_run() -> void:
	assert_true(float(BioDungeonPlan.rules("bile-acida")["drain"]) > 0.0, "bile drains the membrane")
	assert_true(float(BioDungeonPlan.rules("toxinas-altas")["speed_mult"]) > 1.0, "toxins speed the enemies")
	assert_true(float(BioDungeonPlan.rules("glicogenio-cheio")["regen_mult"]) > 1.0, "glycogen speeds the ATP")
	assert_true(float(BioDungeonPlan.rules("kupffer-aliadas")["hp_mult"]) < 1.0, "Kupffer cells weaken the enemies")
	assert_true(float(BioDungeonPlan.rules("fibrose-ativa")["respawn_every"]) > 0.0, "fibrosis sends more cells")
	var heavy := BioDungeonPlan.room(5, 3, "core", "fibrose-ativa", "cordoes-hepaticos")
	assert_true(_types(heavy).size() > _types(BioDungeonPlan.room(5, 3, "core", "", "cordoes-hepaticos")).size(), "active fibrosis fills the core")


func test_the_liver_has_its_own_entrance_driven_by_the_view() -> void:
	assert_true(world.gates.has("cordoes-hepaticos") and world.gates.has("granuloma"), "two doors")
	var door: BioGate = world.gates["cordoes-hepaticos"]
	assert_eq(BioBodyMap.region_of(door.global_position), BioBodyMap.FIGADO, "the cords' door is inside the liver")
	world.sync.apply_view({"tick": 1, "dungeon": {"available": [{"id": "granuloma", "eligible": false}, {"id": "cordoes-hepaticos", "eligible": true}]}})
	assert_true(door.eligible and not world.gate.eligible, "only the cords are open")
	world.sync.apply_view({"tick": 2, "dungeon": {"available": [{"id": "granuloma", "eligible": false}, {"id": "cordoes-hepaticos", "eligible": false}]}})
	assert_true(not door.eligible and not door.hint.is_empty(), "and closing leaves a hint")


func test_a_cords_run_builds_the_livers_enemies_and_comes_out_in_the_liver() -> void:
	world.sync.apply_view({"tick": 1, "dungeon": {"available": [], "run": _run(0, "kupffer-aliadas")}})
	await tree.physics_frame
	assert_true(world.dungeon.active and world.dungeon.dungeon_id == "cordoes-hepaticos", "the run is the cords")
	assert_eq(world.dungeon.title, "OS CORDÕES HEPÁTICOS", "with its own title")
	var kinds := world.dungeon.enemies().map(func(e: Node) -> String: return str(e.get_meta("kind", "")))
	assert_true(kinds.size() == 3 and kinds.all(func(k: String) -> bool: return k == "celula_estrelada"), "three stellate cells: %s" % [kinds])
	var hp := (world.dungeon.enemies()[0] as BioCellActor).combatant.actor.vitals.membrane
	assert_near(hp, 22.0 * 0.75, 0.01)
	world.sync.apply_view({"tick": 2, "dungeon": {"available": [], "run": _run(4, "kupffer-aliadas")}})
	await tree.physics_frame
	var boss: Node = null
	for e in world.dungeon.enemies():
		if str(e.get_meta("kind", "")) == "nodulo_cirrotico":
			boss = e
	assert_true(boss != null, "the nodule is in the last room")
	assert_true(boss.get_children().any(func(c: Node) -> bool: return c is BioBossSlam), "and it slams and summons like a boss")
	var done := _run(4, "kupffer-aliadas")
	done["state"] = "cleared"
	world.sync.apply_view({"tick": 3, "dungeon": {"available": [], "run": done}})
	await tree.physics_frame
	assert_true(not world.dungeon.active, "cleared")
	assert_true(world.player.global_position.distance_to(world.liver_gate.global_position) < 5.0 * BioArt.UNIT, "back at the cords' door, in the liver")
