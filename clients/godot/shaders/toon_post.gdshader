shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, fog_disabled;
// Full-screen post pass: soft light bands plus thin ink lines on silhouettes only.
// Lines come from depth discontinuities (never from normal maps, which would
// outline every cobblestone). One pass unifies assets from different packs.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform float cam_near = 0.1;
uniform float cam_far = 250.0;
uniform float thickness = 1.0;
uniform float depth_threshold = 0.45;  // meters of depth jump that starts a line
uniform float line_strength = 0.7;
uniform vec4 line_color : source_color = vec4(0.10, 0.07, 0.08, 1.0);
uniform float bands = 5.0;
uniform float posterize = 0.4;
uniform float saturation = 1.12;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	return cam_near + (1.0 - d) * (cam_far - cam_near);  // orthographic: linear
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;

	// Soft bands: flat inside each band, a short smooth step between them.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	float x = l * bands;
	float lq = (floor(x) + smoothstep(0.35, 0.65, fract(x))) / bands;
	vec3 toon = mix(col, col * (lq / max(l, 0.001)), posterize);
	float g = dot(toon, vec3(0.299, 0.587, 0.114));
	toon = mix(vec3(g), toon, saturation);

	float de = abs(view_depth(uv + vec2(px.x, px.y)) - view_depth(uv - vec2(px.x, px.y)))
		+ abs(view_depth(uv + vec2(px.x, -px.y)) - view_depth(uv + vec2(-px.x, px.y)));
	float edge = smoothstep(depth_threshold, depth_threshold * 2.5, de) * line_strength;

	ALBEDO = mix(toon, line_color.rgb, edge);
}
