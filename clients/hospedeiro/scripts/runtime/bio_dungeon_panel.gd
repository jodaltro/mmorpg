class_name BioDungeonPanel
extends CanvasLayer
## Entrance preview, safe lobby briefing, and post-victory choice use the same server draft.
var world: BioWorld
var modal: BioModal
var mode := ""
var info: Dictionary = {}
var _door: BioGate
var _busy := false
var _note := ""
var _last_run_key := ""
var _run: Dictionary = {}
var _actions: VBoxContainer
var _auto_start_key := ""

func _ready() -> void:
	layer = 24
	modal = BioModal.new()
	modal.max_size = Vector2(600, 520)
	add_child(modal)
	modal.build("MASMORRA")
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 5)
	(modal.card.get_child(0) as VBoxContainer).add_child(_actions)
	modal.dismissed.connect(close)

func open_gate(door: BioGate) -> void:
	_door = door
	mode = "entry"
	info = door.expedition.duplicate(true)
	info["name"] = door.title.capitalize()
	_note = ""
	_render()
	modal.present(self)


func enter_gate(door: BioGate) -> void:
	if _busy or not door.is_near() or not door.eligible: return
	var preview: Dictionary = door.expedition.get("preview", {})
	if preview.is_empty(): return
	_door = door
	mode = "entry"
	info = door.expedition.duplicate(true)
	modal.hide_modal()
	_send("entrar-masmorra", {"dungeon":door.dungeon_id,"preview":str(preview.get("token", "")),"briefing":"yes"})

func open_run() -> void:
	if _run.is_empty(): return
	info = _run.duplicate(true)
	mode = "claim" if str(info.get("state", "")) == "cleared" else "ready"
	_note = ""
	_render()
	modal.present(self)

func apply(view: Dictionary) -> void:
	var value: Variant = view.get("run")
	_run = value.duplicate(true) if value is Dictionary else {}
	var state := str(_run.get("state", ""))
	var preview: Dictionary = _run.get("preview", {})
	var pending: bool = state == "cleared" and str(_run.get("rewardClaimed", "")).is_empty() and not preview.get("choices", []).is_empty()
	var key := "%s:%s" % [str(_run.get("seed", "")), state]
	if state == "ready":
		world.tray.clear_call("dungeon-ready")
		_try_auto_start()
	elif pending:
		world.tray.set_call("dungeon-reward" if pending else "dungeon-ready", "mutation", "Vitória · escolha seu gene" if pending else "Expedição pronta", "toque para ver os prêmios")
		if key != _last_run_key:
			open_run()
		elif mode in ["ready", "claim"] and modal.visible and not _busy and info != _run:
			info = _run.duplicate(true)
			_render()
	elif mode in ["ready", "claim"]:
		close()
	if state != "ready": world.tray.clear_call("dungeon-ready")
	if state != "ready": _auto_start_key = ""
	if not pending: world.tray.clear_call("dungeon-reward")
	_last_run_key = key
	if mode == "entry" and modal.visible and is_instance_valid(_door) and not _busy:
		var updated := _door.expedition.duplicate(true)
		updated["name"] = _door.title.capitalize()
		if updated != info:
			info = updated
			_render()

func close() -> void:
	modal.hide_modal()
	mode = ""


func _try_auto_start() -> void:
	if _busy or str(_run.get("state", "")) != "ready": return
	var key := "%s:%s" % [str(_run.get("dungeon", "")), str(_run.get("seed", ""))]
	if key == _auto_start_key: return
	_auto_start_key = key
	_auto_start.call_deferred()


func _auto_start() -> void:
	if _busy or str(_run.get("state", "")) != "ready": return
	mode = "ready"
	info = _run.duplicate(true)
	modal.hide_modal()
	var preview: Dictionary = info.get("preview", {})
	world.hud.show_banner("Entrando em %s…" % str(info.get("name", "Masmorra")))
	_send("iniciar-masmorra", {"preview":str(preview.get("token", ""))})

func _render() -> void:
	for child in modal.content.get_children():
		modal.content.remove_child(child)
		child.queue_free()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	modal.heading.text = "VITÓRIA · ESCOLHA SEU PRÊMIO" if mode == "claim" else "SALA SEGURA · ANTES DO COMBATE" if mode == "ready" else "ANTES DE ENTRAR"
	modal.content.add_child(BioUi.wrapped(str(info.get("name", "Masmorra")), 16, BioUi.ACCENT))
	if mode == "entry":
		modal.content.add_child(BioUi.wrapped("Uma expedição pessoal: atravesse salas, derrote o chefe e escolha seu prêmio. Ao chegar ao portal liberado, você entra e o combate começa automaticamente após a preparação.", 12))
	elif mode == "ready":
		var modifier: Dictionary = info.get("modifier", {}) if info.get("modifier") is Dictionary else {}
		modal.content.add_child(BioUi.wrapped("%d salas · %s\n%s" % [info.get("rooms", []).size(), str(modifier.get("name", "Condição normal")), str(modifier.get("desc", "Você está em uma sala segura. Leia os prêmios antes de começar."))], 12))
	var preview: Dictionary = info.get("preview", {})
	var choices: Array = preview.get("choices", [])
	if not choices.is_empty():
		modal.content.add_child(BioUi.wrapped("Escolha 1 destes %d genes agora. Você ganhou; o escolhido é seu." % choices.size() if mode == "claim" else "AO VENCER · ESCOLHA 1 DESTES %d GENES" % choices.size(), 13, BioUi.GOOD))
		for reward in choices:
			var select := Callable()
			if mode == "claim" and not _busy:
				select = func() -> void: _send("resgatar-masmorra", {"gene":str(reward.get("id", ""))})
			modal.content.add_child(BioRewardUi.card(reward, select))
		if mode == "claim" and choices.all(func(r: Dictionary) -> bool: return bool(r.get("owned", false))):
			modal.content.add_child(BioUi.wrapped("Esses genes já chegaram à sua biblioteca por outras conquistas. As recompensas fixas da vitória já foram entregues.", 12))
			var done := BioUi.button("Concluir expedição")
			done.disabled = _busy
			done.pressed.connect(func() -> void: _send("resgatar-masmorra", {"gene":"none"}))
			modal.content.add_child(done)
	else:
		modal.content.add_child(BioUi.wrapped("Você já conquistou os genes disponíveis aqui. Esta expedição ainda concede as recompensas abaixo." if not preview.is_empty() else "A lista de prêmios desta expedição ainda não chegou. Aguarde a conexão com o mundo.", 12, BioUi.WARN))
	if mode != "claim":
		BioRewardUi.add_rewards(modal.content, preview.get("guaranteed", []))
		if not preview.get("first", []).is_empty():
			modal.content.add_child(BioUi.wrapped("EXTRA ÚNICO · só se você for o primeiro a vencer neste mundo", 11, BioUi.WARN))
			BioRewardUi.add_rewards(modal.content, preview.first)
		modal.content.add_child(BioUi.wrapped("Os genes só são entregues após a vitória. Cair ou abandonar não entrega o prêmio. Sair e entrar de novo mantém estes mesmos prêmios.", 11, BioUi.MUTED))
	if not _note.is_empty(): modal.content.add_child(BioUi.wrapped(_note, 12, BioUi.WARN))
	if mode in ["entry", "ready"]:
		var button := BioUi.button("Aguarde…" if _busy else "Entrar agora" if mode == "entry" else "Tentar novamente", "primary")
		var near := is_instance_valid(_door) and _door.is_near() and _door.eligible
		button.disabled = _busy or preview.is_empty() or (mode == "entry" and not near)
		button.pressed.connect(func() -> void:
			if mode == "entry":
				world.sync.enter_dungeon(_door)
			else:
				_send("iniciar-masmorra", {"preview":str(preview.get("token", ""))}))
		_actions.add_child(button)
		if mode == "entry" and not near: _actions.add_child(BioUi.wrapped("Aproxime-se da entrada. Requisitos e localização são conferidos novamente ao entrar.", 11, BioUi.MUTED))
		if mode == "ready":
			var leave := BioUi.button("Voltar ao corpo")
			leave.disabled = _busy
			leave.pressed.connect(func() -> void: _send("abandonar-masmorra", {}))
			_actions.add_child(leave)

func _send(action: String, args: Dictionary) -> void:
	if _busy: return
	_busy = true
	_note = "Confirmando…"
	_render()
	var result: Dictionary = await world.sync.link.act(action, args)
	_busy = false
	if int(result.get("status", 0)) != 200:
		_note = "A expedição mudou ou a ação não foi aceita. Confira a conexão e revise os prêmios antes de tentar novamente."
		if result.get("body", {}).get("note") is String: _note = result.body.note
		world.hud.show_banner(_note)
		modal.present(self) # an actual failure can be retried; successful entry never asks permission
		_render()
		return
	if action == "resgatar-masmorra":
		world.tray.clear_call("dungeon-reward")
	if action != "entrar-masmorra" or mode == "entry": close()
	_try_auto_start()
