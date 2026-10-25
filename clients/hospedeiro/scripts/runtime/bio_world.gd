class_name BioWorld
extends Node2D
## Composition root: the marrow and the blood, camera, glow, player, HUD, population upkeep, the
## mutation loop and the link to the engine (BioHostSync). Plays offline when the engine is absent.

signal region_changed(region: StringName)
signal virus_destroyed
signal nutrient_absorbed
signal evaded
signal toxin_filtered
signal glycogen_stored
signal organ_deed(action: String)  # a verb of an organ was done (a mote taken, a kill in the spleen...): the game server tells the engine

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
var design_traits: Dictionary = {}  # what Jev designed for this cell (engine look traits)
var design_source := "nenhuma"  # motor (Jev or default), debug or nenhuma
var design_changed_at := -1.0
var engine_traits: Dictionary = {}  # the last design the engine sent, kept for F6
var design_debug: BioDesignDebug
var jev_panel: BioJevPanel
var debug_menu: BioDebugMenu
var debug_god := false
var touch: BioTouchControls
var display: BioDisplay
var online_client: BioOnlineClient

## Rooms and classes the test menu goes straight to.
const DEBUG_ROOMS := [
	{"id": "guarda-de-linfocitos", "name": "A guarda de linfócitos", "kind": "guard"},
	{"id": "parede-de-macrofagos", "name": "A parede de macrófagos", "kind": "wall"},
	{"id": "anel-interno", "name": "O anel interno", "kind": "wall"},
	{"id": "nucleo-necrotico", "name": "O núcleo necrótico", "kind": "core"},
	{"id": "bacilo", "name": "O bacilo (chefe)", "kind": "boss"},
]
const DEBUG_CLASSES := [&"macrofago", &"neutrofilo", &"dendritica", &"linfocito_b", &"t_citotoxico", &"t_auxiliar", &"mastocito", &"eosinofilo", &"celula_nk", &"t_regulador"]
var codex_panel: BioCodexPanel
var adapted_regions: Array = []
var compass_text := ""
var body := BioBodyState.new()  # the host's vital signs (from the engine) and what they do to the cell
var vitals_panel: BioVitalsPanel
var live_regions: Array[StringName] = []
var fell_in_dungeon := false
var gate: BioGate  # the granuloma's
var liver_gate: BioGate
var gates: Dictionary = {}  # dungeon id -> its gate
var hud: BioHud
var camera: BioCameraFollow
var genome: BioGenome
var tracker: BioMutationTracker
var panel: BioMutationPanel
var tray: BioCallTray
var reset_dialog: BioResetDialog
var body_panel: BioBodyPanel
var build_store: BioBuildStore
var sync: BioHostSync
var region: StringName = BioBodyMap.MEDULA
var fever := false
var sleeping := false
## Online, the engine owns the genome, the pressure and the offer (the advisor reads how the player lives).
var engine_evolution := false
var evolution_presentation: BioEvolutionPresentation
var engine_offer: Array[String] = []  # engine gene ids of the pending offer
var engine_featured := ""
var engine_lineage_offer: Array[Dictionary] = []  # pending differentiation offer (engine)
var engine_lineage_featured := ""
var lineage_id: StringName = &""
var _pending_evolution := {}
var _engine_lineage := {}
var look_name := ""  # the variant the advisor chose for this body (Caçador, Andarilho...)
var _engine_fraction := 0.0

var _rng := RandomNumberGenerator.new()
var _built := false
var _upkeep_timer := 0.0
var _virus_respawn_timer := 0.0
var _tint: CanvasModulate
var _flow_owed := 0.0


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
	if not engine_url.is_empty():
		engine_url = BioPlatform.engine_url(engine_url)
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
		nutrient_absorbed.emit()
		if region == BioBodyMap.FIGADO:
			glycogen_stored.emit()  # in the liver a nutrient is also kept, as glycogen
		elif region == BioBodyMap.RIM:
			organ_deed.emit("equilibrar-sal"))  # in the kidney it is salt to be balanced
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
	liver_gate = BioGate.new()
	liver_gate.name = "CordsGate"
	liver_gate.dungeon_id = "cordoes-hepaticos"
	liver_gate.title = "CORDÕES HEPÁTICOS"
	liver_gate.ring_color = Color(0.95, 0.65, 0.2)
	liver_gate.core_color = Color(0.75, 0.9, 0.2)
	liver_gate.position = BioBodyMap.center_px(BioBodyMap.FIGADO) + Vector2(-8.0, 12.0) * BioArt.UNIT
	add_child(liver_gate)
	liver_gate.configure(player)
	gates = {gate.dungeon_id: gate, liver_gate.dungeon_id: liver_gate}
	_add_organ_gates()
	dungeon.bind(player, gate.global_position + Vector2(0.0, 3.4 * BioArt.UNIT))
	for g in gates.values():
		dungeon.returns[(g as BioGate).dungeon_id] = (g as BioGate).global_position + Vector2(0.0, 3.4 * BioArt.UNIT)
	dungeon.room_started.connect(func(index: int, info: Dictionary) -> void:
		hud.set_dungeon_text("%s  ·  sala %d/%d  ·  %s" % [dungeon.title, index + 1, dungeon.rooms.size(), str(info.get("name", ""))]))
	dungeon.finished.connect(func(_cleared: bool) -> void: hud.set_dungeon_text(""))
	hud.restart_requested.connect(func() -> void: reset_dialog.open())
	codex_panel = BioCodexPanel.new()
	codex_panel.name = "CodexPanel"
	add_child(codex_panel)
	codex_panel.configure()
	jev_panel = BioJevPanel.new()
	jev_panel.name = "JevPanel"
	add_child(jev_panel)
	jev_panel.configure(self)
	debug_menu = BioDebugMenu.new()
	debug_menu.name = "DebugMenu"
	add_child(debug_menu)
	debug_menu.configure(self)
	design_debug = BioDesignDebug.new()
	design_debug.name = "DesignDebug"
	add_child(design_debug)
	design_debug.configure(self)
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
	build_store = BioBuildStore.new("" if save_path.is_empty() else "user://hospedeiro_builds.json")
	tray = BioCallTray.new()
	tray.name = "CallTray"
	add_child(tray)
	body_panel = BioBodyPanel.new()
	body_panel.name = "BodyPanel"
	add_child(body_panel)
	body_panel.configure(self)
	evolution_presentation = BioEvolutionPresentation.new()
	add_child(evolution_presentation)
	evolution_presentation.configure(self)
	reset_dialog = BioResetDialog.new()
	add_child(reset_dialog)
	reset_dialog.configure(self)
	panel.offer_changed.connect(_sync_calls)
	tray.chip_activated.connect(_open_from_chip)

	_update_live()
	_populate(true)

	sync = BioHostSync.new()
	sync.name = "HostSync"
	sync.configure(self)
	add_child(sync)
	if BioOnlineClient.wanted(engine_url):
		online_client = BioOnlineClient.new()
		online_client.world = self
		add_child(online_client)
	if BioPlatform.is_touch():
		_build_for_touch()
	if BioWebProbe.wanted():
		var probe := BioWebProbe.new()
		probe.name = "WebProbe"
		probe.world = self
		add_child(probe)


## A phone or tablet: the interface sized for a thumb, the on-screen controls, and the HUD rearranged around them.
func _build_for_touch() -> void:
	var stride := BioPlatform.query_param("stride")
	BioCellBody.background_stride = int(stride) if stride.is_valid_int() else 2
	display = BioDisplay.new()
	display.name = "Display"
	display.world = self
	add_child(display)
	touch = BioTouchControls.new()
	touch.name = "Touch"
	add_child(touch)
	touch.configure(self)
	hud.set_touch(true)
	tray.set_touch(true)
	panel.set_touch(true)
	sync.system.set_touch(true)


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
			var option: Dictionary = engine_lineage_offer[index]
			if not evolution_presentation.begin(option): return
			var run := evolution_presentation._run
			var result := await sync.link.act("diferenciar", {"lineage": str(option.get("id", "")), "design":"refresh"})
			evolution_presentation.request_finished(int(result.get("status", 0)), run)
			if int(result.get("status", 0)) == 200: panel.hide_offer()
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
	var changed := ev != _pending_evolution
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
	if changed and body_panel != null:
		body_panel.refresh()


## The engine's procedural body for this player, decided from how they play. It arrives in the
## background whenever the engine decides, and the body morphs towards it slowly.
func apply_engine_look(look: Dictionary) -> void:
	if evolution_presentation != null: evolution_presentation.observe(look)
	var designed: Dictionary = look["traits"] if look.get("traits") is Dictionary else {}
	var changed := designed != engine_traits
	engine_traits = designed.duplicate()
	if changed or (design_source == "nenhuma" and not designed.is_empty()):  # a debug preview stays until the engine says something new
		apply_design(designed, "motor")
	var axes: Dictionary = look["axes"] if look.get("axes") is Dictionary else {}  # the engine sends null until the body has a variant
	if axes.is_empty():
		return
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).set_look(axes)
	look_name = str(look.get("name", ""))


## Applies a design (what Jev decided, or a debug preview) to the body, the abilities and the particles. One place, so what the debug
## overlay shows is what is really in effect.
func apply_design(designed: Dictionary, source: String) -> void:
	design_traits = designed.duplicate()
	design_source = source if not designed.is_empty() else "nenhuma"
	design_changed_at = Time.get_ticks_msec() * 0.001
	abilities.effect_style = StringName(str(design_traits.get("efeito", "")))
	abilities.projectile_traits = design_traits.duplicate()
	player.combatant.effect_style = abilities.effect_style if BioEffectPhysics.has_style(abilities.effect_style) else &""
	player.combatant.focus = BioAbilityFocus.params(design_traits)
	player.combatant.modes = BioAbilityMode.from_traits(design_traits)
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).set_traits(design_traits)
	print("[design] origem=%s traços=%s" % [design_source, str(design_traits)])
	if design_debug != null:
		design_debug.refresh()


## The shortcuts behind the test menu (Esc). Each one is a plain method, so it is tested without a screen.
func debug_goto(id: StringName) -> void:
	if dungeon.active:
		dungeon.finish(false)
	player.global_position = BioBodyMap.center_px(id)
	player.velocity = Vector2.ZERO
	player.set_active(true)
	player.combatant.reset_vitals()
	hud.show_banner("")


func debug_dungeon_room(index: int) -> void:
	if dungeon.active:
		dungeon.finish(false)
	player.set_active(true)
	player.combatant.reset_vitals()
	dungeon.start({"state": "active", "seed": 424242, "room": index, "rooms": DEBUG_ROOMS, "modifier": {"id": "necrose-viva", "name": "Necrose viva", "desc": ""}})
	hud.show_banner("")


func debug_leave_dungeon() -> void:
	if dungeon.active:
		dungeon.finish(false)
		respawn_player()


func debug_become(lineage: StringName) -> void:
	lineage_id = lineage
	genome.lineage = lineage
	player.combatant.set_genome(genome)
	abilities.clear()
	for id in BioAbilityCatalog.ids_of_class(lineage):
		abilities.learn(id)
	debug_refill()


func debug_spawn_virions(count: int) -> void:
	for i in count:
		var a := TAU * i / maxf(count, 1) + randf() * 0.4
		_spawn_virus_at(player.global_position + Vector2.from_angle(a) * randf_range(4.0, 8.0) * BioArt.UNIT)


func debug_clear_virions() -> void:
	for v in viruses():
		v.queue_free()


func debug_refill() -> void:
	player.set_active(true)
	player.combatant.actor.vitals.membrane = player.combatant.actor.vitals.max_membrane
	player.combatant.actor.vitals.atp = player.combatant.actor.vitals.max_atp


func debug_reset_cooldowns() -> void:
	player.combatant.actor._ready_at.clear()


func debug_toggle_god() -> void:
	debug_god = not debug_god
	hud.show_banner("INVULNERÁVEL LIGADO" if debug_god else "")


func debug_random_design() -> void:
	_debug_random_design()


func debug_engine_design() -> void:
	apply_design(engine_traits, "motor")


## Moves one trait to its next option (what F4, F7, F8 and F9 do).
func debug_cycle(trait_id: String) -> void:
	var options: Array
	match trait_id:
		"efeito":
			options = BioEffectSignature.STYLES.map(func(s: StringName) -> String: return String(s))
		"trajetoria":
			options = BioProjectileDesign.TRAJECTORIES
		"impacto":
			options = BioProjectileDesign.IMPACTS.keys()
		"calibre":
			options = BioProjectileDesign.CALIBRE.keys()
		"foco":
			options = BioAbilityFocus.FOCUS.keys()
		_:
			return
	var cur := design_traits.duplicate()
	cur[trait_id] = options[(options.find(str(cur.get(trait_id, ""))) + 1) % options.size()]
	apply_design(cur, "debug")


## Debug keys: F4 cycles the effect style, F5 tries a random design, F6 goes back to the engine's.
func _debug_keys() -> void:
	if online_client != null:
		return
	if not BioPlatform.debug_enabled():
		return
	if Input.is_action_just_pressed("bio_jev"):
		jev_panel.toggle()
	if Input.is_action_just_pressed("bio_menu"):
		debug_menu.toggle()
	if Input.is_action_just_pressed("bio_debug_toggle"):
		design_debug.toggle()
	if Input.is_action_just_pressed("bio_debug_style"):
		var styles: Array = BioEffectSignature.STYLES
		var next: StringName = styles[(styles.find(abilities.effect_style) + 1) % styles.size()]
		var cur := design_traits.duplicate()
		cur["efeito"] = String(next)
		apply_design(cur, "debug")
	if Input.is_action_just_pressed("bio_debug_random"):
		_debug_random_design()
	for pair in [["bio_debug_impact", "impacto", BioProjectileDesign.IMPACTS.keys()], ["bio_debug_path", "trajetoria", BioProjectileDesign.TRAJECTORIES], ["bio_debug_calibre", "calibre", BioProjectileDesign.CALIBRE.keys()]]:
		if Input.is_action_just_pressed(pair[0]):
			var options: Array = pair[2]
			var cur := design_traits.duplicate()
			cur[pair[1]] = options[(options.find(str(cur.get(pair[1], ""))) + 1) % options.size()]
			apply_design(cur, "debug")
	if Input.is_action_just_pressed("bio_debug_engine"):
		apply_design(engine_traits, "motor")


## The engine's lineage for this player: the class they have become, the offer to differentiate and progress.
## The newborn is a plain ball (lineage ""); the form, stats and class mutations all follow from this.
func apply_engine_lineage(lin: Dictionary) -> void:
	var lineage_changed := lin != _engine_lineage
	_engine_lineage = lin
	var current := BioLineageCatalog.normalise(str(lin.get("current", "")))
	if current != lineage_id:
		lineage_id = current
		genome.lineage = current
		player.combatant.set_genome(genome)
	var label := BioLineageCatalog.display_name(current) if current != &"" else "Esfera"
	var nxt := int(lin.get("next", 0))
	if nxt > 0 and engine_lineage_offer.is_empty():
		label += "  ·  maturidade %d/%d" % [int(lin.get("maturity", 0)), nxt]
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
	if lineage_changed and body_panel != null:
		body_panel.refresh()


## The engine's expressed genes, library, builds and rest, as the last view said (empty offline).
func engine_evolution_view() -> Dictionary:
	return _pending_evolution if engine_evolution else {}


func engine_lineage_view() -> Dictionary:
	return _engine_lineage


## The chips of the call tray follow the pending offer: one for a differentiation, one for a mutation, none otherwise.
func _sync_calls() -> void:
	if tray == null:
		return
	match panel.offer_kind():
		"lineage":
			tray.clear_call("mutation")
			tray.set_call("lineage", "lineage", "Diferenciação disponível", "seu corpo pode se tornar outra forma", "G")
		"mutation":
			tray.clear_call("lineage")
			tray.set_call("mutation", "mutation", "Mutação disponível", "%d genes para escolher" % panel.entries().size(), "G")
		_:
			tray.clear_call("lineage")
			tray.clear_call("mutation")
	if body_panel != null and body_panel.is_open():
		body_panel.refresh()


func _open_from_chip(key: String) -> void:
	if key == "active_quest":
		sync.system.open_missions()
		return
	if key == "quest":
		sync.system.open_offer()
		return
	body_panel.open()


## Two abilities trade keys, and the order is remembered.
func swap_abilities(a: int, b: int) -> void:
	abilities.swap_slots(a, b)
	build_store.remember_current(abilities.known())


func arrange_abilities(order: Array) -> void:
	abilities.arrange(order)
	build_store.remember_current(abilities.known())


## The order the player gave their abilities, restored once the engine says which ones the class knows.
func restore_ability_order() -> void:
	abilities.arrange(build_store.current_order)


## Back to the local loop (engine gone): the local tracker drives evolution again.
func release_engine_evolution() -> void:
	engine_evolution = false
	engine_offer = []
	engine_featured = ""
	panel.hide_offer()


## Starts everything again: a new world in the engine (when linked) and a newborn plain ball here, with no genes,
## class, abilities or look, in a fresh body of nutrients and virions. The old world stays archived by the engine.
func restart_world(reset_engine := true) -> void:
	if evolution_presentation != null:
		evolution_presentation.reset()
	hud.show_banner("O mundo recomeça…")
	if reset_engine and sync != null and sync.link != null and sync.link.online:
		var status := await sync.link.reset_world()
		if status != 200:
			hud.show_banner("Não consegui reiniciar o mundo no motor.")
			await get_tree().create_timer(2.5).timeout
			hud.show_banner("")
			return
	body_panel.close()
	sync.system.close()
	reset_dialog.close()
	dungeon.finish(false)
	build_store.names.clear()
	build_store.orders.clear()
	build_store.current_order.clear()
	build_store.save()
	codex_panel.set_data([], [])
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
	panel.set_lineage_text("Esfera")
	for child in player.get_children():
		if child is BioCellBody:
			(child as BioCellBody).clear_look()
	abilities.clear()
	set_fever(false)
	set_sleeping(false)
	for node in get_tree().get_nodes_in_group("viruses") + get_tree().get_nodes_in_group("nutrients") + get_tree().get_nodes_in_group("toxins"):
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
	if online_client != null:
		online_client.queue_action("respawn")
		return
	if player.combatant.actor.vitals.is_alive():
		return
	player.set_active(true)
	if fell_in_dungeon:  # back at the portal, not all the way to the marrow
		player.global_position = (gates[dungeon.dungeon_id] as BioGate).global_position + Vector2(0.0, 3.4 * BioArt.UNIT)
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
	_apply_regen()
	BioNutrientRules.body_multiplier = body.nutrient_multiplier()
	if body.value("pulso") > 0.0:
		BioAnatomy.heart_hz = body.value("pulso") / 60.0
	vitals_panel.refresh()


## Energy comes back at the pace the body allows (fever, a lung short of air), faster in a place the cell has adapted to.
func _apply_regen() -> void:
	var adapted_here := adapted_regions.has(String(region))
	player.combatant.actor.vitals.regen_scale = body.atp_regen_multiplier() * (1.15 if adapted_here else 1.0)


## The regions the engine says this cell has adapted to by living in them.
func set_adapted(regions: Array) -> void:
	adapted_regions = regions
	_apply_regen()


## Fever (a body state the player knows of): virions slow down.
func set_fever(on: bool) -> void:
	if fever == on:
		return
	fever = on
	for v in viruses():
		(v as BioCellActor).max_speed_units = float(v.get_meta("base_speed", VIRUS_SPEED)) * (FEVER_SLOWDOWN if fever else 1.0)
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
		hud.show_banner(("Você caiu no granuloma" if dungeon.dungeon_id == "granuloma" else "Você caiu em %s" % dungeon.title.capitalize()) + ("\nToque em Renascer para voltar ao portal" if BioPlatform.is_touch() else "\nPressione R para voltar ao portal"))
	else:
		hud.show_banner("A célula se dissolveu no fluido\n" + ("Toque em Renascer para voltar à medula" if BioPlatform.is_touch() else "Pressione R para renascer na medula"))


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
			_apply_regen()
			region_changed.emit(region)
	if Input.is_action_just_pressed("bio_map"):
		atlas.toggle()
	if Input.is_action_just_pressed("bio_vitals"):
		vitals_panel.toggle()
	if Input.is_action_just_pressed("bio_codex"):
		codex_panel.toggle()
	if Input.is_action_just_pressed("bio_body") and not BioUi.typing():
		body_panel.toggle()
	_debug_keys()
	if debug_god:
		player.combatant.actor.vitals.membrane = player.combatant.actor.vitals.max_membrane
		player.combatant.actor.vitals.atp = player.combatant.actor.vitals.max_atp
	if dungeon.active:
		var left := dungeon.grace_left()
		hud.set_dungeon_extra("Prepare-se… %d" % ceili(left) if left > 0.0 else ("Segure para atacar · arraste para mirar" if BioPlatform.is_touch() else "WASD move · clique ataca · Q F C V habilidades · Backspace sai"))
	var guide_gate := _nearest_open_gate()
	if guide_gate != null and not dungeon.active and player.is_active():
		var to := guide_gate.global_position - player.global_position
		var far := to.length() > 9.0 * BioArt.UNIT
		hud.set_guide(far, to, "%s  %s · %d" % ["➤", guide_gate.title.capitalize(), roundi(to.length() / BioArt.UNIT)])
	elif not dungeon.active and player.is_active() and exploration != null:
		var trail := exploration.compass(player.global_position, region)
		if trail.is_empty() or float(trail["distance"]) < 12.0:
			hud.set_guide(false, Vector2.ZERO, "")
		else:
			compass_text = str(trail["hint"])
			hud.set_guide(true, (trail["target"] as Vector2) - player.global_position, "rastro químico · %d" % roundi(float(trail["distance"])))
	else:
		hud.set_guide(false, Vector2.ZERO, "")
	if body_panel.is_open() and not sync.wants_numbers() and not BioUi.typing():  # offers are chosen in the Body window, when calm
		for i in 5:
			if Input.is_action_just_pressed("bio_pick_%d" % (i + 1)):
				body_panel.pick(i)
		if Input.is_action_just_pressed("bio_decline"):
			body_panel.decline()
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
	if online_client != null:
		return
	if BioCellBody.background_stride > 1:  # the current is slow: on a phone it is stepped every other tick, with the time it was owed
		_flow_owed += delta
		if Engine.get_physics_frames() % 2 == 1:
			return
		delta = _flow_owed
		_flow_owed = 0.0
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
## The entrances of the dungeons of the next organs: where, how it is called and how it looks. The granuloma's and the cords' are above.
const ORGAN_GATES := [
	{"id": "centro-germinativo", "region": &"baco", "title": "CENTRO GERMINATIVO", "at": Vector2(-8.0, 14.0), "ring": Color(0.65, 0.45, 0.95), "core": Color(0.95, 0.45, 0.8)},
	{"id": "criptas-profundas", "region": &"intestino", "title": "CRIPTAS PROFUNDAS", "at": Vector2(10.0, -14.0), "ring": Color(0.55, 0.9, 0.4), "core": Color(0.95, 0.8, 0.3)},
	{"id": "nefrons", "region": &"rim", "title": "NÉFRONS", "at": Vector2(-6.0, -13.0), "ring": Color(0.35, 0.9, 0.85), "core": Color(1.0, 0.85, 0.4)},
]


func _add_organ_gates() -> void:
	for g in ORGAN_GATES:
		var door := BioGate.new()
		door.name = "Gate_%s" % g["id"]
		door.dungeon_id = g["id"]
		door.title = g["title"]
		door.ring_color = g["ring"]
		door.core_color = g["core"]
		door.position = BioBodyMap.center_px(g["region"]) + (g["at"] as Vector2) * BioArt.UNIT
		add_child(door)
		door.configure(player)
		gates[g["id"]] = door


## The open dungeon entrance closest to the cell (null when none is open).
func _nearest_open_gate() -> BioGate:
	var best: BioGate = null
	for g in gates.values():
		var candidate := g as BioGate
		if candidate.eligible and (best == null or candidate.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = candidate
	return best


func _update_live() -> void:
	live_regions = BioAnatomy.within(region, BioAnatomyView.LIVE_HOPS)
	anatomy.set_live(live_regions)


## The population of the body, streamed: each live region holds the nutrients and virions its biome calls for (scaled by the
## exported targets); what lies in sleeping regions is let go, and spawned again when the cell comes near.
func _populate(fill_all: bool) -> void:
	if online_client != null:
		return
	var nutrient_scale := float(nutrient_target) / 45.0
	var virus_scale := float(virus_count) / 6.0
	var nutrients_in := {}
	var viruses_in := {}
	var toxins_in := {}
	var motes_in := {}
	for node in get_tree().get_nodes_in_group("toxins"):
		var rt := BioBodyMap.region_of((node as Node2D).global_position)
		if not live_regions.has(rt):
			node.queue_free()
		else:
			toxins_in[rt] = int(toxins_in.get(rt, 0)) + 1
	for node in get_tree().get_nodes_in_group("nutrients"):
		var at := (node as Node2D).global_position
		if not BioAnatomy.in_body(seed_value, at / BioArt.UNIT):
			continue  # not the body's: leave it be (the granuloma's drops)
		var r := BioBodyMap.region_of(at)
		if not live_regions.has(r):
			node.queue_free()
		else:
			nutrients_in[r] = int(nutrients_in.get(r, 0)) + 1
	for node in get_tree().get_nodes_in_group("motes"):
		var rm := BioBodyMap.region_of((node as Node2D).global_position)
		if not live_regions.has(rm):
			node.queue_free()
		else:
			motes_in[rm] = int(motes_in.get(rm, 0)) + 1
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
		var missing_t: int = int(def.get("toxins", 0)) - int(toxins_in.get(id, 0))
		for i in (missing_t if fill_all else mini(missing_t, 2)):
			_spawn_toxin_in(id, 0.0 if fill_all else 8.0)
		for mote_kind in (def.get("motes", {}) as Dictionary):
			var missing_m: int = int((def["motes"] as Dictionary)[mote_kind]) - int(motes_in.get(id, 0))  # (one kind per organ)
			for i in (missing_m if fill_all else mini(missing_m, 2)):
				_spawn_mote_in(id, mote_kind, 0.0 if fill_all else 8.0)
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


func _spawn_toxin_in(where: StringName, min_distance_units: float) -> void:
	var toxin := BioToxin.new()
	toxin.name = "Toxin"
	toxin.position = BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units)
	toxin.resistant_check = func() -> bool: return genome != null and genome.has_gene(BioToxinRules.RESISTANT_GENE)
	toxin.filtered.connect(func() -> void:
		add_pressure(BioMutationTracker.NUTRIENT_POINTS)
		toxin_filtered.emit())
	add_child(toxin)


func _spawn_mote_in(where: StringName, kind: StringName, min_distance_units: float) -> void:
	var mote := BioMote.new()
	mote.name = "Mote"
	mote.configure(kind)
	mote.position = BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units)
	mote.taken.connect(func(taken_kind: StringName) -> void:
		add_pressure(BioMutationTracker.NUTRIENT_POINTS)
		organ_deed.emit(str(BioMoteRules.kind(taken_kind)["action"])))
	add_child(mote)


func _spawn_virus(min_distance_units: float) -> void:
	_spawn_virus_in(BioBodyMap.SANGUE, min_distance_units)


func _spawn_virus_in(where: StringName, min_distance_units: float) -> void:
	var at := BioBodyMap.random_point_px(_rng, where, player.global_position, min_distance_units)
	var kind := BioBestiary.pick(where, _rng)  # each organ has its own wild things (the blood has the virion)
	if kind == BioBestiary.VIRION:
		_spawn_virus_at(at)
	else:
		_spawn_native_at(kind, at)


## A wild thing died: pressure and the confirmed kill, and in the spleen and the intestine the verb of the organ too.
func _on_wild_kill(at: Vector2) -> void:
	add_pressure(BioMutationTracker.KILL_POINTS)
	virus_destroyed.emit()
	match BioBodyMap.region_of(at):
		BioBodyMap.BACO:
			organ_deed.emit("capturar-antigeno")
		BioBodyMap.INTESTINO:
			organ_deed.emit("repelir-invasor")


## A wild thing of an organ (see BioBestiary): counted with the virions, so it is streamed, slowed by fever and paid in pressure alike.
func _spawn_native_at(kind: StringName, pos: Vector2) -> void:
	var def := BioDungeonPlan.enemy(kind)
	for i in int(def.get("group", 1)):
		var at := pos + Vector2.from_angle(randf() * TAU) * (0.8 * BioArt.UNIT if i > 0 else 0.0)
		var brain := BioFactory.spawn_enemy(self, at, player, def, FEVER_SLOWDOWN if fever else 1.0, "viruses")
		var host := brain.get_parent() as BioCellActor
		host.set_meta("kind", str(kind))
		host.set_meta("base_speed", float(def["speed"]))
		host.combatant.died.connect(func(_who: BioCombatant) -> void:
			_on_wild_kill(host.global_position)
			var split: Variant = def.get("split")
			if split is Dictionary:
				for k in int((split as Dictionary)["count"]):
					_spawn_native_at.call_deferred(StringName((split as Dictionary)["kind"]), host.global_position + Vector2.from_angle(randf() * TAU) * 0.9 * BioArt.UNIT))


func _spawn_virus_at(pos: Vector2) -> void:
	var brain := BioFactory.spawn_virus(self, pos, player)
	var host := brain.get_parent() as BioCellActor
	host.max_speed_units = _virus_speed()
	host.combatant.died.connect(func(_who: BioCombatant) -> void: _on_wild_kill(host.global_position))


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


## A whole design drawn at random from every option the client knows (nucleus, membrane, effects, projectile, focus and the mode of
## each family), to see combinations without waiting for the engine.
func _debug_random_design() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick := func(options: Array) -> Variant: return options[rng.randi() % options.size()]
	var designed := {
		"nucleo": "composto", "lobulacao": pick.call(BioDesign.LOBES.keys()), "recorte": pick.call(BioDesign.CUTS), "nucleolo": pick.call(BioDesign.NUCLEOLI),
		"membrana": pick.call(BioDesign.MEMBRANES), "organelas": pick.call(BioDesign.ORGANELLES), "brilho": pick.call(BioDesign.GLOW.keys()),
		"efeito": String(pick.call(BioEffectSignature.STYLES)), "foco": pick.call(BioAbilityFocus.FOCUS.keys()),
		"trajetoria": pick.call(BioProjectileDesign.TRAJECTORIES), "calibre": pick.call(BioProjectileDesign.CALIBRE.keys()),
		"impacto": pick.call(BioProjectileDesign.IMPACTS.keys()), "ritmo": pick.call(BioProjectileDesign.TEMPO.keys())}
	for family in BioAbilityMode.TRAIT_OF:
		designed[BioAbilityMode.TRAIT_OF[family]] = pick.call(BioAbilityMode.FAMILIES[family])
	apply_design(designed, "debug")
