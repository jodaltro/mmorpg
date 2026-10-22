class_name Enemy
extends Actor
## A hostile character. Fighting is the game server's job (this client plays that
## role in development): the engine only hears confirmed outcomes ("the group was
## defeated") and decides what they mean for the world.

signal damaged(enemy: Enemy, amount: float)
signal hit_player(enemy: Enemy, amount: float)
signal died(enemy: Enemy)

enum State { IDLE, CHASE, RETURN, DEAD }

# kind -> stats and look. Data, not code paths: new enemies are new rows.
const KINDS := {
	"bandido": {"name": "Bandido", "hp": 50.0, "dmg": 9.0, "aggro": 8.0, "range": 1.9, "speed": 3.9,
		"idle": "Sword_Idle", "move": "Jog_Fwd", "attack": "Sword_Regular_B", "hit_at": 0.32,
		"outfit": "Ranger", "tint": Color(0.85, 0.45, 0.4), "sword": true, "hit": "Hit_Chest", "death": "Death01"},
	"corrompido": {"name": "Corrompido", "hp": 40.0, "dmg": 7.0, "aggro": 10.0, "range": 1.7, "speed": 2.0,
		"idle": "Zombie_Idle", "move": "Zombie_Walk_Fwd", "attack": "Zombie_Scratch", "hit_at": 0.45,
		"outfit": "Peasant", "tint": Color(0.7, 0.45, 0.95), "sword": false, "hit": "Hit_Chest", "death": "Death01"},
	# Creatures: a GLB with its own clips (wolf) or a static model with a procedural gait (boar).
	"lobo": {"name": "Lobo corrompido", "hp": 45.0, "dmg": 8.0, "aggro": 11.0, "range": 1.8, "speed": 6.2, "creature": true,
		"model": "res://assets/creatures/wolf_a.glb", "scale": 0.32, "ground": 0.0, "label_y": 1.7,
		"idle": "Idle", "move": "Gallop", "attack": "Attack", "hit": "Idle_HitReact_Left", "death": "Death", "hit_at": 0.3,
		"loops": ["Idle", "Idle_2", "Walk", "Gallop"], "tint": Color(0.85, 0.76, 1.0), "bar_y": 1.45},
	# The boar is the animated Quaternius pig (CC0) made darker and bigger, with tusks.
	"javali": {"name": "Javali", "hp": 60.0, "dmg": 10.0, "aggro": 8.0, "range": 1.9, "speed": 5.2, "creature": true,
		"model": "res://assets/creatures/pig_animated.glb", "scale": 0.55, "ground": 0.0, "label_y": 1.35,
		"idle": "AnimalArmature|AnimalArmature|AnimalArmature|Idle", "move": "AnimalArmature|AnimalArmature|AnimalArmature|Run", "attack": "AnimalArmature|AnimalArmature|AnimalArmature|Headbutt", "hit": "", "death": "AnimalArmature|AnimalArmature|AnimalArmature|Death", "hit_at": 0.35,
		"loops": ["AnimalArmature|AnimalArmature|AnimalArmature|Idle", "AnimalArmature|AnimalArmature|AnimalArmature|Idle_Eating", "AnimalArmature|AnimalArmature|AnimalArmature|Walk", "AnimalArmature|AnimalArmature|AnimalArmature|Run"], "tint": Color(0.42, 0.48, 0.46), "bar_y": 1.1,
		"tusks": {"bone": "Head_end", "length": 0.22, "spread": 0.09, "rot": Vector3(0, 0, 0)}},
}

var kind := "bandido"
var camp := ""
var hp := 50.0
var max_hp := 50.0
var damage := 9.0
var aggro := 8.0
var leash := 18.0
var attack_range := 1.9
var attack_clip := "Sword_Regular_B"
var hit_at := 0.32
var home := Vector3.ZERO
var target: Actor
var target_down := false
var state := State.IDLE
var cooldown := 0.6
var staggered := false
var bar: MeshInstance3D
var bar_fg: MeshInstance3D


func configure(k: String, camp_id: String, at: Vector3, who: Actor) -> void:
	var d: Dictionary = KINDS[k]
	kind = k
	camp = camp_id
	target = who
	home = at
	hp = d.hp
	max_hp = d.hp
	damage = d.dmg
	aggro = d.aggro
	attack_range = d.range
	attack_clip = d.attack
	hit_at = d.hit_at
	if d.get("creature", false):
		setup_creature("%s-%d" % [k, get_instance_id()], d.name, d)
	else:
		setup("%s-%d" % [k, get_instance_id()], d.name, k == "corrompido", d.sword, d.outfit)
		idle_clip = d.idle
		clip_run = d.move
		hit_clip = d.hit
		death_clip = d.death
	if d.tint != Color.WHITE:
		tint(d.tint)
	if d.has("tusks"):
		_add_tusks(d.tusks, float(d.scale))
	speed_run = d.speed
	play(idle_clip)
	global_position = at
	_build_bar(d.get("bar_y", 2.05))


## Two ivory cones on the snout bone. The attachment inherits the armature scale,
## so a holder undoes it and the sizes below are in meters.
func _add_tusks(t: Dictionary, model_scale: float) -> void:
	if skeleton == null or skeleton.find_bone(t.bone) < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = t.bone
	skeleton.add_child(att)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / skeleton.global_transform.basis.get_scale().x  # global scale already includes the model scale
	holder.rotation_degrees = t.rot
	att.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.9, 0.78)
	mat.roughness = 0.6
	for side in [-1.0, 1.0]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.035
		cm.height = t.length
		cm.radial_segments = 6
		cone.mesh = cm
		cone.material_override = mat
		cone.position = Vector3(side * t.spread, t.length * 0.5, 0)
		cone.rotation_degrees = Vector3(0, 0, -side * 18.0)
		holder.add_child(cone)


func _build_bar(y: float) -> void:
	bar = _quad(Vector2(1.0, 0.11), Color(0.1, 0.03, 0.03))
	bar_fg = _quad(Vector2(1.0, 0.11), Color(0.9, 0.2, 0.2))
	bar.position = Vector3(0, y, 0)
	bar_fg.position = Vector3(0, y, 0.001)
	add_child(bar)
	add_child(bar_fg)
	label.position.y = y + 0.3


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 5
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _update_bar() -> void:
	var r := clampf(hp / max_hp, 0.0, 1.0)
	bar_fg.scale.x = maxf(r, 0.001)
	bar_fg.position.x = -(1.0 - r) * 0.5  # shrink toward the left edge


func take_hit(amount: float, from: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_update_bar()
	damaged.emit(self, amount)
	if hp <= 0.0:
		_die()
		return
	state = State.CHASE  # being hit wakes it up, whatever the distance
	staggered = true
	interrupt()
	has_goal = false
	var away := (global_position - from)
	away.y = 0
	dash(away, 0.12)  # short knockback
	play_once(hit_clip, 1.3)
	await get_tree().create_timer(0.45).timeout
	staggered = false
	cooldown = maxf(cooldown, 0.35)


func _die() -> void:
	state = State.DEAD
	interrupt()
	has_goal = false
	collision_layer = 0
	if pick:
		pick.queue_free()
	bar.queue_free()
	bar_fg.queue_free()
	label.queue_free()
	play_death()
	died.emit(self)
	await get_tree().create_timer(2.6).timeout
	var tw := create_tween()
	tw.tween_property(self, "position:y", -1.4, 0.9)
	await tw.finished
	queue_free()


func _physics_process(delta: float) -> void:
	if state == State.DEAD or staggered or target == null:
		super(delta)
		return
	cooldown -= delta
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var home_dist := global_position.distance_to(home)
	match state:
		State.IDLE:
			if dist < aggro and not target_down:
				state = State.CHASE
		State.CHASE:
			if target_down or dist > leash or home_dist > leash * 1.8:
				state = State.RETURN
			elif busy:
				pass
			elif dist <= attack_range:
				has_goal = false
				face(to)
				model.rotation.y = atan2(to.x, to.z)
				play(idle_clip)
				if cooldown <= 0.0:
					_attack()
			else:
				walk_to(target.global_position)
		State.RETURN:
			if home_dist < 1.0:
				state = State.IDLE
				hp = max_hp
				_update_bar()
				play(idle_clip)
			elif not busy:
				walk_to(home)
	super(delta)


func _attack() -> void:
	cooldown = 1.5
	play_once(attack_clip, 1.0)
	await get_tree().create_timer(hit_at).timeout
	if state == State.DEAD or staggered or target == null or target_down:
		return
	if global_position.distance_to(target.global_position) <= attack_range + 0.7:
		hit_player.emit(self, damage)
