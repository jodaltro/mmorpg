class_name BioPocketLayer
extends Node2D
## Draws the mutation pockets on top of the body with NORMAL blending (the membrane itself is additive): each pocket gets a
## dark backing disc, so pale marks never add up with the glow underneath into a white blob.

var body: BioCellBody


func _ready() -> void:
	z_index = 11


func _draw() -> void:
	if body == null:
		return
	var rim := body.rim()
	var size := maxf(BioOrganelles.body_radius(rim) * BioOrganelles.POCKET_SIZE, 5.0)
	var away: Vector2 = body.tail.tail_direction() if body.tail != null and body.tail_on else Vector2.ZERO
	var t := Time.get_ticks_msec() * 0.001
	for i in body.genes.size():
		var mark: Dictionary = BioGeneCatalog.get_gene(body.genes[i]).mark
		if mark.is_empty():
			continue
		var at := BioOrganelles.pocket_position(rim, i, away)
		draw_circle(at, size * 1.12, Color(0.01, 0.03, 0.09, 0.62))
		BioOrganelles.draw_pocket(self, mark, at, size, t, i)
