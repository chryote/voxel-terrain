shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

/**
 * Studio Ghibli Painterly Terrain Shader
 *
 * Implements:
 * 1. Soft-Banded Cel Shader (Custom Lighting Model with watercolor terminator smoothing)
 * 2. Tinted Ambient Shadows (Cool lavender/sky blue/teal unlit zones)
 * 3. Triplanar Mapping with 3D Macro-Noise Hue & Saturation variation
 * 4. Elevation-Based Color Gradients (Cool/dark valleys, warm/bright peaks)
 * 5. Directional Rim Lighting (Fresnel halo modulated by sun direction)
 * + Full backward compatibility with Splat Painting, Biomes, and Voxel Palettes.
 */

// --- Triplanar & Projection Settings ---
uniform float triplanar_scale : hint_range(0.01, 2.0) = 0.2;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// --- Slope / Cliff Blending ---
uniform float slope_threshold : hint_range(0.1, 0.95) = 0.70;
uniform float slope_blend_margin : hint_range(0.01, 0.5) = 0.15;

// --- Elevation Layer Blending ---
uniform float beach_height = 25.0;
uniform float beach_blend_margin = 3.0;
uniform float snow_height = 140.0;
uniform float snow_blend_margin = 15.0;

// --- Macro Anti-Tiling & Hue/Sat Brush Variation ---
uniform float macro_variation_strength : hint_range(0.0, 0.5) = 0.10;
uniform float macro_variation_scale : hint_range(0.001, 0.1) = 0.012;
uniform float macro_hue_shift : hint_range(0.0, 0.2) = 0.05;
uniform float macro_saturation_shift : hint_range(0.0, 0.3) = 0.10;

// --- Elevation-Based Color Gradients (Depth & Scale) ---
uniform float gradient_valley_y = 25.0;
uniform float gradient_peak_y = 135.0;
uniform vec4 gradient_valley_tint : source_color = vec4(0.85, 0.88, 0.98, 1.0); // Cooler, slightly darker
uniform vec4 gradient_peak_tint : source_color = vec4(1.08, 1.04, 0.95, 1.0);   // Warmer, brighter
uniform float gradient_strength : hint_range(0.0, 1.0) = 0.45;

// --- Soft-Banded Cel Shading & Custom Lighting ---
uniform bool cel_enabled = true;
uniform float cel_shadow_threshold : hint_range(0.05, 0.70) = 0.35;
uniform float cel_highlight_threshold : hint_range(0.40, 0.95) = 0.72;
uniform float cel_softness : hint_range(0.01, 0.30) = 0.08;

// --- Tinted Ambient Shadows & Light Tints ---
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.46, 0.65, 1.0);    // Vibrant cool lavender / sky blue
uniform vec4 midtone_tint : source_color = vec4(1.0, 0.98, 0.95, 1.0);   // Neutral-warm light
uniform vec4 highlight_tint : source_color = vec4(1.15, 1.10, 0.95, 1.0);// Warm golden sun
uniform float shadow_ambient_intensity : hint_range(0.0, 1.0) = 0.45;

// --- Directional Rim Lighting (Fresnel) ---
uniform bool rim_enabled = true;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.80, 1.0);      // Warm golden glowing outline
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.45;

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

// --- Procedural 3D Noise for Painterly Variations ---
float hash31(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.12));
	p += dot(p, p + 45.32);
	return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

// Color space conversion for painterly hue & saturation shifting
vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
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

	// 4. Elevation Layer Blending (Lowlands = sand/beach, Highlands = snow)
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

	// 6. Elevation-Based Color Gradient (Faking depth & atmospheric scale)
	float elev_norm = clamp((v_world_pos.y - gradient_valley_y) / max(gradient_peak_y - gradient_valley_y, 0.001), 0.0, 1.0);
	float elev_curve = smoothstep(0.0, 1.0, elev_norm);
	vec3 elev_tint = mix(gradient_valley_tint.rgb, gradient_peak_tint.rgb, elev_curve);
	final_albedo.rgb = mix(final_albedo.rgb, final_albedo.rgb * elev_tint, gradient_strength);

	// 7. Macro-Noise Brush Variation (Hue & Saturation shifting across vast distances)
	vec3 p_noise = v_world_pos * macro_variation_scale;
	float n_hue = (noise3d(p_noise) - 0.5) * 2.0;
	float n_sat = (noise3d(p_noise + vec3(127.1, 311.7, 74.3)) - 0.5) * 2.0;
	float n_val = (noise3d(p_noise + vec3(269.5, 183.3, 419.1)) - 0.5) * 2.0;

	vec3 hsv = rgb_to_hsv(final_albedo.rgb);
	hsv.x = fract(hsv.x + n_hue * macro_hue_shift);
	hsv.y = clamp(hsv.y + n_sat * macro_saturation_shift, 0.0, 1.0);
	hsv.z = clamp(hsv.z + n_val * macro_variation_strength, 0.0, 1.0);
	final_albedo.rgb = hsv_to_rgb(hsv);

	// Output PBR lighting channels
	// Output PBR lighting channels (matte painterly finish)
	ALBEDO = clamp(final_albedo.rgb, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	if (!cel_enabled) {
		float NdotL = max(dot(NORMAL, LIGHT), 0.0);
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * NdotL * ATTENUATION;
	} else {
		// 1. Soft-Banded Cel Lighting with Half-Lambert wrapping
		float NdotL = dot(NORMAL, LIGHT);
		float half_lambert = clamp(NdotL * 0.5 + 0.5, 0.0, 1.0);
		float light_intensity = half_lambert * ATTENUATION;

		// Soft watercolor transitions between Shadow -> Midtone and Midtone -> Highlight
		float shadow_band = smoothstep(cel_shadow_threshold - cel_softness, cel_shadow_threshold + cel_softness, light_intensity);
		float highlight_band = smoothstep(cel_highlight_threshold - cel_softness, cel_highlight_threshold + cel_softness, light_intensity);

		// 2. Tinted Ambient Shadows
		// Unlit areas receive a cool saturated tint (lavender/sky blue/teal) instead of default engine gray
		vec3 band_mix = mix(shadow_tint.rgb * shadow_ambient_intensity, midtone_tint.rgb, shadow_band);
		band_mix = mix(band_mix, highlight_tint.rgb, highlight_band);

		// Multiply by ALBEDO to preserve grass, rock, dirt, sand, and macro variations
		vec3 diffuse = ALBEDO * band_mix * LIGHT_COLOR;

		// 5. Directional Rim Lighting (Fresnel)
		// Masked to vertical block steps, ridges, and cliff edges so flat ground isn't washed out
		if (rim_enabled) {
			float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
			float fresnel = pow(1.0 - NdotV, rim_power);

			// Directional alignment: light wrapping around sun-facing edges
			float dir_align = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0) * ATTENUATION;

			// Edge mask: voxel steps, cliffs, and ridges (avoids flat top ground washout)
			float edge_mask = 1.0 - clamp(abs(v_world_normal.y), 0.0, 1.0);

			float rim = fresnel * dir_align * edge_mask * rim_strength;

			// Add golden rim glow tinted by material albedo for organic painted warmth
			diffuse += ALBEDO * rim_color.rgb * LIGHT_COLOR * rim;
		}

		DIFFUSE_LIGHT += diffuse;
	}
}
