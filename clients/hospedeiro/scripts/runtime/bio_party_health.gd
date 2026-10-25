class_name BioPartyHealth
extends Node2D
## Visible membrane and name for open-world PvP participants.
var cell: BioCellActor
var display_name := "Célula"


static func attach(target: BioCellActor, title: String) -> void:
	if target.has_node("PartyHealth"): return
	var marker := BioPartyHealth.new()
	marker.name = "PartyHealth"
	marker.cell = target
	marker.display_name = title.left(24)
	target.add_child(marker)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if cell == null or not cell.is_active(): return
	var v := cell.combatant.actor.vitals
	var ratio := clampf(v.membrane / maxf(1, v.max_membrane), 0, 1)
	var rect := Rect2(-34,-43,68,5)
	draw_rect(rect.grow(2), Color(0.01,0.025,0.04,0.9))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x*ratio,5)), Color(0.95,0.3,0.4))
	var font := ThemeDB.fallback_font
	var text := "%s · %d/%d" % [display_name, ceili(v.membrane), ceili(v.max_membrane)]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, Vector2(-width*0.5,-48), text, HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color(0.01,0.02,0.03))
	draw_string(font,Vector2(-width*0.5,-48),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(0.95,0.9,0.9))
