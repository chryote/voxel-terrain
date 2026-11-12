shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;

// Controls the swing lifecycle (0.0 = start of swing, 1.0 = fully dissipated)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float trail_length : hint_range(0.1, 1.0) = 0.65;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float void_emission : hint_range(1.0, 15.0) = 8.0;

// Procedural noise for reality tear distortion
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float head_pos = progress * (1.0 + trail_length);
	float tail_pos = head_pos - trail_length;

	float head_mask = smoothstep(head_pos, head_pos - 0.06, UV.x);
	float tail_mask = smoothstep(tail_pos, tail_pos + 0.30, UV.x);
	float arc_mask = head_mask * tail_mask;

	if (arc_mask <= 0.001) {
		discard;
	}

	float radial_factor = clamp(UV.y, 0.0, 1.0);
	float inner_edge_soft = smoothstep(0.0, 0.15, radial_factor);

	// Razor cutting edge rim band
	float rim_band = smoothstep(0.78, 0.99, radial_factor);

	// Outer incandescent glowing rim (tinted by card edge_color and white core)
	vec3 rim_glow = mix(edge_color.rgb * 4.0, core_color.rgb * void_emission, smoothstep(0.88, 1.0, radial_factor));

	// Core is pure pitch black (#000000), tearing a hole in reality
	vec3 void_color = mix(vec3(0.0), rim_glow, rim_band);

	// Solid black center occludes scene behind it, rim is full opacity
	float void_alpha = arc_mask * inner_edge_soft * (0.92 + 0.08 * rim_band);

	ALBEDO = void_color;
	ALPHA = clamp(void_alpha, 0.0, 1.0);
}

