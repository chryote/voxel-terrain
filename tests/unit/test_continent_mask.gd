class_name TestContinentMask
extends "res://tests/framework/test_case.gd"

func test_mask_bounds_and_falloff() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0) # -512 to 512
	var mask = ContinentMask.new(42)

	# Exactly at border or beyond
	var factor_border_x = mask.get_factor_world(bounds.min_world_x, 0.0, bounds)
	assert_almost_eq(factor_border_x, 0.0, 0.0001, "Border should have 0.0 land factor")

	var factor_outside = mask.get_factor_world(-1000.0, 0.0, bounds)
	assert_almost_eq(factor_outside, 0.0, 0.0001, "Outside should have 0.0 land factor")

	# Center of continent should have high land factor
	var factor_center = mask.get_factor_world(0.0, 0.0, bounds)
	assert_true(factor_center > 0.5, "Center should have significant land factor (got %f)" % factor_center)
	assert_true(factor_center <= 1.0, "Center land factor should not exceed 1.0")

func test_factor_range() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var mask = ContinentMask.new(1234)

	for x in [-200.0, -100.0, 0.0, 100.0, 200.0]:
		for z in [-200.0, -100.0, 0.0, 100.0, 200.0]:
			var f = mask.get_factor_world(x, z, bounds)
			assert_true(f >= 0.0 and f <= 1.0, "Factor at (%f, %f) must be in [0, 1], got %f" % [x, z, f])
