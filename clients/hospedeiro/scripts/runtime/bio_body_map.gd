class_name BioBodyMap
extends RefCounted
## The playable body, as the game asks about it. A thin facade over BioAnatomy (the body as data): regions, where things are, the
## flow of the blood. Distances are in world units; *_px helpers return pixels. Region ids match the universe.

const MEDULA := &"medula"
const TRAINING_POINT := Vector2(3, 2)
const SANGUE := &"sangue"
const CORACAO := &"coracao"
const PULMAO := &"pulmao"
const AORTA := &"aorta"
const FIGADO := &"figado"
const BACO := &"baco"
const INTESTINO := &"intestino"
const RIM := &"rim"
const PELE := &"pele"
const LINFONODO := &"linfonodo"
const CEREBRO := &"cerebro"

## The seed the body is grown from (the world sets it; the same seed gives the same body to everyone).
static var seed_value := 1337

## Where the universe's spots are drawn (the engine never places anything).
const SPOTS := {
	"nicho": Vector2(-6.0, 5.0),
	"sinusoide": Vector2(11.0, 0.0),
	"capilar": Vector2(44.0, 10.0),
	"corrente": Vector2(36.0, -8.0),
	"atrio": Vector2(92.0, -8.0),
	"valvula": Vector2(112.0, 4.0),
	"alveolos": Vector2(96.0, -104.0),
	"bronquiolo": Vector2(88.0, -78.0),
	"arco": Vector2(178.0, 8.0),
	"braquiocefalica": Vector2(198.0, 34.0),
	"sinusoide-hepatico": Vector2(256.0, 88.0),
	"veia-central": Vector2(284.0, 108.0),
	"polpa-vermelha": Vector2(258.0, -54.0),
	"polpa-branca": Vector2(280.0, -72.0),
	"vilosidades": Vector2(156.0, 130.0),
	"cripta-profunda": Vector2(186.0, 154.0),
	"glomerulo": Vector2(320.0, 4.0),
	"tubulo": Vector2(342.0, 18.0),
}

## Where each resident cell lives in its region.
const RESIDENTS := {
	"estroma": Vector2(-8.0, -4.0),
	"neva": Vector2(47.0, -4.0),
	"rubra": Vector2(31.0, 9.0),
	"dendra": Vector2(41.0, 12.0),
}

const NAMES := {MEDULA: "NICHO DA MEDULA", SANGUE: "VÊNULA", CORACAO: "ENDOCÁRDIO", PULMAO: "ALVÉOLOS", AORTA: "ARTÉRIA", FIGADO: "SINUSOIDES DO FÍGADO", BACO: "POLPA DO BAÇO", INTESTINO: "CRIPTAS DO INTESTINO", RIM: "NÉFRONS DO RIM", PELE: "DERME E EPIDERME", LINFONODO: "LINFONODO", CEREBRO: "TECIDO CEREBRAL"}


static func body() -> Dictionary:
	return BioAnatomy.build(seed_value)


static func region_of(pos_px: Vector2) -> StringName:
	return BioAnatomy.region_at(seed_value, pos_px / BioArt.UNIT)


static func center_px(region: StringName) -> Vector2:
	return (BioAnatomy.region_def(region)["center"] as Vector2) * BioArt.UNIT


static func radius_units(region: StringName) -> float:
	return float(BioAnatomy.region_def(region)["radius"])


static func spot_px(spot: String) -> Vector2:
	return SPOTS.get(spot, Vector2.ZERO) * BioArt.UNIT


static func random_point_px(rng: RandomNumberGenerator, region: StringName, avoid_px: Vector2, min_distance_units: float) -> Vector2:
	for attempt in 12:
		var p := BioAnatomy.random_point(seed_value, region, rng, 2.0) * BioArt.UNIT
		if p.distance_to(avoid_px) >= min_distance_units * BioArt.UNIT:
			return p
	return center_px(region)


## A point of the region close to a place (the cell): what a region holds is mostly where the player is, not spread over thousands of pixels.
static func random_point_near_px(rng: RandomNumberGenerator, region: StringName, near_px: Vector2, radius_units: float, min_distance_units: float) -> Vector2:
	for attempt in 16:
		var p := BioAnatomy.random_point(seed_value, region, rng, 2.0) * BioArt.UNIT
		var d := p.distance_to(near_px)
		if d <= radius_units * BioArt.UNIT and d >= min_distance_units * BioArt.UNIT:
			return p
	return random_point_px(rng, region, near_px, min_distance_units)


## The flow of the blood at a point (pixels per second) at time t; zero outside the body.
static func flow_px(pos_px: Vector2, t: float) -> Vector2:
	return BioAnatomy.flow_at(seed_value, pos_px / BioArt.UNIT, t) * BioArt.UNIT


## Where a niche hides in its region (px): a fixed point, the same for everyone, away from the walls.
static func niche_px(id: String, region: StringName) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + id.hash()
	return BioAnatomy.random_point(seed_value, region, rng, 7.0) * BioArt.UNIT
