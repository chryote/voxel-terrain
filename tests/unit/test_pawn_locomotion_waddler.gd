class_name TestPawnLocomotionWaddler
extends "res://tests/framework/test_case.gd"

## Unit tests for PawnLocomotionWaddler procedural bouncing, rolling, and dampening.

func test_waddler_initialization_and_rest() -> void:
	var target = Node3D.new()
	target.position = Vector3(0.0, 0.9, 0.0)
	target.scale = Vector3.ONE

	var waddler = PawnLocomotionWaddler.new()
	waddler.visual_target = target
	waddler._ready()

	assert_almost_eq(target.position.y, 0.9)
	assert_vec_almost_eq(target.scale, Vector3.ONE)
	assert_vec_almost_eq(target.rotation, Vector3.ZERO)

	waddler.free()
	target.free()

func test_waddler_motion_transforms() -> void:
	var body = CharacterBody3D.new()
	var target = Node3D.new()
	target.position = Vector3(0.0, 0.9, 0.0)

	var waddler = PawnLocomotionWaddler.new()
	waddler.character_body = body
	waddler.visual_target = target
	waddler._ready()

	# Simulate grounded horizontal movement
	body.velocity = Vector3(6.0, 0.0, 0.0)
	for i in range(10):
		waddler.update_locomotion(0.05)

	# Should have modified pitch, roll, or position
	assert_true(target.position.y != 0.9 or target.rotation.x != 0.0 or target.rotation.z != 0.0)

	# Reset
	waddler.reset_to_rest()
	assert_almost_eq(target.position.y, 0.9)
	assert_almost_eq(target.rotation.z, 0.0)
	assert_almost_eq(target.rotation.x, 0.0)

	waddler.free()
	body.free()
	target.free()

func test_waddler_disabled_toggle() -> void:
	var body = CharacterBody3D.new()
	body.velocity = Vector3(5.0, 0.0, 0.0)
	var target = Node3D.new()
	target.position = Vector3(0.0, 0.9, 0.0)

	var waddler = PawnLocomotionWaddler.new()
	waddler.character_body = body
	waddler.visual_target = target
	waddler.enabled = false
	waddler._ready()

	for i in range(5):
		waddler.update_locomotion(0.05)

	assert_almost_eq(target.position.y, 0.9)
	assert_vec_almost_eq(target.rotation, Vector3.ZERO)

	waddler.free()
	body.free()
	target.free()
