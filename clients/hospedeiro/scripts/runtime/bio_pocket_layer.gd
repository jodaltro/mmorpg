class_name BioPocketLayer
extends Node2D
## Draws the organelles of the mutations floating inside the body, with NORMAL blending (the membrane itself is additive), so
## translucent fills and bright outlines read like fluorescence microscopy instead of adding up into a white glow.

var body: BioCellBody


func _ready() -> void:
	z_index = 11


func _draw() -> void:
	if body == null:
		return
	var rim := body.rim()
	var r := BioOrganelles.body_radius(rim)
	var t := Time.get_ticks_msec() * 0.001
	var orgs := body.organelles()
	for id in body.genes:
		if not orgs.has(id):
			continue
		var mark: Dictionary = BioGeneCatalog.get_gene(id).mark
		if mark.is_empty():
			continue
		var o: Dictionary = orgs[id]
		var size := BioOrganelles.size_of(str(mark.get("kind", "")), r)
		BioOrganelles.draw_organelle(self, mark, o["p"], size, t, float(o["rot"]), float(o["seed"]))
