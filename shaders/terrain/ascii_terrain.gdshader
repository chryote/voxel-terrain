shader_type spatial;
render_mode diffuse_toon, specular_disabled;

/**
 * ASCII Map Atlas Voxel Face Spatial Shader
 * (Subtle Tactile Coarseness & Finer Detail)
 */

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
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.24, 0.32, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Computes world-space local face UV using dominant normal axis
vec2 calculate_voxel_face_uv(vec3 pos, vec3 norm, float frequency) {
	vec3 an = abs(norm);
	if (an.y >= an.x && an.y >= an.z) return pos.xz * frequency;
	if (an.x >= an.z) return vec2(pos.z, pos.y) * frequency;
	return vec2(pos.x, pos.y) * frequency;
}

vec2 get_atlas_tile_uv(vec2 cell_uv, int glyph_idx, ivec2 grid) {
	int gx = glyph_idx % grid.x;
	int gy = glyph_idx / grid.x;
	vec2 tile_size = 1.0 / vec2(grid);
	return (vec2(float(gx), float(gy)) + clamp(cell_uv, 0.005, 0.995)) * tile_size;
}

vec2 evaluate_parallax(vec2 cell_uv, vec3 view_dir_tangent, float height, float strength) {
	return cell_uv - view_dir_tangent.xy * (1.0 - height) * strength;
}

int decode_material_id(vec4 col) {
	if (col.a < 0.98 && col.a > 0.002) return clamp(int(round(col.a * 255.0)), 1, 10);
	if (col.r > 0.85 && col.g > 0.85) return 5; // Snow
	if (col.r > 0.75 && col.g > 0.65 && col.b < 0.60) return 4; // Sand
	if (col.b > 0.60 && col.g > 0.60 && col.r < 0.40) return 10; // Crystal
	if (col.g > col.r && col.g > col.b) return 1; // Grass
	if (col.r < 0.20 && col.g < 0.20 && col.b < 0.20) return 9; // Basalt
	if (abs(col.r - col.g) < 0.04 && abs(col.g - col.b) < 0.04) return 3; // Stone
	return (col.r > col.b) ? 2 : 8; // Dirt / Cave Wall
}

vec4 sample_glyph_cell_uv(vec2 cell_uv, int glyph_idx) {
	return texture(ascii_atlas, get_atlas_tile_uv(cell_uv, glyph_idx, atlas_grid));
}

vec4 sample_glyph_data(vec2 face_uv, int glyph_idx) {
	return sample_glyph_cell_uv(fract(face_uv), glyph_idx);
}

vec3 perturb_normal_micro_relief(vec3 norm, vec2 face_uv, int glyph_idx, float strength) {
	vec2 uv_c = fract(face_uv);
	float eps = 0.035;
	vec2 uv_dx = clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995));
	vec2 uv_dy = clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995));
	float h_c  = sample_glyph_cell_uv(uv_c, glyph_idx).g;
	float h_dx = sample_glyph_cell_uv(uv_dx, glyph_idx).g;
	float h_dy = sample_glyph_cell_uv(uv_dy, glyph_idx).g;
	float du = (h_dx - h_c) * strength * 2.0;
	float dv = (h_dy - h_c) * strength * 2.0;
	vec3 an = abs(norm);
	vec3 pert = (an.y >= an.x && an.y >= an.z) ? vec3(-du, 0.0, -dv) * sign(norm.y) :
		((an.x >= an.z) ? vec3(0.0, -dv, -du) * sign(norm.x) : vec3(-du, -dv, 0.0) * sign(norm.z));
	return normalize(norm + pert);
}

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

int select_procedural_glyph(int mat_id, vec2 cell_id, vec3 pos, float slope, out int out_band) {
	float jitter = hash_cell(cell_id);
	vec2 m_coord = (abs(v_world_normal.y) < 0.5) ? vec2((abs(v_world_normal.x) > 0.5) ? pos.z : pos.x, pos.y) : pos.xz;
	float macro = sin(m_coord.x * macro_variation_scale) * cos(m_coord.y * macro_variation_scale) * 0.5 + 0.5;
	float pattern = macro * 0.6 + jitter * 0.4;
	int band = 1;
	if (mat_id == 1) {
		if (slope > 0.40) {
			band = (jitter > 0.75) ? 0 : 1;
		} else if (pattern < 0.22 && jitter > 0.70) {
			band = 0; // Sparse, delicate thatch soil ticks
		} else if (pattern > 0.58) {
			band = 2; // Blade ticks (")
		}
	} else {
		band = (pattern > 0.60) ? 2 : ((pattern < 0.20) ? 0 : 1);
	}
	out_band = band;
	return int(round(texelFetch(material_lut, ivec2(mat_id, out_band), 0).r * 255.0));
}

vec3 evaluate_subtle_color(vec3 base_col, int mat_id, int band, float stroke_mask, float cavity_ao, float emboss, float fade) {
	float ground_tone = (sin(floor(v_world_pos.y) * 0.3) * 0.04 + sin(v_world_pos.x * 0.06 + v_world_pos.z * 0.04) * 0.03) * fade;
	vec3 ground_col = clamp(base_col * (1.0 + ground_tone), vec3(0.0), vec3(1.0));
	vec3 cavity_col = ground_col * (1.0 - cavity_shadow_intensity * 0.35 * (1.0 - cavity_ao) * fade);
	float eff_contrast = glyph_contrast * fade;
	if (mat_id == 1 && band == 0) {
		vec3 dirt_top = vec3(0.42, 0.31, 0.22); // Dirt voxel top face (#6b4f38)
		vec3 soil_bg = mix(ground_col, dirt_top, 0.16 * fade) * mix(1.0, cavity_ao, 0.12 * fade);
		vec3 soil_stroke = mix(ground_col, dirt_top * 1.20, 0.42 * fade) + emboss * 0.06;
		return mix(soil_bg, soil_stroke, stroke_mask);
	}
	if (band == 0) return mix(ground_col * (1.0 - 0.20 * fade) * cavity_ao, ground_col * (1.0 - eff_contrast * 0.90), stroke_mask);
	vec3 stroke_col = (band == 2) ? (ground_col * (1.0 + eff_contrast * 0.55) + vec3(0.03, 0.07, 0.01) * fade + emboss * 0.12) :
		(ground_col * (1.0 - eff_contrast * 0.40) + emboss * 0.08);
	return mix(cavity_col, stroke_col, stroke_mask);
}

void fragment() {
	vec2 face_uv = calculate_voxel_face_uv(v_world_pos, v_world_normal, glyphs_per_voxel);
	int band;
	int glyph_idx = select_procedural_glyph(decode_material_id(COLOR), floor(face_uv), v_world_pos, 1.0 - abs(v_world_normal.y), band);
	vec2 uv_c = fract(face_uv);
	float eps = 0.035;
	vec2 uv_dx = clamp(uv_c + vec2(eps, 0.0), vec2(0.005), vec2(0.995));
	vec2 uv_dy = clamp(uv_c + vec2(0.0, eps), vec2(0.005), vec2(0.995));
	vec4 glyph_data = sample_glyph_cell_uv(uv_c, glyph_idx);
	float stroke_mask = smoothstep(0.35, 0.55, glyph_data.g);
	float h_c  = glyph_data.g;
	float h_dx = sample_glyph_cell_uv(uv_dx, glyph_idx).g;
	float h_dy = sample_glyph_cell_uv(uv_dy, glyph_idx).g;
	float emboss = clamp(dot(vec2(h_dx - h_c, h_dy - h_c), vec2(0.707, 0.707)) * 4.0 * depth_relief_strength, -0.4, 0.4);
	float detail_fade = clamp(1.0 - (length(VERTEX) - 14.0) / 30.0, 0.0, 1.0);

	ALBEDO = evaluate_subtle_color(COLOR.rgb, decode_material_id(COLOR), band, stroke_mask, glyph_data.b, emboss, detail_fade);
	NORMAL = perturb_normal_micro_relief(NORMAL, face_uv, glyph_idx, depth_relief_strength * 0.20 * detail_fade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float is_lit = step(lit_threshold, n_dot_l);
	DIFFUSE_LIGHT += mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR, is_lit);
}
