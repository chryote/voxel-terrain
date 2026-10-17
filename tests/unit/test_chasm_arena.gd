class_name TestChasmArena
extends "res://tests/framework/test_case.gd"

## Unit test suite for Phase 2.2: Chasm Arena POI Anchor System.
## Validates procedural generation of wide, flat subterranean battle arenas,
## suppression of random pillars in the combat zone, stepped perimeter spectator ledges,
## and vaulted high ceiling domes.

func test_arena_trigger_and_flattened_floor() -> void:
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = true
	config.arena_rift_threshold = 0.80
	config.arena_floor_y = 6
	config.arena_ceiling_y = 28
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	var found_core_arena = false
	var found_perimeter_ledge = false

	var max_raw_rift = 0.0
	for ix in range(-200, 200, 4):
		for iz in range(-200, 200, 4):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			var r = sampler.sample_rift_mask(wx, wz)
			max_raw_rift = maxf(max_raw_rift, r)

			sampler.sample_column(wx, wz, col)

			if col.is_arena:
				assert_true(col.is_chasm, "Arena columns must be active chasm voids")
				assert_true(col.raw_rift >= 0.80, "Arena raw_rift must be >= 0.80")

				if col.raw_rift >= 0.82:
					found_core_arena = true
					assert_false(col.is_arena_ledge, "Core combat arena must not be marked as ledge")
					assert_eq(col.floor_y, config.arena_floor_y, "Combat arena floor must be flattened to arena_floor_y (6)")
					assert_true(col.ceil_y >= config.arena_ceiling_y, "Ceiling dome must reach arena_ceiling_y (28)")
				else:
					found_perimeter_ledge = true
					assert_true(col.is_arena_ledge, "Perimeter zone must be marked as arena ledge")
					assert_true(col.floor_y >= 3, "Perimeter ledge must remain above bedrock")

			if found_core_arena and found_perimeter_ledge:
				break
		if found_core_arena and found_perimeter_ledge:
			break

	assert_true(found_core_arena, "Must locate core combat arena with flattened floor")
	assert_true(found_perimeter_ledge, "Must locate stepped perimeter spectator ledges")

func test_arena_pillar_suppression() -> void:
	## Validates that within the core combat arena,
	## random support pillars are strictly suppressed so the battle floor is clear.
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = true
	config.arena_rift_threshold = 0.80
	config.arena_floor_y = 6
	config.arena_ceiling_y = 28
	config.pillar_threshold = 0.1 # Very low pillar threshold to force pillars everywhere
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	# 1. Locate arena center
	var arena_center: Vector2 = Vector2.ZERO
	var found = false
	for ix in range(-200, 200, 4):
		for iz in range(-200, 200, 4):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			sampler.sample_column(wx, wz, col)
			if col.is_arena and col.raw_rift >= (config.arena_rift_threshold + 0.02):
				arena_center = Vector2(wx, wz)
				found = true
				break
		if found:
			break

	assert_true(found, "Must locate core combat arena")

	# 2. Test neighborhood columns inside the combat zone
	var tested_core_columns = 0
	for dx in range(-15, 16, 2):
		for dz in range(-15, 16, 2):
			var wx = arena_center.x + float(dx)
			var wz = arena_center.y + float(dz)
			sampler.sample_column(wx, wz, col)

			if col.is_arena and col.raw_rift >= (config.arena_rift_threshold + 0.02):
				tested_core_columns += 1
				assert_false(col.is_pillar, "Support pillars must be suppressed in combat arena pit at (%f, %f)" % [wx, wz])
				# Point-query carve check: middle combat elevation (Y=18) must be open air
				assert_eq(sampler.get_chasm_carve(wx, 18.0, wz), 1.0, "Combat zone must be open air void")

	assert_true(tested_core_columns >= 10, "Must test core arena columns for pillar suppression (tested %d)" % tested_core_columns)

func test_arena_disabled_toggle() -> void:
	var config = CaveGeneratorConfig.new()
	config.arena_enabled = false
	var sampler = UndergroundChasmSampler.new(1337, config)
	var col = ChasmColumnResult.new()

	for ix in range(-100, 100, 5):
		for iz in range(-100, 100, 5):
			var wx = float(ix) * 5.0
			var wz = float(iz) * 5.0
			sampler.sample_column(wx, wz, col)
			assert_false(col.is_arena, "Arena flags must be false when arena_enabled is false")
			assert_false(sampler.is_arena(wx, wz), "is_arena must return false when arena_enabled is false")

func test_ocean_falloff_encasing() -> void:
	## Validates that chasms and arenas are 100% encased with solid rock curtain walls
	## facing the continental ocean fall-off and never puncture the ocean plane.
	var world_config = WorldConfig.new()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var bounds = world_config.create_world_bounds()
	var cont_gen = ContinentGenerator.new(1337, gen_config)
	var sampler = UndergroundChasmSampler.new(1337, cave_config)
	sampler.set_continent_mask(cont_gen.mask, bounds)

	var col = ChasmColumnResult.new()

	# 1. Verify that ocean columns (land_raw < 0.08) have zero chasm density and zero carve
	var ocean_samples = 0
	for cz in range(bounds.min_chunk_z + 2, bounds.max_chunk_z - 2, 8):
		for cx in range(bounds.min_chunk_x + 2, bounds.max_chunk_x - 2, 8):
			var wx = float(cx * bounds.chunk_size + 16) * bounds.voxel_size
			var wz = float(cz * bounds.chunk_size + 16) * bounds.voxel_size
			var land = cont_gen.mask.get_land_raw(wx, wz, bounds)
			if land < 0.08:
				ocean_samples += 1
				var rift = sampler.sample_rift_mask(wx, wz)
				assert_eq(rift, 0.0, "Ocean rift density must be 0.0 at land=%.3f" % land)
				sampler.sample_column(wx, wz, col)
				assert_false(col.is_chasm, "Chasm must be false in ocean falloff")
				assert_false(col.is_arena, "Arena must be false in ocean falloff")
				assert_eq(sampler.get_chasm_carve(wx, 10.0, wz), 0.0, "Carve density must be 0.0 in ocean")

	assert_true(ocean_samples > 20, "Should have tested at least 20 ocean samples")

	# 2. Verify encasing at chunk (33, 57) boundary facing ocean chunk (33, 58)
	var start_p = Vector3(1073.1, 4.0, 1851.2)
	var dir = Vector3(-0.5, 0.0, 0.866).normalized()
	var hit_wall = false
	var hit_d = 0.0
	for d in range(1, 20):
		var p = start_p + dir * float(d)
		sampler.sample_column(p.x, p.z, col)
		if not col.is_chasm:
			hit_wall = true
			hit_d = float(d)
			break

	assert_true(hit_wall, "Cavern near chunk (33, 57) must hit solid encasing wall towards ocean")
	assert_true(hit_d <= 5.0, "Wall encasing must seal cave within 5 meters of margin (hit at %.1f m)" % hit_d)
