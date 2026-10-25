extends TestCase

class Peer extends BioPeerTransport:
	var sent: Array = []
	func _ready() -> void:
		connected = true
	func _process(_delta: float) -> void:
		pass
	func send_data(code: int, body: Dictionary) -> void:
		sent.append({"code":code,"body":body.duplicate(true)})

var world: BioWorld
var host: BioPersonalHost
var peer: Peer


func before_each() -> void:
	world = BioWorld.new()
	world.engine_url = ""
	world.save_path = ""
	world.identity_path = ""
	world.virus_count = 0
	world.nutrient_target = 0
	tree.root.add_child(world)
	peer = Peer.new()
	tree.root.add_child(peer)
	host = BioPersonalHost.new()
	host.arena = world
	host.transport = peer
	tree.root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	host._packet(10, {"event":"join"})


func after_each() -> void:
	host.queue_free()
	await tree.process_frame
	peer.queue_free()
	world.queue_free()
	await tree.process_frame


func test_host_stays_local_and_both_players_are_in_the_same_map() -> void:
	world.player.set_intent(Vector2.RIGHT)
	host._process(0.02)
	assert_eq(world.player.intent, Vector2.RIGHT, "host must not wait for network input")
	var guest: BioCellActor = host.players.guest.cell
	assert_eq(guest.get_world_2d(), world.player.get_world_2d(), "PvP is in the open world")
	assert_true(BioCombatRules.can_hit(world.player.combatant.actor, guest.combatant.actor))
	assert_true(BioCombatRules.can_hit(guest.combatant.actor, world.player.combatant.actor))
	var monster := BioActor.new("virus", 1, BioVitals.new(10,10,0))
	assert_true(BioCombatRules.can_hit(guest.combatant.actor, monster))
	assert_true(BioCombatRules.can_hit(world.player.combatant.actor, monster))
	peer.sent.clear()
	host._snapshot()
	var snapshot: Dictionary = peer.sent.back().body.body
	assert_true(snapshot.entities.any(func(e: Dictionary) -> bool: return e.get("uid") == "host"))
	assert_true(snapshot.entities.any(func(e: Dictionary) -> bool: return e.get("uid") == "guest" and e.get("team") == 2))


func test_visitor_monster_deeds_go_to_visitor_and_pvp_has_no_progression_reward() -> void:
	var guest: BioCellActor = host.players.guest.cell
	peer.sent.clear()
	guest.combatant.nutrient_consumed.emit(0)
	assert_true(peer.sent.any(func(e: Dictionary) -> bool: return e.code == 21 and e.body.action == "absorver-nutriente"))
	peer.sent.clear()
	guest.combatant._after_blow(world.player.combatant, BioHitResult.new(BioActor.HitOutcome.KILLED,100))
	assert_true(not peer.sent.any(func(e: Dictionary) -> bool: return e.code == 21), "killing a player is never a monster deed")
	var target := BioFactory.spawn_virus(world, Vector2.ZERO, world.player)
	guest.combatant._after_blow((target.get_parent() as BioCellActor).combatant, BioHitResult.new(BioActor.HitOutcome.KILLED,100))
	assert_true(peer.sent.any(func(e: Dictionary) -> bool: return e.code == 21 and e.body.action == "derrotar-virus"))
	peer.sent.clear()
	guest.combatant.actor.invulnerable_until = BioClock.now()+10
	guest.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"test",0,5,0,1,0,0))
	assert_true(not peer.sent.any(func(e: Dictionary) -> bool: return e.code == 21), "PvP evasion has no permanent reward")


func test_visitor_build_only_contains_catalogue_choices_and_no_dungeon_or_hp() -> void:
	var clean := BioPartyBuild.clean({"hp":99999,"damage":99999,"dungeon":{"run":{"state":"active"}},"lineage":{"current":"invented"},"evolution":{"genes":[{"id":"invented"}]},"skills":[{"id":"invented"}]})
	assert_true(not clean.has("hp") and not clean.has("damage") and not clean.has("dungeon"))
	assert_eq(clean.lineage.current, "")
	assert_true(clean.evolution.genes.is_empty() and clean.skills.is_empty())
	host._packet(22, {"view":clean})
	var guest: BioCellActor = host.players.guest.cell
	assert_true(guest.combatant.actor.vitals.max_membrane <= 100)
	assert_eq(guest.combatant.actor.team, 2, "evolution preserves the visitor's PvP faction")
	var own := {"explore":{"niches":[{"id":"memoria","region":"sangue","hint":"Lembre"},{"id":"bad","region":"invented"}],"adapted":["sangue","invented"]}}
	var exploration := BioPartyBuild.clean(own).explore as Dictionary
	assert_eq(exploration.niches.size(), 1, "visitor can discover personal niches on the host")
	assert_eq(exploration.adapted, ["sangue"])


func test_host_victory_survives_death_and_mission_banners_and_is_not_repeated() -> void:
	var guest: BioCellActor = host.players.guest.cell
	guest.combatant.actor.invulnerable_until = 0
	peer.sent.clear()
	guest.combatant.receive_hit(world.player.combatant, BioAttackDef.new(&"test",0,1000,0,1,0,0))
	assert_true(world.hud.pvp_result_text.begins_with("Anfitrião venceu"))
	assert_eq(peer.sent.filter(func(e: Dictionary) -> bool: return e.code == 23).size(), 1)
	world.hud.show_banner("Missão recebida")
	world._on_player_died(world.player.combatant)
	assert_true(world.hud._pvp_result.text.begins_with("Anfitrião venceu"), "a later death snapshot must not erase the result")
	host._defeated("guest", guest.combatant)
	assert_eq(peer.sent.filter(func(e: Dictionary) -> bool: return e.code == 23).size(), 1, "one result per defeated life")
	world.hud.show_pvp_result(-1, "resultado antigo")
	assert_true(world.hud.pvp_result_text.begins_with("Anfitrião venceu"))


func test_visitor_victory_and_next_life_have_separate_results() -> void:
	var guest: BioCellActor = host.players.guest.cell
	world.player.combatant.died.connect(func(victim: BioCombatant) -> void: host._defeated("host", victim))
	world.player.combatant.actor.invulnerable_until = 0
	world.player.combatant.receive_hit(guest.combatant, BioAttackDef.new(&"test",0,1000,0,1,0,0))
	assert_true(world.hud.pvp_result_text.begins_with("Visitante venceu"))
	var first_id := world.hud._pvp_result_id
	world.player.combatant.reset_vitals()
	world.player.set_active(true)
	host._physics_process(1.0/60.0)
	world.player.combatant.actor.invulnerable_until = 0
	world.player.combatant.receive_hit(guest.combatant, BioAttackDef.new(&"test",0,1000,0,1,0,0))
	assert_true(world.hud._pvp_result_id > first_id, "respawning allows another result")


func test_peer_snapshots_run_after_physics_at_thirty_hz_without_render() -> void:
	peer.sent.clear()
	for i in 6: host._physics_process(1.0/60.0)
	assert_eq(peer.sent.filter(func(e: Dictionary) -> bool: return e.code == 2).size(), 3)
	peer.sent.clear()
	host._process(0.02)
	assert_true(not peer.sent.any(func(e: Dictionary) -> bool: return e.code == 2), "render must not create a second snapshot clock")
