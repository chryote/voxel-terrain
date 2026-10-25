shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

/**
 * Stylized NPR Toon Water Spatial Shader (Graphic Novel / Moebius Aesthetic)
 * 1. Hard-edge intersection foam line via linearized depth buffer.
 * 2. Stepped depth color horizons (shallow, mid, deep bands) with zero gradients.
 * 3. Procedural cellular graphic ripple rings with hard binary thresholding.
 * 4. Unshaded flat shading with zero specular highlights or normal maps.
 */

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Foam_Settings;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_thickness : hint_range(0.02, 2.0) = 0.35;

group_uniforms Stepped_Depth_Colors;
uniform vec4 shallow_color : source_color = vec4(0.23, 0.64, 0.86, 0.85);
uniform vec4 mid_color : source_color = vec4(0.12, 0.38, 0.62, 0.90);
uniform vec4 deep_color : source_color = vec4(0.07, 0.16, 0.26, 0.95);
uniform float shallow_threshold : hint_range(0.2, 5.0) = 1.5;
uniform float deep_threshold : hint_range(1.0, 20.0) = 5.0;

group_uniforms Graphic_Ripples;
uniform bool ripples_enabled = true;
uniform float ripple_scale : hint_range(0.05, 1.0) = 0.25;
uniform float ripple_speed : hint_range(0.01, 1.0) = 0.08;
uniform float ripple_threshold : hint_range(0.01, 0.2) = 0.04;
uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 0.90);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Pseudo-random 2D hash for cellular noise
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

// 2D cellular (Voronoi) distance function
float cellular_distance(vec2 p) {
	vec2 i_pos = floor(p);
	vec2 f_pos = fract(p);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 pt = hash2(i_pos + neighbor);
			vec2 diff = neighbor + pt - f_pos;
			min_dist = min(min_dist, length(diff));
		}
	}
	return min_dist;
}

// Reconstructs linear metric depth in camera view space
float get_linear_scene_depth(vec2 screen_uv, mat4 inv_proj) {
	float raw_depth = textureLod(depth_texture, screen_uv, 0.0).r;
	if (raw_depth >= 0.99999) {
		return 10000.0;
	}
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view_pos = inv_proj * ndc;
	return -view_pos.z / max(abs(view_pos.w), 0.00001);
}

// Stepped discrete color horizons based on depth behind water surface
vec4 evaluate_stepped_depth(float depth_diff) {
	if (depth_diff < shallow_threshold) {
		return shallow_color;
	} else if (depth_diff < deep_threshold) {
		return mid_color;
	}
	return deep_color;
}

// Procedural dual-scrolling cellular ripple rings with hard binary cutoff
float evaluate_graphic_ripples(vec2 world_xz, float time) {
	vec2 uv1 = world_xz * ripple_scale + vec2(time * ripple_speed, time * ripple_speed * 0.7);
	vec2 uv2 = world_xz * (ripple_scale * 1.35) - vec2(time * ripple_speed * 0.85, -time * ripple_speed * 0.6);
	float d1 = cellular_distance(uv1);
	float d2 = cellular_distance(uv2);
	float ring1 = step(abs(d1 - 0.35), ripple_threshold);
	float ring2 = step(abs(d2 - 0.35), ripple_threshold);
	return max(ring1, ring2);
}

void fragment() {
	float scene_depth = get_linear_scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float water_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - water_depth, 0.0);

	// 1. Stepped depth color (discrete flat bands)
	vec4 col = evaluate_stepped_depth(depth_diff);

	// 2. Stylized surface noise / graphic ripple lines
	if (ripples_enabled) {
		float ripple_mask = evaluate_graphic_ripples(v_world_pos.xz, TIME);
		if (ripple_mask > 0.5) {
			col = mix(col, ripple_color, ripple_color.a);
		}
	}

	// 3. Hard-edge intersection foam line
	if (depth_diff < foam_thickness) {
		col = foam_color;
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
