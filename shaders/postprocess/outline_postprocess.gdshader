shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

/**
 * Outline Post-Processing Spatial Shader (Graphic Novel / Moebius Aesthetic)
 * Fullscreen NDC quad shader using 2nd-order Laplacian depth edge detection
 * and normal divergence with distance-aware fade to prevent grazing-angle ink blots.
 */

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms Outline_Settings;
uniform bool outlines_enabled = true;
uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform float outline_thickness : hint_range(0.5, 4.0) = 1.2;
uniform float depth_threshold : hint_range(0.001, 0.5) = 0.05;
uniform float normal_threshold : hint_range(0.05, 1.5) = 0.40;

group_uniforms Distance_Fade;
uniform float outline_fade_start : hint_range(10.0, 200.0) = 45.0;
uniform float max_outline_distance : hint_range(20.0, 500.0) = 150.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Converts raw depth buffer value into linear camera distance in metric units
float get_linear_depth(vec2 uv, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, uv).r;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view = inv_proj * ndc;
	return -view.z / max(abs(view.w), 0.0001);
}

// 2nd-order Laplacian depth evaluation across opposing pairs (immune to grazing angle slope)
float evaluate_depth_edge(float d_c, float d_p1, float d_p2) {
	return abs(d_p1 + d_p2 - 2.0 * d_c) / max(d_c, 0.1);
}

// Surface normal divergence between opposing pairs
float evaluate_normal_edge(vec3 n_p1, vec3 n_p2) {
	return length(n_p1 - n_p2);
}

void fragment() {
	if (!outlines_enabled) {
		discard;
	}

	vec2 ps = (1.0 / VIEWPORT_SIZE) * outline_thickness;
	vec2 uv = SCREEN_UV;

	float center_raw_depth = texture(depth_texture, uv).r;
	float center_depth = get_linear_depth(uv, INV_PROJECTION_MATRIX);

	// In Godot 4, raw depth >= 0.99999 corresponds to the unwritten far-plane skybox
	bool center_is_sky = (center_raw_depth >= 0.99999);

	// Sample opposing neighbor coordinates
	vec2 uv_up    = uv + vec2(0.0, ps.y);
	vec2 uv_down  = uv - vec2(0.0, ps.y);
	vec2 uv_right = uv + vec2(ps.x, 0.0);
	vec2 uv_left  = uv - vec2(ps.x, 0.0);

	float raw_up    = texture(depth_texture, uv_up).r;
	float raw_down  = texture(depth_texture, uv_down).r;
	float raw_right = texture(depth_texture, uv_right).r;
	float raw_left  = texture(depth_texture, uv_left).r;

	bool sky_up    = (raw_up >= 0.99999);
	bool sky_down  = (raw_down >= 0.99999);
	bool sky_right = (raw_right >= 0.99999);
	bool sky_left  = (raw_left >= 0.99999);

	// Check if this pixel is a silhouette boundary against the sky
	bool is_sky_silhouette = false;
	if (center_is_sky) {
		if (!sky_up || !sky_down || !sky_right || !sky_left) {
			is_sky_silhouette = true;
		}
	} else {
		if (sky_up || sky_down || sky_right || sky_left) {
			is_sky_silhouette = true;
		}
	}

	if (is_sky_silhouette) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	} else if (center_is_sky) {
		discard;
	} else {
		float d_up    = get_linear_depth(uv_up, INV_PROJECTION_MATRIX);
		float d_down  = get_linear_depth(uv_down, INV_PROJECTION_MATRIX);
		float d_right = get_linear_depth(uv_right, INV_PROJECTION_MATRIX);
		float d_left  = get_linear_depth(uv_left, INV_PROJECTION_MATRIX);

		// 2nd-order Laplacian: evaluates curvature/step, exactly 0.0 on flat slopes at grazing angles
		float lap_v = evaluate_depth_edge(center_depth, d_up, d_down);
		float lap_h = evaluate_depth_edge(center_depth, d_right, d_left);
		float depth_edge = max(lap_v, lap_h);

		// Opposing normal divergence
		vec3 n_up    = texture(normal_roughness_texture, uv_up).rgb * 2.0 - 1.0;
		vec3 n_down  = texture(normal_roughness_texture, uv_down).rgb * 2.0 - 1.0;
		vec3 n_right = texture(normal_roughness_texture, uv_right).rgb * 2.0 - 1.0;
		vec3 n_left  = texture(normal_roughness_texture, uv_left).rgb * 2.0 - 1.0;

		float norm_v = evaluate_normal_edge(n_up, n_down);
		float norm_h = evaluate_normal_edge(n_right, n_left);
		float normal_edge = max(norm_v, norm_h);

		// Distance attenuation: soften interior block creases at long range so distant terrain colors shine
		float dist_fade = clamp(1.0 - (center_depth - outline_fade_start) / max(max_outline_distance - outline_fade_start, 1.0), 0.0, 1.0);

		// Foreground thresholding with distance weighting
		bool is_depth_edge = (depth_edge > depth_threshold);
		bool is_normal_edge = (normal_edge > normal_threshold) && (dist_fade > 0.0);

		if (is_depth_edge || is_normal_edge) {
			float alpha_weight = (is_depth_edge) ? 1.0 : dist_fade;
			ALBEDO = outline_color.rgb;
			ALPHA = outline_color.a * alpha_weight;
		} else {
			discard;
		}
	}
}
