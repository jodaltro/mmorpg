class_name BioMoteRules
extends RefCounted
## The motes that drift in the organs and that the cell takes by touching them: an old red cell in the spleen (recycled: it mends the membrane
## and gives energy), a bacterium of the microbiota in the intestine (fed: energy), a crystal of urea in the kidney (filtered: it costs a
## little membrane). Each one is a verb of its organ: touching it is the deed the engine is told about.

const KINDS := {
	&"hemacia_velha": {"name": "Hemácia velha", "color": Color(0.85, 0.22, 0.25), "membrane": 4.0, "atp": 3.0, "action": "reciclar-hemacia"},
	&"microbio": {"name": "Bactéria boa", "color": Color(0.55, 1.0, 0.4), "membrane": 2.0, "atp": 5.0, "action": "nutrir-microbiota"},
	&"cristal_de_ureia": {"name": "Cristal de ureia", "color": Color(0.4, 0.95, 0.9), "membrane": -3.0, "atp": 0.0, "action": "filtrar-ureia"},
	&"fibrina": {"name": "Fibra de fibrina", "color": Color(1.0, 0.82, 0.78), "membrane": 3.0, "atp": 2.0, "action": "selar-ferida-pele"},
	&"residuo_neural": {"name": "Resíduo neural", "color": Color(0.72, 0.55, 0.98), "membrane": 1.0, "atp": 2.0, "action": "amparar-neuronios-cerebro"},
	&"antigeno": {"name": "Antígeno", "color": Color(1.0, 0.65, 0.3), "membrane": 0.0, "atp": 3.0, "action": "acalmar-reacao-linfonodo"},
}


static func kind(id: StringName) -> Dictionary:
	return KINDS.get(id, {})


## Applies one mote to the actor; returns the membrane it cost (0 when it mended or gave energy).
static func apply(id: StringName, actor: BioActor) -> float:
	var k := kind(id)
	if k.is_empty() or not actor.vitals.is_alive():
		return 0.0
	var membrane := float(k["membrane"])
	var cost := 0.0
	if membrane > 0.0:
		actor.vitals.repair(membrane)
	elif membrane < 0.0:
		cost = actor.vitals.take_damage(-membrane)
	if float(k["atp"]) != 0.0:
		actor.vitals.add_atp(float(k["atp"]))
	return cost
