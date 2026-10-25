shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform vec4 holes[4]; // center x/y, half width/height, in logical screen pixels
uniform int hole_count = 0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 point = UV * viewport_size;
	float shade = 1.0;
	for (int i = 0; i < 4; i++) {
		if (i >= hole_count) { break; }
		vec2 half_size = holes[i].zw;
		float radius = min(half_size.x, half_size.y) * 0.32;
		vec2 q = abs(point - holes[i].xy) - half_size + vec2(radius);
		float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
		shade *= smoothstep(0.0, 14.0, distance_to_edge);
	}
	COLOR = vec4(0.004, 0.012, 0.028, shade * opacity);
}
