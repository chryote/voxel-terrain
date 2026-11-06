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

group_uniforms Sedimentary_Strata;
uniform bool strata_enabled = true;
uniform float strata_frequency : hint_range(0.05, 1.0) = 0.35;
uniform float strata_warp_strength : hint_range(0.0, 1.0) = 0.50;
uniform vec4 strata_color_0 : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 strata_color_1 : source_color = vec4(0.24, 0.15, 0.13, 1.0);
uniform vec4 strata_color_2 : source_color = vec4(0.29, 0.25, 0.22, 1.0);
uniform vec4 strata_color_3 : source_color = vec4(0.16, 0.14, 0.15, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 calculate_voxel_face_uv(vec3 pos, vec3 norm, float frequency) {
	vec3 an = abs(norm);
	if (an.y >= an.x && an.y >= an.z) return pos.xz * frequency;
	return ((an.x >= an.z) ? vec2(pos.z, pos.y) : vec2(pos.x, pos.y)) * frequency;
}

vec2 get_atlas_tile_uv(vec2 cell_uv, int glyph_idx, ivec2 grid) {
	return (vec2(float(glyph_idx % grid.x), float(glyph_idx / grid.x)) + clamp(cell_uv, 0.005, 0.995)) / vec2(grid);
}

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

vec4 sample_glyph_data(vec2 face_uv, int glyph_idx) {
	return textureGrad(ascii_atlas, get_atlas_tile_uv(fract(face_uv), glyph_idx, atlas_grid), dFdx(face_uv) / vec2(atlas_grid), dFdy(face_uv) / vec2(atlas_grid));
}

vec3 perturb_normal_micro_relief(vec3 norm, vec2 face_uv, int glyph_idx, float strength, mat3 view_mat) {
	vec2 uv_c = fract(face_uv), dx = dFdx(face_uv) / vec2(atlas_grid), dy = dFdy(face_uv) / vec2(atlas_grid);
	float eps = 0.035;
	vec2 uv_dx = clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995)), uv_dy = clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995));
	float h_c  = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_c, glyph_idx, atlas_grid), dx, dy).g;
	float h_dx = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_dx, glyph_idx, atlas_grid), dx, dy).g;
	float h_dy = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_dy, glyph_idx, atlas_grid), dx, dy).g;
	float du = clamp((h_dx - h_c) * strength * 2.0, -0.08, 0.08), dv = clamp((h_dy - h_c) * strength * 2.0, -0.08, 0.08);
	vec3 an = abs(v_world_normal);
	vec3 pert_w = (an.y >= an.x && an.y >= an.z) ? vec3(-du, 0.0, -dv) * sign(v_world_normal.y) :
		((an.x >= an.z) ? vec3(0.0, -dv, -du) * sign(v_world_normal.x) : vec3(-du, -dv, 0.0) * sign(v_world_normal.z));
	return normalize(norm + view_mat * pert_w);
}

float hash_cell(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

int select_procedural_glyph(int mat_id, vec2 cell_id, vec3 pos, float slope, out int out_band) {
	float jitter = hash_cell(cell_id);
	vec2 m_coord = (abs(v_world_normal.y) < 0.5) ? vec2((abs(v_world_normal.x) > 0.5) ? pos.z : pos.x, pos.y) : pos.xz;
	float macro = sin(m_coord.x * macro_variation_scale) * cos(m_coord.y * macro_variation_scale) * 0.5 + 0.5;
	float pattern = macro * 0.6 + jitter * 0.4;
	int band = 1;
	if (mat_id == 1) {
		if (slope > 0.40) band = (jitter > 0.75) ? 0 : 1;
		else if (pattern < 0.22 && jitter > 0.70) band = 0;
		else if (pattern > 0.58) band = 2;
	} else {
		band = (pattern > 0.60) ? 2 : ((pattern < 0.20) ? 0 : 1);
	}
	out_band = band;
	return int(round(texelFetch(material_lut, ivec2(mat_id, out_band), 0).r * 255.0));
}

vec3 evaluate_subtle_color(vec3 base_col, int mat_id, int band, float stroke_mask, float cavity_ao, float emboss, float fade) {
	vec3 ground_col = base_col;
	if (abs(v_world_normal.y) < 0.5 && strata_enabled) {
		float strata_y = v_world_pos.y + sin(v_world_pos.x * 0.15 + v_world_pos.z * 0.12) * (strata_warp_strength * 1.5);
		int layer = int(floor(mod(strata_y * strata_frequency, 4.0)));
		vec3 s_col = (layer == 0) ? strata_color_0.rgb : ((layer == 1) ? strata_color_1.rgb : ((layer == 2) ? strata_color_2.rgb : strata_color_3.rgb));
		ground_col = mix(base_col, s_col, (mat_id == 2) ? 0.85 : 0.35);
	} else {
		float ground_tone = (sin(floor(v_world_pos.y) * 0.3) * 0.04 + sin(v_world_pos.x * 0.06 + v_world_pos.z * 0.04) * 0.03) * fade;
		ground_col = clamp(base_col * (1.0 + ground_tone), vec3(0.0), vec3(1.0));
	}
	vec3 cavity_col = ground_col * (1.0 - cavity_shadow_intensity * 0.35 * (1.0 - cavity_ao) * fade);
	float eff_contrast = glyph_contrast * fade;
	if (mat_id == 1 && band == 0) {
		vec3 dirt_top = vec3(0.24, 0.19, 0.16);
		return mix(mix(ground_col, dirt_top, 0.16 * fade) * mix(1.0, cavity_ao, 0.12 * fade), mix(ground_col, dirt_top * 1.20, 0.42 * fade) + emboss * 0.06, stroke_mask);
	}
	if (band == 0) return mix(ground_col * (1.0 - 0.20 * fade) * cavity_ao, ground_col * (1.0 - eff_contrast * 0.90), stroke_mask);
	vec3 stroke_col = (band == 2) ? (ground_col * (1.0 + eff_contrast * 0.55) + vec3(0.02, 0.015, 0.01) * fade + emboss * 0.12) :
		(ground_col * (1.0 - eff_contrast * 0.40) + emboss * 0.08);
	return mix(cavity_col, stroke_col, stroke_mask);
}

float get_bayer_4x4(vec2 p) {
	int x = (int(p.x) % 4 + 4) % 4, y = (int(p.y) % 4 + 4) % 4;
	const float b[16] = float[](
		0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0, 12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
		3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0, 15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
	);
	return b[x + y * 4];
}

void fragment() {
	vec2 face_uv = calculate_voxel_face_uv(v_world_pos, v_world_normal, glyphs_per_voxel);
	int band;
	int glyph_idx = select_procedural_glyph(decode_material_id(COLOR), floor(face_uv), v_world_pos, 1.0 - abs(v_world_normal.y), band);
	vec2 uv_c = fract(face_uv), dx = dFdx(face_uv) / vec2(atlas_grid), dy = dFdy(face_uv) / vec2(atlas_grid);
	float eps = 0.035;
	vec4 glyph_data = textureGrad(ascii_atlas, get_atlas_tile_uv(uv_c, glyph_idx, atlas_grid), dx, dy);
	float stroke_mask = smoothstep(0.35, 0.55, glyph_data.g), h_c = glyph_data.g;
	float h_dx = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float h_dy = textureGrad(ascii_atlas, get_atlas_tile_uv(clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995)), glyph_idx, atlas_grid), dx, dy).g;
	float emboss = clamp(dot(vec2(h_dx - h_c, h_dy - h_c), vec2(0.707, 0.707)) * 4.0 * depth_relief_strength, -0.4, 0.4);
	float detail_fade = clamp(1.0 - (length(VERTEX) - 14.0) / 30.0, 0.0, 1.0);

	ALBEDO = evaluate_subtle_color(COLOR.rgb, decode_material_id(COLOR), band, stroke_mask, glyph_data.b, emboss, detail_fade);
	NORMAL = perturb_normal_micro_relief(NORMAL, face_uv, glyph_idx, depth_relief_strength * 0.20 * detail_fade, mat3(VIEW_MATRIX));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	vec2 p = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float is_lit = (clamp((n_dot_l - (lit_threshold - 0.12)) / 0.24, 0.0, 1.0) > get_bayer_4x4(p)) ? 1.0 : 0.0;
	DIFFUSE_LIGHT += mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR, is_lit);
}
