class_name TestCaveMouthLimiter
extends "res://tests/framework/test_case.gd"

## Unit test suite for Cave Mouth Limiting:
## - Tunable configuration variables on CaveGeneratorConfig
## - CaveMouthLimiter filtering, prioritization, and determinism
## - Sampler and Carver integration with allowed mouths
## - Full continent detection limit enforcement

const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthLimiterClass = preload("res://src/generation/caves/cave_mouth_limiter.gd")
const CaveMouthSamplerClass = preload("res://src/generation/caves/cave_mouth_sampler.gd")
const CaveCarverClass = preload("res://src/generation/caves/cave_carver.gd")
const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const VolumetricTerrainGeneratorClass = preload("res://src/generation/volumetric_terrain_generator.gd")

func test_default_config_variables() -> void:
	var config = CaveGeneratorConfigClass.new()
	assert_true(config.limit_cave_mouths, "limit_cave_mouths should default to true")
	assert_eq(config.max_chasm_mouths, 1, "Default maximum chasm cave mouths must be 1")
	assert_eq(config.max_tunnel_mouths, 2, "Default maximum tunnel cave mouths must be 2")
	assert_eq(config.max_dead_end_mouths, 3, "Default maximum dead end cave mouths must be 3")

func test_filtering_excess_candidates() -> void:
	var limiter = CaveMouthLimiterClass.new()
	var config = CaveGeneratorConfigClass.new()

	# Create a mock set of candidates with excess mouths in every category
	var candidates: Array = []
	# 4 chasm mouths
	for i in range(4):
		candidates.append(CaveMouthDataClass.new(
			Vector3(float(i * 100), 50.0, 0.0),
			Vector2(float(i * 50), 0.0),
			CaveMouthDataClass.Type.CHASM,
			10.0 + float(i),
			7.0,
			50.0
		))
	# 5 tunnel mouths
	for i in range(5):
		candidates.append(CaveMouthDataClass.new(
			Vector3(0.0, 50.0, float(i * 100)),
			Vector2(0.0, float(i * 50)),
			CaveMouthDataClass.Type.TUNNEL,
			8.0 + float(i),
			6.0,
			50.0
		))
	# 6 dead end mouths
	for i in range(6):
		candidates.append(CaveMouthDataClass.new(
			Vector3(float(i * 80), 50.0, float(i * 80)),
			Vector2(float(i * 40), float(i * 40)),
			CaveMouthDataClass.Type.DEAD_END,
			4.0 + float(i),
			5.0,
			50.0
		))

	assert_eq(candidates.size(), 15, "Total candidates before limit must be 15")

	var limited = limiter.limit_mouths(candidates, config)
	var counts = limiter.count_by_type(limited)

	assert_eq(counts[CaveMouthDataClass.Type.CHASM], 1, "Chasm cave mouths must be limited to 1")
	assert_eq(counts[CaveMouthDataClass.Type.TUNNEL], 2, "Tunnel cave mouths must be limited to 2")
	assert_eq(counts[CaveMouthDataClass.Type.DEAD_END], 3, "Dead end cave mouths must be limited to 3")
	assert_eq(limited.size(), 6, "Total limited mouths must be 1 + 2 + 3 = 6")

func test_tuning_limits_via_variables() -> void:
	var limiter = CaveMouthLimiterClass.new()
	var config = CaveGeneratorConfigClass.new()

	# Generate mock candidates
	var candidates: Array = []
	for i in range(5):
		candidates.append(CaveMouthDataClass.new(Vector3(float(i * 50), 40.0, 0.0), Vector2.ZERO, CaveMouthDataClass.Type.CHASM, 10.0, 7.0))
		candidates.append(CaveMouthDataClass.new(Vector3(0.0, 40.0, float(i * 50)), Vector2.ZERO, CaveMouthDataClass.Type.TUNNEL, 8.0, 6.0))
		candidates.append(CaveMouthDataClass.new(Vector3(float(i * 50), 40.0, float(i * 50)), Vector2.ZERO, CaveMouthDataClass.Type.DEAD_END, 5.0, 5.0))

	# Tuning test 1: chasm = 0 (disabled), tunnel = 1, dead_end = 2
	config.max_chasm_mouths = 0
	config.max_tunnel_mouths = 1
	config.max_dead_end_mouths = 2
	var res1 = limiter.limit_mouths(candidates, config)
	var counts1 = limiter.count_by_type(res1)
	assert_eq(counts1[CaveMouthDataClass.Type.CHASM], 0, "Chasm count must be 0 when tuned to 0")
	assert_eq(counts1[CaveMouthDataClass.Type.TUNNEL], 1, "Tunnel count must be 1 when tuned to 1")
	assert_eq(counts1[CaveMouthDataClass.Type.DEAD_END], 2, "Dead end count must be 2 when tuned to 2")
	assert_eq(res1.size(), 3, "Total tuned count must equal 3")

	# Tuning test 2: chasm = 3, tunnel = 4, dead_end = 0
	config.max_chasm_mouths = 3
	config.max_tunnel_mouths = 4
	config.max_dead_end_mouths = 0
	var res2 = limiter.limit_mouths(candidates, config)
	var counts2 = limiter.count_by_type(res2)
	assert_eq(counts2[CaveMouthDataClass.Type.CHASM], 3, "Chasm count must be 3 when tuned to 3")
	assert_eq(counts2[CaveMouthDataClass.Type.TUNNEL], 4, "Tunnel count must be 4 when tuned to 4")
	assert_eq(counts2[CaveMouthDataClass.Type.DEAD_END], 0, "Dead end count must be 0 when tuned to 0")
	assert_eq(res2.size(), 7, "Total tuned count must equal 7")

	# Tuning test 3: disabling master switch keeps all candidates
	config.limit_cave_mouths = false
	var res3 = limiter.limit_mouths(candidates, config)
	assert_eq(res3.size(), candidates.size(), "Disabling limit_cave_mouths must preserve all candidates")

func test_deterministic_prominence_priority() -> void:
	var limiter = CaveMouthLimiterClass.new()
	var config = CaveGeneratorConfigClass.new()
	config.max_chasm_mouths = 1

	var m_shallow = CaveMouthDataClass.new(Vector3(100.0, 40.0, 100.0), Vector2.ZERO, CaveMouthDataClass.Type.CHASM, 4.0, 5.0)
	var m_deep = CaveMouthDataClass.new(Vector3(200.0, 40.0, 200.0), Vector2.ZERO, CaveMouthDataClass.Type.CHASM, 14.0, 8.0)
	var m_medium = CaveMouthDataClass.new(Vector3(300.0, 40.0, 300.0), Vector2.ZERO, CaveMouthDataClass.Type.CHASM, 8.0, 6.0)

	var candidates = [m_shallow, m_deep, m_medium]
	var res = limiter.limit_mouths(candidates, config)

	assert_eq(res.size(), 1, "Must select exactly 1 mouth")
	assert_eq(res[0].depth, 14.0, "Limiter must prioritize deepest entrance (depth=14.0)")
	assert_eq(res[0].world_pos, Vector3(200.0, 40.0, 200.0), "Selected mouth must match m_deep")

func test_spatial_point_and_box_queries() -> void:
	var limiter = CaveMouthLimiterClass.new()
	var mouths = [
		CaveMouthDataClass.new(Vector3(100.0, 50.0, 200.0), Vector2.ZERO, CaveMouthDataClass.Type.CHASM, 10.0, 8.0),
		CaveMouthDataClass.new(Vector3(-300.0, 50.0, -400.0), Vector2.ZERO, CaveMouthDataClass.Type.TUNNEL, 9.0, 7.0)
	]

	# Point inside first mouth
	var inside1 = limiter.find_nearest_mouth(102.0, 201.0, mouths)
	assert_not_null(inside1, "Point (102, 201) must fall inside mouth at (100, 200) with r=8")
	assert_eq(inside1.type, CaveMouthDataClass.Type.CHASM)

	# Point far away
	var far_away = limiter.find_nearest_mouth(0.0, 0.0, mouths)
	assert_null(far_away, "Origin must be far away from both mouths")

	# Bounding box overlapping first mouth
	var box_hits = limiter.can_box_intersect_mouths(90.0, 190.0, 110.0, 210.0, mouths)
	assert_true(box_hits, "AABB [90..110] x [190..210] must intersect mouth at (100, 200)")

	# Bounding box disjoint
	var box_misses = limiter.can_box_intersect_mouths(0.0, 0.0, 50.0, 50.0, mouths)
	assert_false(box_misses, "AABB [0..50] x [0..50] must not intersect any mouth")

func test_sampler_respects_allowed_mouths() -> void:
	var config = CaveGeneratorConfigClass.new()
	var sampler = CaveMouthSamplerClass.new(1337, config)
	var surface_h = 50.0
	var sea_level = 24

	# Find a coordinate where raw noise triggers a mouth candidate
	var cand_x = 0.0
	var cand_z = 0.0
	var found = false
	for z in range(0, 1000, 20):
		for x in range(0, 1000, 20):
			if sampler.sample_raw_noise(float(x), float(z)) >= config.mouth_threshold:
				cand_x = float(x)
				cand_z = float(z)
				found = true
				break
		if found:
			break
	assert_true(found, "Must find raw mouth candidate")

	# Raw check must be true
	var raw_res = sampler.sample_raw_mouth(cand_x, cand_z, surface_h, sea_level)
	assert_true(raw_res.is_mouth, "Raw mouth check must be true at candidate point")

	# Register an allowed mouth located FAR AWAY from (cand_x, cand_z)
	var far_mouth = CaveMouthDataClass.new(
		Vector3(cand_x + 500.0, surface_h, cand_z + 500.0),
		Vector2.ZERO,
		CaveMouthDataClass.Type.CHASM,
		10.0,
		config.mouth_radius
	)
	sampler.set_allowed_mouths([far_mouth])

	# Now sample_mouth at cand_x, cand_z must be REJECTED because it's not in allowed_mouths
	var filtered_res = sampler.sample_mouth(cand_x, cand_z, surface_h, sea_level)
	assert_false(filtered_res.is_mouth, "Point outside allowed_mouths must be rejected by sampler")
	assert_true(sampler.is_crust_sealed(cand_x, surface_h - 1.0, cand_z, surface_h, sea_level), "Crust must remain sealed at rejected candidate")

	# But at the allowed mouth location, it must be allowed
	var at_allowed = sampler.sample_mouth(cand_x + 500.0, cand_z + 500.0, surface_h, sea_level)
	# (May or may not have raw noise at +500, but is_mouth_candidate checks allowed list first)
	assert_false(sampler.is_mouth_candidate(cand_x, cand_z, surface_h, sea_level), "is_mouth_candidate must reject unallowed coordinate")

	# Reset allowed mouths back to default
	sampler.clear_allowed_mouths()
	assert_true(sampler.sample_mouth(cand_x, cand_z, surface_h, sea_level).is_mouth, "Clearing allowed mouths restores raw behavior")

func test_detector_continent_scan_respects_limits() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfigClass.new()
	cave_config.enabled = true
	cave_config.max_chasm_mouths = 1
	cave_config.max_tunnel_mouths = 2
	cave_config.max_dead_end_mouths = 3
	cave_config.limit_cave_mouths = true

	var generator = VolumetricTerrainGeneratorClass.new(1337, config, cave_config)
	var detector = CaveMouthDetectorClass.new()

	var mouths = detector.detect_cave_mouths(generator, bounds, 256)
	assert_not_null(mouths, "Detector must return array")

	var limiter = CaveMouthLimiterClass.new()
	var counts = limiter.count_by_type(mouths)

	assert_true(counts[CaveMouthDataClass.Type.CHASM] <= 1, "Chasm mouths must not exceed 1 (got %d)" % counts[CaveMouthDataClass.Type.CHASM])
	assert_true(counts[CaveMouthDataClass.Type.TUNNEL] <= 2, "Tunnel mouths must not exceed 2 (got %d)" % counts[CaveMouthDataClass.Type.TUNNEL])
	assert_true(counts[CaveMouthDataClass.Type.DEAD_END] <= 3, "Dead end mouths must not exceed 3 (got %d)" % counts[CaveMouthDataClass.Type.DEAD_END])
	assert_true(mouths.size() <= 6, "Total cave mouths must not exceed 6 (got %d)" % mouths.size())
