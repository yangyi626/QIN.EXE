shader_type canvas_item;

uniform vec4 holo_tint : source_color = vec4(0.18, 0.94, 1.0, 0.92);
uniform float scan_density : hint_range(20.0, 200.0) = 92.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float scan = 0.78 + 0.22 * sin(UV.y * scan_density + TIME * 5.2);
	float flicker = 0.94 + 0.06 * sin(TIME * 16.0);
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float edge_x = 1.0 - smoothstep(0.62, 1.0, abs(d.x));
	float edge_top = 1.0 - smoothstep(0.66, 1.0, max(0.0, -d.y));
	float edge_bot = 1.0 - smoothstep(0.45, 1.0, max(0.0, d.y));
	float mask = edge_x * edge_top * edge_bot;

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb * vec3(0.55, 1.05, 1.18), holo_tint.rgb * (0.42 + luma * 0.95), 0.42);
	COLOR = vec4(col * scan * flicker, tex.a * holo_tint.a * mask * (0.76 + 0.24 * scan));
}
