class_name BioTouchMinimap
extends Control
## Compact atlas using only already visited regions; tap opens the full map.
var world: BioWorld
var _body := {}
var _age := 0.0

func configure(value: BioWorld) -> void:
	world = value
	_body = BioAnatomy.build(world.seed_value)
	size = Vector2(92,92)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		world.atlas.toggle()
		accept_event()

func _process(delta: float) -> void:
	_age += delta
	if _age > 0.2:
		_age = 0
		queue_redraw()

func _draw() -> void:
	if world == null:
		return
	draw_style_box(BioUi.style(Color(0.01,0.025,0.05,0.86),Color(0.55,0.65,0.7,0.45),8,0),Rect2(Vector2.ZERO,size))
	var me_units := world.player.global_position/BioArt.UNIT
	var factor := 78.0/52.0
	var offset := size*0.5-me_units*factor
	var frame := Rect2(Vector2(7,7),size-Vector2(14,14))
	for wall in _body.get("walls",[]):
		if not world.atlas.knows(wall["region"]):
			continue
		var points: PackedVector2Array = wall["points"]
		for i in range(1,points.size()):
			var a: Vector2 = points[i-1]*factor+offset
			var b: Vector2 = points[i]*factor+offset
			if frame.has_point(a) and frame.has_point(b):
				draw_line(a,b,Color(0.3,0.65,0.75,0.65),1,true)
	for resident in world.sync._residents.values():
		if is_instance_valid(resident):
			var at: Vector2 = resident.global_position/BioArt.UNIT*factor+offset
			if frame.has_point(at):
				draw_circle(at,1.6,Color(0.9,0.75,0.4,0.8))
	draw_circle(size*0.5,5,Color(0.5,1,1,0.2))
	draw_circle(size*0.5,2.5,Color(0.8,1,1))
	draw_string(ThemeDB.fallback_font,Vector2(9,15),"N",HORIZONTAL_ALIGNMENT_LEFT,12,8,Color(0.7,0.8,0.85,0.6))
