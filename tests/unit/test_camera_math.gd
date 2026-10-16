class_name TestCameraMath
extends "res://tests/framework/test_case.gd"

func test_clamp_pitch() -> void:
	var clamped_normal = CameraMath.clamp_pitch(0.0, -75.0, 75.0)
	assert_almost_eq(clamped_normal, 0.0)

	var clamped_high = CameraMath.clamp_pitch(deg_to_rad(90.0), -75.0, 75.0)
	assert_almost_eq(clamped_high, deg_to_rad(75.0))

	var clamped_low = CameraMath.clamp_pitch(deg_to_rad(-90.0), -75.0, 75.0)
	assert_almost_eq(clamped_low, deg_to_rad(-75.0))

func test_lerp_shoulder() -> void:
	var cur_x = 0.65
	var target_x = -0.65
	var next_x = CameraMath.lerp_shoulder_x(cur_x, target_x, 0.1, 5.0) # 0.5 step
	assert_almost_eq(next_x, 0.0, 0.001)

func test_lerp_fov() -> void:
	var fov = 75.0
	var target = 50.0
	var zoomed = CameraMath.lerp_fov(fov, target, 0.05, 10.0) # 0.5 step
	assert_almost_eq(zoomed, 62.5, 0.001)
