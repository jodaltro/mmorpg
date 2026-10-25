class_name BioEvolutionPresentation
extends CanvasLayer
## Presentation follows acknowledged world state; it never grants a class or protects the player.
var world: BioWorld
var modal: BioModal
var busy := false
var _caption: Label
var _detail: Label
var _status: VBoxContainer
var _combat_until := 0.0
var _dismissed := ""
var _shown := ""
var _target := ""
var _title := ""
var _age := 0.0
var _accepted := false
var _resolved := false
var _revealing := false
var _revision := 0
var _baseline := 0
var _run := 0
var _notice_left := 0.0

func configure(owner_world: BioWorld) -> void:
	world = owner_world
	layer = 29
	modal = BioModal.new()
	modal.max_size = Vector2(590, 350)
	add_child(modal)
	modal.build("EVOLUÇÃO DISPONÍVEL")
	modal.heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.heading.clip_text = true
	modal.heading.custom_minimum_size = Vector2(10, 32)
	modal.dismissed.connect(close)
	_status = VBoxContainer.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_top = 65
	_status.offset_left = -220
	_status.offset_right = 220
	add_child(_status)
	_caption = BioUi.label("", 18, BioUi.ACCENT)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.clip_text = true
	_caption.custom_minimum_size = Vector2(10, 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(_caption)
	_detail = BioUi.wrapped("", 12, BioUi.TEXT)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(_detail)
	_status.hide()
	get_viewport().size_changed.connect(_fit_status)
	_fit_status()
	world.player.combatant.hit.connect(func(_who: BioCombatant, result: BioHitResult) -> void:
		if result.damage_applied > 0: note_combat())
	for child in world.player.get_children():
		if child is BioAttackExecutor:
			(child as BioAttackExecutor).performed.connect(func(_id: StringName, _dir: Vector2) -> void: note_combat())

func _fit_status() -> void:
	var half_width := minf(220, get_viewport().get_visible_rect().size.x * 0.45)
	_status.offset_left = -half_width
	_status.offset_right = half_width

func note_combat() -> void:
	_combat_until = BioClock.now() + 5.0

func in_combat() -> bool:
	if BioClock.now() < _combat_until: return true
	for child in world.get_children():
		if child is BioCellActor and child != world.player:
			var enemy := child as BioCellActor
			if enemy.combatant.actor.team == BioActor.Team.VIRUS and enemy.is_active() and enemy.global_position.distance_to(world.player.global_position) < 5.0 * BioArt.UNIT:
				return true
	return false

func close() -> void:
	_dismissed = _offer_key()
	modal.hide_modal()

func _offer_key() -> String:
	var ids: Array = []
	for option in world.engine_lineage_offer: ids.append(str(option.get("id", "")))
	return "|".join(ids)

func _open_offer() -> void:
	modal.max_size.y = minf(420, 100 + world.engine_lineage_offer.size() * 90)
	for child in modal.content.get_children():
		modal.content.remove_child(child)
		child.queue_free()
	modal.content.add_child(BioUi.wrapped("Escolha uma linhagem permanente. Você pode decidir depois no menu Corpo.", 12, BioUi.MUTED))
	for index in world.engine_lineage_offer.size():
		var option: Dictionary = world.engine_lineage_offer[index]
		var card := VBoxContainer.new()
		modal.content.add_child(card)
		var title := str(option.get("name", ""))
		var button := BioUi.button("Evoluir para " + title)
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void:
			if not in_combat(): world.pick_mutation(index))
		card.add_child(button)
		var desc := BioUi.wrapped(str(option.get("desc", "")), 12, BioUi.MUTED)
		desc.max_lines_visible = 2
		card.add_child(desc)
	_shown = _offer_key()
	modal.present(self)

func body() -> BioCellBody:
	for child in world.player.get_children():
		if child is BioCellBody: return child as BioCellBody
	return null

func begin(option: Dictionary) -> bool:
	if busy: return false
	busy = true
	_run += 1
	_age = 0
	_accepted = false
	_resolved = false
	_revealing = false
	_baseline = _revision
	_target = str(BioLineageCatalog.normalise(str(option.get("id", ""))))
	_title = str(option.get("name", "Nova forma"))
	modal.hide_modal()
	world.body_panel.close()
	body().begin_evolution()
	_status.show()
	_caption.text = "INICIANDO EVOLUÇÃO"
	_detail.text = "Seu corpo desperta para " + _title + "."
	return true

func request_finished(status: int, run: int) -> void:
	if run != _run or not busy: return
	if status != 200:
		cancel("A evolução não foi confirmada. Abra Corpo para tentar novamente.")
		return
	_accepted = true

func observe(look: Dictionary) -> void:
	_revision = int(look.get("designRevision", 0))
	if busy and _revision > _baseline and not bool(look.get("designPending", true)) and str(world.lineage_id) == _target:
		_resolved = true

func cancel(message := "") -> void:
	_run += 1
	busy = false
	_revealing = false
	body().finish_evolution()
	_caption.text = ""
	_detail.text = message
	_notice_left = 5.0 if not message.is_empty() else 0.0
	_status.visible = _notice_left > 0

func reset() -> void:
	cancel()
	modal.hide_modal()
	_dismissed = ""
	_shown = ""
	_revision = 0
	_combat_until = 0

func _reveal() -> void:
	_revealing = true
	_age = 0
	body().finish_evolution()
	body().swell(1.22, 0.15)
	BioFx.burst(world.player.global_position, Color.WHITE, 36, 5.0, 0.5, 0.9)
	BioFx.ring(world.player.global_position, 1.5, Color.WHITE)
	BioFx.ring(world.player.global_position, 2.6, BioArt.CYAN)
	_caption.text = "EVOLUÇÃO CONCLUÍDA"
	_detail.text = _title + " · Sua nova forma despertou."

func _process(delta: float) -> void:
	if world == null or world.sync == null: return
	if busy:
		_age += delta
		if not world.player.is_active() or not world.sync.link.online or _age > 90:
			cancel("A transformação continua em segundo plano. Confira seu corpo ao reconectar.")
			return
		if _revealing:
			if _age > 3.0: busy = false; _status.hide()
			return
		body().evolution_white = 0.18 + 0.65 * pow(sin(_age * PI * 2.0), 2) if _age < 1.5 else minf(1.0, 0.65 + (_age-1.5)*0.5)
		if _age > 1.5:
			_caption.text = "UMA NOVA FORMA ESTÁ NASCENDO"
			_detail.text = _title + " · O Jev prepara os detalhes do seu corpo…"
		if _accepted and _resolved and _age >= 2.3: _reveal()
		return
	if _notice_left > 0:
		_notice_left -= delta
		if _notice_left <= 0: _status.hide()
	var key := _offer_key()
	var combat := in_combat()
	if modal.visible and (combat or not world.sync.link.online or key.is_empty() or key != _shown): modal.hide_modal()
	if not key.is_empty() and key != _dismissed and not modal.visible and not combat and world.player.is_active() and world.sync.link.online and not world.dungeon.active and not BioUi.captures_input():
		_open_offer()

func _unhandled_input(event: InputEvent) -> void:
	if modal.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
