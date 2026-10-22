extends SceneTree
func _init() -> void:
	var inst := (load("res://assets/creatures/boar_polygoogle.glb") as PackedScene).instantiate()
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var b := mat as BaseMaterial3D
				print("boar surf ", i, " albedo=", b.albedo_color, " tex=", b.albedo_texture, " vcolor=", b.vertex_color_use_as_albedo, " metallic=", b.metallic, " rough=", b.roughness)
		var arr := mi.mesh.surface_get_arrays(0)
		print("has COLOR: ", arr[Mesh.ARRAY_COLOR] != null, " verts=", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	quit()
