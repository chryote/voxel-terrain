shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

/**
 * Stylized NPR Toon Grass Spatial Shader (Graphic Novel / Moebius Aesthetic)
 * Features:
 * - Double-sided cross-quad foliage rendering with alpha scissor cutout.
 * - Vertex wind sway modulated by normalized height (1.0 - UV.y).
 * - Screen-space 4x4 Bayer matrix dither dissolve between distance_fade_start and distance_fade_max.
 * - Quantized cel-lighting matching terrain halftone/ASCII visual stack.
 */

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_scissor_threshold : hint_range(0.05, 0.95) = 0.5;

group_uniforms Wind_Settings;
uniform bool wind_enabled = true;
uniform float wind_speed : hint_range(0.1, 5.0) = 1.8;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.08;
uniform float wind_turbulence : hint_range(0.1, 4.0) = 1.2;

group_uniforms Distance_Fade;
uniform bool distance_fade_enabled = true;
uniform float distance_fade_start : hint_range(10.0, 150.0) = 45.0;
uniform float distance_fade_max : hint_range(20.0, 200.0) = 60.0;

group_uniforms Cel_Lighting;
uniform float lit_threshold : hint_range(0.0, 1.0) = 0.35;
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.24, 0.32, 1.0);

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
		float height_factor = clamp(1.0 - UV.y, 0.0, 1.0);
		float wave = sin(TIME * wind_speed + v_world_pos.x * 0.8 + v_world_pos.z * 0.6)
		           + 0.5 * cos(TIME * wind_speed * wind_turbulence + v_world_pos.x * 1.3 - v_world_pos.z * 0.9);
		VERTEX.x += wave * wind_strength * height_factor;
		VERTEX.z += wave * wind_strength * 0.6 * height_factor;
	}
}

void fragment() {
	vec4 tex_col = texture(albedo_texture, UV);
	vec4 col = tex_col * COLOR * albedo_tint;

	if (col.a < alpha_scissor_threshold) {
		discard;
	}

	if (distance_fade_enabled && v_camera_dist > distance_fade_start) {
		float fade = clamp((v_camera_dist - distance_fade_start) / max(0.001, distance_fade_max - distance_fade_start), 0.0, 1.0);
		if (get_bayer_4x4(FRAGCOORD.xy) < fade) {
			discard;
		}
	}

	ALBEDO = col.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = step(lit_threshold, NdotL * ATTENUATION);
	vec3 light_color = mix(shadow_tint.rgb, LIGHT_COLOR.rgb, lit);
	DIFFUSE_LIGHT += ALBEDO * light_color;
}

