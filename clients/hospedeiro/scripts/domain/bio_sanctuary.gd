class_name BioSanctuary
extends RefCounted
## Starting region is safe from wild enemies, including attacks across its border.
static func contains(seed_value: int, position_units: Vector2) -> bool:
	return BioAnatomy.region_at(seed_value, position_units) == &"medula"
