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

## Director's Lens: Computes dynamic camera FOV pull-back based on blade tip velocity.
## When tip_velocity exceeds threshold (500 m/s), smoothly expands FOV towards max_fov (88°).
static func compute_velocity_fov(
	base_fov: float,
	tip_velocity: float,
	max_fov: float = 88.0,
	threshold_velocity: float = 500.0,
	saturation_velocity: float = 3000.0
) -> float:
	if tip_velocity <= threshold_velocity:
		return base_fov
	var factor = clampf((tip_velocity - threshold_velocity) / maxf(saturation_velocity - threshold_velocity, 1.0), 0.0, 1.0)
	return lerpf(base_fov, max_fov, factor)

## Director's Lens: Computes camera screen shake displacement along the slash's cutting plane.
## Cleaves shake vertically, sweeps shake horizontally, diagonal slashes shake along the diagonal.
static func compute_directional_shake(
	tilt_degrees: float,
	intensity: float,
	time_sec: float,
	frequency: float = 38.0
) -> Vector2:
	var angle_rad = deg_to_rad(tilt_degrees)
	var cut_dir = Vector2(cos(angle_rad), sin(angle_rad)).normalized()
	var oscillation = sin(time_sec * frequency) * intensity
	return cut_dir * oscillation

## Director's Lens: Computes inward impact FOV snap (punch inward, then spring back).
static func compute_impact_snap_fov(
	target_fov: float,
	punch_degrees: float,
	snap_timer: float,
	snap_duration: float = 0.08
) -> float:
	if snap_timer <= 0.0:
		return target_fov
	var progress = clampf(snap_timer / maxf(snap_duration, 0.001), 0.0, 1.0)
	var punch_factor = sin(progress * PI)
	return target_fov - punch_degrees * punch_factor
