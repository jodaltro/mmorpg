class_name BioWorld
extends Node2D
## Composition root: the marrow and the blood, camera, glow, player, HUD, population upkeep, the
## mutation loop and the link to the engine (BioHostSync). Plays offline when the engine is absent.

signal region_changed(region: StringName)
signal virus_destroyed
signal nutrient_absorbed
signal evaded

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
var abilities: BioAbilityRunner
var dungeon: BioDungeon
var anatomy: BioAnatomyView
var atlas: BioAtlas
var exploration: BioExploration
var compass_text := ""
var body := BioBodyState.new()  # the host's vital signs (from the engine) and what they do to the cell
var vitals_panel: BioVitalsPanel
var live_regions: Array[StringName] = []
var fell_in_dungeon := false
var gate: BioGate
var hud: BioHud
var camera: BioCameraFollow
var genome: BioGenome
var tracker: BioMutationTracker
var panel: BioMutationPanel
var sync: BioHostSync
var region: StringName = BioBodyMap.MEDULA
var fever := false
var sleeping := false
## Online, the engine owns the genome, the pressure and the offer (the advisor reads how the player lives).
var engine_evolution := false
var engine_offer: Array[String] = []  # engine gene ids of the pending offer
var engine_featured := ""
var engine_lineage_offer: Array[Dictionary] = []  # pending differentiation offer (engine)
var engine_lineage_featured := ""
var lineage_id: StringName = &""
var _pending_evolution := {}
var look_name := ""  # the variant the advisor chose for this body (Caçador, Andarilho...)
var _engine_fraction := 0.0

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

	BioBodyMap.seed_value = seed_value
	anatomy = BioAnatomyView.new()
	anatomy.name = "Anatomy"
	add_child(anatomy)
	anatomy.build(seed_value)  # the whole body, grown from the seed; only the regions around the cell are alive

	player = BioFactory.spawn_player(self, BioBodyMap.center_px(BioBodyMap.MEDULA))
	abilities = player.get_node("Abilities") as BioAbilityRunner
	camera = BioCameraFollow.new()
	camera.name = "Camera"
	add_child(camera)
	camera.set_target(player)
	camera.make_current()
	BioFx.shake_hook = camera.shake
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
			add_pressure(BioMutationTracker.EVADE_POINTS)
			evaded.emit())

	hud = BioHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player.combatant)
	hud.bind_abilities(abilities)
	gate = BioGate.new()
	gate.name = "GranulomaGate"
	gate.position = BioBodyMap.center_px(BioBodyMap.SANGUE) + Vector2(6.0, -9.0) * BioArt.UNIT
	add_child(gate)
	gate.configure(player)
	dungeon = BioDungeon.new()
	dungeon.name = "Dungeon"
	add_child(dungeon)
	dungeon.bind(player, gate.global_position + Vector2(0.0, 3.4 * BioArt.UNIT))
	dungeon.room_started.connect(func(index: int, info: Dictionary) -> void:
		hud.set_dungeon_text("GRANULOMA  ·  sala %d/%d  ·  %s" % [index + 1, dungeon.rooms.size(), str(info.get("name", ""))]))
	dungeon.finished.connect(func(_cleared: bool) -> void: hud.set_dungeon_text(""))
	hud.restart_requested.connect(restart_world)
	exploration = BioExploration.new()
	exploration.name = "Exploration"
	add_child(exploration)
	exploration.configure(player, seed_value)
	vitals_panel = BioVitalsPanel.new()
	vitals_panel.name = "VitalsPanel"
	add_child(vitals_panel)
	vitals_panel.configure(body)
	atlas = BioAtlas.new()
	atlas.name = "Atlas"
	add_child(atlas)
	atlas.configure(player, seed_value, "" if save_path.is_empty() else "user://hospedeiro_atlas.json")
	atlas.discovered.connect(func(id: StringName) -> void:
		if _built:
			hud.show_banner(str(BioBodyMap.NAMES.get(id, id)))
			get_tree().create_timer(2.2).timeout.connect(func() -> void:
				if is_instance_valid(hud) and hud.banner_text() == str(BioBodyMap.NAMES.get(id, id)):
					hud.show_banner(""))
			sync.system.push_feed("Nova região no atlas: %s." % BioBodyMap.NAMES.get(id, id)))
	panel = BioMutationPanel.new()
	panel.name = "MutationPanel"
	add_child(panel)
	panel.refresh(genome, tracker)

	_update_live()
	_populate(true)

	sync = BioHostSync.new()
	sync.name = "HostSync"
	sync.configure(self)
	add_child(sync)


## Confirmed events (food, kills, evasions) build evolutionary pressure; at the threshold a mutation is offered.
func add_pressure(points: int) -> void:
	if engine_evolution:
		return  # the engine counts the confirmed deed itself
	if tracker.add_pressure(points, genome):
		panel.show_offer(tracker.offer)
	BioGenomeStore.save(save_path, genome, tracker)


func pick_mutation(index: int) -> void:
	if not engine_lineage_offer.is_empty():  # differentiating comes first and is permanent
		if index >= 0 and index < engine_lineage_offer.size():
			sync.link.act("diferenciar", {"lineage": str(engine_lineage_offer[index].get("id", ""))})
			panel.hide_offer()
		return
	if engine_evolution:
		if index >= 0 and index < engine_offer.size():
			sync.link.act("evoluir", {"gene": engine_offer[index]})
			panel.hide_offer()
		return
	if not tracker.has_offer():
		return
	tracker.choose(index, genome)
	player.combatant.set_genome(genome)
	panel.hide_offer()
	BioGenomeStore.save(save_path, genome, tracker)


func decline_mutation() -> void:
	if not engine_lineage_offer.is_empty():
		return  # a lineage offer waits for the player: there is no refusing growth, only taking your time
	if engine_evolution:
		if not engine_offer.is_empty():
			sync.link.act("recusar-evolucao")
			panel.hide_offer()
		return
	if not tracker.has_offer():
		return
	tracker.decline()
	panel.hide_offer()
	BioGenomeStore.save(save_path, genome, tracker)


## The engine's view of this cell's evolution: expressed genes, the pending offer and the pressure.
## Engine ids use hyphens (cilios-ageis); the local catalogue uses underscores (cilios_ageis).
func apply_engine_evolution(ev: Dictionary) -> void:
	engine_evolution = true
	_pending_evolution = ev
	var expressed: Array[StringName] = []
	for g in ev.get("genes", []):
		var id := StringName(str(g.get("id", "")).replace("-", "_"))
		if BioGeneCatalog.all_ids().has(id):
			expressed.append(id)
	if expressed != genome.equipped:
		genome.equipped = expressed
		player.combatant.set_genome(genome)
	var offer: Array[String] = []
	for g in ev.get("offer", []):
		offer.append(str(g.get("id", "")))
	var featured := str(ev.get("featured", ""))
	if offer != engine_offer or featured != engine_featured:
		engine_offer = offer
		engine_featured = featured
		if offer.is_empty():
			if engine_lineage_offer.is_empty():
				panel.hide_offer()
		elif engine_lineage_offer.is_empty():
			var local: Array = offer.map(func(id: String) -> StringName: return StringName(id.replace("-", "_")))
			panel.show_offer(local, StringName(featured.replace("-", "_")))
	var threshold := maxf(1.0, float(ev.get("threshold", 1)))
	_engine_fraction = 1.0 if not offer.is_empty() else clampf(float(ev.get("pressure", 0)) / threshold, 0.0, 1.0)


## The engine's procedural body for this player, decided from how they play. It arrives in the
## background whenever the engine decides, and the body morphs towards it slowly.
func apply_engine_look(look: Dictionary) -> void:
	var axes: Dictionary = look.get("axes", {})
	if axes.is_empty():
		return
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).set_look(axes)
	look_name = str(look.get("name", ""))


## The engine's lineage for this player: the class they have become, the offer to differentiate and progress.
## The newborn is a plain ball (lineage ""); the form, stats and class mutations all follow from this.
func apply_engine_lineage(lin: Dictionary) -> void:
	var current := BioLineageCatalog.normalise(str(lin.get("current", "")))
	if current != lineage_id:
		lineage_id = current
		genome.lineage = current
		player.combatant.set_genome(genome)
	var label := "FORMA: " + (BioLineageCatalog.display_name(current) if current != &"" else "Esfera (indiferenciada)")
	var nxt := int(lin.get("next", 0))
	if nxt > 0 and engine_lineage_offer.is_empty():
		label += "   ·   maturidade %d/%d" % [int(lin.get("maturity", 0)), nxt]
	panel.set_lineage_text(label)
	var offer: Array[Dictionary] = []
	for o in lin.get("offer", []):
		offer.append(o)
	var featured := str(lin.get("featured", ""))
	if offer.size() != engine_lineage_offer.size() or featured != engine_lineage_featured:
		var had_offer := not engine_lineage_offer.is_empty()
		engine_lineage_offer = offer
		engine_lineage_featured = featured
		if offer.is_empty():
			if had_offer:  # growth done: the pending mutation offer, if any, can be shown now
				panel.hide_offer()
				engine_offer = []
				apply_engine_evolution(_pending_evolution)
		else:
			panel.show_lineage_offer(offer, featured)


## Back to the local loop (engine gone): the local tracker drives evolution again.
func release_engine_evolution() -> void:
	engine_evolution = false
	engine_offer = []
	engine_featured = ""
	panel.hide_offer()


## Starts everything again: a new world in the engine (when linked) and a newborn plain ball here, with no genes,
## class, abilities or look, in a fresh body of nutrients and virions. The old world stays archived by the engine.
func restart_world() -> void:
	hud.show_banner("O mundo recomeça…")
	if sync != null and sync.link != null and sync.link.online:
		var status := await sync.link.reset_world()
		if status != 200:
			hud.show_banner("Não consegui reiniciar o mundo no motor.")
			await get_tree().create_timer(2.5).timeout
			hud.show_banner("")
			return
	tracker = BioMutationTracker.new(seed_value)
	genome = BioGenome.new()
	player.combatant.set_genome(genome)
	BioGenomeStore.save(save_path, genome, tracker)
	panel.hide_offer()
	panel.refresh(genome, tracker)
	engine_offer = []
	engine_featured = ""
	engine_lineage_offer = []
	engine_lineage_featured = ""
	_pending_evolution = {}
	_engine_fraction = 0.0
	engine_evolution = false
	lineage_id = &""
	look_name = ""
	panel.set_lineage_text("FORMA: Esfera (indiferenciada)")
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).clear_look()
	abilities.clear()
	set_fever(false)
	set_sleeping(false)
	for node in get_tree().get_nodes_in_group("viruses") + get_tree().get_nodes_in_group("nutrients"):
		node.queue_free()
	await get_tree().process_frame
	player.set_active(true)
	player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
	player.velocity = Vector2.ZERO
	player.combatant.reset_vitals()
	region = BioBodyMap.MEDULA
	sync.link.region = String(region)
	_update_live()
	_populate(true)
	atlas.forget_all()
	sync.forget()
	sync.system.push_feed("O mundo recomeçou. Você é uma esfera outra vez.")
	hud.show_banner("")


func respawn_player() -> void:
	if player.combatant.actor.vitals.is_alive():
		return
	player.set_active(true)
	if fell_in_dungeon:  # back at the portal, not all the way to the marrow
		player.global_position = gate.global_position + Vector2(0.0, 3.4 * BioArt.UNIT)
		fell_in_dungeon = false
	else:
		player.global_position = BioBodyMap.center_px(BioBodyMap.MEDULA)
	player.velocity = Vector2.ZERO
	player.combatant.reset_vitals()
	hud.show_banner("")


## The host's vital signs arrived (from the engine's view): they weigh on the cell. Fever tires it, a lung short of air starves it of
## energy, adrenaline hurries it and insulin makes nutrients worth more.
func apply_body(vitals: Array) -> void:
	body.apply(vitals)
	player.combatant.environment_speed = body.speed_multiplier()
	player.combatant.actor.vitals.regen_scale = body.atp_regen_multiplier()
	BioNutrientRules.body_multiplier = body.nutrient_multiplier()
	if body.value("pulso") > 0.0:
		BioAnatomy.heart_hz = body.value("pulso") / 60.0
	vitals_panel.refresh()


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
	fell_in_dungeon = dungeon != null and dungeon.active
	if fell_in_dungeon:
		hud.show_banner("Você caiu no granuloma\nPressione R para voltar ao portal")
	else:
		hud.show_banner("A célula se dissolveu no fluido\nPressione R para renascer na medula")


func _process(delta: float) -> void:
	if not _built:
		return
	if not player.is_active() and Input.is_action_just_pressed("bio_respawn"):
		respawn_player()
	if player.is_active() and not dungeon.active:
		var now := BioBodyMap.region_of(player.global_position)
		if now != region:
			region = now
			_update_live()
			_populate(true)  # the regions that just woke fill up before the cell gets there
			atlas.set_region(region)
			region_changed.emit(region)
	if Input.is_action_just_pressed("bio_map"):
		atlas.toggle()
	if Input.is_action_just_pressed("bio_vitals"):
		vitals_panel.toggle()
	if dungeon.active:
		var left := dungeon.grace_left()
		hud.set_dungeon_extra("Prepare-se… %d" % ceili(left) if left > 0.0 else "WASD move · clique ataca · Q F C V habilidades · Backspace sai")
	if gate != null and gate.eligible and not dungeon.active and player.is_active():
		var to := gate.global_position - player.global_position
		var far := to.length() > 9.0 * BioArt.UNIT
		hud.set_guide(far, to, "%s  Granuloma · %d" % ["➤", roundi(to.length() / BioArt.UNIT)])
	elif not dungeon.active and player.is_active() and exploration != null:
		var trail := exploration.compass(player.global_position, region)
		if trail.is_empty() or float(trail["distance"]) < 12.0:
			hud.set_guide(false, Vector2.ZERO, "")
		else:
			compass_text = str(trail["hint"])
			hud.set_guide(true, (trail["target"] as Vector2) - player.global_position, "rastro químico · %d" % roundi(float(trail["distance"])))
	else:
		hud.set_guide(false, Vector2.ZERO, "")
	if not sync.wants_numbers():
		for i in 3:
			if Input.is_action_just_pressed("bio_pick_%d" % (i + 1)):
				pick_mutation(i)
	if Input.is_action_just_pressed("bio_decline"):
		decline_mutation()
	if engine_evolution:
		panel.refresh_values(genome, _engine_fraction)
	else:
		panel.refresh(genome, tracker)
	_upkeep_timer -= delta
	if _upkeep_timer > 0.0:
		return
	_upkeep_timer = 1.0
	_populate(false)


## The blood is a river that beats with the heart: cells and nutrients are carried by the flow of the body (vessels and chambers).
func _physics_process(delta: float) -> void:
	var clock := Time.get_ticks_msec() * 0.001
	if dungeon == null or not dungeon.active:  # inside the granuloma there is no current
		for node in get_tree().get_nodes_in_group("cells"):
			var cell := node as BioCellActor
			if cell != null and cell.is_active():
				cell.velocity += BioBodyMap.flow_px(cell.global_position, clock) * delta * 1.5
	for node in get_tree().get_nodes_in_group("nutrients"):
		var nutrient := node as Node2D
		nutrient.global_position += BioBodyMap.flow_px(nutrient.global_position, clock) * 0.6 * delta


## Keeps the regions around the cell alive: the one it is in and the ones a vessel away. The rest of the body sleeps.
func _update_live() -> void:
	live_regions = BioAnatomy.within(region, BioAnatomyView.LIVE_HOPS)
	anatomy.set_live(live_regions)


## The population of the body, streamed: each live region holds the nutrients and virions its biome calls for (scaled by the
## exported targets); what lies in sleeping regions is let go, and spawned again when the cell comes near.
func _populate(fill_all: bool) -> void:
	var nutrient_scale := float(nutrient_target) / 45.0
	var virus_scale := float(virus_count) / 6.0
	var nutrients_in := {}
	var viruses_in := {}
	for node in get_tree().get_nodes_in_group("nutrients"):
		var at := (node as Node2D).global_position
		if not BioAnatomy.in_body(seed_value, at / BioArt.UNIT):
			continue  # not the body's: leave it be (the granuloma's drops)
		var r := BioBodyMap.region_of(at)
		if not live_regions.has(r):
			node.queue_free()
		else:
			nutrients_in[r] = int(nutrients_in.get(r, 0)) + 1
	for node in get_tree().get_nodes_in_group("viruses"):
		var r2 := BioBodyMap.region_of((node as Node2D).global_position)
		if not live_regions.has(r2):
			node.queue_free()
		else:
			viruses_in[r2] = int(viruses_in.get(r2, 0)) + 1
	for id in live_regions:
		var def := BioAnatomy.region_def(id)
		var want_n := roundi(float(def["nutrients"]) * nutrient_scale)
		var want_v := roundi(float(def["viruses"]) * virus_scale)
		var missing_n: int = want_n - int(nutrients_in.get(id, 0))
		var missing_v: int = want_v - int(viruses_in.get(id, 0))
		for i in (missing_n if fill_all else mini(missing_n, 3)):
			_spawn_nutrient_in(id, 0.0 if fill_all else 8.0)
		for i in (missing_v if fill_all else mini(missing_v, 1)):
			if fill_all or _virus_respawn_timer <= 0.0:
				_spawn_virus_in(id, 12.0 if fill_all else 14.0)
				_virus_respawn_timer = 6.0
	_virus_respawn_timer -= 1.0


func _spawn_nutrient_in(where: StringName, min_distance_units: float) -> void:
	var kind := BioNutrientRules.Kind.GLUCOSE if _rng.randf() < 0.75 else BioNutrientRules.Kind.LIPID
	BioFactory.spawn_nutrient(self, BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units), kind)


func _spawn_nutrient(min_distance_units: float) -> void:
	_spawn_nutrient_in(BioBodyMap.MEDULA if _rng.randf() < 0.6 else BioBodyMap.SANGUE, min_distance_units)


func _spawn_virus(min_distance_units: float) -> void:
	_spawn_virus_in(BioBodyMap.SANGUE, min_distance_units)


func _spawn_virus_in(where: StringName, min_distance_units: float) -> void:
	var pos := BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units)
	var brain := BioFactory.spawn_virus(self, pos, player)
	var host := brain.get_parent() as BioCellActor
	host.max_speed_units = _virus_speed()
	host.combatant.died.connect(func(_who: BioCombatant) -> void:
		add_pressure(BioMutationTracker.KILL_POINTS)
		virus_destroyed.emit())


func _add_glow_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.8
	env.glow_bloom = 0.03
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	var holder := WorldEnvironment.new()
	holder.name = "GlowEnvironment"
	holder.environment = env
	add_child(holder)
