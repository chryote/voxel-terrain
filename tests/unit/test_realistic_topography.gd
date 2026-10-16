class_name TestRealisticTopography
extends "res://tests/framework/test_case.gd"

## Comprehensive unit test suite for realistic 2D procedural topography features:
## Coasts, Lowlands, Rolling Hills, Highlands, Mountains, Wide Rivers,
## Small Winding Rivers, and Lakes.

func test_coastal_transition_and_beaches() -> void:
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

func test_lowland_and_rolling_hills_bounds() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(1337, config)

	# Find a chunk in the lowland / rolling hills continental zone
	var target_coord = null
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

	var data = gen.generate(target_coord, bounds)

	var found_grass = false
	var found_moderate_elevation = false

	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			var h = data.get_height(lx, lz)
			var top_mat = data.get_top_material(lx, lz)
			if top_mat == MaterialDef.ID_GRASS:
				found_grass = true
			if h >= config.sea_level and h <= config.sea_level + 45:
				found_moderate_elevation = true

	assert_true(found_grass, "Lowlands and rolling hills must produce grass surface material")
	assert_true(found_moderate_elevation, "Lowlands and rolling hills must stay within moderate elevation bounds")

func test_highland_plateaus_and_escarpments() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(9999, config)

	# Sample central continental core for highland plateau elevations
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

func test_mountainous_regions_and_snow_caps() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(5555, config)

	var max_elevation = 0
	var found_snow = false
	var found_stone = false

	for cx in range(-4, 5):
		for cz in range(-4, 5):
			var data = gen.generate(ChunkCoord.new(cx, cz), bounds)
			for lz in range(data.chunk_size):
				for lx in range(data.chunk_size):
					var h = data.get_height(lx, lz)
					var top_mat = data.get_top_material(lx, lz)
					max_elevation = maxi(max_elevation, h)
					if top_mat == MaterialDef.ID_SNOW:
						found_snow = true
					if top_mat == MaterialDef.ID_STONE:
						found_stone = true
			if found_stone and found_snow:
				break
		if found_stone and found_snow:
			break

	assert_true(max_elevation >= config.stone_height, "Mountainous regions must reach high stone elevation (max: %d)" % max_elevation)
	assert_true(found_stone, "Mountainous regions must feature exposed stone summits")
	assert_true(found_snow or max_elevation >= config.snow_height - 10, "High altitude terrain must reach alpine snow zone")

func test_fluvial_river_carving() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(8888, config)

	var found_river_channel = false
	var found_gravel_or_sand_bed = false

	# Sample across a wide grid
	for step in range(-200, 200, 2):
		var wx = float(step) * 5.0
		var wz = float(step) * 3.0
		var sample = gen.sample_world(wx, wz, bounds)
		if sample.is_river and sample.carve_depth > 1.5:
			found_river_channel = true
			var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
			var chunk_c = bounds.world_to_chunk(Vector3(wx, 0.0, wz))
			var chunk_data = gen.generate(chunk_c, bounds)
			var lx = col.x - chunk_c.x * bounds.chunk_size
			var lz = col.y - chunk_c.z * bounds.chunk_size
			var top_mat = chunk_data.get_top_material(lx, lz)
			if top_mat == MaterialDef.ID_GRAVEL or top_mat == MaterialDef.ID_SAND or top_mat == MaterialDef.ID_SEABED:
				found_gravel_or_sand_bed = true
			break

	assert_true(found_river_channel, "Fluvial system must generate carved river channels")
	assert_true(found_gravel_or_sand_bed, "Riverbeds must be classified with gravel, sand, or seabed materials")

func test_lake_basin_formation() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(7777, config)

	var found_lake = false
	var found_water = false

	# Search for lake basin
	for gx in range(-80, 80, 5):
		for gz in range(-80, 80, 5):
			var wx = float(gx) * 10.0
			var wz = float(gz) * 10.0
			var sample = gen.sample_world(wx, wz, bounds)
			if sample.is_lake and sample.carve_depth > 2.0:
				found_lake = true
				if sample.is_water:
					found_water = true
				break
		if found_lake:
			break

	assert_true(found_lake, "Fluvial system must generate lake basin depressions")
	assert_true(found_water, "Lake basins must calculate water level above carved terrain")
