class_name TestPlayerIntent
extends "res://tests/framework/test_case.gd"

func test_intent_initial_and_reset() -> void:
	var intent = PlayerIntent.new()
	assert_eq(intent.move_vector, Vector2.ZERO)
	assert_false(intent.jump_requested)
	assert_false(intent.aim_requested)
	assert_false(intent.fire_requested)
	assert_false(intent.toggle_fly_requested)
	assert_false(intent.fly_up_requested)
	assert_false(intent.fly_down_requested)

	intent.move_vector = Vector2(1, -1)
	intent.jump_requested = true
	intent.aim_requested = true
	intent.fire_requested = true
	intent.toggle_fly_requested = true
	intent.fly_up_requested = true
	intent.fly_down_requested = true

	intent.reset()
	assert_eq(intent.move_vector, Vector2.ZERO)
	assert_false(intent.jump_requested)
	assert_false(intent.aim_requested)
	assert_false(intent.fire_requested)
	assert_false(intent.toggle_fly_requested)
	assert_false(intent.fly_up_requested)
	assert_false(intent.fly_down_requested)
