class_name BioHostSync
extends Node
## Bridges the local game and the engine. Outgoing: confirmed happenings (virion destroyed, nutrient
## absorbed), region changes and the player's intentions (accept, decline, the action menu). Incoming:
## the engine's view, turned into the System window, resident cells, traces, body states and genes.
## Without an engine everything here stays quiet and the game plays offline.

## Echoes of the player's own combat and lifecycle notices already shown elsewhere (the System window).
const QUIET_EVENTS := ["abate", "nutriente", "faro", "esquiva", "join", "moved", "quest-offered", "quest-active", "quest-expired", "quest-obsolete", "quest-withdrawn", "evolution-offered", "evolution-declined", "mutated", "lineage-offered", "appearance", "skill-learned", "dungeon-preparing", "dungeon-started", "dungeon-room", "dungeon-cleared", "dungeon-failed", "dungeon-left"]

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
var _dungeon_state := ""  # the run state we last reacted to
var _dungeon_seed := 0

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
	link = BioEngineLink.new()
	link.name = "EngineLink"
	if not _world.engine_url.is_empty():
		var identity := BioEngineLink.local_identity(_world.identity_path)
		link.configure(_world.engine_url, str(identity["id"]), str(identity["name"]))
	link.region = String(_world.region)
	link.status_changed.connect(_on_status)
	link.view_changed.connect(apply_view)
	add_child(link)
	_world.region_changed.connect(_on_region)
	_world.dungeon.room_cleared.connect(func(_index: int) -> void:
		if link.online:
			link.occur("sala-limpa"))
	_world.dungeon.run_failed.connect(func() -> void:
		if link.online:
			link.occur("falhar-masmorra"))
	_world.virus_destroyed.connect(func() -> void:
		if link.online:
			link.occur("derrotar-virus"))
	_world.nutrient_absorbed.connect(func() -> void:
		if link.online:
			link.occur("absorver-nutriente"))
	_world.evaded.connect(func() -> void:
		if link.online:
			link.occur("esquivar"))
	system.set_region(_world.region)
	_last_pos = _world.player.global_position
	for child in _world.player.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(func(id: StringName, _dir: Vector2) -> void: _used[id] = true)


## The world began again: forget the other cells, traces and news of the old one. The next view is history again.
func forget() -> void:
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
	system.set_active({})
	system.hide_offer()
	system.close_menu()


func wants_numbers() -> bool:
	return system.menu_open


func _process(delta: float) -> void:
	_track_behaviour(delta)
	if Input.is_action_just_pressed("bio_accept") and not system.offer_key.is_empty():
		_answer_offer(true)
	elif Input.is_action_just_pressed("bio_refuse") and not system.offer_key.is_empty():
		_answer_offer(false)
	if Input.is_action_just_pressed("bio_leave") and _world.dungeon.active and link.online:
		link.act("abandonar-masmorra")
	if Input.is_action_just_pressed("bio_interact"):
		if _world.gate != null and _world.gate.is_near() and not _world.dungeon.active:
			enter_dungeon()
		elif system.menu_open:
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


## The player asks to go into the granuloma. The engine decides whether they may and prepares the run.
func enter_dungeon() -> void:
	if not link.online:
		system.push_feed("O granuloma só abre com o corpo conectado ao motor.")
		return
	if not _world.gate.eligible:
		system.push_feed(_world.gate.hint if not _world.gate.hint.is_empty() else "O granuloma ainda não está ao seu alcance.")
		return
	var res := await link.act("entrar-masmorra", {"dungeon": "granuloma"})
	if res.status != 200:
		system.push_feed("O granuloma recusou a entrada agora.")


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


func _answer_offer(accepted: bool) -> void:
	var key := system.offer_key
	system.hide_offer()
	var res: Dictionary
	if accepted:
		res = await link.accept(key)
	else:
		res = await link.decline(key)
	if res.status != 200:
		system.push_feed("O chamado já não estava de pé.")


## Applies one view from the engine. Public so tests can feed a view without a network.
func apply_view(view: Dictionary) -> void:
	system.set_status(true, int(view.get("tick", 0)))
	for o in view.get("others", []):
		_names[str(o.get("id", ""))] = str(o.get("name", ""))
	_apply_quests(view.get("quests", []))
	_apply_residents(view.get("others", []))
	_apply_signs(view.get("signs", []))
	_apply_beliefs(view.get("beliefs", []))
	_apply_skills(view.get("skills", []))
	if view.get("dungeon") is Dictionary:
		_apply_dungeon(view["dungeon"])
	_apply_events(view.get("events", []))
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


## The granuloma: whether the entrance is open to this cell, and the run, step by step. The engine owns the run; this only
## builds what it says (the chamber, the enemies) and confirms what happened in it.
func _apply_dungeon(d: Dictionary) -> void:
	var open := false
	var hint := "Entre no Granuloma na corrente sanguínea quando seu corpo estiver mais maduro."
	for o in d.get("available", []):
		if str(o.get("id", "")) == "granuloma":
			open = bool(o.get("eligible", false))
			if open:
				hint = ""
	if open and not _world.gate.eligible:
		system.push_feed("O Granuloma abriu para você: siga a seta até os anéis na corrente sanguínea e aperte E.")
	_world.gate.eligible = open
	_world.gate.hint = hint
	var run: Variant = d.get("run")
	if not (run is Dictionary):
		return
	var state := str(run.get("state", ""))
	var seed_value := int(run.get("seed", 0))
	var mod: Variant = run.get("modifier")
	if state != "preparing" and _world.hud.banner_text().begins_with("Entrando no granuloma"):
		_world.hud.show_banner("")
	if state == "preparing":
		_world.hud.show_banner("Entrando no granuloma…  o Jev escolhe o desafio desta vez")
		if _dungeon_state != "preparing":
			system.push_feed("O granuloma se prepara…")
	elif state == "active":
		if not _world.dungeon.active and (_dungeon_state != "active" or seed_value != _dungeon_seed):
			_world.dungeon.start(run)
			if mod is Dictionary:
				system.push_feed("Granuloma, %s: %s" % [mod.get("name", ""), mod.get("desc", "")])
		elif _world.dungeon.active and int(run.get("room", 0)) > _world.dungeon.room_index:
			_world.dungeon.advance(int(run.get("room", 0)))
	elif state == "cleared" and _world.dungeon.active and seed_value == _world.dungeon.seed_value:
		_world.dungeon.finish(true)
		system.push_feed("O granuloma foi selado. A carga de infecção no sangue cai.")
	elif state == "failed" and _world.dungeon.active and seed_value == _world.dungeon.seed_value:
		_world.dungeon.finish(false)
		system.push_feed("Você deixou o granuloma. Ele continua lá.")
	_dungeon_state = state
	_dungeon_seed = seed_value


func _apply_quests(quests: Array) -> void:
	var offered: Dictionary = {}
	var active: Dictionary = {}
	for q in quests:
		match q.get("state", ""):
			"offered":
				offered = q
			"active":
				active = q
	system.set_active(active)
	if offered.is_empty():
		system.hide_offer()
	elif str(offered.get("key", "")) != system.offer_key:
		var giver := str(offered.get("giver", ""))
		system.show_offer(offered, str(_names.get(giver, giver.capitalize())) if not giver.is_empty() else "")


func _apply_residents(others: Array) -> void:
	var wanted := {}
	for o in others:
		var id := str(o.get("id", ""))
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
		if kind == "quest-done":
			system.push_feed("Missão concluída: %s" % e.get("text", ""))
		elif not QUIET_EVENTS.has(kind):
			system.push_feed(str(e.get("text", "")))
		if first_view:
			continue  # history before this session: shown, not replayed
		match kind:
			"refeicao":
				_world.spawn_meal(10)
			"surto":
				_world.spawn_outbreak(3)
			"mutated":
				system.push_feed("Seu corpo expressa um novo gene: %s" % e.get("text", ""))


func _on_status(online: bool) -> void:
	system.set_status(online, 0)
	if not online:
		_world.release_engine_evolution()
	system.push_feed("Conectado ao Hospedeiro." if online else "Conexão perdida: o corpo segue offline.")


func _on_region(region: StringName) -> void:
	system.set_region(region)
	link.move_region(String(region))
