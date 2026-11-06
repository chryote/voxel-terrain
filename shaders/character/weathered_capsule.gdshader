shader_type spatial;
render_mode diffuse_toon, specular_disabled;

group_uniforms Capsule_Palette;
uniform vec4 base_color : source_color = vec4(0.82, 0.81, 0.79, 1.0);
uniform vec4 stain_dark : source_color = vec4(0.08, 0.06, 0.05, 0.85);
uniform vec4 stain_rust : source_color = vec4(0.48, 0.28, 0.12, 0.85);
uniform float drip_frequency : hint_range(4.0, 32.0) = 14.0;
uniform float stain_intensity : hint_range(0.0, 1.0) = 0.85;

group_uniforms Contact_AO;
uniform float contact_ao_intensity : hint_range(0.0, 1.0) = 0.90;
uniform float contact_ao_height : hint_range(0.05, 0.40) = 0.22;
uniform vec4 contact_crevice_color : source_color = vec4(0.04, 0.03, 0.03, 1.0);

group_uniforms Rim_And_Silhouette_Highlights;
uniform bool rim_highlight_enabled = true;
uniform vec4 rim_color : source_color = vec4(0.82, 0.86, 0.92, 1.0);
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.55;
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float upward_highlight_bias : hint_range(0.0, 1.0) = 0.70;

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

	// Ground contact crevice ambient occlusion grounding the capsule
	float contact_crevice = 1.0 - smoothstep(0.0, contact_ao_height, y_norm);
	col = mix(col, contact_crevice_color.rgb, contact_crevice * contact_ao_intensity);

	ALBEDO = col;
	AO = 1.0 - contact_crevice * contact_ao_intensity;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	float is_lit = step(0.25, n_dot_l);
	vec3 lit_color = ALBEDO * LIGHT_COLOR;

	if (rim_highlight_enabled) {
		float n_dot_v = max(dot(NORMAL, VIEW), 0.0);
		float rim = pow(1.0 - n_dot_v, rim_power);
		float top_factor = mix(1.0, clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0), upward_highlight_bias);
		float glint = rim * top_factor * n_dot_l;
		float is_rim = step(0.35, glint);
		lit_color = mix(lit_color, rim_color.rgb * LIGHT_COLOR * 1.3, is_rim * rim_intensity);
	}

	DIFFUSE_LIGHT += mix(ALBEDO * vec3(0.22, 0.23, 0.26), lit_color, is_lit);
}
