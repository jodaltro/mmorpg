class_name BioBodyMap
extends RefCounted
## Geometry of the playable part of the Hospedeiro: the marrow and the blood, two chambers joined by a
## sinusoid. Distances are in world units; *_px helpers return pixels. Region ids match the universe.

const MEDULA := &"medula"
const SANGUE := &"sangue"

const MEDULA_CENTER := Vector2(0.0, 0.0)
const MEDULA_RADIUS := 14.0
const SANGUE_CENTER := Vector2(38.0, 0.0)
const SANGUE_RADIUS := 18.0
const NECK_HALF_WIDTH := 2.6
const ARC_POINTS := 72

## Where the universe's spots are drawn (the engine never places anything).
const SPOTS := {
	"nicho": Vector2(-6.0, 5.0),
	"sinusoide": Vector2(11.0, 0.0),
	"capilar": Vector2(44.0, 10.0),
	"corrente": Vector2(36.0, -8.0),
}

## Where each resident cell lives in its region.
const RESIDENTS := {
	"estroma": Vector2(-8.0, -4.0),
	"neva": Vector2(47.0, -4.0),
	"rubra": Vector2(31.0, 9.0),
	"dendra": Vector2(41.0, 12.0),
}

const NAMES := {MEDULA: "MEDULA ÓSSEA", SANGUE: "CORRENTE SANGUÍNEA"}


static func neck_x_units() -> float:
	var medula_edge := MEDULA_CENTER.x + sqrt(MEDULA_RADIUS * MEDULA_RADIUS - NECK_HALF_WIDTH * NECK_HALF_WIDTH)
	var sangue_edge := SANGUE_CENTER.x - sqrt(SANGUE_RADIUS * SANGUE_RADIUS - NECK_HALF_WIDTH * NECK_HALF_WIDTH)
	return (medula_edge + sangue_edge) * 0.5


static func region_of(pos_px: Vector2) -> StringName:
	return MEDULA if pos_px.x / BioArt.UNIT < neck_x_units() else SANGUE


static func center_px(region: StringName) -> Vector2:
	return (MEDULA_CENTER if region == MEDULA else SANGUE_CENTER) * BioArt.UNIT


static func radius_units(region: StringName) -> float:
	return MEDULA_RADIUS if region == MEDULA else SANGUE_RADIUS


static func spot_px(spot: String) -> Vector2:
	return SPOTS.get(spot, MEDULA_CENTER) * BioArt.UNIT


## Closed outline (units): marrow arc around the left, the sinusoid's lower wall, the blood arc around
## the right, then the sinusoid's upper wall back to the start.
static func outline_units() -> PackedVector2Array:
	var points := PackedVector2Array()
	var a_cut := asin(NECK_HALF_WIDTH / MEDULA_RADIUS)
	for i in ARC_POINTS + 1:
		var a := lerpf(a_cut, TAU - a_cut, i / float(ARC_POINTS))
		points.append(MEDULA_CENTER + Vector2.from_angle(a) * MEDULA_RADIUS)
	var b_cut := asin(NECK_HALF_WIDTH / SANGUE_RADIUS)
	for i in ARC_POINTS + 1:
		var a := lerpf(PI + b_cut, 3.0 * PI - b_cut, i / float(ARC_POINTS))
		points.append(SANGUE_CENTER + Vector2.from_angle(a) * SANGUE_RADIUS)
	return points


static func random_point_px(rng: RandomNumberGenerator, region: StringName, avoid_px: Vector2, min_distance_units: float) -> Vector2:
	var center := center_px(region)
	var reach := (radius_units(region) - 2.0) * BioArt.UNIT
	for attempt in 12:
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * reach
		if p.distance_to(avoid_px) >= min_distance_units * BioArt.UNIT:
			return p
	return center + Vector2(0.0, reach * 0.8)


## Tangential flow of the blood chamber at a point (pixels per second), zero outside it.
static func blood_flow_px(pos_px: Vector2, speed_units: float) -> Vector2:
	var d := pos_px - center_px(SANGUE)
	var r := d.length()
	var limit := SANGUE_RADIUS * BioArt.UNIT
	if r < 1.0 or r > limit:
		return Vector2.ZERO
	var strength := sin(PI * r / limit)  # calm at the centre and at the walls, fastest in between
	return Vector2(-d.y, d.x) / r * speed_units * BioArt.UNIT * strength
