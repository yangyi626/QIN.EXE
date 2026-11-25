shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color;
uniform vec4 holo_tint : source_color = vec4(0.18, 0.92, 1.0, 0.92);
uniform float scan_density : hint_range(10.0, 160.0) = 72.0;

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float scan = 0.78 + 0.22 * sin(UV.y * scan_density + TIME * 5.0);
	float flicker = 0.94 + 0.06 * sin(TIME * 17.0);
	// Soft oval/frame fade so square portrait edges melt into hologram projection
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float edge_x = 1.0 - smoothstep(0.72, 1.0, abs(d.x));
	float edge_top = 1.0 - smoothstep(0.74, 1.0, max(0.0, -d.y));
	float edge_bot = 1.0 - smoothstep(0.62, 1.0, max(0.0, d.y));
	float mask = edge_x * edge_top * edge_bot;

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb * vec3(0.65, 1.05, 1.15), holo_tint.rgb * (0.45 + luma * 0.95), 0.36);
	ALBEDO = col * scan * flicker;
	ALPHA = tex.a * holo_tint.a * mask * (0.72 + 0.28 * scan);
}
