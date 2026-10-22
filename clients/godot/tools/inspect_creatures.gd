extends SceneTree
func _init() -> void:
	for n in ["wolf_a", "wolf_b", "pig_animated"]:
		var inst := (load("res://assets/creatures/%s.glb" % n) as PackedScene).instantiate()
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var box := AABB()
		var first := true
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var a := (m as MeshInstance3D).mesh.get_aabb()
			box = a if first else box.merge(a)
			first = false
		print(n, " anims=", ap.get_animation_list().size() if ap else 0, " size=", box.size, " list=", ap.get_animation_list() if ap else [])
	quit()
