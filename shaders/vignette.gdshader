shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.5) = 0.62;
uniform float danger_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_alpha : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered * vec2(1.15, 1.0));
	float vig = smoothstep(0.32, 0.86, dist) * vignette_strength;
	float pulse = 0.65 + 0.35 * sin(TIME * 4.2);
	float danger = smoothstep(0.36, 0.85, dist) * danger_intensity * pulse * 0.55;
	float scan = (0.5 + 0.5 * sin(UV.y * 520.0 + TIME * 1.5)) * scanline_alpha;

	vec3 base_col = mix(vec3(0.02, 0.025, 0.035), vec3(0.55, 0.04, 0.05), clamp(danger * 1.8, 0.0, 1.0));
	float alpha = clamp(vig + danger + scan, 0.0, 0.82);
	COLOR = vec4(base_col, alpha);
}
