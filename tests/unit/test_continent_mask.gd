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

func test_continent_radius_and_islands_config() -> void:
	var cfg = ContinentGeneratorConfig.new()
	cfg.continent_radius = 0.85
	cfg.islands_enabled = true
	cfg.island_threshold = 0.65
	cfg.island_boost = 0.25

	var mask = ContinentMask.new(1337, cfg)
	assert_almost_eq(mask.continent_radius, 0.85, 0.001, "Continent radius should match config")
	assert_true(mask.islands_enabled, "Islands enabled should match config")
	assert_almost_eq(mask.island_threshold, 0.65, 0.001, "Island threshold should match config")
	assert_almost_eq(mask.island_boost, 0.25, 0.001, "Island boost should match config")

func test_border_falloff_protected_with_islands() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var cfg = ContinentGeneratorConfig.new()
	cfg.islands_enabled = true
	cfg.continent_radius = 0.85
	var mask = ContinentMask.new(1337, cfg)

	# Verify every point right on and outside the world border strictly evaluates to 0.0
	for t in [0.1, 0.3, 0.5, 0.7, 0.9]:
		var z = lerpf(bounds.min_world_z, bounds.max_world_z, t)
		var f_left = mask.get_factor_world(bounds.min_world_x, z, bounds)
		var f_right = mask.get_factor_world(bounds.max_world_x, z, bounds)
		assert_almost_eq(f_left, 0.0, 0.0001, "Left border factor must be strictly 0")
		assert_almost_eq(f_right, 0.0, 0.0001, "Right border factor must be strictly 0")

