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
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.16, 0.17, 1.0);
uniform vec4 mist_color : source_color = vec4(0.13, 0.17, 0.14, 1.0);
uniform float valley_mist_strength : hint_range(0.0, 1.0) = 0.75;
group_uniforms Ink_Scratches;
uniform bool scratches_enabled = false;
uniform float scratch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scratch_color : source_color = vec4(0.52, 0.08, 0.13, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float evaluate_ink_scratches(vec3 pos, vec3 norm) {
	// Turn off ink scratch streaks on upward-facing floor and downward-facing ceiling rock
	if (norm.y > 0.4 || norm.y < -0.4) {
		return 0.0;
	}
	vec2 p = (abs(norm.y) > 0.5) ? pos.xz : ((abs(norm.x) > 0.5) ? pos.zy : pos.xy);
	float u1 = p.x * 0.7 + p.y * 0.7, v1 = -p.x * 0.7 + p.y * 0.7, c1 = sin(v1 * 0.4) * 1.5;
	float s1 = pow(clamp(1.0 - abs(sin(u1 * 0.85 + c1)) * 1.35, 0.0, 1.0), 1.5);
	float u2 = p.x * 0.85 - p.y * 0.5, v2 = p.x * 0.5 + p.y * 0.85, c2 = cos(v2 * 0.5) * 1.4;
	float s2 = pow(clamp(1.0 - abs(sin(u2 * 1.1 + c2)) * 1.4, 0.0, 1.0), 1.5);
	float s3 = pow(clamp(1.0 - abs(sin((p.x - p.y) * 2.2 + sin(p.y * 0.8) * 2.0)) * 1.5, 0.0, 1.0), 2.0);
	return smoothstep(0.12, 0.45, max(max(s1, s2 * 0.85), s3 * 0.75));
}

void fragment() {
	// Atmospheric aerial perspective fade and deep valley height mist
	float dist_fade = clamp((length(VERTEX) - 35.0) / 185.0, 0.0, 1.0) * 0.65;
	float valley_mist = clamp((26.0 - v_world_pos.y) / 20.0, 0.0, 1.0) * valley_mist_strength;
	vec3 ground_col = mix(COLOR.rgb, mist_color.rgb, clamp(max(dist_fade, valley_mist), 0.0, 0.88));
	if (scratches_enabled && (v_world_normal.y > 0.4 || v_world_normal.y < -0.4)) {
		// Subterranean floor and ceiling rock: crimson red tone with highlight
		vec3 crimson_red = vec3(0.60, 0.06, 0.12);
		ground_col = crimson_red;
	}
	if (scratches_enabled && scratch_intensity > 0.001) {
		ground_col = mix(ground_col, scratch_color.rgb, evaluate_ink_scratches(v_world_pos, v_world_normal) * scratch_intensity);
	}

	ALBEDO = ground_col;
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
	vec2 pixel_coord = floor(FRAGCOORD.xy / 4.0) * 4.0;
	float is_lit = quantize_light(dot(NORMAL, LIGHT), ATTENUATION);
	float pattern = evaluate_halftone(pixel_coord, halftone_scale);

	vec3 lit_color = ALBEDO * LIGHT_COLOR;

	// In shadow: tint with cool ambient comic hue and apply halftone dot darkness
	vec3 shadow_base = ALBEDO * shadow_tint.rgb;
	vec3 shadow_with_dots = mix(shadow_base, shadow_base * (1.0 - halftone_intensity), pattern);

	DIFFUSE_LIGHT += mix(shadow_with_dots, lit_color, is_lit);
}
