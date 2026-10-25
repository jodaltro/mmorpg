extends TestCase

class LocalAuthority extends BioGameServer:
	func _ready() -> void:
		engine_url = ""
		arena = BioWorld.new()
		arena.engine_url = ""
		arena.save_path = ""
		arena.virus_count = 0
		arena.nutrient_target = 0
		add_child(arena)
		arena.set_process(false)
		arena.player.set_active(false)
		transport = BioNakama.new()
		add_child(transport)
		set_process(false)

var server: BioGameServer

func before_each() -> void:
	server = LocalAuthority.new()
	tree.root.add_child(server)
	server._join("alpha", "Alfa")
	server._join("beta", "Beta")
	for id in server.players:
		(server.players[id].link as BioEngineLink)._set_online(true)
	await tree.physics_frame
	await tree.physics_frame

func after_each() -> void:
	server.queue_free()
	await tree.process_frame
	await tree.process_frame

func test_combat_uses_server_position_damage_and_cooldown() -> void:
	var cell: BioCellActor = server.players.alpha.cell
	var brain := BioFactory.spawn_virus(server.arena, cell.global_position + Vector2.RIGHT*BioArt.UNIT, cell)
	brain.set_process(false)
	var enemy := brain.get_parent() as BioCellActor
	enemy.combatant.actor.vitals.membrane = 1
	var defeated := [0]
	cell.combatant.enemy_defeated.connect(func(_victim: BioCombatant) -> void: defeated[0] += 1)
	await tree.physics_frame
	await tree.physics_frame
	server._packet(1, {"id":"alpha", "input":{"seq":1,"move":[999,0],"aim":[1,0],"hp":99999,"damage":99999,"actions":["lash"]}})
	assert_eq(defeated[0], 1, "trusted combat confirms one kill")
	assert_true(cell.intent.length() <= 1, "client cannot send speed")
	assert_true(cell.combatant.actor.vitals.membrane <= 100, "client cannot send health")
	assert_true(cell.combatant.actor.cooldown_remaining(BioAttackCatalog.FLAGELLUM_LASH, BioClock.now()) > 0, "cooldown belongs to authority")
	server._packet(1, {"id":"alpha", "input":{"seq":1,"move":[-1,0],"aim":[1,0]}})
	assert_true(cell.intent.x > 0, "replayed input cannot replace newer state")

func test_shared_nutrient_is_consumed_only_once() -> void:
	var a: BioCellActor = server.players.alpha.cell
	var b: BioCellActor = server.players.beta.cell
	var food := BioFactory.spawn_nutrient(server.arena, a.global_position + Vector2(200,0), BioNutrientRules.Kind.GLUCOSE)
	var taken := [0]
	a.combatant.nutrient_consumed.connect(func(_kind: int) -> void: taken[0] += 1)
	b.combatant.nutrient_consumed.connect(func(_kind: int) -> void: taken[0] += 1)
	food._on_body_entered(a)
	food._on_body_entered(b)
	assert_eq(taken[0], 1, "two bodies cannot both collect the same mote")

func test_delayed_damage_keeps_the_kill_credit() -> void:
	var a: BioCellActor = server.players.alpha.cell
	var brain := BioFactory.spawn_virus(server.arena, a.global_position+Vector2(200,0), a)
	brain.set_process(false)
	var enemy := brain.get_parent() as BioCellActor
	var defeated := [0]
	a.combatant.enemy_defeated.connect(func(_v: BioCombatant) -> void: defeated[0] += 1)
	var hit := BioAttackDef.new(&"test_burn", 0, 1, 0, 2, 0, 0)
	enemy.combatant.receive_hit(a.combatant, hit)
	enemy.combatant.actor.vitals.membrane = 1
	enemy.combatant.ignite(20, 1)
	enemy.combatant._tick_burn(0.1)
	assert_eq(defeated[0], 1, "burning kill still advances the attacker's server-owned progress")

func test_dungeons_isolate_physics_and_return_to_shared_world() -> void:
	var run := {"seed":4242,"room":0,"rooms":[{"id":"guarda","kind":"guard","name":"Guarda"}]}
	server._dungeon("alpha", run)
	server._dungeon("beta", run)
	await tree.physics_frame
	var a: BioCellActor = server.players.alpha.cell
	var b: BioCellActor = server.players.beta.cell
	assert_true(a.get_world_2d() != b.get_world_2d(), "personal instances never share physics")
	var dungeon: BioDungeon = server.players.alpha.dungeon
	for enemy in dungeon.enemies():
		assert_eq((enemy as Node2D).get_world_2d(), a.get_world_2d(), "room clear counts only its own enemies")
	server._end_dungeon("alpha")
	assert_eq(a.get_world_2d(), server.arena.get_world_2d(), "returns to shared body")
	assert_true((server.players.beta.dungeon as BioDungeon).active, "other player's room continues")

func test_snapshots_include_server_projectiles_and_ground_effects() -> void:
	var a: BioCellActor = server.players.alpha.cell
	var def := a.combatant.actor.attack_def(BioAttackCatalog.TOXIN_SPIT)
	BioAbilityBolt.spawn(server.arena, a.combatant, def, a.global_position, Vector2.RIGHT, 10, 8, Color.CYAN, false)
	BioAbilityZone.spawn(server.arena, a, &"rede", a.global_position, {"radius":2.0,"duration":3.0})
	BioMine.spawn(server.arena, a, def, a.global_position, 2, 0.5, 5, Color.ORANGE)
	BioSignature.play(&"bite", a.global_position, Color.CYAN, 1, {"dir":Vector2.RIGHT}, a)
	server._snapshot()
	assert_eq(server._serial, 1, "projectiles, zones, mines and procedural signatures serialize successfully")
