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
