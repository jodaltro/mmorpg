class_name Layout
extends RefCounted
## Where things are in this client's 3D world. The engine only knows regions and
## named spots (what an NPC is doing, and where in the region); every coordinate
## lives here. The map is a hub: the village at the centre, a road east to the
## crossroads, and from there the mine (north-east) and the ruins (east); the
## forest lies north of the village and the den west of it.

const ORIGIN := {
	"vila": Vector3(0, 0, 0), "estrada": Vector3(52, 0, 0), "floresta": Vector3(6, 0, -72),
	"mina": Vector3(84, 0, -48), "ruinas": Vector3(112, 0, 6), "toca": Vector3(-52, 0, -28),
}
# Region trigger boxes: id -> [centre, size]. They never overlap.
const ZONES := {
	"vila": [Vector3(0, 0, 0), Vector3(68, 6, 60)],
	"estrada": [Vector3(57, 0, 0), Vector3(46, 6, 28)],
	"floresta": [Vector3(6, 0, -72), Vector3(92, 6, 70)],
	"mina": [Vector3(84, 0, -48), Vector3(36, 6, 36)],
	"ruinas": [Vector3(112, 0, 6), Vector3(36, 6, 40)],
	"toca": [Vector3(-52, 0, -28), Vector3(20, 6, 16)],
}
const VILLAGE := Rect2(-32, -28, 64, 56)  # inside the palisade
const CROSSROADS := Vector3(64, 0, 0)
# Roads: from, to, width.
const ROADS := [
	[Vector3(32, 0, 0), Vector3(64, 0, 0), 3.2],
	[Vector3(64, 0, 0), Vector3(108, 0, 6), 3.0],
	[Vector3(64, 0, 0), Vector3(86, 0, -58), 3.0],
	[Vector3(0, 0, -28), Vector3(4, 0, -62), 2.0],
	[Vector3(4, 0, -62), Vector3(22, 0, -84), 2.0],
	[Vector3(-32, 0, -14), Vector3(-50, 0, -26), 1.4],
]
# Named places inside regions: where an NPC's routine puts it, as the engine names the spot.
const SPOTS := {
	"portao": Vector3(30, 0, 2), "guarita": Vector3(28, 0, -5), "praca": Vector3(0, 0, 5.5), "poco": Vector3(2.4, 0, 1.4),
	"taverna": Vector3(15, 0, -8.4), "horta": Vector3(-22, 0, -4), "casa-mira": Vector3(-16, 0, -8.4),
	"forja": Vector3(-17, 0, 9.4), "capela": Vector3(16, 0, 10.4), "celeiro": Vector3(2, 0, 17.4),
	"mirante": Vector3(0, 0, -20.5), "casa-nino": Vector3(-9, 0, -16.4), "banco-estrada": Vector3(44, 0, 3.4),
	"veio-mina": Vector3(81, 0, -54), "clareira": Vector3(-8, 0, -78),
	"torre": Vector3(116, 0, -2), "entrada-ruinas": Vector3(114, 0, 13), "salao-ruinas": Vector3(116, 0, 4),
	"mercado": Vector3(6, 0, 12), "galeria": Vector3(88, 0, -72), "selo-pedras": Vector3(22, 0, -88), "sarca": Vector3(-24, 0, -88),
}
const GALLERY := Rect2(84, -84, 8, 18)  # the dark gallery behind the mine mouth (x, z, width, depth)
const PASSAGE_GALLERY := Vector3(88, 0, -80)
const PASSAGE_RUINS := Vector3(118, 0, 14)
const LOOKOUT := Vector3(0, 0, -21)  # where the village lookout is
# Where people sleep: inside the house that belongs to the spot.
const INSIDE := {
	"casa-mira": Vector3(-16, 0, -14.4), "casa-nino": Vector3(-9, 0, -22.4), "forja": Vector3(-17, 0, 16.0),
}
# Which region each spot belongs to (the engine refuses a spot outside its region).
const SPOT_REGION := {
	"portao": "vila", "guarita": "vila", "praca": "vila", "poco": "vila", "taverna": "vila", "horta": "vila", "casa-mira": "vila",
	"forja": "vila", "capela": "vila", "celeiro": "vila", "mirante": "vila", "casa-nino": "vila", "mercado": "vila",
	"banco-estrada": "estrada", "veio-mina": "mina", "galeria": "mina", "clareira": "floresta", "selo-pedras": "floresta",
	"sarca": "floresta", "torre": "ruinas", "entrada-ruinas": "ruinas", "salao-ruinas": "ruinas",
}
const MAP_BOUNDS := Rect2(-70, -105, 205, 145)  # what the minimap shows


static func spot(id: String, fallback := Vector3.ZERO) -> Vector3:
	return SPOTS.get(id, fallback)


## Distance from p (on the ground plane) to the edge of the nearest road.
static func road_distance(p: Vector3) -> float:
	var best := 1e9
	for r in ROADS:
		var a := Vector2(r[0].x, r[0].z)
		var b := Vector2(r[1].x, r[1].z)
		var q := Vector2(p.x, p.z)
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, q.distance_to(a + (b - a) * t) - float(r[2]) / 2.0)
	return best


## Roads, the village, camps and landmarks stay free of trees so the fixed camera sees the action.
static func tree_free(p: Vector3) -> bool:
	if absf(p.x) < 38.0 and absf(p.z) < 34.0:
		return true
	if road_distance(p) < 3.5:
		return true
	for c in [ORIGIN.estrada, ORIGIN.mina + Vector3(4, 0, 12), ORIGIN.ruinas + Vector3(4, 0, 0)]:
		if Vector2(p.x - c.x, p.z - c.z).length() < 16.0:
			return true
	if Vector2(p.x - ORIGIN.toca.x, p.z - (ORIGIN.toca.z + 3)).length() < 10.0:
		return true
	if Vector2(p.x - (ORIGIN.floresta.x + 16), p.z - (ORIGIN.floresta.z - 16)).length() < 6.0:
		return true
	if Vector2(p.x + 24.0, p.z + 85.0).length() < 9.0:  # the bramble and the slab behind it
		return true
	return false
