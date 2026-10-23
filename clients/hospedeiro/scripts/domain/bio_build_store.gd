class_name BioBuildStore
extends RefCounted
## What the player keeps about their builds on this machine: the name of each saved slot, the order of the class abilities saved with
## it, and the order they use now. The genes themselves live in the engine (it validates them); this is only what is personal to
## how the player arranges and calls things.

const SLOTS := 3

var path := ""
var names: Dictionary = {}  # slot ("1".."3") -> name
var orders: Dictionary = {}  # slot -> ability ids saved with the build
var current_order: Array = []  # the ability order in use


func _init(p_path: String = "") -> void:
	path = p_path
	_load()


func name_of(slot: int) -> String:
	return str(names.get(str(slot), "Build %d" % slot))


func set_name(slot: int, value: String) -> void:
	var clean := value.strip_edges().left(18)
	if clean.is_empty():
		names.erase(str(slot))
	else:
		names[str(slot)] = clean
	save()


func order_of(slot: int) -> Array:
	return orders.get(str(slot), [])


func save_order(slot: int, ids: Array) -> void:
	orders[str(slot)] = ids.map(func(id: Variant) -> String: return str(id))
	save()


func remember_current(ids: Array) -> void:
	current_order = ids.map(func(id: Variant) -> String: return str(id))
	save()


func save() -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"names": names, "orders": orders, "current": current_order}))


func _load() -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		names = data.get("names", {}) if data.get("names") is Dictionary else {}
		orders = data.get("orders", {}) if data.get("orders") is Dictionary else {}
		current_order = data.get("current", []) if data.get("current") is Array else []
