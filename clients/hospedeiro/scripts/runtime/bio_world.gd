class_name BioWorld
extends Node2D
## Composition root: the marrow and the blood, camera, glow, player, HUD, population upkeep, the
## mutation loop and the link to the engine (BioHostSync). Plays offline when the engine is absent.

signal region_changed(region: StringName)
signal virus_destroyed
signal nutrient_absorbed

const BLOOD_FLOW_UNITS := 2.2
const VIRUS_SPEED := 3.6
const FEVER_SLOWDOWN := 0.55

@export var virus_count := 6
@export var nutrient_target := 45
@export var seed_value := 1337
@export var save_path := "user://hospedeiro_genome.json"  # empty disables persistence
@export var engine_url := "http://127.0.0.1:8096"  # empty keeps the game offline
@export var identity_path := "user://hospedeiro_player.json"

var player: BioCellActor
var hud: BioHud
var camera: BioCameraFollow
var genome: BioGenome
var tracker: BioMutationTracker
var panel: BioMutationPanel
var sync: BioHostSync
var region: StringName = BioBodyMap.MEDULA
var fever := false
var sleeping := false

var _rng := RandomNumberGenerator.new()
var _built := false
var _upkeep_timer := 0.0
var _virus_respawn_timer := 0.0
var _tint: CanvasModulate


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
	_tint = CanvasModulate.new()
	add_child(_tint)

	BioFactory.create_body_boundary(self, BioBodyMap.outline_units())
	_add_motes(BioBodyMap.MEDULA, [BioArt.AMBER, BioArt.MAGENTA, BioArt.JADE])
	_add_motes(BioBodyMap.SANGUE, [BioArt.CRIMSON, BioArt.MAGENTA, Color(0.6, 0.05, 0.12)])

	player = BioFactory.spawn_player(self, BioBodyMap.center_px(BioBodyMap.MEDULA))
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
	player.combatant.nutrient_consumed.connect(func(_kind: int) -> void:
		add_pressure(BioMutationTracker.NUTRIENT_POINTS)
		nutrient_absorbed.emit())
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

	sync = BioHostSync.new()
	sync.name = "HostSync"
	sync.configure(self)
	add_child(sync)


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


## A gene the engine says this cell discovered by living (a skill). Expressed if there is a free slot.
func discover_gene(id: StringName) -> bool:
	if genome.has_gene(id) or not BioGeneCatalog.all_ids().has(id) or genome.equipped.size() >= BioGenome.SLOTS:
		return false
	genome.equip(id)
	player.combatant.set_genome(genome)
	BioGenomeStore.save(save_path, genome, tracker)
	return true


func respawn_player() -> void:
	if player.combatant.actor.vitals.is_alive():
		return
	player.set_active(true)
	player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
	player.velocity = Vector2.ZERO
	player.combatant.reset_vitals()
	hud.show_banner("")


## Fever (a body state the player knows of): virions slow down.
func set_fever(on: bool) -> void:
	if fever == on:
		return
	fever = on
	for v in viruses():
		(v as BioCellActor).max_speed_units = _virus_speed()
	_update_tint()


func set_sleeping(on: bool) -> void:
	if sleeping == on:
		return
	sleeping = on
	_update_tint()


## The host ate: glucose floods the blood.
func spawn_meal(count: int) -> void:
	for i in count:
		BioFactory.spawn_nutrient(self, BioBodyMap.random_point_px(_rng, BioBodyMap.SANGUE, player.global_position, 3.0), BioNutrientRules.Kind.GLUCOSE)


## A new outbreak: more virions in the blood.
func spawn_outbreak(count: int) -> void:
	for i in count:
		_spawn_virus(10.0)


func _virus_speed() -> float:
	return VIRUS_SPEED * (FEVER_SLOWDOWN if fever else 1.0)


func _update_tint() -> void:
	var c := Color.WHITE
	if fever:
		c *= Color(1.15, 0.92, 0.85)
	if sleeping:
		c *= Color(0.8, 0.82, 0.95)
	_tint.color = c


func _on_player_died(_who: BioCombatant) -> void:
	player.set_intent(Vector2.ZERO)
	player.set_active(false)
	hud.show_banner("A célula se dissolveu no fluido\nPressione R para renascer na medula")


func _process(delta: float) -> void:
	if not _built:
		return
	if not player.is_active() and Input.is_action_just_pressed("bio_respawn"):
		respawn_player()
	if player.is_active():
		var now := BioBodyMap.region_of(player.global_position)
		if now != region:
			region = now
			region_changed.emit(region)
	if not sync.wants_numbers():
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


## The blood is a river: cells and nutrients there are carried around the chamber.
func _physics_process(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("cells"):
		var cell := node as BioCellActor
		if cell != null and cell.is_active():
			cell.velocity += BioBodyMap.blood_flow_px(cell.global_position, BLOOD_FLOW_UNITS) * delta * 1.5
	for node in get_tree().get_nodes_in_group("nutrients"):
		var nutrient := node as Node2D
		nutrient.global_position += BioBodyMap.blood_flow_px(nutrient.global_position, BLOOD_FLOW_UNITS * 0.6) * delta


func _spawn_nutrient(min_distance_units: float) -> void:
	var kind := BioNutrientRules.Kind.GLUCOSE if _rng.randf() < 0.75 else BioNutrientRules.Kind.LIPID
	var where := BioBodyMap.MEDULA if _rng.randf() < 0.6 else BioBodyMap.SANGUE
	BioFactory.spawn_nutrient(self, BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units), kind)


func _spawn_virus(min_distance_units: float) -> void:
	var pos := BioBodyMap.random_point_px(_rng, BioBodyMap.SANGUE, player.global_position, min_distance_units)
	var brain := BioFactory.spawn_virus(self, pos, player)
	var host := brain.get_parent() as BioCellActor
	host.max_speed_units = _virus_speed()
	host.combatant.died.connect(func(_who: BioCombatant) -> void:
		add_pressure(BioMutationTracker.KILL_POINTS)
		virus_destroyed.emit())


func _add_motes(where: StringName, palette: Array) -> void:
	var motes := BioAmbientMotes.new()
	motes.position = BioBodyMap.center_px(where)
	motes.build(70, 9, BioBodyMap.radius_units(where), seed_value + where.length(), palette)
	add_child(motes)


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
