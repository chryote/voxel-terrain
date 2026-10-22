shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

/**
 * Animated Water Shader with wave displacement, normal ripple animation,
 * fresnel absorption, and depth-based color gradients.
 */

uniform vec4 shallow_color : source_color = vec4(0.18, 0.55, 0.72, 0.85);
uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.42, 0.95);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 0.8);

uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.15;
uniform float wave_frequency : hint_range(0.05, 1.0) = 0.25;

uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;
uniform float fresnel_power : hint_range(1.0, 10.0) = 4.0;

varying vec3 v_world_pos;
varying vec3 v_view_dir;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Gentle wave displacement
	float wave1 = sin(v_world_pos.x * wave_frequency + TIME * wave_speed);
	float wave2 = cos(v_world_pos.z * wave_frequency * 0.8 + TIME * wave_speed * 1.2);
	VERTEX.y += (wave1 + wave2) * wave_amplitude;
}

void fragment() {
	// Normal ripple calculation using procedural sine derivatives
	vec2 uv_anim = v_world_pos.xz * 0.5 + vec2(TIME * 0.05 * wave_speed, TIME * 0.03 * wave_speed);
	float ripple_x = sin(uv_anim.x * 6.0) * cos(uv_anim.y * 6.0) * 0.1;
	float ripple_z = cos(uv_anim.x * 5.0) * sin(uv_anim.y * 5.0) * 0.1;
	NORMAL = normalize(NORMAL + vec3(ripple_x, 0.0, ripple_z));

	// Fresnel factor
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	// Blend deep and shallow water
	vec3 water_rgb = mix(deep_color.rgb, shallow_color.rgb, fresnel * 0.7 + 0.3);
	water_rgb = mix(water_rgb, foam_color.rgb, fresnel * 0.3);

	ALBEDO = water_rgb;
	ALPHA = mix(deep_color.a, shallow_color.a, fresnel);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.5;
}
