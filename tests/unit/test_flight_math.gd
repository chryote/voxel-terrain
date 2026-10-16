class_name TestFlightMath
extends "res://tests/framework/test_case.gd"

const FlightMath = preload("res://src/player/flight_math.gd")

func test_3d_camera_forward_vector() -> void:
	# Facing north (-Z) level (pitch = 0)
	var fwd_level = FlightMath.compute_3d_camera_forward(0.0, 0.0)
	assert_vec_almost_eq(fwd_level, Vector3(0, 0, -1))

	# Looking 45 degrees up (pitch = PI / 4.0)
	var fwd_up = FlightMath.compute_3d_camera_forward(0.0, PI * 0.25)
	assert_almost_eq(fwd_up.length(), 1.0, 0.001)
	assert_almost_eq(fwd_up.y, 1.0 / sqrt(2.0), 0.001)
	assert_almost_eq(fwd_up.z, -1.0 / sqrt(2.0), 0.001)

	# Looking 45 degrees down (pitch = -PI / 4.0)
	var fwd_down = FlightMath.compute_3d_camera_forward(0.0, -PI * 0.25)
	assert_almost_eq(fwd_down.length(), 1.0, 0.001)
	assert_almost_eq(fwd_down.y, -1.0 / sqrt(2.0), 0.001)
	assert_almost_eq(fwd_down.z, -1.0 / sqrt(2.0), 0.001)

func test_flight_direction_driven_by_camera_pitch() -> void:
	# Pitching camera up 45 deg and pressing forward (W: Vector2(0, -1))
	var dir_climb = FlightMath.compute_flight_direction(0.0, PI * 0.25, Vector2(0, -1))
	assert_true(dir_climb.y > 0.7, "Forward flight with upward camera pitch must fly upward")
	assert_true(dir_climb.z < -0.7, "Forward flight with upward camera pitch must fly forward")

	# Pitching camera down 45 deg and pressing forward (W: Vector2(0, -1))
	var dir_dive = FlightMath.compute_flight_direction(0.0, -PI * 0.25, Vector2(0, -1))
	assert_true(dir_dive.y < -0.7, "Forward flight with downward camera pitch must dive downward")
	assert_true(dir_dive.z < -0.7, "Forward flight with downward camera pitch must fly forward")

	# Pitching camera up 45 deg and pressing backward (S: Vector2(0, 1))
	var dir_back = FlightMath.compute_flight_direction(0.0, PI * 0.25, Vector2(0, 1))
	assert_true(dir_back.y < -0.7, "Backward flight with upward camera pitch must move down and back")
	assert_true(dir_back.z > 0.7)

	# Strafing right (D: Vector2(1, 0)) remains horizontal
	var dir_strafe = FlightMath.compute_flight_direction(0.0, PI * 0.25, Vector2(1, 0))
	assert_almost_eq(dir_strafe.y, 0.0, 0.001, "Strafing right remains level")
	assert_almost_eq(dir_strafe.x, 1.0, 0.001)

func test_horizontal_flight_direction() -> void:
	# Facing north (-Z) with cam_yaw = 0.0
	var fwd = FlightMath.compute_horizontal_flight_direction(0.0, Vector2(0, -1))
	assert_vec_almost_eq(fwd, Vector3(0, 0, -1))

	var back = FlightMath.compute_horizontal_flight_direction(0.0, Vector2(0, 1))
	assert_vec_almost_eq(back, Vector3(0, 0, 1))

	var right = FlightMath.compute_horizontal_flight_direction(0.0, Vector2(1, 0))
	assert_vec_almost_eq(right, Vector3(1, 0, 0))

	var left = FlightMath.compute_horizontal_flight_direction(0.0, Vector2(-1, 0))
	assert_vec_almost_eq(left, Vector3(-1, 0, 0))

	# Facing east (-X) with cam_yaw = PI / 2.0
	var fwd_east = FlightMath.compute_horizontal_flight_direction(PI * 0.5, Vector2(0, -1))
	assert_vec_almost_eq(fwd_east, Vector3(-1, 0, 0))

func test_vertical_axis() -> void:
	assert_almost_eq(FlightMath.calculate_vertical_axis(true, false), 1.0)
	assert_almost_eq(FlightMath.calculate_vertical_axis(false, true), -1.0)
	assert_almost_eq(FlightMath.calculate_vertical_axis(true, true), 0.0)
	assert_almost_eq(FlightMath.calculate_vertical_axis(false, false), 0.0)

func test_compute_flight_direction_3d_and_clamping() -> void:
	# Pure vertical flight via vertical axis
	var dir_up = FlightMath.compute_flight_direction(0.0, 0.0, Vector2.ZERO, 1.0)
	assert_vec_almost_eq(dir_up, Vector3(0, 1, 0))

	var dir_down = FlightMath.compute_flight_direction(0.0, 0.0, Vector2.ZERO, -1.0)
	assert_vec_almost_eq(dir_down, Vector3(0, -1, 0))

	# Diagonal flight (forward + vertical trim): normalized to unit length
	var dir_diag = FlightMath.compute_flight_direction(0.0, 0.0, Vector2(0, -1), 1.0)
	assert_almost_eq(dir_diag.length(), 1.0, 0.001)
	assert_almost_eq(dir_diag.y, 1.0 / sqrt(2.0), 0.001)
	assert_almost_eq(dir_diag.z, -1.0 / sqrt(2.0), 0.001)

func test_target_speed() -> void:
	var walk_fly_speed = 12.0
	var sprint_fly_speed = 24.0

	assert_almost_eq(FlightMath.calculate_target_speed(false, walk_fly_speed, sprint_fly_speed), 12.0)
	assert_almost_eq(FlightMath.calculate_target_speed(true, walk_fly_speed, sprint_fly_speed), 24.0)

func test_accelerate_flight_velocity() -> void:
	var current = Vector3.ZERO
	var target = Vector3(10, 0, 0)
	var delta = 0.1
	var accel = 5.0
	var friction = 5.0

	# Accelerating
	var next_vel = FlightMath.accelerate_flight_velocity(current, target, delta, accel, friction)
	assert_true(next_vel.x > 0.0)
	assert_true(next_vel.x < 10.0)

	# Decelerating
	var moving = Vector3(10, 0, 0)
	var stopped = FlightMath.accelerate_flight_velocity(moving, Vector3.ZERO, delta, accel, friction)
	assert_true(stopped.x < 10.0)
	assert_true(stopped.x >= 0.0)
