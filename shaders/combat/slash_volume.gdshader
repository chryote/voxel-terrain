shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

// Controls the swing lifecycle (0.0 = start of swing, 1.0 = fully dissipated)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float trail_length : hint_range(0.1, 1.0) = 0.65;

uniform vec4 core_color : source_color = vec4(0.9, 0.96, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.75, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.18, 0.75, 1.0);

uniform float emission_intensity : hint_range(1.0, 10.0) = 4.5;
uniform float blade_sharpness : hint_range(1.0, 6.0) = 2.8;

// Procedural noise for plasma energy sizzle
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
	// Head position sweeps from 0.0 to 1.0 + trail_length
	float head_pos = progress * (1.0 + trail_length);
	float tail_pos = head_pos - trail_length;

	// Alpha mask along arc length (UV.x)
	float head_mask = smoothstep(head_pos, head_pos - 0.06, UV.x);
	float tail_mask = smoothstep(tail_pos, tail_pos + 0.30, UV.x);
	float arc_mask = head_mask * tail_mask;

	if (arc_mask <= 0.001) {
		discard;
	}

	// Radial gradient (UV.y: 0.0 = inner radius, 1.0 = outer razor edge)
	float radial_factor = clamp(UV.y, 0.0, 1.0);
	float outer_edge_glow = pow(radial_factor, blade_sharpness);
	float inner_edge_soft = smoothstep(0.0, 0.22, radial_factor);

	// High frequency plasma sizzle along the arc
	vec2 noise_uv = vec2(UV.x * 12.0 - progress * 4.0, UV.y * 5.0);
	float sizzle = noise(noise_uv) * 0.35 + 0.65;

	// Color composition
	vec3 color = mix(deep_color.rgb, edge_color.rgb, outer_edge_glow);
	// Outer razor cutting edge gets incandescent white-hot core
	float core_edge = smoothstep(0.75, 0.98, radial_factor) * head_mask;
	color = mix(color, core_color.rgb * 1.5, core_edge);

	// 3D Rim / fresnel effect to emphasize volumetric thickness
	float fresnel = 1.0 - abs(dot(NORMAL, VIEW));
	color += edge_color.rgb * pow(fresnel, 2.5) * 0.5;

	// Final alpha and emission output
	float alpha = arc_mask * inner_edge_soft * sizzle * (0.35 + 0.65 * outer_edge_glow);
	alpha = clamp(alpha, 0.0, 1.0);

	ALBEDO = color * emission_intensity;
	ALPHA = alpha;
}

