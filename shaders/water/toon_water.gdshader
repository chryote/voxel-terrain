shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

/**
 * Stylized NPR Toon Water Spatial Shader (Moebius / Graphic Novel Aesthetic)
 * 1. Hard-edge depth intersection foam (toggleable for noise-free distant ocean).
 * 2. Stepped depth color horizons (shallow, mid, deep bands) with zero gradients.
 * 3. Pixelized blocky cellular ripples (Chebyshev/Manhattan metric, quantized grid).
 * 4. Animated downward-streaming fluid flow for vertical side faces.
 * 5. Unshaded flat shading with zero specular highlights or normal maps.
 */

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Foam_Settings;
uniform bool foam_enabled = true;
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
uniform float pixel_density : hint_range(1.0, 32.0) = 8.0;
uniform float ripple_scale : hint_range(0.05, 1.0) = 0.25;
uniform float ripple_speed : hint_range(0.01, 1.0) = 0.08;
uniform float ripple_threshold : hint_range(0.01, 0.25) = 0.06;
uniform vec4 ripple_color : source_color = vec4(1.0, 1.0, 1.0, 0.90);

group_uniforms Side_Face_Fluid;
uniform float side_fluid_speed : hint_range(0.5, 5.0) = 2.2;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Pseudo-random 2D hash for cellular noise
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

// Blocky/pixelized cellular distance function using Chebyshev-Manhattan metric
float cellular_distance(vec2 p) {
	vec2 i_pos = floor(p);
	vec2 f_pos = fract(p);
	float min_dist = 2.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 pt = hash2(i_pos + neighbor);
			vec2 diff = neighbor + pt - f_pos;
			float d = max(abs(diff.x), abs(diff.y)) + 0.35 * (abs(diff.x) + abs(diff.y));
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

// Reconstructs linear metric depth in camera view space
float get_linear_scene_depth(vec2 screen_uv, mat4 inv_proj) {
	float raw_depth = textureLod(depth_texture, screen_uv, 0.0).r;
	if (raw_depth >= 0.99999) return 10000.0;
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view_pos = inv_proj * ndc;
	return -view_pos.z / max(abs(view_pos.w), 0.00001);
}

// Stepped discrete color horizons based on depth behind water surface
vec4 evaluate_stepped_depth(float depth_diff) {
	if (depth_diff < shallow_threshold) return shallow_color;
	if (depth_diff < deep_threshold) return mid_color;
	return deep_color;
}

// Pixelized graphic ripples with Chebyshev-Manhattan metric and distance fade
float evaluate_graphic_ripples(vec2 world_xz, float time, float view_depth) {
	vec2 pix_xz = floor(world_xz * pixel_density) / pixel_density;
	vec2 uv1 = pix_xz * ripple_scale + vec2(time * ripple_speed, time * ripple_speed * 0.7);
	vec2 uv2 = pix_xz * (ripple_scale * 1.35) - vec2(time * ripple_speed * 0.85, -time * ripple_speed * 0.6);
	float d1 = cellular_distance(uv1);
	float d2 = cellular_distance(uv2);
	float ring1 = step(abs(d1 - 0.45), ripple_threshold);
	float ring2 = step(abs(d2 - 0.45), ripple_threshold);
	float dist_fade = clamp(1.0 - (view_depth - 15.0) / 35.0, 0.0, 1.0);
	return max(ring1, ring2) * dist_fade;
}

// Animated downward fluid streams for vertical side faces
float evaluate_side_fluid_flow(vec3 pos, vec3 norm, float time) {
	float horiz = (abs(norm.x) > abs(norm.z)) ? pos.z : pos.x;
	vec2 flow_coord = vec2(horiz * ripple_scale * 1.5, (pos.y - time * side_fluid_speed) * ripple_scale * 2.0);
	vec2 pix_flow = floor(flow_coord * pixel_density) / pixel_density;
	float stream = sin(pix_flow.x * 6.28 + sin(pix_flow.y * 3.14)) + cos(pix_flow.x * 3.14 - pix_flow.y * 5.0);
	return step(0.35, stream * 0.5);
}

void fragment() {
	float scene_depth = get_linear_scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float water_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - water_depth, 0.0);
	bool is_side = abs(v_world_normal.y) < 0.5;

	// 1. Stepped depth color (discrete flat bands)
	vec4 col = evaluate_stepped_depth(depth_diff);

	// 2. Surface ripples or downward fluid flow
	if (ripples_enabled) {
		if (is_side) {
			col = mix(col, shallow_color, 0.4);
			float fluid = evaluate_side_fluid_flow(v_world_pos, v_world_normal, TIME);
			if (fluid > 0.5) col = mix(col, ripple_color, ripple_color.a * 0.85);
		} else {
			float rip = evaluate_graphic_ripples(v_world_pos.xz, TIME, water_depth);
			if (rip > 0.5) col = mix(col, ripple_color, ripple_color.a);
		}
	}

	// 3. Hard-edge intersection foam line (if enabled)
	if (foam_enabled && depth_diff < foam_thickness) {
		col = foam_color;
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
