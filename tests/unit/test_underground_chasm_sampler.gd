class_name TestUndergroundChasmSampler
extends "res://tests/framework/test_case.gd"

func test_depth_envelope() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_min_y = 4
	config.chasm_max_y = 22
	var sampler = UndergroundChasmSampler.new(1337, config)

	# Exactly at or outside bounds
	assert_eq(sampler.get_depth_envelope(3.0), 0.0, "Below min_y must be 0")
	assert_eq(sampler.get_depth_envelope(4.0), 0.0, "At min_y must be 0")
	assert_eq(sampler.get_depth_envelope(22.0), 0.0, "At max_y must be 0")
	assert_eq(sampler.get_depth_envelope(35.0), 0.0, "Above max_y must be 0")

	# Inside core elevation (mid-depth)
	var mid_val = sampler.get_depth_envelope(13.0)
	assert_almost_eq(mid_val, 1.0, 0.001, "Mid-depth elevation must have full envelope (1.0)")

func test_subterranean_water_allocation() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_water_level = 10
	config.chasm_threshold = 0.2 # Lower threshold to easily find open chasm space
	var sampler = UndergroundChasmSampler.new(1337, config)

	var found_water = false
	var found_dry_air = false

	for x in range(0, 300, 20):
		for z in range(0, 300, 20):
			# Test point below water level (Y = 8)
			var res_low = sampler.sample_chasm(float(x), 8.0, float(z))
			if res_low.is_chasm and res_low.is_water:
				found_water = true

			# Test point above water level (Y = 16)
			var res_high = sampler.sample_chasm(float(x), 16.0, float(z))
			if res_high.is_chasm and not res_high.is_water:
				found_dry_air = true

			if found_water and found_dry_air:
				break
		if found_water and found_dry_air:
			break

	assert_true(found_water, "Must find subterranean water pool space at Y <= chasm_water_level")
	assert_true(found_dry_air, "Must find open dry cavern void space at Y > chasm_water_level")

func test_support_pillars() -> void:
	var config = CaveGeneratorConfig.new()
	config.pillar_threshold = 0.3 # Lower threshold to guarantee finding pillars
	var sampler = UndergroundChasmSampler.new(1337, config)

	var found_pillar = false
	for x in range(0, 300, 10):
		for z in range(0, 300, 10):
			var res = sampler.sample_chasm(float(x), 12.0, float(z))
			if res.is_pillar:
				found_pillar = true
				assert_false(res.is_chasm, "Pillars must remain uncarved solid rock")
				assert_eq(sampler.get_chasm_carve(float(x), 12.0, float(z)), 0.0, "Pillar carve factor must be 0")
				break
		if found_pillar:
			break

	assert_true(found_pillar, "Must locate natural support pillars")

func test_early_exit_warp_margin_calibration() -> void:
	var config = CaveGeneratorConfig.new()
	config.chasm_wall_warp_amplitude = 4.0
	config.chasm_rift_frequency = 0.003
	var sampler = UndergroundChasmSampler.new(1337, config)

	var margin = sampler.get_wall_warp_margin()
	# Expected margin = 4.0 * 1.4142 * 0.003 * 2.0 ~= 0.03394
	assert_almost_eq(margin, 4.0 * 1.4142 * 0.003 * 2.0, 0.0001, "Warp margin must scale with amplitude and frequency")

	# Zero amplitude warp must yield 0 margin
	config.chasm_wall_warp_amplitude = 0.0
	assert_eq(sampler.get_wall_warp_margin(), 0.0, "Zero amplitude warp must yield zero margin")

func test_fast_early_exit_corridor_masking() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	var col = ChasmColumnResult.new()
	var early_exits = 0
	var total_samples = 0
	var early_exit_threshold = config.chasm_rift_threshold - (sampler.get_wall_warp_margin() + UndergroundChasmSampler.WALL_MARGIN)

	for x in range(-50, 50, 2):
		for z in range(-50, 50, 2):
			total_samples += 1
			var wx = float(x) * 8.0
			var wz = float(z) * 8.0
			var unwarped_rift = sampler.sample_unwarped_rift(wx, wz)

			sampler.sample_column(wx, wz, col)

			if unwarped_rift < early_exit_threshold:
				early_exits += 1
				assert_false(col.is_chasm, "Early-exited column must have is_chasm = false")
				assert_false(col.is_wall, "Early-exited column must have is_wall = false")
				assert_false(col.is_pillar, "Early-exited column must have is_pillar = false")
				assert_false(col.is_arena, "Early-exited column must have is_arena = false")
				assert_eq(col.floor_y, 0, "Early-exited column floor_y must be 0")
				assert_eq(col.ceil_y, 0, "Early-exited column ceil_y must be 0")
				assert_false(sampler.can_column_contain_chasm(wx, wz), "can_column_contain_chasm must be false")
				assert_eq(sampler.get_chasm_carve(wx, 10.0, wz), 0.0, "Point carve query must return 0.0")

	assert_true(early_exits > 500, "Early exit must prune void columns (pruned %d / %d)" % [early_exits, total_samples])

func test_no_false_negatives_in_corridor() -> void:
	## Validates that every column with is_chasm or is_wall has unwarped_rift >= early_exit_threshold.
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	var col = ChasmColumnResult.new()
	var early_exit_threshold = config.chasm_rift_threshold - (sampler.get_wall_warp_margin() + UndergroundChasmSampler.WALL_MARGIN)

	var chasm_columns_found = 0
	for x in range(-40, 40, 2):
		for z in range(-40, 40, 2):
			var wx = float(x) * 6.0
			var wz = float(z) * 6.0
			sampler.sample_column(wx, wz, col)

			if col.is_chasm or col.is_wall:
				chasm_columns_found += 1
				var unwarped_rift = sampler.sample_unwarped_rift(wx, wz)
				assert_true(
					unwarped_rift >= early_exit_threshold,
					"Active chasm or wall at (%f, %f) must never be culled: unwarped_rift was %f (threshold: %f)" % [wx, wz, unwarped_rift, early_exit_threshold]
				)

	assert_true(chasm_columns_found > 100, "Must validate across active chasm and wall columns (found %d)" % chasm_columns_found)

func test_inland_continent_mask_bypass_detection() -> void:
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var bounds = world_config.create_world_bounds()
	var cont_gen = ContinentGenerator.new(1337, gen_config)
	var sampler = UndergroundChasmSampler.new(1337, cave_config)
	sampler.set_continent_mask(cont_gen.mask, bounds)

	assert_false(sampler.is_deep_inland, "Initially is_deep_inland must be false")

	var mid_x = (bounds.min_world_x + bounds.max_world_x) * 0.5
	var mid_z = (bounds.min_world_z + bounds.max_world_z) * 0.5
	var is_inland = sampler.update_deep_inland_status(mid_x, mid_z, mid_x + 16.0, mid_z + 16.0)

	assert_true(is_inland, "Center of continent must be detected as deep inland")
	assert_true(sampler.is_deep_inland, "is_deep_inland flag must be true")

	# Mathematical equivalence check: sample_rift_mask with bypass vs without bypass must match
	var rift_bypassed = sampler.sample_rift_mask(mid_x + 8.0, mid_z + 8.0)
	sampler.is_deep_inland = false
	var rift_evaluated = sampler.sample_rift_mask(mid_x + 8.0, mid_z + 8.0)
	assert_almost_eq(rift_bypassed, rift_evaluated, 0.00001, "Deep inland rift calculation must be mathematically identical")

func test_coastal_continent_mask_falloff_preservation() -> void:
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var bounds = world_config.create_world_bounds()
	var cont_gen = ContinentGenerator.new(1337, gen_config)
	var sampler = UndergroundChasmSampler.new(1337, cave_config)
	sampler.set_continent_mask(cont_gen.mask, bounds)

	# Coastal / ocean chunk near the world boundary
	var ocean_x = bounds.min_world_x + 10.0
	var ocean_z = bounds.min_world_z + 10.0
	var is_inland = sampler.update_deep_inland_status(ocean_x, ocean_z, ocean_x + 16.0, ocean_z + 16.0)

	assert_false(is_inland, "Ocean boundary must not be detected as deep inland")
	assert_false(sampler.is_deep_inland, "is_deep_inland must be false on ocean chunk")

	# can_chasm_intersect_cell integration: inland cell sets flag
	var mid_x = (bounds.min_world_x + bounds.max_world_x) * 0.5
	var mid_z = (bounds.min_world_z + bounds.max_world_z) * 0.5
	var _intersect = sampler.can_chasm_intersect_cell(Vector3(mid_x, 4.0, mid_z), Vector3(mid_x + 16.0, 24.0, mid_z + 16.0))
	assert_true(sampler.is_deep_inland, "can_chasm_intersect_cell must set is_deep_inland on inland cell")

func test_multi_point_culling_no_false_negatives_near_ocean_falloff() -> void:
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var bounds = world_config.create_world_bounds()
	var cont_gen = ContinentGenerator.new(1337, gen_config)
	var sampler = UndergroundChasmSampler.new(1337, cave_config)
	sampler.set_continent_mask(cont_gen.mask, bounds)

	# Chunk (79, 4) world box [2528, 0, 128] to [2560, 160, 160]
	var min_p = Vector3(2528.0, 0.0, 128.0)
	var max_p = Vector3(2560.0, 160.0, 160.0)

	var can_intersect = sampler.can_chasm_intersect_cell(min_p, max_p)
	assert_true(can_intersect, "can_chasm_intersect_cell must return true for Chunk (79, 4) where a chasm traverses the corner")


