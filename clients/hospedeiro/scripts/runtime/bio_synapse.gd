class_name BioSynapse
extends Node2D
## The link between the enemies a regulatory T cell tied together: a thread of light from one to the next, with a pulse running along it
## every time one of them is hurt. It lasts as long as the link does (or while at least two of them live).

var members: Array = []  # BioCellActor
var color := Color(0.5, 1.0, 0.8)
var seconds := 7.0

var _age := 0.0
var _pulse := 0.0
var _seed := randf() * 10.0


static func tie(parent: Node, cells: Array, p_color: Color, p_seconds: float) -> BioSynapse:
	var s := BioSynapse.new()
	s.members = cells
	s.color = p_color
	s.seconds = p_seconds
	parent.add_child(s)
	var ref: WeakRef = weakref(s)  # the cells outlive the synapse: a lambda holding it would call into a freed object
	for c in cells:
		(c as BioCellActor).combatant.hit.connect(func(_who: BioCombatant, _r: BioHitResult) -> void:
			var alive: Object = ref.get_ref()
			if alive != null:
				(alive as BioSynapse)._pulse = 1.0)
	return s


func _ready() -> void:
	z_index = 8
	material = BioArt.additive()


func _alive_members() -> Array:
	return members.filter(func(c: Variant) -> bool: return is_instance_valid(c) and (c as BioCellActor).combatant.actor.vitals.is_alive() and (c as BioCellActor).combatant.is_linked())


func _process(delta: float) -> void:
	_age += delta
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	if _age >= seconds or _alive_members().size() < 2:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var live := _alive_members()
	var fade := clampf((seconds - _age) / 0.5, 0.0, 1.0)
	for i in live.size() - 1:
		var a: Vector2 = (live[i] as BioCellActor).global_position
		var b: Vector2 = (live[i + 1] as BioCellActor).global_position
		var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * 14.0 * sin(_age * 2.0 + i + _seed)
		var pts := PackedVector2Array()
		for k in 13:
			var f := k / 12.0
			pts.append(to_local(a.lerp(mid, f).lerp(mid.lerp(b, f), f)))
		draw_polyline(pts, BioArt.with_alpha(color, (0.25 + 0.3 * _pulse) * fade), 6.0, true)
		draw_polyline(pts, BioArt.with_alpha(color.lerp(Color.WHITE, 0.6), (0.6 + 0.4 * _pulse) * fade), 1.6, true)
		var dot := fposmod(_age * 0.8 + i * 0.3, 1.0)
		draw_circle(pts[int(dot * 12.0)], 3.5 + 3.0 * _pulse, BioArt.with_alpha(Color.WHITE, 0.95 * fade))
	for c in live:  # a ring on each tied cell: two small half-moons that face each other, like the two sides of a synapse
		var p := to_local((c as BioCellActor).global_position)
		draw_arc(p, 26.0, _age, _age + 1.5, 10, BioArt.with_alpha(color, 0.8 * fade), 2.2, true)
		draw_arc(p, 26.0, _age + PI, _age + PI + 1.5, 10, BioArt.with_alpha(color, 0.8 * fade), 2.2, true)
