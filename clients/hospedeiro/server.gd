extends SceneTree

func _initialize() -> void:
	root.call_deferred("add_child", BioGameServer.new())
