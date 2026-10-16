class_name TestRealisticTopography
extends "res://tests/framework/test_case.gd"

## Comprehensive unit test suite for realistic 2D procedural topography features:
## 1. Coast
## 2. Lowland
## 3. Rolling Hills
## 4. Highland Plateaus
## 5. Mountainous Region
## 6. Small Winding River
## 7. Wide River
## 8. Lakes
## + Determinism and Height Bounds

func test_feature_1_coastal_transition_and_beaches() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(4242, config)

	# Sample across the continent from ocean border to inland
	var found_beach_sand = false
	var found_shallow_seabed = false

	for step in range(0, 100):
		var wx = bounds.min_world_x + float(step) * 10.0
		var wz = 0.0
		var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
		var h = gen.height_at(col, bounds)

		if h < config.sea_level:
			found_shallow_seabed = true
		if h >= config.sea_level and h <= config.sea_level + config.sand_height_offset + 1:
			found_beach_sand = true

	assert_true(found_shallow_seabed, "Must feature shallow seabed near coastal waters")
	assert_true(found_beach_sand, "Must feature sand beach near coastline sea level transition")

func test_feature_2_lowlands_flat_terrain() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(1337, config)

	# Find a chunk in the lowland zone (moderate continentalness, not highland/mountain/river)
	var target_coord: ChunkCoord = null
	for r in range(4, 15):
		for dx in [-r, r]:
			for dz in range(-r, r + 1):
				var sample = gen.sample_world(float(dx * 32), float(dz * 32), bounds)
				if sample.continentalness >= 0.18 and sample.continentalness <= 0.45 and not sample.is_highland and not sample.is_river and not sample.is_lake and not sample.is_water:
					target_coord = ChunkCoord.new(dx, dz)
					break
			if target_coord != null:
				break
		if target_coord != null:
			break

	assert_not_null(target_coord, "Must find lowland candidate chunk")
	var data = gen.generate(target_coord, bounds)

	var found_grass = false
	var in_lowland_elevation = true

	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			var h = data.get_height(lx, lz)
			var top_mat = data.get_top_material(lx, lz)
			if top_mat == MaterialDef.ID_GRASS:
				found_grass = true
			if h < config.sea_level or h > config.sea_level + 45:
				in_lowland_elevation = false

	assert_true(found_grass, "Lowlands must feature grass surface material")
	assert_true(in_lowland_elevation, "Lowlands must stay within gentle low elevation bounds")

func test_feature_3_rolling_hills_undulations() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(2026, config)

	# Find an area with rolling hills
	var center_wx = 0.0
	var center_wz = 0.0
	var found_hills_zone = false

	for dx in range(-15, 16):
		for dz in range(-15, 16):
			var wx = float(dx * 20)
			var wz = float(dz * 20)
			var sample = gen.sample_world(wx, wz, bounds)
			if sample.continentalness >= 0.20 and sample.continentalness <= 0.60 and not sample.is_highland and not sample.is_river and not sample.is_lake and not sample.is_water:
				center_wx = wx
				center_wz = wz
				found_hills_zone = true
				break
		if found_hills_zone:
			break

	assert_true(found_hills_zone, "Must find rolling hills zone")

	# Sample a 32-meter transect and verify smooth undulating variance
	var heights: Array[int] = []
	for step in range(32):
		var col = bounds.world_to_column(Vector3(center_wx + float(step), 0.0, center_wz))
		heights.append(gen.height_at(col, bounds))

	var min_h = heights[0]
	var max_h = heights[0]
	var max_step = 0
	for i in range(1, heights.size()):
		min_h = mini(min_h, heights[i])
		max_h = maxi(max_h, heights[i])
		max_step = maxi(max_step, absi(heights[i] - heights[i - 1]))

	assert_true(max_h > min_h, "Rolling hills must have undulating height relief")
	assert_true(max_step <= 5, "Rolling hills must have gentle slopes without extreme vertical cliff walls (max_step: %d)" % max_step)

func test_feature_4_highland_plateaus_and_escarpments() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(9999, config)

	# Search central continent for highland plateau elevation and stone cliff escarpments
	var found_highland_elevation = false
	var found_stone_escarpment = false

	for cx in range(-2, 3):
		for cz in range(-2, 3):
			var data = gen.generate(ChunkCoord.new(cx, cz), bounds)
			for lz in range(data.chunk_size):
				for lx in range(data.chunk_size):
					var h = data.get_height(lx, lz)
					var side_mat = data.get_side_material(lx, lz)
					if h >= config.sea_level + 45:
						found_highland_elevation = true
					if side_mat == MaterialDef.ID_STONE:
						found_stone_escarpment = true
			if found_highland_elevation and found_stone_escarpment:
				break
		if found_highland_elevation and found_stone_escarpment:
			break

	assert_true(found_highland_elevation, "Highlands must produce elevated plateau terrain")
	assert_true(found_stone_escarpment, "Highland escarpments and steep grades must produce stone cliff walls")

func test_feature_5_mountainous_regions_and_snow_caps() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(5555, config)

	# Check mountainous chunks across continental core
	var max_elevation = 0
	var found_stone = false
	var found_snow = false

	for cx in [-3, -1, 0, 1, 3]:
		for cz in [-3, -1, 0, 1, 3]:
			var data = gen.generate(ChunkCoord.new(cx, cz), bounds)
			for lz in range(data.chunk_size):
				for lx in range(data.chunk_size):
					var h = data.get_height(lx, lz)
					var top_mat = data.get_top_material(lx, lz)
					var side_mat = data.get_side_material(lx, lz)
					max_elevation = maxi(max_elevation, h)
					if top_mat == MaterialDef.ID_STONE or side_mat == MaterialDef.ID_STONE:
						found_stone = true
					if top_mat == MaterialDef.ID_SNOW:
						found_snow = true
			if found_stone and (found_snow or max_elevation >= config.snow_height - 10):
				break
		if found_stone and (found_snow or max_elevation >= config.snow_height - 10):
			break

	assert_true(max_elevation >= 80, "Mountainous regions must reach high alpine elevation (max: %d)" % max_elevation)
	assert_true(found_stone, "Mountainous summit chunk must feature exposed stone ridges or faces")
	assert_true(found_snow or max_elevation >= config.snow_height - 10, "Alpine heights must feature snow caps")

func test_feature_6_small_winding_river() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(8888, config)

	var found_small_river = false
	var carve_depth_valid = false
	var riverbed_mat_valid = false

	# Search for a small river coordinate
	for step in range(-150, 150, 2):
		var wx = float(step) * 4.0
		var wz = float(step) * 6.0
		var sample = gen.sample_world(wx, wz, bounds)
		if sample.is_small_river and sample.carve_depth >= 1.0:
			found_small_river = true
			if sample.carve_depth <= config.small_river_depth + 1.0:
				carve_depth_valid = true

			var chunk_c = bounds.world_to_chunk(Vector3(wx, 0.0, wz))
			var chunk_data = gen.generate(chunk_c, bounds)
			var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
			var lx = col.x - chunk_c.x * bounds.chunk_size
			var lz = col.y - chunk_c.z * bounds.chunk_size
			var top_mat = chunk_data.get_top_material(lx, lz)
			if top_mat in [MaterialDef.ID_GRAVEL, MaterialDef.ID_SAND, MaterialDef.ID_SEABED]:
				riverbed_mat_valid = true
			break

	assert_true(found_small_river, "Fluvial system must carve small winding rivers")
	assert_true(carve_depth_valid, "Small river carve depth must match small stream configuration")
	assert_true(riverbed_mat_valid, "Small river bed must be classified with gravel/sand/seabed")

func test_feature_7_wide_river() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(8888, config)

	var found_wide_river = false
	var deep_carve = false
	var wide_profile = false

	for step in range(-150, 150, 3):
		var wx = float(step) * 8.0
		var wz = float(step) * 4.0
		var sample = gen.sample_world(wx, wz, bounds)
		if sample.is_wide_river and sample.carve_depth >= 3.0:
			found_wide_river = true
			if sample.carve_depth >= 5.0:
				deep_carve = true

			# Check broad width across perpendicular cross section
			var channel_points = 0
			for offset in range(-12, 13, 2):
				var check_sample = gen.sample_world(wx + float(offset), wz - float(offset), bounds)
				if check_sample.is_river and check_sample.carve_depth >= 1.5:
					channel_points += 1
			if channel_points >= 4:
				wide_profile = true
			break

	assert_true(found_wide_river, "Fluvial system must generate wide river channels")
	assert_true(deep_carve, "Wide rivers must carve deep river valleys (carve >= 5m)")
	assert_true(wide_profile, "Wide rivers must feature a broad cross-sectional channel profile")

func test_feature_8_lakes() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(7777, config)

	var found_lake = false
	var found_water = false
	var lake_basin_depression = false

	for gx in range(-80, 80, 5):
		for gz in range(-80, 80, 5):
			var wx = float(gx) * 10.0
			var wz = float(gz) * 10.0
			var sample = gen.sample_world(wx, wz, bounds)
			if sample.is_lake and sample.carve_depth >= 2.0:
				found_lake = true
				if sample.is_water:
					found_water = true
				if sample.water_height > sample.height:
					lake_basin_depression = true
				break
		if found_lake:
			break

	assert_true(found_lake, "Fluvial system must generate lake basin depressions")
	assert_true(found_water, "Lake basins must calculate water level above carved terrain")
	assert_true(lake_basin_depression, "Lake water elevation must strictly exceed carved basin ground")

func test_determinism_and_height_bounds() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen1 = ContinentGenerator.new(1337, config)
	var gen2 = ContinentGenerator.new(1337, config)

	var coord = ChunkCoord.new(3, 4)
	var data1 = gen1.generate(coord, bounds)
	var data2 = gen2.generate(coord, bounds)

	# Verify bit-for-bit determinism
	assert_eq(data1.heights, data2.heights, "Identical seeds must produce identical heights")
	assert_eq(data1.water_heights, data2.water_heights, "Identical seeds must produce identical water heights")
	assert_eq(data1.top_material, data2.top_material, "Identical seeds must produce identical top materials")
	assert_eq(data1.side_material, data2.side_material, "Identical seeds must produce identical side materials")

	# Verify global bounds
	for h in data1.heights:
		assert_true(h >= config.seabed_level, "Heights must never be below seabed level")
		assert_true(h <= 255, "Heights must never exceed 255")
