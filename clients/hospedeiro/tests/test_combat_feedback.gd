extends TestCase

func test_enemy_damage_retracts_spikes_smoothly_and_healing_restores_the_silhouette() -> void:
	var body := BioCellBody.new()
	body.wear_enabled = true
	body.spikes = 9
	body.set_integrity(1)
	body.set_integrity(0.2)
	assert_eq(body.integrity, 1.0, "damage must ease into the silhouette")
	body._step_wear(1.0/60)
	assert_true(body.integrity > 0.2 and body.integrity < 1)
	for i in 60: body._step_wear(1.0/60)
	var spikes_left := 0.0
	for i in 9: spikes_left += body._spike_health(i,9,body.integrity)
	assert_true(spikes_left < 4, "low health loses most spikes without changing their angular frequency")
	assert_true(body.wear_size() < 0.9 and body.wear_size() >= 0.84)
	assert_true(body._shed.is_empty(), "fragments expire without allocating Nodes")
	body.set_integrity(1)
	for i in 60: body._step_wear(1.0/60)
	assert_near(body.wear_size(), 1, 0.001)
	body.free()

func test_injured_first_appearance_and_repeated_snapshots_do_not_shed_again() -> void:
	var body := BioCellBody.new()
	body.wear_enabled = true
	body.spikes = 12
	body.set_integrity(0.5)
	assert_eq(body.integrity, 0.5)
	assert_eq(body._shed.size(), 0)
	body.set_integrity(0.15)
	var count := body._shed.size()
	assert_true(count > 0 and count <= 12)
	for i in 20: body.set_integrity(0.15)
	assert_eq(body._shed.size(), count)
	body.free()

func test_enemy_wear_reads_real_health_without_changing_hitbox_or_player_shape() -> void:
	var root := Node2D.new()
	tree.root.add_child(root)
	var player := BioFactory.spawn_player(root, Vector2.ZERO)
	var brain := BioFactory.spawn_virus(root, Vector2(100,0), player)
	brain.set_process(false)
	var enemy := brain.get_parent() as BioCellActor
	var body: BioCellBody
	for child in enemy.get_children():
		if child is BioCellBody: body = child
	var collider := enemy.get_child(0) as CollisionShape2D
	var radius := (collider.shape as CircleShape2D).radius
	body._process(0.016)
	enemy.combatant.actor.vitals.membrane = 8.0
	for i in 40: body._process(0.016)
	assert_true(body.integrity < 0.21)
	assert_eq((collider.shape as CircleShape2D).radius, radius)
	assert_eq(enemy.combatant.actor.vitals.membrane, 8.0)
	for child in player.get_children():
		if child is BioCellBody:
			child.set_integrity(0.1)
			assert_eq(child.wear_size(), 1.0)
	root.queue_free()
	await tree.process_frame

func test_replica_plays_confirmed_hits_once_without_changing_health() -> void:
	var host := BioCellBody.new()
	var replica := BioCellBody.new()
	replica.apply_combat_visual(host.combat_visual_state())
	host.hit_reaction(Vector2.LEFT)
	replica.apply_combat_visual(host.combat_visual_state())
	assert_true(replica._flash > 0.9, "confirmed impact lights the membrane")
	assert_true(replica._impact_left > 0.0, "confirmed impact starts recoil")
	var count := replica._hit_serial
	replica.apply_combat_visual(host.combat_visual_state())
	assert_eq(replica._hit_serial, count, "repeated states never replay damage feedback")
	host.free()
	replica.free()

func test_first_appearance_does_not_replay_old_attacks_or_hits() -> void:
	var body := BioCellBody.new()
	body.apply_combat_visual([7, 9, 0.8, "viral_lunge", 1, 0])
	assert_eq(body._flash, 0.0)
	assert_eq(body._attack_left, 0.0)
	assert_near(body._telegraph_target, 0.8, 0.001, "ongoing windup remains visible")
	body.free()

func test_coalesced_attack_is_directional_and_starts_only_once() -> void:
	var body := BioCellBody.new()
	body.apply_combat_visual([0, 0, 0, "", 1, 0])
	body.apply_combat_visual([0, 3, 0, "enemy_spit", 0, -1])
	assert_eq(body._attack_dir, Vector2.UP)
	assert_true(body._attack_left > 0, "last confirmed attack survives skipped snapshots")
	assert_true(not body._kicks.is_empty(), "smooth recoil and recovery are scheduled")
	body.apply_combat_visual([0, 3, 0, "enemy_spit", 0, -1])
	assert_eq(body._attack_serial, 1, "attack is not retriggered by every snapshot")
	body.free()
