extends SceneTree
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var inst: Node3D = (load("res://assets/creatures/pig_animated.glb") as PackedScene).instantiate()
	root.add_child(inst)
	var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in sk.get_bone_count():
		var p: Vector3 = inst.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_rest(i).origin)
		print("bone ", i, " ", sk.get_bone_name(i), " world=", p.snapped(Vector3.ONE * 0.01))
	quit()
