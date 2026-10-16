class_name FlightMath
extends RefCounted

## Pure mathematical helpers for 3D flight locomotion, camera-directed flight, and velocity smoothing.

static func compute_3d_camera_forward(cam_yaw: float, cam_pitch: float) -> Vector3:
	var cos_pitch = cos(cam_pitch)
	var sin_pitch = sin(cam_pitch)
	return Vector3(
		-sin(cam_yaw) * cos_pitch,
		sin_pitch,
		-cos(cam_yaw) * cos_pitch
	)

static func compute_camera_right(cam_yaw: float) -> Vector3:
	return Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))

static func compute_horizontal_flight_direction(cam_yaw: float, move_vector: Vector2) -> Vector3:
	var forward = -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var right = compute_camera_right(cam_yaw)
	return forward * -move_vector.y + right * move_vector.x

static func calculate_vertical_axis(fly_up: bool, fly_down: bool) -> float:
	var axis: float = 0.0
	if fly_up:
		axis += 1.0
	if fly_down:
		axis -= 1.0
	return axis

static func compute_flight_direction(cam_yaw: float, cam_pitch: float, move_vector: Vector2, vertical_axis: float = 0.0) -> Vector3:
	var forward_3d = compute_3d_camera_forward(cam_yaw, cam_pitch)
	var right = compute_camera_right(cam_yaw)
	var dir = forward_3d * -move_vector.y + right * move_vector.x
	if absf(vertical_axis) > 0.001:
		dir += Vector3(0.0, vertical_axis, 0.0)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir

static func calculate_target_speed(is_sprinting: bool, base_speed: float, sprint_speed: float) -> float:
	return sprint_speed if is_sprinting else base_speed

static func accelerate_flight_velocity(current_vel: Vector3, target_vel: Vector3, delta: float, accel: float, friction: float) -> Vector3:
	if target_vel.length_squared() > 0.0001:
		return current_vel.lerp(target_vel, clampf(delta * accel, 0.0, 1.0))
	else:
		return current_vel.lerp(Vector3.ZERO, clampf(delta * friction, 0.0, 1.0))
