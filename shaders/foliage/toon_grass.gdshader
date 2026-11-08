shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

/**
 * Stylized NPR Toon Grass Spatial Shader (Pixel Art / Graphic Novel Aesthetic)
 * Features:
 * - Double-sided cross-quad foliage rendering with alpha scissor cutout.
 * - Quantized pixel-art vertex wind sway in stepped frame ticks.
 * - Screen-space 4x4 Bayer matrix dither dissolve and cel-lighting on pixel grid.
 * - Stepped pixel palette color grading with nearest-neighbor texture sampling.
 */

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(0.58, 0.27, 0.22, 1.0);
uniform float alpha_scissor_threshold : hint_range(0.05, 0.95) = 0.5;

group_uniforms Wind_Settings;
uniform bool wind_enabled = true;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.8;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform float wind_turbulence : hint_range(0.1, 4.0) = 1.2;

group_uniforms Distance_Fade;
uniform bool distance_fade_enabled = true;
uniform float distance_fade_start : hint_range(10.0, 1000.0, 5.0) = 45.0;
uniform float distance_fade_max : hint_range(20.0, 1200.0, 5.0) = 60.0;

group_uniforms Cel_Lighting;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.35;
uniform vec4 shadow_tint : source_color = vec4(0.20, 0.13, 0.14, 1.0);
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;

varying vec3 v_world_pos;
varying float v_camera_dist;

// Evaluates 4x4 Bayer dither threshold matrix [0.0..1.0]
float get_bayer_4x4(vec2 screen_coord) {
	ivec2 p = ivec2(mod(screen_coord, 4.0));
	int index = p.x + p.y * 4;
	const float bayer[16] = float[16](
		 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return bayer[index];
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_camera_dist = length(v_world_pos - CAMERA_POSITION_WORLD);

	if (wind_enabled) {
		float height_factor = floor(clamp(1.0 - UV.y, 0.0, 1.0) * 4.0 + 0.5) * 0.25;
		float stepped_time = floor(TIME * 8.0) * 0.125;
		float wave = sin(stepped_time * wind_speed + v_world_pos.x * 0.8 + v_world_pos.z * 0.6)
		           + 0.5 * cos(stepped_time * wind_speed * wind_turbulence + v_world_pos.x * 1.3 - v_world_pos.z * 0.9);
		wave = floor(wave * 8.0) * 0.125;
		VERTEX.x += wave * wind_strength * height_factor;
		VERTEX.z += wave * wind_strength * 0.6 * height_factor;
	}
}

void fragment() {
	vec2 uv_pix = floor(UV * 64.0) / 64.0;
	vec4 tex_col = texture(albedo_texture, uv_pix);
	float alpha = tex_col.a * COLOR.a * albedo_tint.a;

	if (alpha < alpha_scissor_threshold) {
		discard;
	}

	if (distance_fade_enabled && v_camera_dist > distance_fade_start) {
		float fade = clamp((v_camera_dist - distance_fade_start) / max(0.001, distance_fade_max - distance_fade_start), 0.0, 1.0);
		vec2 p_dither = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
		if (get_bayer_4x4(p_dither) < fade) {
			discard;
		}
	}

	float height = floor(clamp(1.0 - uv_pix.y, 0.0, 1.0) * 4.0 + 0.5) * 0.25;
	float tone = clamp(dot(tex_col.rgb * COLOR.rgb, vec3(0.25, 0.65, 0.10)) * 1.55, 0.0, 1.0);
	tone = floor(tone * 4.0 + 0.5) * 0.25;
	vec3 root_decay = albedo_tint.rgb * vec3(0.52, 0.42, 0.44);
	vec3 tip_decay = albedo_tint.rgb * vec3(1.18, 0.95, 0.88);
	vec3 tint_ramp = mix(root_decay, tip_decay, height);
	ALBEDO = clamp(mix(tint_ramp * tone, tex_col.rgb * (tint_ramp * 1.8), 0.55), 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	vec2 pixel_coord = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
	float dither = get_bayer_4x4(pixel_coord);
	float NdotL = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float lit_transition = clamp((NdotL - (lit_threshold - 0.12)) / 0.24, 0.0, 1.0);
	float lit = (lit_transition > dither) ? 1.0 : 0.0;
	vec3 light_color = mix(shadow_tint.rgb, LIGHT_COLOR.rgb, lit);
	DIFFUSE_LIGHT += ALBEDO * light_color;
}
