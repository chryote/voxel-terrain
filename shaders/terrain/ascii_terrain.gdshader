shader_type spatial;
render_mode diffuse_toon, specular_disabled;

group_uniforms ASCII_Atlas;
uniform sampler2D ascii_atlas : filter_linear_mipmap, repeat_enable;
uniform sampler2D material_lut : filter_nearest, repeat_disable;
uniform ivec2 atlas_grid = ivec2(16, 16);
uniform float glyphs_per_voxel : hint_range(1.0, 24.0) = 10.0;
group_uniforms Depth_And_Subtlety;
uniform float glyph_contrast : hint_range(0.05, 1.0) = 0.30;
uniform float depth_relief_strength : hint_range(0.0, 1.0) = 0.15;
uniform float cavity_shadow_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float macro_variation_scale : hint_range(0.02, 0.5) = 0.08;
uniform float parallax_strength : hint_range(0.0, 0.05) = 0.015;
group_uniforms Cel_Lighting;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.30;
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.16, 0.17, 1.0);
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform vec4 mist_color : source_color = vec4(0.13, 0.15, 0.16, 1.0);
uniform float valley_mist_strength : hint_range(0.0, 1.0) = 0.75;
group_uniforms Ink_Scratches;
uniform bool scratches_enabled = false;
uniform float scratch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scratch_color : source_color = vec4(0.52, 0.08, 0.13, 1.0);
group_uniforms Sedimentary_Strata;
uniform bool strata_enabled = true;
uniform float strata_frequency : hint_range(0.05, 1.0) = 0.35;
uniform float strata_warp_strength : hint_range(0.0, 1.0) = 0.50;
uniform vec4 strata_color_0 : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 strata_color_1 : source_color = vec4(0.24, 0.15, 0.13, 1.0);
uniform vec4 strata_color_2 : source_color = vec4(0.29, 0.25, 0.22, 1.0);
uniform vec4 strata_color_3 : source_color = vec4(0.16, 0.14, 0.15, 1.0);
group_uniforms Procedural_Stains;
uniform bool stains_enabled = true;
uniform float stain_scale : hint_range(0.01, 0.5) = 0.08;
uniform float stain_threshold : hint_range(0.2, 0.8) = 0.45;
uniform float stain_intensity : hint_range(0.0, 1.0) = 0.70;
uniform vec4 stain_color_dark : source_color = vec4(0.08, 0.06, 0.05, 0.85);
uniform vec4 stain_color_green : source_color = vec4(0.48, 0.28, 0.12, 0.85);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec2 calculate_voxel_face_uv(vec3 pos, vec3 norm, float frequency) {
	vec3 an = abs(norm);
	return ((an.y >= an.x && an.y >= an.z) ? pos.xz : ((an.x >= an.z) ? vec2(pos.z, pos.y) : vec2(pos.x, pos.y))) * frequency;
}
vec2 get_atlas_tile_uv(vec2 cell_uv, int glyph_idx, ivec2 grid) { return (vec2(float(glyph_idx % grid.x), float(glyph_idx / grid.x)) + clamp(cell_uv, 0.005, 0.995)) / vec2(grid); }
vec2 evaluate_parallax(vec2 cell_uv, vec3 view_dir_tangent, float height, float strength) { return cell_uv - view_dir_tangent.xy * (1.0 - height) * strength; }
int decode_material_id(vec4 col) {
	if (col.a < 0.98 && col.a > 0.002) return clamp(int(round(col.a * 255.0)), 1, 10);
	if (col.r > 0.48 && col.g > 0.46 && col.b > 0.42) return 5; // Snow
	if (col.r > 0.32 && col.g > 0.28 && (col.r - col.b) > 0.08) return 4; // Sand
	if (col.b > 0.30 && col.g > 0.30 && col.r < 0.30) return 10; // Crystal
	if (col.g > col.r && col.g > col.b) return 1; // Grass
	if (col.r < 0.12 && col.g < 0.12 && col.b < 0.12) return 9; // Basalt
	if (abs(col.r - col.g) < 0.025 && abs(col.g - col.b) < 0.025) return 3; // Stone
	return (col.r > col.b) ? 2 : 8; // Dirt / Cave Wall
}
vec4 sample_glyph_data(vec2 face_uv, int glyph_idx) { return textureGrad(ascii_atlas, get_atlas_tile_uv(fract(face_uv), glyph_idx, atlas_grid), dFdx(face_uv) / vec2(atlas_grid), dFdy(face_uv) / vec2(atlas_grid)); }

vec3 perturb_normal_micro_relief(vec3 norm, vec2 face_uv, int glyph_idx, float strength, mat3 view_mat) {
	vec2 uv_c = fract(face_uv), dx = dFdx(face_uv) / vec2(atlas_grid), dy = dFdy(face_uv) / vec2(atlas_grid);
	float eps = 0.035, h_c = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_c, glyph_idx, atlas_grid), dx, dy).g;
	float h_dx = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float h_dy = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float du = clamp((h_dx - h_c) * strength * 2.0, -0.08, 0.08), dv = clamp((h_dy - h_c) * strength * 2.0, -0.08, 0.08);
	vec3 an = abs(v_world_normal);
	vec3 pert_w = (an.y >= an.x && an.y >= an.z) ? vec3(-du, 0.0, -dv) * sign(v_world_normal.y) : ((an.x >= an.z) ? vec3(0.0, -dv, -du) * sign(v_world_normal.x) : vec3(-du, -dv, 0.0) * sign(v_world_normal.z));
	return normalize(norm + view_mat * pert_w);
}
float hash_cell(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float evaluate_procedural_stain(vec3 pos, vec3 norm, out float out_taint) {
	if (scratches_enabled && (norm.y > 0.4 || norm.y < -0.4)) { out_taint = 0.0; return 0.0; }
	vec3 p = pos * stain_scale;
	float is_side = step(abs(norm.y), 0.5), h = (abs(norm.x) > 0.5) ? pos.z : pos.x;
	float drip = pow(clamp(sin(h * 12.0 + sin(h * 28.0) * 0.6) * 0.5 + 0.5, 0.0, 1.0), 2.6);
	float side_w = max(smoothstep(0.65, 0.98, fract(pos.y)) * 0.85, drip * (0.3 + 0.7 * fract(pos.y)));
	float macro = sin(p.x + sin(p.z * 1.5)) * cos(p.z + sin(p.y * 1.2)) * 0.5 + 0.5;
	float medium = sin(p.x * 2.6 + sin(p.z * 2.1)) * cos(p.z * 2.4 + sin(p.x * 1.8)) * 0.5 + 0.5;
	float micro = sin(p.x * 6.2 - p.z * 4.8) * cos(p.z * 5.7 + p.x * 3.4) * 0.5 + 0.5;
	float top_w = macro * 0.50 + medium * 0.35 + micro * 0.15;
	float s = clamp(mix(top_w, macro * 0.35 + side_w * 0.75, is_side), 0.0, 1.0);
	out_taint = clamp(1.0 - smoothstep(stain_threshold + 0.06, stain_threshold + 0.26, s), 0.0, 1.0);
	return s;
}

float evaluate_ink_scratches(vec3 pos, vec3 norm) {
	if (norm.y > 0.4 || norm.y < -0.4) return 0.0; // Suppress floor and ceiling rock streaks
	vec2 p = (abs(norm.y) > 0.5) ? pos.xz : ((abs(norm.x) > 0.5) ? pos.zy : pos.xy);
	float u1 = p.x * 0.7 + p.y * 0.7, v1 = -p.x * 0.7 + p.y * 0.7, c1 = sin(v1 * 0.4) * 1.5, s1 = pow(clamp(1.0 - abs(sin(u1 * 0.85 + c1)) * 1.35, 0.0, 1.0), 1.5);
	float u2 = p.x * 0.85 - p.y * 0.5, v2 = p.x * 0.5 + p.y * 0.85, c2 = cos(v2 * 0.5) * 1.4, s2 = pow(clamp(1.0 - abs(sin(u2 * 1.1 + c2)) * 1.4, 0.0, 1.0), 1.5);
	float s3 = pow(clamp(1.0 - abs(sin((p.x - p.y) * 2.2 + sin(p.y * 0.8) * 2.0)) * 1.5, 0.0, 1.0), 2.0);
	return smoothstep(0.12, 0.45, max(max(s1, s2 * 0.85), s3 * 0.75));
}

int select_procedural_glyph(int mat_id, vec2 cell_id, vec3 pos, float slope, out int out_band) {
	float jitter = hash_cell(cell_id);
	vec2 m_coord = (abs(v_world_normal.y) < 0.5) ? vec2((abs(v_world_normal.x) > 0.5) ? pos.z : pos.x, pos.y) : pos.xz;
	float macro = sin(m_coord.x * macro_variation_scale) * cos(m_coord.y * macro_variation_scale) * 0.5 + 0.5;
	float pattern = macro * 0.6 + jitter * 0.4;
	int band = (mat_id == 1) ? ((slope > 0.40) ? ((jitter > 0.75) ? 0 : 1) : ((pattern < 0.22 && jitter > 0.70) ? 0 : ((pattern > 0.58) ? 2 : 1))) : ((pattern > 0.60) ? 2 : ((pattern < 0.20) ? 0 : 1));
	out_band = band;
	if (scratches_enabled && (v_world_normal.y > 0.4 || v_world_normal.y < -0.4) && jitter < 0.75) return 32;
	return int(round(texelFetch(material_lut, ivec2(mat_id, out_band), 0).r * 255.0));
}

vec3 evaluate_subtle_color(vec3 base_col, int mat_id, int band, float stroke_mask, float cavity_ao, float emboss, float fade) {
	vec3 ground_col = base_col;
	if (abs(v_world_normal.y) < 0.5 && strata_enabled) {
		float strata_y = v_world_pos.y + sin(v_world_pos.x * 0.15 + v_world_pos.z * 0.12) * (strata_warp_strength * 1.5);
		int layer = int(floor(mod(strata_y * strata_frequency, 4.0)));
		vec3 s_col = (layer == 0) ? strata_color_0.rgb : ((layer == 1) ? strata_color_1.rgb : ((layer == 2) ? strata_color_2.rgb : strata_color_3.rgb));
		ground_col = mix(base_col, s_col, (mat_id == 2) ? 0.85 : 0.75);
	} else {
		float ground_tone = (sin(floor(v_world_pos.y) * 0.3) * 0.04 + sin(v_world_pos.x * 0.06 + v_world_pos.z * 0.04) * 0.03) * fade;
		ground_col = clamp(base_col * (1.0 + ground_tone), vec3(0.0), vec3(1.0));
		if (strata_enabled && scratches_enabled) ground_col = (v_world_normal.y > 0.4 || v_world_normal.y < -0.4) ? mix(strata_color_1.rgb, strata_color_2.rgb, 0.45) : mix(ground_col, mix(strata_color_0.rgb, strata_color_1.rgb, 0.55), 0.75);
	}
	if (stains_enabled) {
		float taint_kind, s_val = evaluate_procedural_stain(v_world_pos, v_world_normal, taint_kind);
		if (s_val > stain_threshold) ground_col = mix(ground_col, mix(stain_color_dark.rgb, stain_color_green.rgb, taint_kind), smoothstep(stain_threshold, stain_threshold + 0.25, s_val) * stain_intensity);
	}
	vec3 cavity_col = ground_col * (1.0 - cavity_shadow_intensity * 0.35 * (1.0 - cavity_ao) * fade);
	float eff_contrast = glyph_contrast * fade;
	if (scratches_enabled && (v_world_normal.y > 0.4 || v_world_normal.y < -0.4)) return mix(ground_col, ground_col * (1.0 + eff_contrast * 0.75) + emboss * 0.12, stroke_mask);
	if (mat_id == 1 && band == 0) return mix(mix(ground_col, vec3(0.18), 0.16 * fade) * mix(1.0, cavity_ao, 0.12 * fade), mix(ground_col, vec3(0.216), 0.42 * fade) + emboss * 0.06, stroke_mask);
	if (band == 0) return mix(ground_col * (1.0 - 0.20 * fade) * cavity_ao, ground_col * (1.0 - eff_contrast * 0.90), stroke_mask);
	vec3 stroke_col = (band == 2) ? (ground_col * (1.0 + eff_contrast * 0.55) + vec3(0.015) * fade + emboss * 0.12) : (ground_col * (1.0 - eff_contrast * 0.40) + emboss * 0.08);
	return mix(cavity_col, stroke_col, stroke_mask);
}

void fragment() {
	float g_freq = ((v_world_normal.y > 0.4 || v_world_normal.y < -0.4) && scratches_enabled) ? glyphs_per_voxel * 0.5 : glyphs_per_voxel;
	vec2 face_uv = calculate_voxel_face_uv(v_world_pos, v_world_normal, g_freq);
	int band, glyph_idx = select_procedural_glyph(decode_material_id(COLOR), floor(face_uv), v_world_pos, 1.0 - abs(v_world_normal.y), band);
	vec2 uv_c = fract(face_uv), dx = dFdx(face_uv) / vec2(atlas_grid), dy = dFdy(face_uv) / vec2(atlas_grid);
	float eps = 0.035, detail_fade = clamp(1.0 - (length(VERTEX) - 14.0) / 30.0, 0.0, 1.0);
	vec4 glyph_data = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_c, glyph_idx, atlas_grid), dx, dy);
	float stroke_mask = smoothstep(0.35, 0.55, glyph_data.g), h_c = glyph_data.g;
	float h_dx = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float h_dy = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float emboss = clamp(dot(vec2(h_dx - h_c, h_dy - h_c), vec2(0.707, 0.707)) * 4.0 * depth_relief_strength, -0.4, 0.4);
	vec3 ground_col = evaluate_subtle_color(COLOR.rgb, decode_material_id(COLOR), band, stroke_mask, glyph_data.b, emboss, detail_fade);
	float dist_fade = clamp((length(VERTEX) - 35.0) / 185.0, 0.0, 1.0) * 0.65;
	float valley_mist = clamp((26.0 - v_world_pos.y) / 20.0, 0.0, 1.0) * valley_mist_strength;
	ALBEDO = mix(ground_col, mist_color.rgb, clamp(max(dist_fade, valley_mist), 0.0, 0.88));
	if (scratches_enabled && scratch_intensity > 0.001) ALBEDO = mix(ALBEDO, scratch_color.rgb, evaluate_ink_scratches(v_world_pos, v_world_normal) * scratch_intensity);
	NORMAL = perturb_normal_micro_relief(NORMAL, face_uv, glyph_idx, depth_relief_strength * 0.20 * detail_fade, mat3(VIEW_MATRIX));
	ROUGHNESS = 1.0; SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR, step(lit_threshold, max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION));
}
