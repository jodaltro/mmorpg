extends SceneTree

func aabb_of(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = mi.mesh.get_aabb()
		a = mi.transform * a if mi.get_parent() == n else a
		if first: box = a; first = false
		else: box = box.merge(a)
	return box

func _init() -> void:
	for p in ["village/Wall_Plaster_Straight", "village/Wall_Plaster_Door_Round", "village/Wall_UnevenBrick_Straight", "village/Corner_Exterior_Wood", "village/Floor_Brick", "village/Floor_UnevenBrick", "village/Roof_RoundTiles_6x6", "village/Roof_RoundTiles_6x8", "village/Door_1_Round", "village/Prop_Crate", "village/Prop_Wagon", "village/Prop_WoodenFence_Single", "nature/CommonTree_1", "nature/Grass_Common_Short", "props/Barrel", "props/Table_Large", "props/Sword_Bronze", "characters/Superhero_Male_FullBody"]:
		var s := load("res://assets/%s.gltf" % p) as PackedScene
		if s == null: print(p, " MISSING"); continue
		var n := s.instantiate()
		var b := aabb_of(n)
		print(p, " pos=", b.position, " size=", b.size)
	quit()
