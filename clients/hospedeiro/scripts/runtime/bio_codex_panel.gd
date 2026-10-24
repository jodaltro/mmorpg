class_name BioCodexPanel
extends CanvasLayer
const KINDS := [["regiao", "LUGARES"], ["patogeno", "INVASORES"], ["corpo", "O CORPO"], ["segredo", "SEGREDOS"]]
var entries: Array = []
var adapted: Array = []
var _modal: BioModal

func configure() -> void:
	layer = 14
	_modal = BioModal.new()
	add_child(_modal)
	_modal.build("CÓDICE DO CORPO")
	_modal.dismissed.connect(close)

func is_open() -> bool:
	return _modal.visible

func toggle() -> void:
	if is_open():
		close()
	else:
		_modal.present(self)
		_rebuild()

func close() -> void:
	_modal.hide_modal()

func set_data(codex: Array, adapted_regions: Array) -> void:
	if entries == codex and adapted == adapted_regions:
		return
	entries = codex.duplicate(true)
	adapted = adapted_regions.duplicate()
	if is_open():
		_rebuild()

func unlocked_count() -> int:
	return entries.filter(func(e: Dictionary) -> bool: return bool(e.get("unlocked", false))).size()

func scroll(by: int) -> void:
	_modal.scroll.scroll_vertical += by * 18

func _rebuild() -> void:
	for child in _modal.content.get_children():
		_modal.content.remove_child(child)
		child.queue_free()
	_modal.heading.text = "CÓDICE · %d/%d" % [unlocked_count(), entries.size()]
	for group in KINDS:
		var items := entries.filter(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == group[0])
		if items.is_empty():
			continue
		_modal.content.add_child(BioUi.label(group[1], BioUi.FS_SMALL, BioUi.WARN))
		for entry in items:
			var card := PanelContainer.new()
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioUi.LINE, 8, 10))
			_modal.content.add_child(card)
			var column := VBoxContainer.new()
			column.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_child(column)
			var unlocked := bool(entry.get("unlocked", false))
			column.add_child(BioUi.wrapped(str(entry.get("title", "")) if unlocked else "???", BioUi.FS_HEAD, BioUi.TEXT if unlocked else BioUi.MUTED))
			if unlocked:
				column.add_child(BioUi.wrapped(str(entry.get("text", "")), BioUi.FS_BODY, BioUi.MUTED))
	if not adapted.is_empty():
		var names := adapted.map(func(id: Variant) -> String: return str(BioBodyMap.NAMES.get(StringName(str(id)), str(id))))
		_modal.content.add_child(BioUi.wrapped("ADAPTADO A: " + ", ".join(names), BioUi.FS_SMALL, BioUi.GOOD))
	if entries.is_empty():
		_modal.content.add_child(BioUi.wrapped("Explore o corpo para descobrir novas entradas.", BioUi.FS_BODY, BioUi.MUTED))
