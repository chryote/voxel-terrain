shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

/**
 * Procedural PBR Terrain Shader with Triplanar Mapping, Slope/Elevation Blending,
 * Biome Tinting, Macro Anti-Tiling, and Multi-Layer Terrain Splat Painting.
 */

// --- Triplanar & Projection Settings ---
uniform float triplanar_scale : hint_range(0.01, 2.0) = 0.2;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// --- Slope / Cliff Blending ---
uniform float slope_threshold : hint_range(0.1, 0.95) = 0.70;
uniform float slope_blend_margin : hint_range(0.01, 0.5) = 0.15;

// --- Elevation Blending ---
uniform float beach_height = 25.0;
uniform float beach_blend_margin = 3.0;
uniform float snow_height = 140.0;
uniform float snow_blend_margin = 15.0;

// --- Macro Anti-Tiling ---
uniform float macro_variation_strength : hint_range(0.0, 0.5) = 0.12;
uniform float macro_variation_scale : hint_range(0.001, 0.1) = 0.015;

// --- Biome & Global Tint ---
uniform vec3 biome_tint : source_color = vec3(1.0, 1.0, 1.0);

// --- Base PBR Layer Colors ---
uniform vec4 grass_color : source_color = vec4(0.337, 0.490, 0.275, 1.0); // #567d46
uniform vec4 dirt_color : source_color = vec4(0.420, 0.310, 0.220, 1.0);  // #6b4f38
uniform vec4 rock_color : source_color = vec4(0.420, 0.420, 0.420, 1.0);  // #6b6b6b
uniform vec4 sand_color : source_color = vec4(0.843, 0.773, 0.553, 1.0);  // #d7c58d
uniform vec4 snow_color : source_color = vec4(0.941, 0.957, 0.973, 1.0);  // #f0f4f8

// --- Base PBR Layer Roughness ---
uniform float grass_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.90;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.75;
uniform float sand_roughness : hint_range(0.0, 1.0) = 0.88;
uniform float snow_roughness : hint_range(0.0, 1.0) = 0.65;

// --- Texture Support (Optional PBR Textures) ---
uniform bool use_textures = false;
uniform sampler2D texture_grass_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_dirt_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow_albedo : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// --- Terrain Painting / Splatmap Uniforms ---
uniform bool use_splat_map = false;
uniform sampler2D splat_map : hint_default_black, filter_linear, repeat_disable;
uniform vec2 chunk_origin = vec2(0.0, 0.0);
uniform float chunk_size_world = 32.0;

// Painted Layer Overrides
uniform vec4 paint_layer_r_color : source_color = vec4(0.42, 0.31, 0.22, 1.0); // Dirt Path
uniform vec4 paint_layer_g_color : source_color = vec4(0.84, 0.77, 0.55, 1.0); // Sand / Gravel
uniform vec4 paint_layer_b_color : source_color = vec4(0.35, 0.34, 0.32, 1.0); // Cobblestone / Rock
uniform vec4 paint_layer_a_color : source_color = vec4(0.94, 0.96, 0.97, 1.0); // Snow / Special
uniform float paint_layer_r_roughness : hint_range(0.0, 1.0) = 0.92;
uniform float paint_layer_g_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float paint_layer_b_roughness : hint_range(0.0, 1.0) = 0.70;
uniform float paint_layer_a_roughness : hint_range(0.0, 1.0) = 0.60;

// --- Varyings ---
varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_color;

// Simple procedural noise for macro variation
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vertex_color = COLOR;
}

// Samples a texture using world-space triplanar projection
vec4 sample_triplanar(sampler2D tex, vec3 p, vec3 weights) {
	vec4 col_x = texture(tex, p.zy * triplanar_scale);
	vec4 col_y = texture(tex, p.xz * triplanar_scale);
	vec4 col_z = texture(tex, p.xy * triplanar_scale);
	return col_x * weights.x + col_y * weights.y + col_z * weights.z;
}

void fragment() {
	// 1. Calculate Triplanar Projection Weights
	vec3 triblend = pow(abs(v_world_normal), vec3(triplanar_sharpness));
	triblend /= max(triblend.x + triblend.y + triblend.z, 0.0001);

	// 2. Sample or evaluate layer albedo & roughness
	vec4 albedo_grass = grass_color;
	vec4 albedo_dirt = dirt_color;
	vec4 albedo_rock = rock_color;
	vec4 albedo_sand = sand_color;
	vec4 albedo_snow = snow_color;

	if (use_textures) {
		albedo_grass *= sample_triplanar(texture_grass_albedo, v_world_pos, triblend);
		albedo_dirt *= sample_triplanar(texture_dirt_albedo, v_world_pos, triblend);
		albedo_rock *= sample_triplanar(texture_rock_albedo, v_world_pos, triblend);
		albedo_sand *= sample_triplanar(texture_sand_albedo, v_world_pos, triblend);
		albedo_snow *= sample_triplanar(texture_snow_albedo, v_world_pos, triblend);
	}

	// Apply biome tint to vegetation/grass
	albedo_grass.rgb *= biome_tint;

	// 3. Slope Blending (Vertical cliffs get rock)
	float slope = clamp(dot(v_world_normal, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float cliff_factor = 1.0 - smoothstep(slope_threshold - slope_blend_margin, slope_threshold + slope_blend_margin, slope);

	// 4. Elevation Blending (Lowlands = sand/beach, Highlands = snow)
	float beach_factor = 1.0 - smoothstep(beach_height - beach_blend_margin, beach_height + beach_blend_margin, v_world_pos.y);
	float snow_factor = smoothstep(snow_height - snow_blend_margin, snow_height + snow_blend_margin, v_world_pos.y);

	// Blend base flat layer: Grass -> Sand (low) and Grass -> Snow (high)
	vec4 flat_albedo = albedo_grass;
	float flat_roughness = grass_roughness;

	flat_albedo = mix(flat_albedo, albedo_sand, beach_factor);
	flat_roughness = mix(flat_roughness, sand_roughness, beach_factor);

	flat_albedo = mix(flat_albedo, albedo_snow, snow_factor);
	flat_roughness = mix(flat_roughness, snow_roughness, snow_factor);

	// Blend flat surface with steep cliff rock
	vec4 base_albedo = mix(flat_albedo, albedo_rock, cliff_factor);
	float base_roughness = mix(flat_roughness, rock_roughness, cliff_factor);

	// Blend with vertex colors if present (enables voxel palette compatibility)
	if (length(v_vertex_color.rgb) > 0.05) {
		base_albedo.rgb = mix(base_albedo.rgb, v_vertex_color.rgb, 0.6);
	}

	// 5. Terrain Splat Painting Overlay
	vec4 final_albedo = base_albedo;
	float final_roughness = base_roughness;

	if (use_splat_map) {
		vec2 splat_uv = (v_world_pos.xz - chunk_origin) / max(chunk_size_world, 0.001);
		splat_uv = clamp(splat_uv, vec2(0.0), vec2(1.0));
		vec4 splat = texture(splat_map, splat_uv);

		// Blend painted layers in order: R (dirt/path), G (sand/gravel), B (rock/cobble), A (snow/special)
		if (splat.r > 0.001) {
			final_albedo = mix(final_albedo, paint_layer_r_color, splat.r);
			final_roughness = mix(final_roughness, paint_layer_r_roughness, splat.r);
		}
		if (splat.g > 0.001) {
			final_albedo = mix(final_albedo, paint_layer_g_color, splat.g);
			final_roughness = mix(final_roughness, paint_layer_g_roughness, splat.g);
		}
		if (splat.b > 0.001) {
			final_albedo = mix(final_albedo, paint_layer_b_color, splat.b);
			final_roughness = mix(final_roughness, paint_layer_b_roughness, splat.b);
		}
		if (splat.a > 0.001) {
			final_albedo = mix(final_albedo, paint_layer_a_color, splat.a);
			final_roughness = mix(final_roughness, paint_layer_a_roughness, splat.a);
		}
	}

	// 6. Macro Variation (Anti-Tiling to break repetitive patterns)
	float macro_n = (noise2d(v_world_pos.xz * macro_variation_scale) - 0.5) * 2.0;
	final_albedo.rgb += final_albedo.rgb * (macro_n * macro_variation_strength);

	// Output PBR lighting channels
	ALBEDO = clamp(final_albedo.rgb, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.2;
}
