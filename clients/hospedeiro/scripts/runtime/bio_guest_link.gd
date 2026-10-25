class_name BioGuestLink
extends BioEngineLink
## The host confirms the visitor's deeds; they are recorded in the visitor's
## own local engine. This link has no access to either player's cloud save.

var peer: BioPeerTransport


func _ready() -> void:
	online = true
	reset_allowed = false


func occur(action: String, args: Dictionary = {}) -> Dictionary:
	peer.send_data(21, {"action": action, "args": args})
	return {"status": 200, "body": {}}


func move_region(new_region: String) -> void:
	peer.send_data(23, {"region": new_region})
