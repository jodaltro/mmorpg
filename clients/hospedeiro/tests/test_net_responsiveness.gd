extends TestCase

const MOTION := {"speed":1.0,"thrust":42.0,"maximum":7.0,"damping":3.5,"unit":48.0}
var world: BioWorld
var client: BioOnlineClient

class RecordingTransport extends BioNakama:
	var sent: Array[Dictionary] = []
	func send_data(_code: int, body: Dictionary) -> void:
		sent.append(body.duplicate(true))

func before_each() -> void:
	world = BioWorld.new()
	world.save_path = ""
	world.engine_url = ""
	world.virus_count = 0
	tree.root.add_child(world)
	world.player.set_physics_process(false)
	for child in world.player.get_children():
		if child is BioPlayerInput: child.set_process(false)
	client = BioOnlineClient.new()
	client.world = world
	client.transport = BioNakama.new()
	client.transport.user_id = "local"
	client.is_ready = true
	client._has_started = true
	client._motion = MOTION.duplicate()
	client._last_received = Time.get_ticks_msec()
	world.online_client = client
	await tree.physics_frame

func after_each() -> void:
	world.online_client = null
	client.transport.free()
	client.free()
	world.queue_free()
	await tree.process_frame
	await tree.process_frame

func test_cast_reacts_before_any_packet_and_respects_local_cost_and_cooldown() -> void:
	var visuals := [0]
	var confirmations := [0]
	for child in world.player.get_children():
		if child is BioAttackExecutor:
			child.visual_performed.connect(func(_id: StringName, _aim: Vector2) -> void: visuals[0] += 1)
			child.performed.connect(func(_id: StringName, _aim: Vector2) -> void: confirmations[0] += 1)
	assert_eq(client.queue_action("spit"), BioActor.AttackStatus.STARTED)
	assert_eq(client.preview.shots.size(), 1, "projectile exists in the same input frame")
	assert_eq(visuals[0], 1)
	assert_eq(confirmations[0], 0, "preview is never a confirmed gameplay event")
	assert_eq(world.player.combatant.actor.vitals.atp, 85.0)
	assert_eq(client.queue_action("spit"), BioActor.AttackStatus.ON_COOLDOWN)
	assert_eq(client.preview.shots.size(), 1)
	client._physics_process(1.0/60)
	client._packet(2, _snapshot(1, 0, 100, []))
	assert_true(world.player.combatant.actor.vitals.atp <= 85.01, "stale pre-cast snapshots preserve the reservation")
	client._packet(2, _snapshot(2, 1, 85, [{"id":"local","token":1,"attack":"toxin_spit","aim":[1,0]}]))
	assert_eq(visuals[0], 1, "server confirmation never plays the shot a second time")
	assert_eq(confirmations[0], 1)
	assert_eq(client.actions.pending.size(), 0)

func _snapshot(serial: int, ack: int, atp: float, events: Array) -> Dictionary:
	return {"version":1,"seq":serial,"ack":ack,"time":serial*0.05,"motion":MOTION.duplicate(),"events":events,
		"entities":[{"id":"me","uid":"local","kind":"player","p":[0,0],"v":[0,0],"hp":100,"atp":atp,"max_hp":100,"max_atp":100}]}

func test_zero_ack_during_first_round_trip_does_not_cancel_predicted_movement() -> void:
	world.player.set_intent(Vector2.RIGHT)
	for i in 10: client._physics_process(1.0/60)
	var before := world.player.position.x
	client._packet(2, _snapshot(1, -1, 100, []))
	assert_true(before > 10)
	assert_near(world.player.position.x, before, 0.02, "server has not processed any input yet, so replay all of it")
	assert_eq(client.prediction.frames.size(), 10)

func test_dash_starts_immediately_and_expires_without_waiting_for_another_snapshot() -> void:
	world.player.intent = Vector2.RIGHT
	assert_eq(client.queue_action("dash"), BioActor.AttackStatus.STARTED)
	client._physics_process(1.0/60)
	assert_true(world.player.position.x > 15, "first tick already moves at dash speed")
	for i in 20: client._physics_process(1.0/60)
	assert_true(float(client._motion.ballistic_seconds) <= 0, "an old ballistic snapshot cannot lock movement forever")
	assert_true(world.player.velocity.length() < 12 * BioArt.UNIT, "normal drag is slowing the cell after the impulse")
	for i in 30: client._physics_process(1.0/60)
	assert_true(world.player.velocity.length() <= 7 * BioArt.UNIT + 0.1)

func test_class_preview_never_grants_skills_or_changes_enemy_health() -> void:
	assert_eq(client.queue_action("ability:anticorpo_direcionado"), BioAbilityRunner.UNKNOWN)
	var enemy := BioFactory.spawn_virus(world, Vector2.RIGHT * BioArt.UNIT, world.player).get_parent() as BioCellActor
	enemy.set_physics_process(false)
	var hp := enemy.combatant.actor.vitals.membrane
	client.queue_action("lash")
	assert_eq(enemy.combatant.actor.vitals.membrane, hp, "local contact is light only, not damage")
	assert_true(not enemy.is_queued_for_deletion())

func test_charge_release_keeps_its_second_press_without_paying_again() -> void:
	world.abilities.learn(&"anafilaxia")
	assert_eq(client.queue_action("ability:anafilaxia"), BioActor.AttackStatus.STARTED)
	var paid := world.player.combatant.actor.vitals.atp
	assert_eq(client.queue_action("ability:anafilaxia"), BioActor.AttackStatus.STARTED)
	assert_eq(world.player.combatant.actor.vitals.atp, paid, "releasing a charge never reserves a second cost")
	assert_eq(client.queue_action("ability:anafilaxia"), BioActor.AttackStatus.ON_COOLDOWN)

func test_send_clock_never_accumulates_a_movement_backlog_at_60_20_or_10_fps() -> void:
	client.transport.free()
	var transport := RecordingTransport.new()
	client.transport = transport
	transport.connected = true
	for physics_per_frame in [1, 3, 6]:
		client._send_in = 0
		for render in 120:
			for tick in physics_per_frame: client._physics_process(1.0/60)
			client._process(float(physics_per_frame)/60.0)
			assert_true(client._frames_to_send.size() < 5, "render rate must never slow the simulation input stream")
	for packet in transport.sent: assert_true(packet.frames.size() <= 4, "redundancy stays within the relay's message budget")

func test_selective_retransmission_uses_json_numeric_ids_and_preserves_missing_actions() -> void:
	client.transport.free()
	var transport := RecordingTransport.new()
	client.transport = transport
	transport.connected = true
	client._sent_frames = {1:{"seq":1,"move":[0,0],"actions":["spit"],"tokens":[7]},2:{"seq":2,"move":[0,0]}}
	client._missing_inputs = [1.0,2.0]
	client._frames_to_send = [{"seq":20,"move":[0,0]},{"seq":21,"move":[0,0]}]
	client._process(1.0/60)
	assert_eq(transport.sent.size(), 1)
	if transport.sent.is_empty(): return
	assert_eq(transport.sent[0].frames.map(func(frame: Dictionary) -> int: return int(frame.seq)), [1,2,20,21])

func test_reconnecting_keeps_local_controls_and_bounds_unsent_history() -> void:
	client.is_ready = false
	client.reconnecting = true
	world.player.set_intent(Vector2.RIGHT)
	client._physics_process(1.0/60)
	assert_true(world.player.position.x > 0, "no connection modal freezes an already started session")
	assert_eq(client.queue_action("spit"), BioActor.AttackStatus.STARTED)
	assert_eq(client._frames_to_send.size(), 0, "offline input cannot accumulate into a catch-up speed boost")

func test_reconnected_session_does_not_keep_costs_from_unsent_offline_previews() -> void:
	client.is_ready = false
	client.reconnecting = true
	client._menu = Control.new()
	client.queue_action("spit")
	assert_eq(client.actions.pending.size(), 1)
	client._confirmed_atp = 100
	client._snapshot_ready = true
	world.sync.link._set_online(true)
	client._unlock()
	assert_true(client.is_ready)
	assert_eq(client.actions.pending.size(), 0)
	assert_eq(world.player.combatant.actor.vitals.atp, 100.0)
	client._menu.free()

func test_input_budget_is_server_time_not_client_dt_or_sequence_jump() -> void:
	var buffer := BioNetInputBuffer.new()
	buffer.push([{"seq":10000,"dt":99999,"move":[1000,0]}, {"seq":10001,"dt":99999,"move":[1,0]}])
	assert_eq(buffer.take(0).size(), 0)
	var first := buffer.take(1.0/60)
	assert_eq(first.size(), 1)
	assert_eq(first[0].move, Vector2.RIGHT)
	assert_eq(buffer.take(0).size(), 0, "packets cannot buy simulation time")
	buffer.push([{"seq":10001}, {"seq":9999}])
	assert_eq(buffer.frames.size(), 1, "reliable retransmission cannot duplicate a command")

func test_missing_input_waits_for_redundancy_instead_of_acknowledging_a_gap() -> void:
	var buffer := BioNetInputBuffer.new()
	buffer.next_sequence = 1
	buffer.push([{"seq":1}, {"seq":3}])
	assert_eq(buffer.take(2.0/60).size(), 1, "frame 3 cannot acknowledge the missing frame 2")
	assert_eq(buffer.missing(), [2], "selective retransmission requests only the absent input")
	buffer.push([{"seq":2}, {"seq":3}])
	var recovered := buffer.take(0)
	assert_eq(recovered.size(), 1)
	assert_eq(recovered[0].seq, 2)
	assert_eq(buffer.take(1.0/60)[0].seq, 3)
	assert_eq(buffer.missing(), [])

func test_resending_input_does_not_make_the_ping_look_artificially_low() -> void:
	var stats := BioNetStats.new()
	stats.sent_input(1, 1000)
	stats.sent_input(1, 1300)
	stats.acknowledge(1, 1360)
	assert_eq(stats.current_ms(1360), 360)

func test_interpolation_bridges_missing_snapshots_and_extrapolation_is_bounded() -> void:
	var track := BioNetInterpolation.new()
	track.push(1, Vector2.ZERO, Vector2(100,0))
	track.push(1.1, Vector2(10,0), Vector2(100,0))
	assert_near(track.sample(1.05).x, 5, 0.001)
	assert_near(track.sample(1.16).x, 16, 0.001)
	assert_near(track.sample(99).x, 22, 0.001, "a disconnected enemy never drifts across the whole world")
	track.push(1.05, Vector2(-999,0), Vector2.ZERO)
	assert_eq(track.samples.size(), 2, "out-of-order state cannot rewind the timeline")

func test_rejected_cast_refunds_from_snapshot_and_cancels_only_once() -> void:
	var actor := world.player.combatant.actor
	var ledger := BioNetActions.new()
	var token := ledger.reserve(actor, BioAttackCatalog.TOXIN_SPIT, 10)
	ledger.bind_frame([token], 1)
	ledger.acknowledge(1)
	actor.vitals.atp = 100  # authority rejected this provisional cost
	var results := [{"token":token,"status":BioActor.AttackStatus.ON_COOLDOWN,"attack_id":"toxin_spit","cooldown":0.5,"time":10}]
	assert_eq(ledger.resolve_results(actor, results, 10.2, 10.1, 0.2), [token])
	assert_near(actor.cooldown_remaining(BioAttackCatalog.TOXIN_SPIT, 10.2), 0.3, 0.001)
	assert_eq(ledger.resolve_results(actor, results, 10.3, 10.2, 0.2), [], "repeated snapshots cannot restart rejection feedback")

func test_geometry_rewind_is_capped_and_never_rewinds_vitals() -> void:
	var history := BioNetLagHistory.new()
	history.record(1, 9.5, Vector2.ZERO)
	history.record(1, 9.75, Vector2(25,0))
	history.record(1, 10, Vector2(50,0))
	assert_near(history.point(1, 0, 10, Vector2.ZERO).x, 0, 0.001, "forged timestamps cannot rewind farther than 500 ms")
	assert_near(history.point(1, 999, 10, Vector2.ZERO).x, 50, 0.001)
	history.prune([])
	assert_eq(history.tracks.size(), 0)

func test_delayed_jittery_snapshots_replay_exactly_at_200_367_and_800_ms() -> void:
	for latency in [6, 11, 24]:
		var history := BioNetPrediction.new()
		var buffer := BioNetInputBuffer.new()
		var outbound: Array[Dictionary] = []
		var inbound: Array[Dictionary] = []
		var local_point := Vector2.ZERO
		var local_velocity := Vector2.ZERO
		var server_point := Vector2.ZERO
		var server_velocity := Vector2.ZERO
		var ack := -1
		var last_out := 0
		var last_in := 0
		var max_error := 0.0
		for tick in 360:
			var intent := Vector2.RIGHT if tick < 120 else Vector2.UP if tick < 240 else Vector2.ZERO
			history.remember(tick, 1.0/60, intent)
			local_velocity = BioNetPrediction.velocity(local_velocity, intent, 1.0/60, MOTION.duplicate())
			local_point += local_velocity / 60
			last_out = maxi(last_out, tick + latency + (tick % 7) / 3)
			outbound.append({"due":last_out,"frame":{"seq":tick,"move":[intent.x,intent.y]}})
			while not outbound.is_empty() and int(outbound[0].due) <= tick: buffer.push([outbound.pop_front().frame])
			for frame in buffer.take(1.0/60):
				server_velocity = BioNetPrediction.velocity(server_velocity, frame.move, 1.0/60, MOTION.duplicate())
				server_point += server_velocity / 60
				ack = int(frame.seq)
			if tick % 3 == 0 and tick % 15 != 0:
				last_in = maxi(last_in, tick + latency + tick % 4)
				inbound.append({"due":last_in,"ack":ack,"point":server_point,"velocity":server_velocity})
			while not inbound.is_empty() and int(inbound[0].due) <= tick:
				var snapshot: Dictionary = inbound.pop_front()
				history.acknowledge(int(snapshot.ack))
				var replayed: Vector2 = snapshot.point
				var velocity: Vector2 = snapshot.velocity
				for frame in history.frames:
					velocity = BioNetPrediction.velocity(velocity, frame.intent, float(frame.dt), MOTION.duplicate())
					replayed += velocity * float(frame.dt)
				max_error = maxf(max_error, local_point.distance_to(replayed))
			assert_true(history.frames.size() < 150)
		assert_true(max_error < 0.02, "replayed motion with delay and jitter stays consistent (error %.4f, one way %d ticks)" % [max_error,latency])
