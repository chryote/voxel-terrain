shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.82, 0.81, 0.79, 1.0);
uniform vec4 stain_dark : source_color = vec4(0.08, 0.06, 0.05, 0.85);
uniform vec4 stain_rust : source_color = vec4(0.48, 0.28, 0.12, 0.85);
uniform float drip_frequency : hint_range(4.0, 32.0) = 14.0;
uniform float stain_intensity : hint_range(0.0, 1.0) = 0.85;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float angle = atan(v_local_pos.z, v_local_pos.x);
	float drip_seed = sin(angle * drip_frequency + sin(angle * 2.0)) * 0.5 + 0.5;
	float streak = pow(drip_seed, 2.8);
	float y_norm = clamp((v_local_pos.y + 0.9) / 1.8, 0.0, 1.0);
	float drip_mask = streak * smoothstep(0.05, 0.85, y_norm) * (0.35 + 0.65 * sin(angle * 2.7 + 0.8));
	
	float taint_mix = clamp(1.0 - smoothstep(0.4, 0.75, drip_mask), 0.0, 1.0);
	vec3 stain_col = mix(stain_dark.rgb, stain_rust.rgb, taint_mix);
	vec3 col = mix(base_color.rgb, stain_col, smoothstep(0.22, 0.55, drip_mask) * stain_intensity);
	
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

