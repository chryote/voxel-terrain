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

