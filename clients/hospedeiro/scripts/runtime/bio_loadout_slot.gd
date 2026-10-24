class_name BioLoadoutSlot
extends PanelContainer
## Mouse drag/drop and deliberate touch hold. A normal swipe still belongs to the scroll view.
signal selected(slot: int)
signal reordered(source: int, target: int)
const HOLD_MS := 350
static var active: BioLoadoutSlot
var slot := 0
var scope := 0
var ability: StringName
var editable := true
var tint := BioUi.ACCENT
var _finger := -1
var _start := Vector2.ZERO
var _point := Vector2.ZERO
var _down_at := 0
var _swiped := false
var _ghost_layer: CanvasLayer
var _ghost: Control
var _highlighted := false

func configure(index: int, id: StringName, owner_id: int, picked: bool, can_edit := true) -> void:
	slot = index
	ability = id
	scope = owner_id
	editable = can_edit and id != &""
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(62, 70)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var data := BioAbilityCatalog.get_ability(id) if id != &"" else {}
	tint = data.get("color", BioUi.MUTED)
	add_theme_stylebox_override("panel", BioUi.style(BioUi.BG_RAISED, BioUi.ACCENT if picked else BioUi.LINE, 8, 6, 2 if picked else 1))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var icon := Control.new()
	icon.custom_minimum_size.y = 30
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		BioTouchGlyph.paint(icon, _glyph(str(data.get("kind", ""))), Vector2(icon.size.x/2, 15), 11, tint.lightened(.25)))
	column.add_child(icon)
	var title := BioUi.label(str(data.get("name", "Vazio")), BioUi.FS_SMALL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	tooltip_text = str(data.get("name", "Vazio"))
	BioUi.bind_tap(self, func() -> void:
		if active == null and not _swiped:
			selected.emit(slot))
	add_to_group("loadout_slots")
	visibility_changed.connect(_cancel_if_hidden)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			_finger = event.index
			_start = event.position
			_point = get_global_transform() * event.position
			_down_at = Time.get_ticks_msec()
			_swiped = false
		elif not event.pressed and event.index == _finger:
			_finger = -1
	elif event is InputEventScreenDrag and event.index == _finger and active != self:
		if event.position.distance_to(_start) > 8:
			_swiped = true

func _process(_delta: float) -> void:
	if _finger >= 0 and not _swiped and editable and ability != &"" and active == null and Time.get_ticks_msec() - _down_at >= HOLD_MS:
		active = self
		_ghost_layer = CanvasLayer.new()
		_ghost_layer.layer = 40
		add_child(_ghost_layer)
		_ghost = Control.new()
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.draw.connect(func() -> void:
			_ghost.draw_circle(_point, 23, BioUi.BG)
			_ghost.draw_arc(_point, 23, 0, TAU, 32, tint, 2, true)
			BioTouchGlyph.paint(_ghost, _glyph(str(BioAbilityCatalog.get_ability(ability).get("kind", ""))), _point, 12, tint))
		_ghost_layer.add_child(_ghost)
		modulate.a = .55
	var highlighted := editable and active != null and active != self and active.scope == scope and get_global_rect().has_point(active._point)
	if highlighted != _highlighted:
		_highlighted = highlighted
		queue_redraw()

func _draw() -> void:
	if _highlighted:
		draw_style_box(BioUi.style(Color(0.2, .6, .8, .2), BioUi.ACCENT, 8, 0, 2), Rect2(Vector2.ZERO, size))

func _input(event: InputEvent) -> void:
	if active != self:
		# ScrollContainer can consume GUI events after a swipe. Track the release globally
		# so a lifted finger can never turn into a delayed long press.
		if event is InputEventScreenDrag and event.index == _finger:
			if event.position.distance_to(get_global_transform() * _start) > 8:
				_swiped = true
		elif event is InputEventScreenTouch and not event.pressed and event.index == _finger:
			_finger = -1
			if event.canceled:
				_swiped = true
		return
	if event is InputEventScreenDrag and event.index == _finger:
		_point = event.position
		_ghost.queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and event.index == _finger:
		var target := -1
		if not event.canceled:
			for node in get_tree().get_nodes_in_group("loadout_slots"):
				if node != self and node.is_visible_in_tree() and node.scope == scope and node.editable and node.get_global_rect().has_point(event.position):
					target = node.slot
		_cancel_drag()
		get_viewport().set_input_as_handled()
		if target >= 0:
			reordered.emit(slot, target)

func _get_drag_data(_at: Vector2) -> Variant:
	if BioPlatform.is_touch() or not editable or ability == &"":
		return null
	var preview := BioUi.label(tooltip_text, BioUi.FS_HEAD, tint)
	set_drag_preview(preview)
	return {"kind": "ability", "scope": scope, "slot": slot}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return editable and data is Dictionary and data.get("kind") == "ability" and data.get("scope") == scope and data.get("slot") != slot

func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at, data):
		reordered.emit(int(data.slot), slot)

func _cancel_if_hidden() -> void:
	if not is_visible_in_tree():
		_cancel_drag()

func _exit_tree() -> void:
	_cancel_drag()

func _cancel_drag() -> void:
	_finger = -1
	_swiped = true
	modulate.a = 1
	if active == self:
		active = null
	if is_instance_valid(_ghost_layer):
		_ghost_layer.queue_free()
		_ghost_layer = null

static func _glyph(kind: String) -> String:
	match kind:
		"counter", "phase", "cloak", "lastchance": return "shield"
		"heal", "convert", "grow": return "heal"
		"bolt", "pierce", "beam", "sticky": return "projectile"
		"dash_strike", "leap", "roll", "blink": return "dash"
		"devour", "cone", "execute": return "jaw"
		"zone", "mines", "crystal": return "net"
		"stance", "replay", "recall", "portal": return "cycle"
		"mark", "prey", "sleep", "decoy": return "eye"
		"link", "tether", "hold", "complement", "allies": return "link"
	return "burst"
