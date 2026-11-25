shader_type spatial;
render_mode unshaded;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
// The six region beacons and Xianyang, projected into the map texture.
uniform vec2 sites[7];
uniform float occupied[7];

void fragment() {
	vec3 ink = texture(atlas, UV).rgb;
	float nearest = 100.0;
	float claimed = 0.0;
	for (int i = 0; i < 7; i++) {
		vec2 offset = (UV - sites[i]) * vec2(1.778, 1.0);
		float distance_sq = dot(offset, offset);
		if (distance_sq < nearest) {
			nearest = distance_sq;
			claimed = occupied[i];
		}
	}
	// Warm bronze is land on this atlas. Leave the dark sea and cyan lanes visible.
	float land = smoothstep(0.004, 0.04, ink.r - ink.b);
	vec3 gold = vec3(0.85, 0.47, 0.12) * (0.24 + dot(ink, vec3(0.6, 0.3, 0.1)));
	ALBEDO = mix(ink, gold, claimed * land * 0.8);
}
