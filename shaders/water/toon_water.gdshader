shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

/** Stylized NPR Toon Water Spatial Shader (Moebius / Graphic Novel Aesthetic) */
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms Foam_Settings;
uniform bool foam_enabled = true;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_thickness : hint_range(0.02, 2.0) = 0.35;

group_uniforms Stepped_Depth_Colors;
uniform vec4 shallow_color : source_color = vec4(0.34, 0.72, 0.73, 0.85);
uniform vec4 mid_color : source_color = vec4(0.18, 0.48, 0.68, 0.90);
uniform vec4 deep_color : source_color = vec4(0.08, 0.18, 0.32, 0.95);
uniform float shallow_threshold : hint_range(0.2, 5.0) = 1.5;
uniform float deep_threshold : hint_range(1.0, 20.0) = 5.0;

group_uniforms Graphic_Ripples;
uniform bool ripples_enabled = true;
uniform float pixel_density : hint_range(1.0, 32.0) = 8.0;
uniform float ripple_scale : hint_range(0.01, 1.0) = 0.08;
uniform float ripple_radius : hint_range(0.1, 1.2) = 0.65;
uniform float ripple_speed : hint_range(0.01, 1.0) = 0.08;
uniform float ripple_threshold : hint_range(0.01, 0.25) = 0.05;
uniform vec4 ripple_color : source_color = vec4(0.42, 0.68, 0.85, 0.55);

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

// Organic cellular edge distance with smooth Euclidean metric
float cellular_distance(vec2 p) {
	vec2 i_pos = floor(p), f_pos = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 diff = n + hash2(i_pos + n) - f_pos;
			float d = length(diff);
			if (d < d1) { d2 = d1; d1 = d; }
			else if (d < d2) { d2 = d; }
		}
	}
	return (d2 - d1);
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

// Procedural anime water caustics with pixelized grid & optical shadow
vec2 evaluate_graphic_ripples(vec2 world_xz, float time, float view_depth) {
	vec2 p = floor(world_xz * pixel_density) / pixel_density;
	vec2 w1 = vec2(sin(p.y * ripple_scale * 3.5 + time * 0.8), cos(p.x * ripple_scale * 3.5 + time * 0.6)) * (0.22 * ripple_radius);
	vec2 uv1 = p * ripple_scale + w1 + vec2(time * ripple_speed, time * ripple_speed * 0.7);
	float sc2 = ripple_scale * 1.5;
	vec2 w2 = vec2(cos(p.y * sc2 * 3.0 - time * 0.7), sin(p.x * sc2 * 3.0 + time * 0.9)) * (0.18 * ripple_radius);
	vec2 uv2 = p * sc2 + w2 - vec2(time * ripple_speed * 0.85, -time * ripple_speed * 0.65);
	float c = min(cellular_distance(uv1), cellular_distance(uv2) * 1.15);
	float sc = min(cellular_distance(uv1 + vec2(0.06, 0.08)), cellular_distance(uv2 + vec2(0.06, 0.08)) * 1.15);
	float dist_fade = clamp(1.0 - (view_depth - 15.0) / 35.0, 0.0, 1.0);
	float hi = step(c, ripple_threshold) * dist_fade;
	float sh = step(sc, ripple_threshold * 1.15) * (1.0 - step(c, ripple_threshold * 0.8)) * dist_fade;
	return vec2(hi, sh);
}

// Animated downward fluid streams for vertical side faces (jagged thick sine bands)
float evaluate_side_fluid_flow(vec3 pos, vec3 norm, float time) {
	float horiz = (abs(norm.x) > abs(norm.z)) ? pos.z : pos.x;
	vec2 pix = floor(vec2(horiz, pos.y) * pixel_density) / pixel_density;
	float wave = sin(pix.x * 3.5) * 0.35 + sin(pix.x * 7.0 + 1.2) * 0.12;
	float phase = fract((pix.y + time * side_fluid_speed) * 0.85 + wave);
	return step(phase, 0.32);
}

void fragment() {
	float scene_depth = get_linear_scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float water_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - water_depth, 0.0);
	bool is_side = abs(v_world_normal.y) < 0.5;

	vec4 col = evaluate_stepped_depth(depth_diff);

	if (ripples_enabled) {
		if (is_side) {
			col = mix(col, shallow_color, 0.35);
			float fluid = evaluate_side_fluid_flow(v_world_pos, v_world_normal, TIME);
			if (fluid > 0.5) col = mix(col, vec4(1.0, 1.0, 1.0, 1.0), 0.90);
		} else {
			vec2 rip = evaluate_graphic_ripples(v_world_pos.xz, TIME, water_depth);
			if (rip.y > 0.5) col.rgb = mix(col.rgb, deep_color.rgb * 0.75, 0.35);
			if (rip.x > 0.5) col = mix(col, ripple_color, ripple_color.a);
		}
	}

	if (foam_enabled && !is_side && depth_diff < foam_thickness) {
		col = foam_color;
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
}
