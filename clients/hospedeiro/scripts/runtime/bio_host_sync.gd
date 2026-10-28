class_name BioHostSync
extends Node
## Bridges the local game and the engine. Outgoing: confirmed happenings (virion destroyed, nutrient
## absorbed), region changes and the player's intentions (accept, decline, the action menu). Incoming:
## the engine's view, turned into the System window, resident cells, traces, body states and genes.
## Without an engine everything here stays quiet and the game plays offline.

## Echoes of the player's own combat and lifecycle notices already shown elsewhere (the System window).
const QUIET_EVENTS := ["abate", "nutriente", "faro", "esquiva", "join", "moved", "evolution-offered", "evolution-declined", "mutated", "lineage-offered", "calling-assumed", "calling-released", "appearance", "skill-learned", "conflict-reward", "codice", "adaptou", "rota", "design"]

## How the menu names what can be told (the engine gives the predicate and subject).
const TOLD := {
	"assinatura": "como é o Vírion Espinhoso",
	"foco": "o foco de infecção no sangue",
	"alerta": "o alarme de citocina",
	"febre": "a febre do Hospedeiro",
	"sono": "o sono do Hospedeiro",
	"codigo-estranho": "o brilho estranho no nicho",
	"defesa-armada": "a defesa armada",
	"reescrita-revelada": "a Reescrita",
}

var link: BioEngineLink
var system: BioSystemPanel

var _world: BioWorld
var _residents := {}  # entity id -> BioResident
var _signs := {}  # sign id -> BioSignMarker
var _names := {}  # entity id -> display name
var _last_seq := -1
var _announce_abilities := false  # the first view is history, not news
const FOLLOW_SECONDS := 90.0

var prefs: BioVisualPrefs
var presenter: BioNpcPresenter
var mood: BioTissueMood
var crowd: BioWorkCrowd
var living_hud: BioLivingHud
var tones: BioLivingSound
var _follow_npc := ""
var _follow_region := ""
var _follow_until := 0.0

## Behaviour the engine reads to shape the body. It is reported in batches, in the background:
## one confirmation per kind per interval, so combat never waits on the network.
const REPORT_SECONDS := 3.0
const EXPLORE_UNITS := 15.0
var _used := {}  # attack id -> used since the last report
var _report_in := REPORT_SECONDS
var _travelled := 0.0
var _last_pos := Vector2.ZERO


func configure(world: BioWorld) -> void:
	_world = world


func _ready() -> void:
	system = BioSystemPanel.new()
	system.name = "SystemPanel"
	add_child(system)
	link = BioPersonalLink.new() if BioPersonalLink.wanted() else BioEngineLink.new()
	link.name = "EngineLink"
	if not _world.engine_url.is_empty():
		var identity := BioEngineLink.local_identity(_world.identity_path)
		link.configure(_world.engine_url, identity, _world.identity_path)
		link.capabilities_changed.connect(func(allowed: bool) -> void: _world.hud.set_restart_allowed(allowed))
	system.tray = _world.tray
	system.menu_chosen.connect(choose)
	link.region = String(_world.region)
	link.world_reset_detected.connect(func() -> void: _world.restart_world(false))
	link.status_changed.connect(_on_status)
	link.view_changed.connect(apply_view)
	add_child(link)
	_world.region_changed.connect(_on_region)
	_world.exploration.niche_reached.connect(func(id: String) -> void:
		if link.online:
			link.occur("achar-nicho", {"niche": id}))
	_world.virus_destroyed.connect(func() -> void:
		if link.online:
			link.occur("derrotar-virus"))
	_world.nutrient_absorbed.connect(func() -> void:
		if link.online:
			link.occur("absorver-nutriente"))
	_world.toxin_filtered.connect(func() -> void:
		if link.online:
			link.occur("filtrar-toxina"))
	_world.glycogen_stored.connect(func() -> void:
		if link.online:
			link.occur("guardar-glicogenio"))
	_world.organ_deed.connect(func(action: String) -> void:
		if link.online:
			link.occur(action))
	_world.evaded.connect(func() -> void:
		if link.online:
			link.occur("esquivar"))
	system.set_region(_world.region)
	_last_pos = _world.player.global_position
	if _world.living_enabled:
		_build_living()
	for child in _world.player.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(func(id: StringName, _dir: Vector2) -> void: _used[id] = true)


## The living body: named cells at work, crises on the tissue, and the interface that explains them.
func _build_living() -> void:
	prefs = BioVisualPrefs.load_from()
	tones = BioLivingSound.new()
	tones.name = "LivingSound"
	add_child(tones)
	presenter = BioNpcPresenter.new()
	presenter.name = "Npcs"
	_world.add_child(presenter)
	presenter.configure(_world.player, _world.anatomy, prefs)
	mood = BioTissueMood.new()
	mood.name = "TissueMood"
	_world.add_child(mood)
	mood.configure(_world.anatomy, prefs)
	crowd = BioWorkCrowd.new()
	crowd.name = "WorkCrowd"
	_world.add_child(crowd)
	crowd.configure(_world, prefs)
	presenter.foe_hit = crowd.strike
	living_hud = BioLivingHud.new()
	living_hud.name = "LivingHud"
	add_child(living_hud)
	living_hud.bind(presenter.model, prefs, tones)
	living_hud.help_accepted.connect(_on_help_accepted)
	living_hud.focus_changed.connect(func(_id: String) -> void: _follow_npc = "")
	presenter.cue.connect(_on_npc_cue)
	presenter.thanked.connect(func(_npc: String, name_text: String) -> void:
		system.push_feed("%s agradece a ajuda." % name_text))


func _on_npc_cue(npc: String, kind: StringName, _at: Vector2) -> void:
	if kind == &"confirmed" and prefs.sound:
		var a := presenter.actor(npc)
		if a != null and a.lod >= 2:
			tones.play(&"confirmed", -8.0)


## "Ajudar" never declares a deed: it points the player to the cell and the crisis; the engine counts only what the game server
## confirms (a virion destroyed, a mote taken, ...).
func _on_help_accepted(npc: String, region: String) -> void:
	_follow_npc = npc
	_follow_region = region
	_follow_until = Time.get_ticks_msec() * 0.001 + FOLLOW_SECONDS
	for c in presenter.model.ordered():
		if str(c.get("region", "")) == region:
			living_hud.follow(str(c.get("id", "")))
			break
	_follow_npc = npc  # following a crisis clears the arrow: set it again
	system.push_feed("Siga a seta até %s. Ajude eliminando a causa no local; só o que o motor confirma conta." % str(_names.get(npc, npc)).get_slice(",", 0))


## The arrow towards the cell being helped (empty when there is none), for the guide of the world.
func follow_guide() -> Dictionary:
	if _follow_npc == "" or Time.get_ticks_msec() * 0.001 > _follow_until:
		_follow_npc = ""
		return {}
	var a := presenter.actor(_follow_npc)
	var goal := a.position if a != null else BioBodyMap.center_px(StringName(_follow_region))
	var to := goal - _world.player.global_position
	if to.length() < 9.0 * BioArt.UNIT:
		return {}
	return {"to": to, "text": "ajudar %s · %d" % [str(_names.get(_follow_npc, _follow_npc)).get_slice(",", 0), roundi(to.length() / BioArt.UNIT)]}


## The world began again: forget the other cells, traces and news of the old one. The next view is history again.
func forget() -> void:
	if presenter != null:
		presenter.forget()
		mood.set_conflicts([])
		mood.set_populations([])
		crowd.set_populations([])
		living_hud.queue.clear()
		living_hud.chosen = ""
		_follow_npc = ""
		living_hud.refresh()
	for r in _residents.values():
		if is_instance_valid(r):
			r.queue_free()
	for s in _signs.values():
		if is_instance_valid(s):
			s.queue_free()
	_residents.clear()
	_signs.clear()
	_names.clear()
	_used.clear()
	_last_seq = -1
	_announce_abilities = false
	system.close_menu()


func wants_numbers() -> bool:
	return system.menu_open


func _process(delta: float) -> void:
	_track_behaviour(delta)
	if Input.is_action_just_pressed("bio_interact") and not _world.body_panel.is_open() and not BioUi.typing() and (not BioUi.captures_input() or system.menu_open):
		if system.menu_open:
			system.close_menu()
		else:
			open_menu()
	if system.menu_open:
		for i in BioSystemPanel.MENU_SIZE:
			if Input.is_action_just_pressed("bio_num_%d" % (i + 1)):
				choose(i)


func _track_behaviour(delta: float) -> void:
	if not link.online:
		_used.clear()
		_travelled = 0.0
		return
	var pos := _world.player.global_position
	_travelled += pos.distance_to(_last_pos) / BioArt.UNIT
	_last_pos = pos
	_report_in -= delta
	if _report_in > 0.0:
		return
	_report_in = REPORT_SECONDS
	var kinds := {
		BioAttackCatalog.FLAGELLUM_LASH: "estilo-chicote",
		BioAttackCatalog.TOXIN_SPIT: "estilo-toxina",
		BioAttackCatalog.MEMBRANE_DASH: "estilo-impulso",
	}
	for id in kinds:
		if _used.has(id):
			link.occur(kinds[id])
	_used.clear()
	if _travelled >= EXPLORE_UNITS:
		_travelled = 0.0
		link.occur("estilo-explorar")


func open_menu() -> void:
	if not link.online:
		system.open_menu([])
		system.push_feed("Sem o motor, o corpo não responde a gestos: só ao combate.")
		return
	var items: Array = []
	for a in await link.fetch_affordances():
		if a.get("origin", "") != "player":
			continue
		if a.get("action", "") == "contar":
			var who := str(a.get("args", {}).get("npc", ""))
			var what := str(a.get("args", {}).get("p", ""))
			a["title"] = "Contar a %s: %s" % [str(_names.get(who, who)).get_slice(",", 0), TOLD.get(what, what)]
		items.append(a)
	system.open_menu(items)


func choose(index: int) -> void:
	if index < 0 or index >= system.menu_items.size():
		return
	var item: Dictionary = system.menu_items[index]
	system.close_menu()
	var res := await link.act(str(item.get("action", "")), item.get("args", {}))
	if res.status != 200:
		system.push_feed("Não deu certo: o corpo não reagiu a isso agora.")
		return
	for e in res.body.get("events", []):
		system.push_feed(str(e.get("text", "")))


## Applies one view from the engine. Public so tests can feed a view without a network.
func apply_view(view: Dictionary) -> void:
	system.set_status(true, int(view.get("tick", 0)))
	if presenter != null:
		var notices := presenter.apply_view(view)
		mood.set_conflicts(presenter.model.ordered())
		mood.set_populations(presenter.model.pops)
		crowd.set_populations(presenter.model.pops)
		living_hud.set_stale(false)
		living_hud.push_notices(notices)
		living_hud.refresh()
	for o in view.get("others", []):
		_names[str(o.get("id", ""))] = str(o.get("name", ""))
	_apply_residents(view.get("others", []))
	_apply_signs(view.get("signs", []))
	_apply_beliefs(view.get("beliefs", []))
	if view.get("explore") is Dictionary:
		_world.exploration.apply(view["explore"])
		_world.set_adapted(view["explore"].get("adapted", []))
	if view.get("codex") is Array:
		_world.codex_panel.set_data(view["codex"], _world.adapted_regions)
	var visited: Array = []
	for f in view.get("facts", []):
		if f.get("p", "") == "visitou":
			visited.append(f.get("o", ""))
	if not visited.is_empty():
		_world.atlas.merge(visited)
	if view.get("advisor") is Dictionary:
		_world.jev_panel.set_data(view["advisor"])
	if view.get("vitals") is Array:
		_world.apply_body(view["vitals"])
	_apply_skills(view.get("skills", []))
	_apply_events(view.get("events", []))
	if view.has("calling") and view["calling"] is Dictionary:
		_world.apply_engine_calling(view["calling"])
	if view.has("lineage") and view["lineage"] is Dictionary:
		_world.apply_engine_lineage(view["lineage"])
	if view.has("evolution") and view["evolution"] is Dictionary:
		_world.apply_engine_evolution(view["evolution"])
	if view.has("look") and view["look"] is Dictionary:
		_world.apply_engine_look(view["look"])


## Class abilities the engine says the player knows go into the ability slots; a new one is announced by how it came.
func _apply_skills(skills: Array) -> void:
	for s in skills:
		if str(s.get("class", "")).is_empty():
			continue
		var id := BioAbilityCatalog.normalise(str(s.get("id", "")))
		if _world.abilities.learn(id) and _announce_abilities:
			system.push_feed("Nova habilidade: %s." % BioAbilityCatalog.get_ability(id).get("name", id))
	_announce_abilities = true
	_world.restore_ability_order()


func _apply_residents(others: Array) -> void:
	var wanted := {}
	for o in others:
		var id := str(o.get("id", ""))
		if presenter != null and presenter.model.npcs.has(id):
			continue  # a cell of the society is drawn by the presenter, once
		if o.get("kind", "") == "celula" and str(o.get("region", "")) == String(_world.region) and BioBodyMap.RESIDENTS.has(id):
			wanted[id] = str(o.get("name", id))
	for id in _residents.keys():
		if not wanted.has(id):
			_residents[id].queue_free()
			_residents.erase(id)
	for id in wanted:
		if not _residents.has(id):
			var resident := BioResident.new()
			resident.configure(id, wanted[id], BioBodyMap.RESIDENTS[id] * BioArt.UNIT)
			_world.add_child(resident)
			_residents[id] = resident


func _apply_signs(signs: Array) -> void:
	var wanted := {}
	for s in signs:
		if not s.get("far", false) and str(s.get("region", "")) == String(_world.region):
			wanted[str(s.get("id", ""))] = s
	for id in _signs.keys():
		if not wanted.has(id):
			_signs[id].queue_free()
			_signs.erase(id)
	for id in wanted:
		if not _signs.has(id):
			var s: Dictionary = wanted[id]
			var tint := BioArt.CRIMSON if str(s.get("region", "")) == "sangue" else Color(0.8, 0.7, 1.0)
			var marker := BioSignMarker.new()
			marker.configure(id, str(s.get("look", "")), BioBodyMap.spot_px(str(s.get("spot", ""))), tint)
			_world.add_child(marker)
			_signs[id] = marker


## The body's states the player knows about (public reveals become beliefs).
func _apply_beliefs(beliefs: Array) -> void:
	var fever := false
	var sleep := false
	for b in beliefs:
		if not b.get("holds", false):
			continue
		if b.get("p", "") == "febre" and str(b.get("s", "")) == "sangue":
			fever = true
		if b.get("p", "") == "sono" and str(b.get("s", "")) == "medula":
			sleep = true
	_world.set_fever(fever)
	_world.set_sleeping(sleep)
	var states: Array[String] = []
	if fever:
		states.append("FEBRE")
	if sleep:
		states.append("O HOSPEDEIRO DORME")
	system.set_states(states)


func _apply_events(events: Array) -> void:
	var fresh := events.filter(func(e: Dictionary) -> bool: return int(e.get("seq", -1)) > _last_seq)
	fresh.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("seq", 0)) < int(b.get("seq", 0)))
	var first_view := _last_seq < 0
	for e in fresh:
		_last_seq = maxi(_last_seq, int(e.get("seq", 0)))
		var kind := str(e.get("kind", ""))
		if not QUIET_EVENTS.has(kind):
			system.push_feed(str(e.get("text", "")))
		if first_view:
			continue  # history before this session: shown, not replayed
		match kind:
			"gene-acquired":
				_world.tray.set_call("gene-reward", "mutation", "Gene conquistado", str(e.get("text", "")))
				BioSignature.play(&"cartwheel", _world.player.global_position, BioArt.AMBER, 1.0, {"radius":48.0}, _world.player)
			"refeicao":
				_world.spawn_meal(10)
			"surto":
				_world.spawn_outbreak(3)
			"codice":
				system.push_feed("Códice: %s" % e.get("text", ""))
			"adaptou":
				system.push_feed(str(e.get("text", "")))
			"nicho":
				_world.hud.show_banner("NICHO ENCONTRADO
um gene novo é seu")
				_world.get_tree().create_timer(5.0).timeout.connect(func() -> void:
					if is_instance_valid(_world.hud) and _world.hud.banner_text().begins_with("NICHO ENCONTRADO"):
						_world.hud.show_banner(""))
			"mutated":
				system.push_feed("Seu corpo expressa um novo gene: %s" % e.get("text", ""))


func _on_status(online: bool) -> void:
	if presenter != null:
		living_hud.set_stale(not online)
		if not online:
			presenter.model.expect_history()
	_world.jev_panel.set_online(online)
	system.set_status(online, 0)
	if not online:
		_world.release_engine_evolution()
	system.push_feed("Conectado ao Hospedeiro." if online else "Conexão perdida: o corpo segue offline.")


func _on_region(region: StringName) -> void:
	if living_hud != null:
		living_hud.set_player_region(String(region))
	system.set_region(region)
	link.move_region(String(region))
