class_name BioGenomeStore
extends RefCounted
## Offline persistence of the genome and the evolutionary pressure (JSON). An empty path disables it.

const VERSION := 1


static func save(path: String, genome: BioGenome, tracker: BioMutationTracker) -> bool:
	if path.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "genome": genome.to_dict(), "tracker": tracker.to_dict()}))
	return true


## Loads the saved genome and restores the tracker. A missing or corrupt file yields an empty genome.
static func load_state(path: String, tracker: BioMutationTracker) -> BioGenome:
	if path.is_empty() or not FileAccess.file_exists(path):
		return BioGenome.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return BioGenome.new()
	tracker.load_dict(data.get("tracker", {}))
	return BioGenome.from_dict(data.get("genome", {}))
