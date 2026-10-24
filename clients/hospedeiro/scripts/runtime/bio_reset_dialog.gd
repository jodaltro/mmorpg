class_name BioResetDialog
extends CanvasLayer
## Explicit global test reset; opening or dismissing this window never resets anything.
var world: BioWorld
var modal: BioModal
var _confirm: Button
var _note: Label
var _busy := false

func configure(owner_world: BioWorld) -> void:
	world = owner_world
	layer = 30
	modal = BioModal.new()
	modal.max_size = Vector2(510, 260)
	add_child(modal)
	modal.build("REINICIAR MUNDO · TESTE")
	modal.dismissed.connect(close)
	modal.content.add_child(BioUi.wrapped("Começar do zero para TODOS os jogadores? Genes, missões e evolução do mundo serão reiniciados. O servidor guarda o mundo anterior em arquivo.", BioUi.FS_BODY, BioUi.WARN))
	_note = BioUi.wrapped("", BioUi.FS_SMALL, BioUi.MUTED)
	modal.content.add_child(_note)
	_confirm = BioUi.button("Confirmar: começar do zero", "danger")
	_confirm.pressed.connect(_reset)
	modal.content.add_child(_confirm)

func open() -> void:
	var link := world.sync.link
	var allowed := world.engine_url.is_empty() or (link.online and link.reset_allowed)
	_confirm.disabled = not allowed or _busy
	_note.text = "Reinício local, sem motor conectado." if world.engine_url.is_empty() else "Opção temporária de teste." if allowed else "Aguardando conexão ou permissão de teste do servidor."
	modal.present(self)

func close() -> void:
	if not _busy:
		modal.hide_modal()

func _reset() -> void:
	if _busy or _confirm.disabled:
		return
	_busy = true
	_confirm.disabled = true
	_note.text = "Reiniciando…"
	await world.restart_world()
	_busy = false
	modal.hide_modal()
