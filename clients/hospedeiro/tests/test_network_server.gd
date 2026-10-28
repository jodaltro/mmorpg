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

func test_sequenced_input_acknowledges_simulation_not_packet_receipt() -> void:
	var cell: BioCellActor = server.players.alpha.cell
	var start := cell.position
	server._packet(1, {"id":"alpha","input":{"compact":1,"frames":[{"seq":1,"move":[1,0],"aim":[1,0],"dt":999,"hp":99999}]}})
	assert_eq(server.players.alpha.seq, -1, "receiving a packet does not discard client prediction")
	assert_eq(cell.position, start)
	server._physics_process(1.0/60)
	assert_eq(server.players.alpha.seq, 1)
	assert_true(cell.position.x > start.x)
	assert_true(cell.position.x - start.x < BioArt.UNIT, "untrusted dt cannot speed up the cell")
	assert_true(cell.combatant.actor.vitals.membrane <= 100)

func test_action_results_identify_the_accepted_or_rejected_prediction() -> void:
	server._packet(1, {"id":"alpha","input":{"frames":[{"seq":1,"move":[0,0],"aim":[1,0],"actions":["spit"],"tokens":[42]}]}})
	server._physics_process(1.0/60)
	assert_eq(server.players.alpha.results[0].token, 42)
	assert_eq(server.players.alpha.results[0].status, BioActor.AttackStatus.STARTED)
	server._packet(1, {"id":"alpha","input":{"frames":[{"seq":2,"move":[0,0],"aim":[1,0],"actions":["spit"],"tokens":[43]}]}})
	server._physics_process(1.0/60)
	assert_eq(server.players.alpha.results[1].status, BioActor.AttackStatus.ON_COOLDOWN)
	assert_eq(server.players.alpha.results[1].token, 43)
	server._packet(1, {"id":"alpha","input":{"frames":[{"seq":3,"move":[0,0]}],"result_ack":43}})
	assert_eq(server.players.alpha.results.size(), 0, "confirmed results are not resent forever in every snapshot")

func test_temporary_world_api_loss_does_not_stop_an_initialized_combat_session() -> void:
	var p: Dictionary = server.players.alpha
	p.view = {"observer":"nk-alpha"}
	(p.link as BioEngineLink)._set_online(false)
	var cell: BioCellActor = p.cell
	var start := cell.position
	server._packet(1, {"id":"alpha","input":{"frames":[{"seq":1,"move":[1,0],"aim":[1,0],"actions":["spit"],"tokens":[51]}]}})
	server._physics_process(1.0/60)
	assert_true(cell.position.x > start.x, "movement uses the last validated character instead of waiting on HTTP")
	assert_eq(p.results[0].status, BioActor.AttackStatus.STARTED)

func test_melee_checks_recent_geometry_without_moving_or_reviving_the_target() -> void:
	var cell: BioCellActor = server.players.alpha.cell
	var enemy := BioFactory.spawn_virus(server.arena, cell.position + Vector2.RIGHT * BioArt.UNIT, cell).get_parent() as BioCellActor
	var now := Time.get_ticks_msec()/1000.0
	server.lag_history.record(enemy.get_instance_id(), now - 0.2, enemy.position)
	server.lag_history.record(enemy.get_instance_id(), now - 0.1, enemy.position)
	enemy.position += Vector2.RIGHT * BioArt.UNIT * 6
	var current := enemy.position
	server._packet(1, {"id":"alpha","input":{"seq":1,"view_time":now-0.15,"move":[0,0],"aim":[1,0],"actions":["lash"]}})
	assert_true(enemy.combatant.actor.vitals.membrane < 40, "the server recognizes the recently visible target")
	assert_eq(enemy.position, current, "compensation never teleports the shared entity")

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

func test_snapshots_include_server_projectiles_and_ground_effects() -> void:
	var a: BioCellActor = server.players.alpha.cell
	var def := a.combatant.actor.attack_def(BioAttackCatalog.TOXIN_SPIT)
	BioAbilityBolt.spawn(server.arena, a.combatant, def, a.global_position, Vector2.RIGHT, 10, 8, Color.CYAN, false)
	BioAbilityZone.spawn(server.arena, a, &"rede", a.global_position, {"radius":2.0,"duration":3.0})
	BioMine.spawn(server.arena, a, def, a.global_position, 2, 0.5, 5, Color.ORANGE)
	BioSignature.play(&"bite", a.global_position, Color.CYAN, 1, {"dir":Vector2.RIGHT}, a)
	server._snapshot()
	assert_eq(server._serial, 1, "projectiles, zones, mines and procedural signatures serialize successfully")


func test_enemy_attack_and_damage_visuals_are_driven_by_authority() -> void:
	var a: BioCellActor = server.players.alpha.cell
	var brain := BioFactory.spawn_virus(server.arena, a.global_position + Vector2.RIGHT * 100, a)
	brain.set_process(false)
	var enemy := brain.get_parent() as BioCellActor
	var body: BioCellBody
	var executor: BioAttackExecutor
	for child in enemy.get_children():
		if child is BioCellBody: body = child
		if child is BioAttackExecutor: executor = child
	var hp := enemy.combatant.actor.vitals.membrane
	executor.perform(BioAttackCatalog.VIRAL_LUNGE, Vector2.LEFT)
	assert_eq(body._attack_serial, 1, "real enemy attack starts its visual gesture")
	enemy.combatant.receive_hit(a.combatant, BioAttackDef.new(&"test", 0, 4, 0, 1, 0, 0))
	assert_true(body._hit_serial > 0, "real damage reaches visual feedback")
	var remaining := enemy.combatant.actor.vitals.membrane
	assert_true(remaining < hp)
	var replica := BioCellBody.new()
	replica.apply_combat_visual([0,0,0,"",1,0])
	replica.apply_combat_visual(body.combat_visual_state())
	assert_true(replica._flash > 0, "snapshot reproduces impact on the replica")
	assert_true(replica._attack_left > 0, "snapshot reproduces enemy attack")
	assert_eq(enemy.combatant.actor.vitals.membrane, remaining, "playing visuals never deals extra damage")
	server._snapshot()
	replica.free()
