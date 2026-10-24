class_name BioModal
extends ColorRect
## Shared window shell. A gesture must start and finish outside the card to dismiss it.
signal dismissed
var card: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var max_size := Vector2(880, 620)
var _owner: Object
var _outside := false
var _start := Vector2.ZERO

func _init() -> void:
	color = Color(0, 0.005, 0.02, 0.65)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", BioUi.style(BioUi.BG, BioUi.LINE_STRONG, 12, 12))
	add_child(card)
	gui_input.connect(_outside_input)

func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()

func build(title: String, scrolling := true) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	heading = BioUi.label(title, BioUi.FS_HEAD, BioUi.ACCENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var exit := BioUi.button("Fechar")
	exit.pressed.connect(func() -> void: dismissed.emit())
	head.add_child(exit)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	if scrolling:
		scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.scroll_deadzone = 8
		column.add_child(scroll)
		scroll.add_child(content)
	else:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(content)

func fit() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var extent := Vector2(minf(max_size.x, view.x * 0.88), minf(max_size.y, view.y * 0.86))
	card.custom_minimum_size = Vector2.ZERO
	card.size = extent
	card.position = (view - card.size) * 0.5

func present(owner: Object) -> void:
	_owner = owner
	BioUi.present(owner)
	visible = true
	fit()

func hide_modal() -> void:
	visible = false
	_outside = false
	if is_instance_valid(_owner):
		BioUi.set_modal(_owner, false)

func _outside_input(event: InputEvent) -> void:
	var at: Vector2
	var pressed: bool
	if event is InputEventScreenTouch:
		at = event.position
		pressed = event.pressed
		if event.canceled:
			_outside = false
			return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if BioPlatform.is_touch() and event.device == -1:
			return
		at = event.position
		pressed = event.pressed
	else:
		return
	if pressed:
		_start = at
		_outside = not card.get_rect().has_point(at)
	else:
		var should_close := _outside and not card.get_rect().has_point(at) and at.distance_to(_start) < 10
		_outside = false
		if should_close:
			dismissed.emit()
