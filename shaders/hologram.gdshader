shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_tex : source_color;
uniform vec4 holo_color : source_color = vec4(0.0, 0.94, 1.0, 0.85);
uniform float scanline_density = 85.0;
uniform float scanline_speed = 2.4;
uniform float flicker_strength = 0.08;

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float scan = 0.72 + 0.28 * sin(UV.y * scanline_density - TIME * scanline_speed);
	float flicker = 1.0 - flicker_strength * sin(TIME * 27.0);
	ALBEDO = mix(tex.rgb, holo_color.rgb, 0.45) * scan * flicker * 1.35;
	ALPHA = clamp(luma * holo_color.a * scan, 0.0, 0.92);
}
