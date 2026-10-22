class_name Actor
extends CharacterBody3D
## A character: Quaternius base body + Universal Animation Library clips.
## Both share one 65-bone skeleton, so clips play without retargeting.

signal arrived

const UAL := ["res://assets/animations/UAL1_Standard.glb", "res://assets/animations/UAL2_Standard.glb"]
const LOOPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Idle_Talking", "Idle_Torch", "Idle_FoldArms",
	"Crouch_Idle", "Sitting_Idle", "Idle_Shield", "Idle_Lantern", "Zombie_Idle", "Zombie_Walk_Fwd"]

static var _library: AnimationLibrary

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
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var scene := load("res://assets/characters/Superhero_%s_FullBody.gltf" % ("Female" if female else "Male")) as PackedScene
	model = scene.instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = AnimationPlayer.new()
	model.add_child(anim)  # root_node ".." is the model: "Armature/Skeleton3D:bone" tracks resolve
	anim.add_animation_library("", library())
	anim.animation_finished.connect(_on_finished)

	label = Label3D.new()
	label.text = shown_name
	label.position.y = 2.25
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0075
	label.outline_size = 10
	label.font_size = 40
	add_child(label)

	# Click target for the camera ray (areas on layer 3).
	pick = Area3D.new()
	pick.collision_layer = 4
	pick.collision_mask = 0
	pick.set_meta("actor", self)
	var ps := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 2.0
	ps.shape = cyl
	ps.position.y = 1.0
	pick.add_child(ps)
	add_child(pick)

	if outfit != "":
		dress("%s_%s" % ["Female" if female else "Male", outfit])
	if with_sword:
		equip("res://assets/props/Sword_Bronze.gltf")
	idle_clip = "Idle"
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
	if anim.has_animation(clip) and (anim.current_animation != clip or not anim.is_playing()):
		anim.play(clip, blend, speed)


func play_once(clip: String, speed := 1.0) -> void:
	if busy or not anim.has_animation(clip):
		return
	busy = true
	has_goal = false
	_once += 1
	var mine := _once
	anim.play(clip, 0.1, speed)
	await anim.animation_finished
	if mine != _once:  # walking cancelled this clip meanwhile
		return
	busy = false
	play(idle_clip)


func walk_to(p: Vector3, running := true) -> void:
	if busy:  # moving interrupts a one-shot clip
		busy = false
		_once += 1
	goal = Vector3(p.x, global_position.y, p.z)
	has_goal = true
	run = running
	_stuck = 0.0


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


func dash(dir: Vector3, seconds: float) -> void:
	dash_dir = dir.normalized()
	dash_t = seconds


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 0.25)


func _physics_process(delta: float) -> void:
	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * 7.5
		move_and_slide()
		global_position.y = 0.0
		return
	if not has_goal or busy:
		return
	var to := goal - global_position
	to.y = 0
	if to.length() < 0.2:
		has_goal = false
		velocity = Vector3.ZERO
		play(idle_clip)
		arrived.emit()
		return
	var dir := to.normalized()
	velocity = dir * (speed_run if run else speed_walk)
	move_and_slide()
	global_position.y = 0.0
	face(dir)
	play(clip_run if run else clip_walk)
	_stuck = _stuck + delta if get_real_velocity().length() < 0.3 else 0.0
	if _stuck > 0.5:  # blocked by a wall: give up instead of pushing forever
		has_goal = false
		play(idle_clip)
		arrived.emit()


func _on_finished(_clip: StringName) -> void:
	pass
