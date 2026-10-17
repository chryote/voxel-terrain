class_name RegCaveMouthLimits
extends "res://tests/framework/regression_case.gd"

## Regression test suite for Cave Mouth Generation Limits:
## Verifies that cave mouth limits (max 1 chasm, max 2 tunnel, max 3 dead end)
## are strictly enforced and yield identical, deterministic golden snapshots
## across seeds and game versions.

const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthLimiterClass = preload("res://src/generation/caves/cave_mouth_limiter.gd")
const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const VolumetricTerrainGeneratorClass = preload("res://src/generation/volumetric_terrain_generator.gd")
const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")

var update_golden: bool = false

func test_cave_mouth_limits_regression() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var limiter = CaveMouthLimiterClass.new()
	var detector = CaveMouthDetectorClass.new()

	var seeds = [1337, 4242, 9999]
	var snapshot: Dictionary = {}

	for seed_val in seeds:
		var cont_config = ContinentGeneratorConfig.new()
		var cave_config = CaveGeneratorConfigClass.new()
		cave_config.enabled = true
		cave_config.limit_cave_mouths = true
		cave_config.max_chasm_mouths = 1
		cave_config.max_tunnel_mouths = 2
		cave_config.max_dead_end_mouths = 3

		var generator = VolumetricTerrainGeneratorClass.new(seed_val, cont_config, cave_config)
		var mouths = detector.detect_cave_mouths(generator, bounds, 256)
		var counts = limiter.count_by_type(mouths)

		# Hard invariant assertions
		assert_true(counts[CaveMouthDataClass.Type.CHASM] <= 1, "Seed %d: chasm count must be <= 1" % seed_val)
		assert_true(counts[CaveMouthDataClass.Type.TUNNEL] <= 2, "Seed %d: tunnel count must be <= 2" % seed_val)
		assert_true(counts[CaveMouthDataClass.Type.DEAD_END] <= 3, "Seed %d: dead end count must be <= 3" % seed_val)
		assert_true(mouths.size() <= 6, "Seed %d: total mouths must be <= 6" % seed_val)

		var mouths_dict: Dictionary = {}
		for i in range(mouths.size()):
			var m = mouths[i]
			mouths_dict["mouth_%d" % i] = {
				"type": float(m.type),
				"type_name": CaveMouthDataClass.get_type_name(m.type),
				"world_x": snappedf(m.world_pos.x, 0.01),
				"world_y": snappedf(m.world_pos.y, 0.01),
				"world_z": snappedf(m.world_pos.z, 0.01),
				"depth": snappedf(m.depth, 0.01),
				"radius": snappedf(m.radius, 0.01)
			}

		snapshot["seed_%d" % seed_val] = {
			"total_mouths": float(mouths.size()),
			"chasm_count": float(counts[CaveMouthDataClass.Type.CHASM]),
			"tunnel_count": float(counts[CaveMouthDataClass.Type.TUNNEL]),
			"dead_end_count": float(counts[CaveMouthDataClass.Type.DEAD_END]),
			"mouths": mouths_dict
		}

	# Also test a tuned limits scenario (0 chasm, 1 tunnel, 2 dead end)
	var tuned_cave_config = CaveGeneratorConfigClass.new()
	tuned_cave_config.enabled = true
	tuned_cave_config.limit_cave_mouths = true
	tuned_cave_config.max_chasm_mouths = 0
	tuned_cave_config.max_tunnel_mouths = 1
	tuned_cave_config.max_dead_end_mouths = 2

	var tuned_gen = VolumetricTerrainGeneratorClass.new(1337, ContinentGeneratorConfig.new(), tuned_cave_config)
	var tuned_mouths = detector.detect_cave_mouths(tuned_gen, bounds, 256)
	var tuned_counts = limiter.count_by_type(tuned_mouths)

	assert_eq(tuned_counts[CaveMouthDataClass.Type.CHASM], 0, "Tuned chasm count must be 0")
	assert_true(tuned_counts[CaveMouthDataClass.Type.TUNNEL] <= 1, "Tuned tunnel count must be <= 1")
	assert_true(tuned_counts[CaveMouthDataClass.Type.DEAD_END] <= 2, "Tuned dead end count must be <= 2")

	snapshot["tuned_seed_1337"] = {
		"total_mouths": float(tuned_mouths.size()),
		"chasm_count": float(tuned_counts[CaveMouthDataClass.Type.CHASM]),
		"tunnel_count": float(tuned_counts[CaveMouthDataClass.Type.TUNNEL]),
		"dead_end_count": float(tuned_counts[CaveMouthDataClass.Type.DEAD_END])
	}

	assert_golden("cave_mouth_limits", snapshot, update_golden)
