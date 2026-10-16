class_name CameraMath
extends RefCounted

## Pure mathematical helpers for third-person camera transformations.

static func clamp_pitch(pitch_rad: float, min_deg: float = -75.0, max_deg: float = 75.0) -> float:
	var min_rad = deg_to_rad(min_deg)
	var max_rad = deg_to_rad(max_deg)
	return clampf(pitch_rad, min_rad, max_rad)

static func lerp_shoulder_x(current_x: float, target_x: float, delta: float, speed: float = 10.0) -> float:
	return lerpf(current_x, target_x, clampf(delta * speed, 0.0, 1.0))

static func lerp_fov(current_fov: float, target_fov: float, delta: float, speed: float = 12.0) -> float:
	return lerpf(current_fov, target_fov, clampf(delta * speed, 0.0, 1.0))

static func lerp_arm_length(current_len: float, target_len: float, delta: float, speed: float = 12.0) -> float:
	return lerpf(current_len, target_len, clampf(delta * speed, 0.0, 1.0))
