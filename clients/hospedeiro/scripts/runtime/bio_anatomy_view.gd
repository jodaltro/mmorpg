class_name BioAnatomyView
extends Node2D
## Builds the body of the world from BioAnatomy: the walls (one static body with every wall segment, so nothing leaves the body),
## a BioRegionLayer for each organ and the ambient motes of each. It also keeps only the regions around the player alive: the region
## the player is in and the ones a vessel away are drawn and animated, the rest sleep, so a huge body costs what a small one does.

const LIVE_HOPS := 1

var seed_value := 1337
var live: Array[StringName] = []

var _layers := {}  # region id -> BioRegionLayer
var _motes := {}  # region id -> BioAmbientMotes
var _walls: StaticBody2D


func build(body_seed: int) -> void:
	seed_value = body_seed
	var body := BioAnatomy.build(body_seed)
	_walls = StaticBody2D.new()
	_walls.name = "BodyWalls"
	_walls.collision_layer = BioCellActor.LAYER_WALL
	_walls.collision_mask = 0
	var segments := PackedVector2Array()
	for run in body["walls"]:
		var pts: PackedVector2Array = run["points"]
		for i in pts.size() - 1:
			segments.append(pts[i] * BioArt.UNIT)
			segments.append(pts[i + 1] * BioArt.UNIT)
	var shape := CollisionShape2D.new()
	var concave := ConcavePolygonShape2D.new()
	concave.segments = segments
	shape.shape = concave
	_walls.add_child(shape)
	add_child(_walls)
	for region in body["regions"]:
		var id: StringName = region["id"]
		var layer := BioRegionLayer.new()
		layer.name = "Region_%s" % id
		var my_walls: Array = (body["walls"] as Array).filter(func(w: Dictionary) -> bool: return w["region"] == id)
		layer.configure(region, my_walls, body_seed)
		add_child(layer)
		_layers[id] = layer
		var motes := BioAmbientMotes.new()
		motes.position = (region["center"] as Vector2) * BioArt.UNIT
		var area := BioAnatomy.polygon_area(region["outline"])
		motes.build(clampi(int(area / 800.0 * 70.0), 50, 150), clampi(int(area / 800.0 * 9.0), 8, 20), float(region["radius"]), body_seed + String(id).length(), region["palette"])
		add_child(motes)
		_motes[id] = motes
	set_live(BioAnatomy.within(&"medula", LIVE_HOPS))


## Wakes these regions and puts the rest to sleep (hidden and not processed).
func set_live(ids: Array[StringName]) -> void:
	live = ids
	for id in _layers:
		var on := ids.has(id)
		(_layers[id] as Node2D).visible = on
		(_layers[id] as Node).set_process(on)
		(_motes[id] as Node2D).visible = on
		(_motes[id] as Node).set_process(on)


func is_live(id: StringName) -> bool:
	return live.has(id)


func layer(id: StringName) -> BioRegionLayer:
	return _layers.get(id)
