shader_type spatial;
render_mode diffuse_toon, specular_disabled;

/**
 * Cel-Shaded & Screen-Space Halftone Terrain Spatial Shader
 * (Graphic Novel / Moebius Aesthetic)
 *
 * Preserves vertex color palettes from procedural chunk meshing,
 * applies stepped 2-band toon lighting, and fills shadow regions with
 * screen-anchored halftone dots to emulate classic comic printing.
 */

group_uniforms Halftone_Pattern;
uniform sampler2D halftone_texture : filter_linear_mipmap, repeat_enable;
uniform float halftone_scale : hint_range(0.01, 1.0) = 0.15;
uniform float halftone_intensity : hint_range(0.0, 1.0) = 0.75;
uniform bool use_procedural_pattern = false;

group_uniforms Cel_Lighting;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.30;
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.24, 0.32, 1.0);

void fragment() {
	// Preserve baked vertex colors from MeshData (Grass, Dirt, Stone, etc.)
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

// Pure single-responsibility helper: samples either texture or procedural screen-space Ben-Day dots
float evaluate_halftone(vec2 frag_coord, float scale) {
	vec2 screen_uv = frag_coord * scale;

	if (use_procedural_pattern) {
		// Procedural 45-degree rotated Ben-Day dot matrix
		vec2 grid = fract(screen_uv) - vec2(0.5);
		float d = length(grid);
		return 1.0 - step(0.35, d);
	} else {
		return texture(halftone_texture, screen_uv).r;
	}
}

// Pure single-responsibility helper: quantizes continuous lighting into lit vs shadow band
float quantize_light(float n_dot_l, float attenuation) {
	float intensity = max(n_dot_l, 0.0) * attenuation;
	return step(lit_threshold, intensity);
}

void light() {
	float is_lit = quantize_light(dot(NORMAL, LIGHT), ATTENUATION);
	float pattern = evaluate_halftone(FRAGCOORD.xy, halftone_scale);

	vec3 lit_color = ALBEDO * LIGHT_COLOR;
	// In shadow: tint with cool ambient comic hue and apply halftone dot darkness
	vec3 shadow_base = ALBEDO * shadow_tint.rgb;
	vec3 shadow_with_dots = mix(shadow_base, shadow_base * (1.0 - halftone_intensity), pattern);

	DIFFUSE_LIGHT += mix(shadow_with_dots, lit_color, is_lit);
}
