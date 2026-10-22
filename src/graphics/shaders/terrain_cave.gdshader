shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

/**
 * Subterranean Cave & Chasm Shader with damp basalt, crystalline emission,
 * and triplanar rock textures.
 */

uniform vec4 rock_color : source_color = vec4(0.18, 0.19, 0.20, 1.0);     // #2e3033
uniform vec4 basalt_color : source_color = vec4(0.12, 0.13, 0.14, 1.0);   // #1e2022
uniform vec4 crystal_color : source_color = vec4(0.26, 0.78, 0.82, 1.0);  // #42c8d2
uniform float crystal_emission_energy : hint_range(0.0, 5.0) = 1.8;
uniform float wetness : hint_range(0.0, 1.0) = 0.35;
uniform float triplanar_scale : hint_range(0.01, 1.0) = 0.15;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vertex_color = COLOR;
}

void fragment() {
	vec3 blend_weights = pow(abs(v_world_normal), vec3(3.0));
	blend_weights /= max(blend_weights.x + blend_weights.y + blend_weights.z, 0.0001);

	// Base basalt/rock gradient
	vec3 base_col = mix(rock_color.rgb, basalt_color.rgb, 0.5);

	// Check if vertex color indicates crystals or glowing veins
	bool is_crystal = (v_vertex_color.b > 0.6 && v_vertex_color.r < 0.4);
	if (length(v_vertex_color.rgb) > 0.05) {
		base_col = mix(base_col, v_vertex_color.rgb, 0.75);
	}

	ALBEDO = base_col;
	ROUGHNESS = mix(0.85, 0.3, wetness);
	METALLIC = 0.05;

	// Crystal emission
	if (is_crystal) {
		EMISSION = crystal_color.rgb * crystal_emission_energy;
		ROUGHNESS = 0.2;
	} else {
		EMISSION = vec3(0.0);
	}
}
