class_name TestFlightController
extends "res://tests/framework/test_case.gd"

const FlightController = preload("res://src/player/flight_controller.gd")

func test_default_state() -> void:
	var controller = FlightController.new()
	assert_false(controller.is_flying)
	assert_true(controller.can_fly)
	assert_almost_eq(controller.fly_speed, 12.0)
	assert_almost_eq(controller.fly_sprint_speed, 24.0)
	controller.free()

func test_toggle_flight_and_signal() -> void:
	var controller = FlightController.new()
	var signal_received: Array = []
	controller.flight_mode_changed.connect(func(active: bool): signal_received.append(active))

	var state1 = controller.toggle_flight()
	assert_true(state1)
	assert_true(controller.is_flying)
	assert_eq(signal_received.size(), 1)
	assert_true(signal_received[0])

	var state2 = controller.toggle_flight()
	assert_false(state2)
	assert_false(controller.is_flying)
	assert_eq(signal_received.size(), 2)
	assert_false(signal_received[1])
	controller.free()

func test_can_fly_flag() -> void:
	var controller = FlightController.new()
	controller.can_fly = false

	controller.set_flying(true)
	assert_false(controller.is_flying)

	controller.toggle_flight()
	assert_false(controller.is_flying)
	controller.free()

func test_handle_intent() -> void:
	var controller = FlightController.new()
	var intent = PlayerIntent.new()

	controller.handle_intent(intent)
	assert_false(controller.is_flying)

	intent.toggle_fly_requested = true
	controller.handle_intent(intent)
	assert_true(controller.is_flying)
	controller.free()

func test_compute_flight_velocity() -> void:
	var controller = FlightController.new()
	var intent = PlayerIntent.new()

	# When not flying, velocity is unchanged
	var initial_vel = Vector3(1, 2, 3)
	var out_vel = controller.compute_flight_velocity(initial_vel, intent, 0.0, 0.0, 0.1)
	assert_vec_almost_eq(out_vel, initial_vel)

	# Enter flight mode
	controller.set_flying(true)

	# Flight pitched up 45 degrees: forward movement (W) causes upward climb
	intent.move_vector = Vector2(0, -1)
	var vel_climb = controller.compute_flight_velocity(Vector3.ZERO, intent, 0.0, PI * 0.25, 0.1)
	assert_true(vel_climb.y > 0.0, "Climbing forward in 3D flight has positive Y velocity")
	assert_true(vel_climb.z < 0.0, "Climbing forward in 3D flight has forward Z velocity")

	# Flight pitched down 45 degrees: forward movement (W) causes downward dive
	var vel_dive = controller.compute_flight_velocity(Vector3.ZERO, intent, 0.0, -PI * 0.25, 0.1)
	assert_true(vel_dive.y < 0.0, "Diving forward in 3D flight has negative Y velocity")
	assert_true(vel_dive.z < 0.0, "Diving forward in 3D flight has forward Z velocity")

	# Forward flight with sprint boost
	intent.sprint_requested = true
	var vel_sprint = controller.compute_flight_velocity(Vector3.ZERO, intent, 0.0, 0.0, 0.1)
	assert_true(vel_sprint.z < 0.0)

	controller.free()
