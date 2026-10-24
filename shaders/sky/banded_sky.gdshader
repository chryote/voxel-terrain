shader_type sky;

/**
 * Banded Sky Shader (Graphic Novel / Moebius Aesthetic)
 * Quantizes atmospheric gradients into distinct stepped bands of flat color
 * and renders a sharp, flat graphic sun disk.
 */

group_uniforms Sky_Palette;
uniform vec4 sky_top_color : source_color = vec4(0.24, 0.44, 0.72, 1.0);
uniform vec4 sky_mid_color : source_color = vec4(0.48, 0.72, 0.88, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.96, 0.86, 0.70, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.68, 0.60, 0.52, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.20, 0.18, 0.16, 1.0);

group_uniforms Band_Thresholds;
uniform float mid_band_threshold : hint_range(0.0, 1.0) = 0.25;
uniform float horizon_band_threshold : hint_range(-0.2, 0.2) = 0.02;

group_uniforms Sun_Disk;
uniform bool sun_enabled = true;
uniform vec4 sun_color : source_color = vec4(1.0, 0.98, 0.88, 1.0);
uniform float sun_disk_size : hint_range(0.001, 0.1) = 0.025;

// Pure single-responsibility helper: calculates stepped background color by vertical angle
vec3 calculate_sky_band(float eye_y) {
	if (eye_y >= horizon_band_threshold) {
		// Upper hemisphere (Sky)
		float is_top = step(mid_band_threshold, eye_y);
		return mix(sky_mid_color.rgb, sky_top_color.rgb, is_top);
	} else if (eye_y >= 0.0) {
		// Horizon transition band
		return sky_horizon_color.rgb;
	} else if (eye_y >= -horizon_band_threshold) {
		// Ground horizon band
		return ground_horizon_color.rgb;
	} else {
		// Lower hemisphere (Ground)
		return ground_bottom_color.rgb;
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
