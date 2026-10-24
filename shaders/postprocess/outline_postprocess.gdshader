shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

/**
 * Outline Post-Processing Spatial Shader (Graphic Novel / Moebius Aesthetic)
 * Fullscreen NDC quad shader detecting discontinuities in depth and surface normals
 * to render crisp comic-book ink outlines over voxel geometry.
 */

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms Outline_Settings;
uniform bool outlines_enabled = true;
uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform float outline_thickness : hint_range(0.5, 4.0) = 1.0;
uniform float depth_threshold : hint_range(0.0001, 0.2) = 0.02;
uniform float normal_threshold : hint_range(0.05, 1.5) = 0.35;

void vertex() {
	// Project quad directly to span viewport in Normalized Device Coordinates
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Converts raw depth buffer value into linear camera distance in metric units
float get_linear_depth(vec2 uv, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, uv).r;
	vec4 ndc = vec4(uv * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view = inv_proj * ndc;
	return -view.z / max(abs(view.w), 0.0001);
}

// Evaluates depth delta relative to camera distance
float evaluate_depth_edge(float center_d, float sample_d) {
	return abs(center_d - sample_d) / max(center_d, 0.1);
}

// Evaluates surface normal angle divergence
float evaluate_normal_edge(vec3 center_n, vec3 sample_n) {
	return length(center_n - sample_n);
}

void fragment() {
	if (!outlines_enabled) {
		discard;
	}

	vec2 ps = (1.0 / VIEWPORT_SIZE) * outline_thickness;
	vec2 uv = SCREEN_UV;

	float center_raw_depth = texture(depth_texture, uv).r;
	float center_depth = get_linear_depth(uv, INV_PROJECTION_MATRIX);
	vec3 center_normal = texture(normal_roughness_texture, uv).rgb * 2.0 - 1.0;

	// In Godot 4, raw depth >= 0.99999 corresponds to the unwritten far-plane skybox
	bool center_is_sky = (center_raw_depth >= 0.99999);

	vec2 uvs[4];
	uvs[0] = uv + vec2(0.0, ps.y);  // North
	uvs[1] = uv + vec2(0.0, -ps.y); // South
	uvs[2] = uv + vec2(ps.x, 0.0);  // East
	uvs[3] = uv + vec2(-ps.x, 0.0); // West

	float depth_diff = 0.0;
	float normal_diff = 0.0;

	for (int i = 0; i < 4; i++) {
		float d_raw = texture(depth_texture, uvs[i]).r;
		bool neighbor_is_sky = (d_raw >= 0.99999);

		if (center_is_sky) {
			if (!neighbor_is_sky) {
				depth_diff += 1.0; // Silhouette outline against sky
			}
		} else {
			if (neighbor_is_sky) {
				depth_diff += 1.0; // Silhouette outline against sky
			} else {
				float d = get_linear_depth(uvs[i], INV_PROJECTION_MATRIX);
				depth_diff += evaluate_depth_edge(center_depth, d);
				vec3 n = texture(normal_roughness_texture, uvs[i]).rgb * 2.0 - 1.0;
				normal_diff += evaluate_normal_edge(center_normal, n);
			}
		}
	}

	// Trigger ink line if depth or normal delta exceeds threshold
	if (depth_diff > depth_threshold || normal_diff > normal_threshold) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	} else {
		discard;
	}
}
