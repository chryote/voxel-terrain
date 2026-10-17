class_name TestChasmAesthetics
extends "res://tests/framework/test_case.gd"

## Unit test suite for Phase 3: Mitigation Tuning & Aesthetics.
## Validates wall warp calibration (fracture faulting), subterranean material assignment
## (basalt lining and crystal veins), and subterranean water table isolation (zero mouth leakage).

func test_fracture_wall_warping_calibration() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler = UndergroundChasmSampler.new(1337, config)

	var decorrelated_count = 0
	var shear_roughness_count = 0
	var samples_checked = 0

	for i in range(100):
		var wx = float(i) * 5.7
		var wz = float(i) * 8.3
		var w1 = sampler.get_warped_coordinates(wx, wz)
		var w2 = sampler.get_warped_coordinates(wx + 2.0, wz)

		var disp1 = w1 - Vector2(wx, wz)
		var disp2 = w2 - Vector2(wx + 2.0, wz)

		samples_checked += 1

		# Decorrelation: X displacement and Z displacement must not be identical (avoids 45-degree diagonal bias)
		if absf(disp1.x - disp1.y) > 0.05:
			decorrelated_count += 1

		# Shear roughness from 2-octave FBM: differential perturbation across 2 meters
		if (disp2 - disp1).length() > 0.02:
			shear_roughness_count += 1

	assert_true(decorrelated_count > 80, "Warping must have decorrelated X and Z components (got %d/100)" % decorrelated_count)
	assert_true(shear_roughness_count > 60, "FBM must generate jagged shear differential across short distances (got %d/100)" % shear_roughness_count)

func test_subterranean_materials_in_chunk() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var config = gen.cave_config

	# 1. Locate an inland chunk (height > 30) that intersects an active chasm
	var target_coord: ChunkCoord = null
	var col = ChasmColumnResult.new()

	for cz in range(0, 16):
		for cx in range(0, 16):
			var col_pos = Vector2i(cx * 16 + 8, cz * 16 + 8)
			if gen.height_at(col_pos, bounds) < 30:
				continue

			var wx = (float(col_pos.x) + 0.5) * bounds.voxel_size
			var wz = (float(col_pos.y) + 0.5) * bounds.voxel_size
			gen.cave_carver.sample_chasm_column(wx, wz, col)

			if col.is_chasm and not col.is_pillar:
				target_coord = ChunkCoord.new(cx, cz)
				break
		if target_coord != null:
			break

	assert_not_null(target_coord, "Must locate an inland chunk coordinate containing active chasm void")

	var s_data = gen.generate_surface(target_coord, bounds)
	var v_data = gen.generate_subterranean(s_data, target_coord, bounds)
	assert_not_null(v_data, "Subterranean generation must succeed")

	# Validate material assignments in target chunk:
	# 1. Bedrock (Y <= 2) must remain solid stone
	for lz in range(16):
		for lx in range(16):
			for ly in range(0, 3):
				assert_eq(v_data.get_voxel(lx, ly, lz), MaterialDef.ID_STONE, "Bedrock must remain solid stone")

	# 2. Chasm basin floor and walls must be lined with basalt
	var found_basalt = false
	var found_crystal = false
	for lz in range(16):
		for lx in range(16):
			for ly in range(3, config.chasm_max_y + 1):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == MaterialDef.ID_CHASM_BASALT:
					found_basalt = true
				elif mat == MaterialDef.ID_CAVE_CRYSTAL:
					found_crystal = true

	assert_true(found_basalt, "Chasm basin floor and walls must be lined with basalt")

	# 3. Test direct crystal vein generator in CaveCarver
	var crystal_found = false
	for wx_step in range(0, 200, 4):
		for wz_step in range(0, 200, 4):
			for wy_step in range(config.chasm_water_level + 2, config.chasm_max_y):
				var mat = gen.cave_carver.classify_subterranean_voxel(float(wx_step), float(wy_step), float(wz_step))
				if mat == MaterialDef.ID_CAVE_CRYSTAL:
					crystal_found = true
					break
			if crystal_found:
				break
		if crystal_found:
			break

	assert_true(crystal_found, "CaveCarver crystal generator must produce ID_CAVE_CRYSTAL in chasm strata")

func test_water_table_pooling_and_mouth_leakage_safety() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var cave_config = CaveGeneratorConfig.new()
	cave_config.mouth_threshold = 0.2
	cave_config.mouth_radius = 8.0
	var gen = LayeredTerrainGenerator.new(1337, null, cave_config)
	var config = gen.cave_config
	var sea_level = gen.config.sea_level

	var water_voxels_checked = 0
	var dry_funnel_points_checked = 0

	# 1. Scan across chunk grid to locate a cave mouth chunk
	var mouth_coord: ChunkCoord = null
	for cz in range(0, 10):
		for cx in range(0, 10):
			var c = ChunkCoord.new(cx, cz)
			var s_data = gen.generate_surface(c, bounds)
			if s_data.has_cave_mouth:
				mouth_coord = c
				break
		if mouth_coord != null:
			break

	assert_not_null(mouth_coord, "Must locate a chunk containing a surface cave mouth entrance")
	if mouth_coord == null:
		return

	# Generate subterranean data for the cave mouth chunk
	var s_data_mouth = gen.generate_surface(mouth_coord, bounds)
	var v_data_mouth = gen.generate_subterranean(s_data_mouth, mouth_coord, bounds)


	# 2. Check all columns inside the mouth chunk
	for lz in range(16):
		for lx in range(16):
			var col_h = float(s_data_mouth.get_height(lx, lz))
			var gx = mouth_coord.x * 16 + lx
			var gz = mouth_coord.z * 16 + lz
			var wx = (float(gx) + 0.5) * bounds.voxel_size
			var wz = (float(gz) + 0.5) * bounds.voxel_size

			# Check subterranean water heights
			for ly in range(0, 32):
				if v_data_mouth.has_water(lx, ly, lz):
					water_voxels_checked += 1
					if ly < int(col_h):
						assert_true(
							ly <= config.chasm_water_level,
							"Subterranean water voxel at Y=%d must never exceed chasm_water_level (%d)" % [ly, config.chasm_water_level]
						)

			# Verify cave entrance mouth funnels are dry and well above subterranean water
			var mouth_info = gen.cave_carver.mouth_sampler.sample_mouth(wx, wz, col_h, sea_level)
			if mouth_info.is_mouth:
				dry_funnel_points_checked += 1
				var funnel_bottom = mouth_info.bottom_y
				assert_true(
					funnel_bottom > float(config.chasm_water_level),
					"Cave mouth funnel bottom (%f) must be strictly above subterranean water level (%d)" % [funnel_bottom, config.chasm_water_level]
				)
				# Entrance descent must be hollow dry air, never water
				for fy in range(config.chasm_water_level + 1, int(col_h) + 1):
					assert_false(v_data_mouth.has_water(lx, fy, lz), "Funnel descent must be dry air, never flooded")

	assert_true(dry_funnel_points_checked > 0, "Must inspect cave entrance funnel points")
