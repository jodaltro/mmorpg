class_name BioTouchGlyph
extends RefCounted
## Original vector marks: no external artwork or font-dependent symbols.

static func paint(canvas: Control, kind: String, c: Vector2, r: float, tint: Color) -> void:
	var line := 2.0
	match kind:
		"attack":
			for i in 3:
				var x := (i - 1) * r * 0.65
				canvas.draw_line(c + Vector2(x - r * 0.25, r * 0.65), c + Vector2(x + r * 0.25, -r * 0.65), tint, line + 1, true)
		"toxin":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0,-r), c + Vector2(-r*0.65,r*0.2), c + Vector2(0,r*0.65), c + Vector2(r*0.65,r*0.2)]), tint)
			canvas.draw_circle(c + Vector2(0,r*0.2), r*0.6, tint)
		"dash":
			for i in 2:
				var x := (i - 0.5) * r
				canvas.draw_polyline(PackedVector2Array([c+Vector2(x-r*0.4,-r*0.65),c+Vector2(x+r*0.3,0),c+Vector2(x-r*0.4,r*0.65)]),tint,line,true)
		"close":
			canvas.draw_line(c-Vector2(r,r),c+Vector2(r,r),tint,line,true)
			canvas.draw_line(c-Vector2(-r,r),c+Vector2(-r,r),tint,line,true)
		"menu":
			for i in 3:
				canvas.draw_line(c+Vector2(-r,(i-1)*r*0.65),c+Vector2(r,(i-1)*r*0.65),tint,line,true)
		"interact":
			canvas.draw_arc(c,r*0.8,0,TAU,24,tint,line,true)
			canvas.draw_line(c+Vector2(-r*0.4,0),c+Vector2(r*0.4,0),tint,line,true)
			canvas.draw_line(c+Vector2(0,-r*0.4),c+Vector2(0,r*0.4),tint,line,true)
		"shield":
			canvas.draw_polyline(PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*0.8,-r*0.6),c+Vector2(r*0.6,r*0.5),c+Vector2(0,r),c+Vector2(-r*0.6,r*0.5),c+Vector2(-r*0.8,-r*0.6),c+Vector2(0,-r)]),tint,line,true)
		"projectile":
			canvas.draw_line(c+Vector2(-r,r*0.8),c+Vector2(r*0.7,-r*0.7),tint,line+1,true)
			canvas.draw_polyline(PackedVector2Array([c+Vector2(-r*0.2,-r*0.7),c+Vector2(r*0.7,-r*0.7),c+Vector2(r*0.7,r*0.2)]),tint,line,true)
		"jaw":
			canvas.draw_arc(c,r,-PI*0.8,-PI*0.2,20,tint,line,true)
			canvas.draw_arc(c,r,PI*0.2,PI*0.8,20,tint,line,true)
			for x in [-0.5,0.0,0.5]:
				canvas.draw_line(c+Vector2(x*r,-r*0.8),c+Vector2(x*r,-r*0.25),tint,line,true)
		"net":
			for i in 3:
				var x := (i-1)*r*0.7
				canvas.draw_line(c+Vector2(x,-r),c+Vector2(x,r),tint,1.5,true)
				canvas.draw_line(c+Vector2(-r,x),c+Vector2(r,x),tint,1.5,true)
		"cycle":
			canvas.draw_arc(c,r,-PI*0.8,PI*0.8,28,tint,line,true)
			canvas.draw_colored_polygon(PackedVector2Array([c+Vector2(-r,r*0.2),c+Vector2(-r*0.9,r),c+Vector2(-r*0.2,r*0.7)]),tint)
		"eye":
			canvas.draw_polyline(PackedVector2Array([c+Vector2(-r,0),c+Vector2(0,-r*0.7),c+Vector2(r,0),c+Vector2(0,r*0.7),c+Vector2(-r,0)]),tint,line,true)
			canvas.draw_circle(c,r*0.27,tint)
		"link":
			canvas.draw_arc(c+Vector2(-r*0.5,0),r*0.5,0,TAU,20,tint,line,true)
			canvas.draw_arc(c+Vector2(r*0.5,0),r*0.5,0,TAU,20,tint,line,true)
			canvas.draw_line(c-Vector2(r*0.4,0),c+Vector2(r*0.4,0),tint,line,true)
		"heal":
			canvas.draw_line(c+Vector2(-r*0.8,0),c+Vector2(r*0.8,0),tint,4,true)
			canvas.draw_line(c+Vector2(0,-r*0.8),c+Vector2(0,r*0.8),tint,4,true)
		_:
			var points := PackedVector2Array()
			for i in 9:
				points.append(c + Vector2.from_angle(i*TAU/8) * (r if i%2==0 else r*0.42))
			canvas.draw_polyline(points,tint,line,true)
