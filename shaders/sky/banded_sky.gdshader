shader_type sky;

/**
 * Banded Sky Shader (Graphic Novel / Moebius Aesthetic)
 * Quantizes atmospheric gradients into distinct stepped bands of flat color
 * and renders a sharp, flat graphic sun disk.
 */

group_uniforms Sky_Palette;
uniform vec4 sky_top_color : source_color = vec4(0.14, 0.22, 0.44, 1.0);
uniform vec4 sky_high_color : source_color = vec4(0.24, 0.48, 0.76, 1.0);
uniform vec4 sky_mid_color : source_color = vec4(0.32, 0.68, 0.78, 1.0);
uniform vec4 sky_low_color : source_color = vec4(0.95, 0.68, 0.35, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.96, 0.48, 0.42, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.62, 0.46, 0.48, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.18, 0.15, 0.18, 1.0);

group_uniforms Band_Thresholds;
uniform float high_band_threshold : hint_range(0.0, 1.0) = 0.38;
uniform float mid_band_threshold : hint_range(0.0, 1.0) = 0.20;
uniform float low_band_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float horizon_band_threshold : hint_range(-0.2, 0.2) = 0.02;
uniform float band_smoothness : hint_range(0.0, 0.1) = 0.0;

group_uniforms Sun_Disk;
uniform bool sun_enabled = true;
uniform vec4 sun_color : source_color = vec4(1.0, 0.98, 0.88, 1.0);
uniform float sun_disk_size : hint_range(0.001, 0.1) = 0.025;

// Pure single-responsibility helper: calculates stepped background color by vertical angle
vec3 calculate_sky_band(float eye_y) {
	if (band_smoothness <= 0.0001) {
		// Strictly crisp cel bands (pure posterized graphic novel stripes)
		if (eye_y >= high_band_threshold) {
			return sky_top_color.rgb;
		} else if (eye_y >= mid_band_threshold) {
			return sky_high_color.rgb;
		} else if (eye_y >= low_band_threshold) {
			return sky_mid_color.rgb;
		} else if (eye_y >= horizon_band_threshold) {
			return sky_low_color.rgb;
		} else if (eye_y >= 0.0) {
			return sky_horizon_color.rgb;
		} else if (eye_y >= -horizon_band_threshold) {
			return ground_horizon_color.rgb;
		} else {
			return ground_bottom_color.rgb;
		}
	} else {
		// Configurable smoothed bands
		float half_s = band_smoothness * 0.5;
		vec3 col = ground_bottom_color.rgb;
		col = mix(col, ground_horizon_color.rgb, smoothstep(-horizon_band_threshold - half_s, -horizon_band_threshold + half_s, eye_y));
		col = mix(col, sky_horizon_color.rgb, smoothstep(-half_s, half_s, eye_y));
		col = mix(col, sky_low_color.rgb, smoothstep(horizon_band_threshold - half_s, horizon_band_threshold + half_s, eye_y));
		col = mix(col, sky_mid_color.rgb, smoothstep(low_band_threshold - half_s, low_band_threshold + half_s, eye_y));
		col = mix(col, sky_high_color.rgb, smoothstep(mid_band_threshold - half_s, mid_band_threshold + half_s, eye_y));
		col = mix(col, sky_top_color.rgb, smoothstep(high_band_threshold - half_s, high_band_threshold + half_s, eye_y));
		return col;
	}
}

// Pure single-responsibility helper: renders flat circular sun disk
float calculate_sun_disk(vec3 eye_dir, vec3 light_dir, float disk_size) {
	float sun_dot = max(dot(eye_dir, light_dir), 0.0);
	float angular_threshold = cos(disk_size * 3.14159265);
	return step(angular_threshold, sun_dot);
}

void sky() {
	vec3 base_color = calculate_sky_band(EYEDIR.y);

	if (sun_enabled && LIGHT0_ENABLED) {
		float sun_mask = calculate_sun_disk(EYEDIR, LIGHT0_DIRECTION, sun_disk_size);
		base_color = mix(base_color, sun_color.rgb, sun_mask);
	}

	COLOR = base_color;
}
