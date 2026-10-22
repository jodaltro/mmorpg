class_name BioWorld
extends Node2D
## Composition root: camera, glow, world, player, HUD, population upkeep and the mutation loop.

@export var virus_count := 6
@export var nutrient_target := 45
@export var world_radius_units := 24.0
@export var seed_value := 1337
@export var save_path := "user://hospedeiro_genome.json"  # empty disables persistence

var player: BioCellActor
var hud: BioHud
var camera: BioCameraFollow
var genome: BioGenome
var tracker: BioMutationTracker
var panel: BioMutationPanel

var _rng := RandomNumberGenerator.new()
var _built := false
var _upkeep_timer := 0.0
var _virus_respawn_timer := 0.0


func _ready() -> void:
	build()


func viruses() -> Array:
	return get_tree().get_nodes_in_group("viruses")


func nutrient_count() -> int:
	return get_tree().get_nodes_in_group("nutrients").size()


func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = seed_value
	BioFx.root = self
	RenderingServer.set_default_clear_color(Color(0.006, 0.01, 0.03))
	_add_glow_environment()

	BioFactory.create_boundary(self, world_radius_units)
	var motes := BioAmbientMotes.new()
	motes.build(110, 14, world_radius_units, seed_value)
	add_child(motes)

	player = BioFactory.spawn_player(self, Vector2.ZERO)
	camera = BioCameraFollow.new()
	camera.name = "Camera"
	add_child(camera)
	camera.set_target(player)
	camera.make_current()
	player.combatant.hit.connect(func(_who: BioCombatant, result: BioHitResult) -> void:
		if result.outcome == BioActor.HitOutcome.HIT or result.outcome == BioActor.HitOutcome.KILLED:
			camera.shake(0.18))
	player.combatant.died.connect(_on_player_died)

	tracker = BioMutationTracker.new(seed_value)
	genome = BioGenomeStore.load_state(save_path, tracker)
	player.combatant.set_genome(genome)
	player.combatant.nutrient_consumed.connect(func(_kind: int) -> void: add_pressure(BioMutationTracker.NUTRIENT_POINTS))
	player.combatant.hit.connect(func(_who: BioCombatant, result: BioHitResult) -> void:
		if result.outcome == BioActor.HitOutcome.EVADED:
			add_pressure(BioMutationTracker.EVADE_POINTS))

	hud = BioHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player.combatant)
	panel = BioMutationPanel.new()
	panel.name = "MutationPanel"
	add_child(panel)
	panel.refresh(genome, tracker)

	for i in nutrient_target:
		_spawn_nutrient(0.0)
	for i in virus_count:
		_spawn_virus(12.0)


## Confirmed events (food, kills, evasions) build evolutionary pressure; at the threshold a mutation is offered.
func add_pressure(points: int) -> void:
	if tracker.add_pressure(points, genome):
		panel.show_offer(tracker.offer)
	BioGenomeStore.save(save_path, genome, tracker)


func pick_mutation(index: int) -> void:
	if not tracker.has_offer():
		return
	tracker.choose(index, genome)
	player.combatant.set_genome(genome)
	panel.hide_offer()
	BioGenomeStore.save(save_path, genome, tracker)


func decline_mutation() -> void:
	if not tracker.has_offer():
		return
	tracker.decline()
	panel.hide_offer()
	BioGenomeStore.save(save_path, genome, tracker)


func respawn_player() -> void:
	if player.combatant.actor.vitals.is_alive():
		return
	player.set_active(true)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.combatant.reset_vitals()
	hud.show_banner("")


func _on_player_died(_who: BioCombatant) -> void:
	player.set_intent(Vector2.ZERO)
	player.set_active(false)
	hud.show_banner("A célula se dissolveu no caldo\nPressione R para ressurgir")


func _process(delta: float) -> void:
	if not _built:
		return
	if not player.is_active() and Input.is_action_just_pressed("bio_respawn"):
		respawn_player()
	for i in 3:
		if Input.is_action_just_pressed("bio_pick_%d" % (i + 1)):
			pick_mutation(i)
	if Input.is_action_just_pressed("bio_decline"):
		decline_mutation()
	panel.refresh(genome, tracker)
	_upkeep_timer -= delta
	if _upkeep_timer > 0.0:
		return
	_upkeep_timer = 1.0
	if nutrient_count() < nutrient_target:
		_spawn_nutrient(8.0)
	if viruses().size() < virus_count:
		_virus_respawn_timer -= 1.0
		if _virus_respawn_timer <= 0.0:
			_spawn_virus(14.0)
			_virus_respawn_timer = 6.0


func _random_point(min_distance_units: float) -> Vector2:
	var center := player.global_position if player != null else Vector2.ZERO
	for attempt in 12:
		var p := Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * (world_radius_units - 2.0) * BioArt.UNIT
		if p.distance_to(center) >= min_distance_units * BioArt.UNIT:
			return p
	return Vector2((world_radius_units - 3.0) * BioArt.UNIT, 0.0)


func _spawn_nutrient(min_distance_units: float) -> void:
	var kind := BioNutrientRules.Kind.GLUCOSE if _rng.randf() < 0.75 else BioNutrientRules.Kind.LIPID
	BioFactory.spawn_nutrient(self, _random_point(min_distance_units), kind)


func _spawn_virus(min_distance_units: float) -> void:
	var brain := BioFactory.spawn_virus(self, _random_point(min_distance_units), player)
	var host := brain.get_parent() as BioCellActor
	host.combatant.died.connect(func(_who: BioCombatant) -> void: add_pressure(BioMutationTracker.KILL_POINTS))


func _add_glow_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.8
	env.glow_strength = 1.2
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.45
	var holder := WorldEnvironment.new()
	holder.name = "GlowEnvironment"
	holder.environment = env
	add_child(holder)
