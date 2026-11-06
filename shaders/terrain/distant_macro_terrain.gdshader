shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

/**
 * Extreme Distance LOD Terrain Shader — Stylized Pixel Art Landscape
 * Features:
 * - Virtual Screen-Space Pixel Grid (chunky retro pixel art canvas)
 * - 4x4 Bayer Ordered Dither Matrix for authentic retro shading & transitions
 * - Terraced Elevation Contours (stepped pixel-art mountain shelves)
 * - Multi-Tier Depth Planes (atmospheric parallax ridges receding into horizon)
 * - Dithered Cel Lighting (pixel-stipple transitions from shadow to highlight)
 * - Circular Discard & Pixel-Dither Crossfade with active voxel chunks
 */

group_uniforms Clipping;
uniform vec3 u_clip_center = vec3(0.0);
uniform float u_clip_radius : hint_range(0.0, 2000.0) = 240.0;
uniform float u_clip_feather : hint_range(0.0, 128.0) = 16.0;

group_uniforms Pixel_Art_Stylization;
uniform bool pixel_art_enabled = true;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float terrace_step : hint_range(2.0, 64.0, 1.0) = 16.0;
uniform float terrace_dither_strength : hint_range(0.0, 1.0) = 0.50;
uniform vec4 palette_shadow : source_color = vec4(0.22, 0.19, 0.19, 1.0);
uniform vec4 palette_base : source_color = vec4(0.32, 0.27, 0.26, 1.0);
uniform vec4 palette_lit : source_color = vec4(0.42, 0.36, 0.33, 1.0);
uniform vec4 palette_highlight : source_color = vec4(0.50, 0.43, 0.39, 1.0);
uniform bool depth_layers_enabled = true;
uniform float depth_step_distance : hint_range(200.0, 3000.0, 50.0) = 800.0;

group_uniforms Atmospheric_Perspective;
uniform bool atmosphere_enabled = true;
uniform vec4 haze_color : source_color = vec4(0.38, 0.29, 0.28, 1.0);
uniform float haze_start_distance : hint_range(50.0, 2000.0) = 300.0;
uniform float haze_max_distance : hint_range(500.0, 8000.0) = 3500.0;
uniform float haze_intensity : hint_range(0.0, 1.0) = 0.68;

group_uniforms Legacy_Compatibility;
uniform bool mono_color_enabled = true;
uniform float mono_color_blend : hint_range(0.0, 1.0) = 0.95;
uniform vec4 mono_blue_low : source_color = vec4(0.22, 0.19, 0.19, 1.0);
uniform vec4 mono_blue_mid : source_color = vec4(0.32, 0.27, 0.26, 1.0);
uniform vec4 mono_blue_high : source_color = vec4(0.42, 0.36, 0.33, 1.0);
uniform float mono_distance_start : hint_range(-1.0, 1000.0) = -1.0;
uniform float mono_distance_full : hint_range(50.0, 2000.0) = 360.0;
uniform bool strata_enabled = false;
uniform float strata_frequency : hint_range(0.05, 1.0) = 0.35;
uniform float strata_warp_strength : hint_range(0.0, 1.0) = 0.50;
uniform float strata_tint_strength : hint_range(0.0, 0.5) = 0.0;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.30;
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.40, 0.42, 1.0);
uniform float macro_variation_scale : hint_range(0.01, 0.5) = 0.08;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float get_bayer_4x4(vec2 p) {
	int x = (int(p.x) % 4 + 4) % 4;
	int y = (int(p.y) % 4 + 4) % 4;
	float bayer[16] = float[](
		0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0, 12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
		3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0, 15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
	);
	return bayer[x + y * 4];
}

bool evaluate_bayer_dither(float alpha_val, vec2 frag_coord) {
	vec2 p = pixel_art_enabled ? floor(frag_coord / max(pixel_size, 1.0)) : frag_coord;
	return alpha_val >= get_bayer_4x4(p);
}

vec3 apply_monochrome_blue(vec3 color, float dist) {
	if (!mono_color_enabled) return color;
	float start_d = (mono_distance_start < 0.0) ? u_clip_radius : mono_distance_start;
	float full_d = (mono_distance_start < 0.0) ? (u_clip_radius + mono_distance_full) : (start_d + mono_distance_full);
	float mono_t = clamp((dist - start_d) / max(1.0, full_d - start_d), 0.0, 1.0);
	float eff_blend = mono_color_blend * smoothstep(0.0, 1.0, mono_t);
	if (eff_blend <= 0.001) return color;
	float luma = clamp(dot(color, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	vec3 mono_col = (luma < 0.5) ? mix(mono_blue_low.rgb, mono_blue_mid.rgb, luma * 2.0) : mix(mono_blue_mid.rgb, mono_blue_high.rgb, (luma - 0.5) * 2.0);
	return mix(color, mono_col, eff_blend);
}

vec3 apply_strata_tonal(vec3 base_col, float world_y, float world_x, float world_z) {
	if (!strata_enabled || strata_tint_strength <= 0.001) return base_col;
	float strata_y = world_y + sin(world_x * 0.15 + world_z * 0.12) * (strata_warp_strength * 1.5);
	int layer = int(floor(mod(strata_y * strata_frequency, 4.0)));
	float tone_offset = (layer == 0) ? -strata_tint_strength : ((layer == 2) ? strata_tint_strength : 0.0);
	return clamp(base_col + vec3(tone_offset), vec3(0.0), vec3(1.0));
}

vec3 apply_atmospheric_perspective(vec3 color, float dist) {
	if (!atmosphere_enabled) return color;
	float t = clamp((dist - haze_start_distance) / max(1.0, haze_max_distance - haze_start_distance), 0.0, 1.0);
	return mix(color, haze_color.rgb, smoothstep(0.0, 1.0, t) * haze_intensity);
}

void fragment() {
	float dist = distance(v_world_pos.xz, u_clip_center.xz);
	if (dist < u_clip_radius) discard;
	if (dist < u_clip_radius + u_clip_feather) {
		float alpha_fade = clamp((dist - u_clip_radius) / max(0.001, u_clip_feather), 0.0, 1.0);
		if (!evaluate_bayer_dither(alpha_fade, FRAGCOORD.xy)) discard;
	}

	vec2 pixel_coord = pixel_art_enabled ? floor(FRAGCOORD.xy / max(pixel_size, 1.0)) : FRAGCOORD.xy;
	float dither = get_bayer_4x4(pixel_coord);
	vec3 col = palette_base.rgb;

	// 1. Terraced contour shelves
	if (pixel_art_enabled && terrace_step > 0.5) {
		float step_val = v_world_pos.y / terrace_step;
		float is_shelf = (fract(step_val) < dither * terrace_dither_strength) ? -0.06 : 0.0;
		float alt_band = (mod(floor(step_val), 2.0) == 0.0) ? 0.03 : -0.03;
		col = clamp(col + vec3(is_shelf + alt_band), vec3(0.0), vec3(1.0));
	}

	// 2. Multi-tier depth planes
	if (pixel_art_enabled && depth_layers_enabled) {
		float depth_val = (dist - u_clip_radius) / max(depth_step_distance, 1.0);
		float dithered_tier = floor(depth_val) + (fract(depth_val) > dither ? 1.0 : 0.0);
		col = mix(col, haze_color.rgb, clamp(dithered_tier * 0.05, 0.0, 0.20));
	}

	// 3. Blend with near chunk color at seam, strata, & atmospheric perspective
	col = apply_monochrome_blue(mix(COLOR.rgb, col, mono_color_blend), dist);
	int mat_id = int(round(COLOR.a * 255.0));
	if (mat_id == 3 || mat_id == 2 || abs(v_world_normal.y) < 0.65) {
		col = apply_strata_tonal(col, v_world_pos.y, v_world_pos.x, v_world_pos.z);
	}
	ALBEDO = apply_atmospheric_perspective(col, dist);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	vec2 pixel_coord = pixel_art_enabled ? floor(FRAGCOORD.xy / max(pixel_size, 1.0)) : FRAGCOORD.xy;
	float dither = get_bayer_4x4(pixel_coord);
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float is_lit = (clamp((n_dot_l - (lit_threshold - 0.12)) / 0.24, 0.0, 1.0) > dither) ? 1.0 : 0.0;

	// Pixel art rim highlight on mountain crests
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * step(0.5, n_dot_l);
	float is_rim = (rim > (0.6 + dither * 0.3)) ? 1.0 : 0.0;

	vec3 lit_color = mix(ALBEDO * LIGHT_COLOR, palette_highlight.rgb * LIGHT_COLOR, is_rim * 0.6);
	DIFFUSE_LIGHT += mix(ALBEDO * shadow_tint.rgb, lit_color, is_lit);
}
