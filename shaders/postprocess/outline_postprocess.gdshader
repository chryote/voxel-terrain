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
float get_linear_depth(ivec2 coord, mat4 inv_proj) {
	float raw_depth = texelFetch(depth_texture, coord, 0).r;
	vec4 ndc = vec4(0.0, 0.0, raw_depth, 1.0);
	vec4 view = inv_proj * ndc;
	return -view.z / max(abs(view.w), 0.0001);
}

// 2nd-order Laplacian depth evaluation across opposing pairs (evaluates to 0.0 on flat slopes)
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

	ivec2 p = ivec2(FRAGCOORD.xy);
	ivec2 vp_size = ivec2(VIEWPORT_SIZE);
	int r = max(int(round(outline_thickness)), 1);

	float center_raw_depth = texelFetch(depth_texture, p, 0).r;
	if (center_raw_depth >= 0.99999) {
		// Outlines are drawn on the interior boundary of geometry, never into the sky
		discard;
	}

	// Integer pixel offsets clamped strictly within viewport bounds to guarantee symmetric arms
	ivec2 p_up    = clamp(p + ivec2(0, r), ivec2(0), vp_size - ivec2(1));
	ivec2 p_down  = clamp(p - ivec2(0, r), ivec2(0), vp_size - ivec2(1));
	ivec2 p_right = clamp(p + ivec2(r, 0), ivec2(0), vp_size - ivec2(1));
	ivec2 p_left  = clamp(p - ivec2(r, 0), ivec2(0), vp_size - ivec2(1));

	float raw_up    = texelFetch(depth_texture, p_up, 0).r;
	float raw_down  = texelFetch(depth_texture, p_down, 0).r;
	float raw_right = texelFetch(depth_texture, p_right, 0).r;
	float raw_left  = texelFetch(depth_texture, p_left, 0).r;

	// Check if neighboring taps are sky, requiring 2-pixel depth to reject single-pixel rasterization gaps
	bool sky_up    = (raw_up >= 0.99999)    && (texelFetch(depth_texture, clamp(p + ivec2(0, 2 * r), ivec2(0), vp_size - ivec2(1)), 0).r >= 0.99999);
	bool sky_down  = (raw_down >= 0.99999)  && (texelFetch(depth_texture, clamp(p - ivec2(0, 2 * r), ivec2(0), vp_size - ivec2(1)), 0).r >= 0.99999);
	bool sky_right = (raw_right >= 0.99999) && (texelFetch(depth_texture, clamp(p + ivec2(2 * r, 0), ivec2(0), vp_size - ivec2(1)), 0).r >= 0.99999);
	bool sky_left  = (raw_left >= 0.99999)  && (texelFetch(depth_texture, clamp(p - ivec2(2 * r, 0), ivec2(0), vp_size - ivec2(1)), 0).r >= 0.99999);

	bool is_sky_silhouette = (sky_up || sky_down || sky_right || sky_left);

	if (is_sky_silhouette) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	} else {
		float center_depth = get_linear_depth(p, INV_PROJECTION_MATRIX);
		float d_up    = get_linear_depth(p_up, INV_PROJECTION_MATRIX);
		float d_down  = get_linear_depth(p_down, INV_PROJECTION_MATRIX);
		float d_right = get_linear_depth(p_right, INV_PROJECTION_MATRIX);
		float d_left  = get_linear_depth(p_left, INV_PROJECTION_MATRIX);

		// 2nd-order Laplacian evaluates curvature/step across perfectly symmetric integer taps
		float lap_v = evaluate_depth_edge(center_depth, d_up, d_down);
		float lap_h = evaluate_depth_edge(center_depth, d_right, d_left);
		float depth_edge = max(lap_v, lap_h);

		// Opposing normal divergence
		vec3 n_up    = texelFetch(normal_roughness_texture, p_up, 0).rgb * 2.0 - 1.0;
		vec3 n_down  = texelFetch(normal_roughness_texture, p_down, 0).rgb * 2.0 - 1.0;
		vec3 n_right = texelFetch(normal_roughness_texture, p_right, 0).rgb * 2.0 - 1.0;
		vec3 n_left  = texelFetch(normal_roughness_texture, p_left, 0).rgb * 2.0 - 1.0;

		float norm_v = evaluate_normal_edge(n_up, n_down);
		float norm_h = evaluate_normal_edge(n_right, n_left);
		float normal_edge = max(norm_v, norm_h);

		// Distance attenuation: soften interior block creases at long range
		float dist_fade = clamp(1.0 - (center_depth - outline_fade_start) / max(max_outline_distance - outline_fade_start, 1.0), 0.0, 1.0);

		// Block creases have large normal divergence (> normal_threshold).
		// On flat surfaces with continuous normals (normal_edge < 0.12), depth edge is suppressed
		// unless there is a true major occlusion drop-off step (> depth_threshold * 2.5),
		// completely eliminating 1-pixel fireflies/specks caused by sub-pixel rasterization.
		bool is_normal_edge = (normal_edge > normal_threshold) && (dist_fade > 0.0);
		bool is_depth_edge = (depth_edge > depth_threshold) && (dist_fade > 0.0) && (normal_edge > 0.12 || depth_edge > (depth_threshold * 2.5));

		if (is_normal_edge || is_depth_edge) {
			float alpha_weight = (is_depth_edge) ? 1.0 : dist_fade;
			ALBEDO = outline_color.rgb;
			ALPHA = outline_color.a * alpha_weight;
		} else {
			discard;
		}
	}
}
