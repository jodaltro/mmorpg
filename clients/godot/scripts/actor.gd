class_name Actor
extends CharacterBody3D
## A character: Quaternius base body + Universal Animation Library clips.
## Both share one 65-bone skeleton, so clips play without retargeting.

signal arrived

const UAL := ["res://assets/animations/UAL1_Standard.glb", "res://assets/animations/UAL2_Standard.glb"]
const LOOPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Idle_Talking", "Idle_Torch", "Idle_FoldArms",
	"Crouch_Idle", "Sitting_Idle", "Idle_Shield", "Idle_Lantern", "Zombie_Idle", "Zombie_Walk_Fwd"]

static var _library: AnimationLibrary
static var plan_count := 0  # path queries and how long they took (for the feel report)
static var plan_ms_total := 0.0
static var plan_ms_max := 0.0
static var nav_map: RID  # set once the navigation mesh is baked

var entity_id := ""
var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var label: Label3D
var weapon: Node3D
var idle_clip := "Idle"
var run := true
var busy := false
var goal := Vector3.ZERO
var has_goal := false
var _stuck := 0.0
var _once := 0
var pick: Area3D
var speed_run := 5.0
var speed_walk := 2.2
var clip_run := "Jog_Fwd"
var clip_walk := "Walk"
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 7.5
var input_dir := Vector3.ZERO  # WASD: moves directly, no path
var _was_input := false
var path := PackedVector3Array()
var path_i := 0
var marker: Label3D
var _plan_age := 0.0
var _planned_goal := Vector3.INF
var _bob := 0.0
var _replanned := false
var hit_clip := "Hit_Chest"
var death_clip := "Death01"


static func library() -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
	for path in UAL:
		var inst: Node = (load(path) as PackedScene).instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for n in ap.get_animation_list():
			if n == "A_TPose" or _library.has_animation(n):
				continue
			var a: Animation = ap.get_animation(n).duplicate()
			if LOOPS.has(n):
				a.loop_mode = Animation.LOOP_LINEAR
			_library.add_animation(n, a)
		inst.free()
	return _library


func setup(id: String, shown_name: String, female := false, with_sword := false, outfit := "Peasant") -> void:
	entity_id = id
	_hitbox(shown_name, 0.35, 1.8, 2.25, 0.7, 2.0)

	var scene := load("res://assets/characters/Superhero_%s_FullBody.gltf" % ("Female" if female else "Male")) as PackedScene
	model = scene.instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = AnimationPlayer.new()
	model.add_child(anim)  # root_node ".." is the model: "Armature/Skeleton3D:bone" tracks resolve
	anim.add_animation_library("", library())
	anim.animation_finished.connect(_on_finished)

	if outfit != "":
		dress("%s_%s" % ["Female" if female else "Male", outfit])
	if with_sword:
		equip("res://assets/props/Sword_Bronze.gltf")
	idle_clip = "Idle"
	play(idle_clip)


## Collision body, name label and the click target the camera ray hits.
func _hitbox(shown_name: String, radius: float, height: float, label_y: float, pick_radius: float, pick_height: float) -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height / 2.0
	add_child(shape)
	label = Label3D.new()
	label.text = shown_name
	label.position.y = label_y
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0075
	label.outline_size = 10
	label.font_size = 40
	add_child(label)
	pick = Area3D.new()  # areas on layer 3
	pick.collision_layer = 4
	pick.collision_mask = 0
	pick.set_meta("actor", self)
	var ps := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = pick_radius
	cyl.height = pick_height
	ps.shape = cyl
	ps.position.y = pick_height / 2.0
	pick.add_child(ps)
	add_child(pick)


## A four-legged creature from its own animated GLB (Quaternius animals).
func setup_creature(id: String, shown_name: String, spec: Dictionary) -> void:
	entity_id = id
	_hitbox(shown_name, 0.5, 1.0, spec.get("label_y", 1.6), 0.9, 1.2)
	model = Node3D.new()  # wrapper: facing and procedural motion live here
	add_child(model)
	var visual: Node3D = (load(spec.model) as PackedScene).instantiate()
	visual.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	visual.position.y = float(spec.get("ground", 0.0))
	model.add_child(visual)
	skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for n in spec.get("loops", []):
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	idle_clip = spec.idle
	clip_run = spec.move
	hit_clip = spec.hit
	death_clip = spec.death
	play(idle_clip)


## Outfits are skinned meshes on the same 65-bone skeleton: move them onto ours.
func dress(outfit: String) -> void:
	var inst: Node = (load("res://assets/outfits/%s.gltf" % outfit) as PackedScene).instantiate()
	var src := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for m in src.get_children():
		if m is MeshInstance3D:
			m.owner = null  # reparenting keeps the old scene owner otherwise
			m.reparent(skeleton, false)
			(m as MeshInstance3D).skeleton = NodePath("..")
	inst.free()


func equip(path: String) -> void:
	if skeleton == null or skeleton.find_bone("hand_r") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skeleton.add_child(att)
	weapon = (load(path) as PackedScene).instantiate()
	weapon.rotation_degrees = Vector3(0, 0, 0)
	weapon.position = Vector3(0, 0.0, 0)
	att.add_child(weapon)


func play(clip: String, speed := 1.0, blend := 0.15) -> void:
	if anim and anim.has_animation(clip) and (anim.current_animation != clip or not anim.is_playing()):
		anim.play(clip, blend, speed)


func play_once(clip: String, speed := 1.0) -> void:
	if busy or anim == null or not anim.has_animation(clip):
		return
	busy = true
	has_goal = false
	_once += 1
	var mine := _once
	anim.play(clip, 0.1, speed)
	# Wait for the clip's length, not animation_finished: some clips loop in
	# their files and never "finish".
	await get_tree().create_timer(anim.get_animation(clip).length / maxf(speed, 0.01)).timeout
	if mine != _once:  # walking cancelled this clip meanwhile
		return
	busy = false
	play(idle_clip)


func play_death() -> void:
	if anim:
		anim.play(death_clip, 0.1, 1.2)


func walk_to(p: Vector3, running := true) -> void:
	if busy:  # moving interrupts a one-shot clip
		busy = false
		_once += 1
	goal = Vector3(p.x, global_position.y, p.z)
	has_goal = true
	run = running
	if path.is_empty() or goal.distance_to(_planned_goal) > 0.8 or _plan_age > 0.6:
		_plan()


## Routes around obstacles with the baked navigation mesh; straight line until it exists.
func _plan() -> void:
	_planned_goal = goal
	_plan_age = 0.0
	_stuck = 0.0
	path = PackedVector3Array()
	path_i = 0
	if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		var t_plan := Time.get_ticks_usec()
		var g := NavigationServer3D.map_get_closest_point(nav_map, goal)
		goal = Vector3(g.x, global_position.y, g.z)
		path = NavigationServer3D.map_get_path(nav_map, global_position, goal, true)
		var took := (Time.get_ticks_usec() - t_plan) / 1000.0
		plan_count += 1
		plan_ms_total += took
		plan_ms_max = maxf(plan_ms_max, took)
		if path.size() > 1 and Vector2(path[0].x - global_position.x, path[0].z - global_position.z).length() < 0.4:
			path_i = 1


## A glow on the hand for what the person carries (the seal's mark): a violet orb and a faint light.
func set_mark(on: bool) -> void:
	var existing := get_node_or_null("SealMark")
	if not on:
		if existing:
			existing.queue_free()
		return
	if existing:
		return
	var n := Node3D.new()
	n.name = "SealMark"
	n.position = Vector3(0.45, 1.05, 0.1)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	orb.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.65, 0.35, 1.0)
	mat.emission_energy_multiplier = 3.0
	orb.material_override = mat
	n.add_child(orb)
	var l := OmniLight3D.new()
	l.light_color = Color(0.65, 0.4, 1.0)
	l.omni_range = 3.2
	l.light_energy = 0.9
	n.add_child(l)
	var tw := n.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 1.6, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 0.5, 0.8).set_trans(Tween.TRANS_SINE)
	add_child(n)


## A speech balloon above the head that fades after a few seconds.
func say(text: String, secs := 6.0) -> void:
	var b := Label3D.new()
	b.text = text
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.no_depth_test = true
	b.font_size = 34
	b.pixel_size = 0.0065
	b.outline_size = 12
	b.width = 520.0
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.modulate = Color(1.0, 0.97, 0.85)
	b.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM  # grows upward, clear of the name
	b.position = Vector3(0, label.position.y + 0.45, 0)
	add_child(b)
	var tw := b.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(b, "modulate:a", 0.0, 0.8)
	tw.tween_callback(b.queue_free)


func set_marker(text: String, color := Color(1.0, 0.85, 0.3)) -> void:
	if text == "":
		if marker:
			marker.queue_free()
			marker = null
		return
	if marker == null:
		marker = Label3D.new()
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.font_size = 110
		marker.pixel_size = 0.008
		marker.outline_size = 16
		marker.render_priority = 6
		add_child(marker)
	marker.text = text
	marker.modulate = color


func _process(delta: float) -> void:
	if marker:
		_bob += delta
		marker.position.y = 2.85 + sin(_bob * 3.0) * 0.1


## Multiplies the albedo of every surface (a cheap way to make variants).
func tint(c: Color) -> void:
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name.begins_with("Eye"):
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var d := mat.duplicate() as BaseMaterial3D
				d.albedo_color = d.albedo_color * c
				mi.set_surface_override_material(i, d)


func interrupt() -> void:
	busy = false
	_once += 1



func dash(dir: Vector3, seconds: float, speed := 7.5) -> void:
	dash_dir = dir.normalized()
	dash_t = seconds
	dash_speed = speed


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.25)


func _physics_process(delta: float) -> void:
	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * dash_speed
		move_and_slide()
		global_position.y = 0.0
		return
	if input_dir != Vector3.ZERO and not busy:
		has_goal = false
		velocity = input_dir * speed_run
		move_and_slide()
		global_position.y = 0.0
		face(input_dir)
		play(clip_run)
		_was_input = true
		return
	if _was_input:
		_was_input = false
		if not busy and not has_goal:
			play(idle_clip)
	if not has_goal or busy:
		return
	_plan_age += delta
	var wp := goal
	var last := true
	if path_i < path.size():
		wp = path[path_i]
		last = path_i >= path.size() - 1
		if last:
			wp = goal
	var to := wp - global_position
	to.y = 0
	if to.length() < (0.2 if last else 0.5):
		if last:
			has_goal = false
			velocity = Vector3.ZERO
			path = PackedVector3Array()
			play(idle_clip)
			arrived.emit()
		else:
			path_i += 1
		return
	var dir := to.normalized()
	velocity = dir * (speed_run if run else speed_walk)
	move_and_slide()
	global_position.y = 0.0
	face(dir)
	play(clip_run if run else clip_walk)
	_stuck = _stuck + delta if get_real_velocity().length() < 0.3 else 0.0
	if _stuck > 0.5:  # blocked: try one fresh route, then give up instead of pushing forever
		if _planned_goal != Vector3.INF and not _replanned:
			_replanned = true
			_plan()
		else:
			_replanned = false
			has_goal = false
			play(idle_clip)
			arrived.emit()


func _on_finished(_clip: StringName) -> void:
	pass
