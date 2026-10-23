class_name BioAttackCatalog
extends RefCounted
## Damage, costs and cooldowns live here, never in client input: the authority reads them from this catalog.
## Distances are in world units (1 unit = BioArt.UNIT pixels in the runtime).

const FLAGELLUM_LASH := &"flagellum_lash"
const TOXIN_SPIT := &"toxin_spit"
const MEMBRANE_DASH := &"membrane_dash"
const VIRAL_LUNGE := &"viral_lunge"
const ENEMY_SPIT := &"enemy_spit"  # what the spitters of the organs throw
const BACILLUS_SLAM := &"bacillus_slam"  # the boss of the granuloma: a shockwave around itself

static var _defs: Dictionary = {}


static func get_def(id: StringName) -> BioAttackDef:
	if BioAbilityCatalog.has(id):
		return BioAbilityCatalog.attack_def(id)
	if _defs.is_empty():
		_defs[FLAGELLUM_LASH] = BioAttackDef.new(FLAGELLUM_LASH, 8.0, 14.0, 0.45, 1.7, 6.0, 0.0)
		_defs[TOXIN_SPIT] = BioAttackDef.new(TOXIN_SPIT, 15.0, 10.0, 0.9, 9.0, 3.0, 0.0)
		_defs[MEMBRANE_DASH] = BioAttackDef.new(MEMBRANE_DASH, 12.0, 0.0, 1.2, 4.5, 0.0, 0.28)
		_defs[VIRAL_LUNGE] = BioAttackDef.new(VIRAL_LUNGE, 0.0, 12.0, 2.4, 3.2, 9.0, 0.0)
		_defs[ENEMY_SPIT] = BioAttackDef.new(ENEMY_SPIT, 0.0, 9.0, 2.6, 9.0, 3.0, 0.0)
		_defs[BACILLUS_SLAM] = BioAttackDef.new(BACILLUS_SLAM, 0.0, 18.0, 5.5, 4.2, 14.0, 0.0)
	return _defs[id]


static func all_ids() -> Array:
	get_def(FLAGELLUM_LASH)
	return _defs.keys()
