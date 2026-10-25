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
	if state == "ready" or pending:
		world.tray.set_call("dungeon-reward" if pending else "dungeon-ready", "mutation", "Vitória · escolha seu gene" if pending else "Expedição pronta", "toque para ver os prêmios")
		if key != _last_run_key:
			open_run()
		elif mode in ["ready", "claim"] and modal.visible and not _busy and info != _run:
			info = _run.duplicate(true)
			_render()
	elif mode in ["ready", "claim"]:
		close()
	if state != "ready": world.tray.clear_call("dungeon-ready")
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
		modal.content.add_child(BioUi.wrapped("Uma expedição pessoal: atravesse salas, derrote o chefe e escolha seu prêmio. Entrar leva primeiro à preparação; o combate só começa quando você confirmar.", 12))
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
		var button := BioUi.button("Aguarde…" if _busy else "Entrar e preparar" if mode == "entry" else "Iniciar combate", "primary")
		var near := is_instance_valid(_door) and _door.is_near() and _door.eligible
		button.disabled = _busy or preview.is_empty() or (mode == "entry" and not near)
		button.pressed.connect(func() -> void:
			var args := {"preview":str(preview.get("token", ""))}
			if mode == "entry":
				args["dungeon"] = _door.dungeon_id
				args["briefing"] = "yes"
			_send("entrar-masmorra" if mode == "entry" else "iniciar-masmorra", args))
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
		_render()
		return
	if action == "resgatar-masmorra":
		world.tray.clear_call("dungeon-reward")
	if action != "entrar-masmorra" or mode == "entry": close()
