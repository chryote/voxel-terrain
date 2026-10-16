class_name TestFriendReviewImprovements
extends "res://tests/framework/test_case.gd"

## Unit test suite validating implementations of the feedback from review from a friend.md:
## 1. Fixing jagged steep peaks (fractal gain reduction + power curve exponent).
## 2. Removing inland water dips (inland elevation bias).
## 3. Decoupling sand from elevation (low-frequency climate moisture model).

const MacroTopographyClass = preload("res://src/generation/macro_topography.gd")
const ContinentMaskClass = preload("res://src/generation/continent_mask.gd")
const ClimateModelClass = preload("res://src/generation/climate_model.gd")
const TerrainMaterialClassifierClass = preload("res://src/generation/terrain_material_classifier.gd")
const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")

func test_mountain_fractal_gain_and_power_curve_smoothing() -> void:
	var config = ContinentGeneratorConfig.new()
	assert_true(config.mountain_fractal_gain <= 0.35, "Mountain fractal gain must be weakened (<= 0.35) to prevent noisy boulders and spikes")
	assert_true(config.mountain_power <= 1.8, "Mountain power curve exponent must be moderate (<= 1.8) to widen mountain base and round ridges")

	var mask = ContinentMaskClass.new(1337, config)
	var macro = MacroTopographyClass.new(1337, config, mask)
	assert_almost_eq(macro.mountain_noise.fractal_gain, config.mountain_fractal_gain, 0.001, "MacroTopography mountain_noise must apply configured fractal gain")

	# Check summit continuity across a 64m sample line through mountain peak
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var heights: Array[float] = []
	for step in range(64):
		var sample = macro.sample_macro(float(step * 2), 0.0, bounds)
		heights.append(sample.elevation)

	# Ensure height changes are continuous without NaN or invalid spikes
	for i in range(1, heights.size()):
		var step_diff = absf(heights[i] - heights[i - 1])
		assert_true(step_diff < 15.0, "Smoothed mountain ridges must not violently jump more than 15m in 2 meters (jump: %.2f)" % step_diff)

func test_inland_elevation_bias_prevents_sea_level_punctures() -> void:
	var config = ContinentGeneratorConfig.new()
	assert_true(config.inland_elevation_bias >= 5.0, "Inland elevation bias must be at least +5m to safely lift continental interior above sea level")

	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var gen = ContinentGenerator.new(4242, config)

	# Sample across the continent interior
	var tested_interior_points = 0
	for x in range(-20, 21, 2):
		for z in range(-20, 21, 2):
			var wx = float(x * 16)
			var wz = float(z * 16)
			var sample = gen.sample_world(wx, wz, bounds)

			# If point is inland and not carved by an intentional river or lake
			if sample.continentalness >= 0.20 and not sample.is_river and not sample.is_lake:
				tested_interior_points += 1
				assert_true(
					sample.height >= config.sea_level + 4,
					"Interior point (%.1f, %.1f) height %d must be comfortably above sea level %d (no accidental puddles)" % [wx, wz, sample.height, config.sea_level]
				)

	assert_true(tested_interior_points >= 50, "Must test at least 50 interior continental points")

func test_climate_model_moisture_distribution() -> void:
	var config = ContinentGeneratorConfig.new()
	var climate = ClimateModelClass.new(1234, config)

	var min_m = 1.0
	var max_m = 0.0

	for x in range(-20, 21, 4):
		for z in range(-20, 21, 4):
			var m = climate.sample_moisture(float(x * 100), float(z * 100))
			assert_true(m >= 0.0 and m <= 1.0, "Moisture must be normalized in [0.0, 1.0]")
			min_m = minf(min_m, m)
			max_m = maxf(max_m, m)

	assert_true(max_m > min_m, "Climate model must produce spatial moisture variation across the continent")
	assert_true(climate.is_humid(0.8), "0.8 moisture must be classified as humid")
	assert_false(climate.is_humid(0.2), "0.2 moisture must not be classified as humid")
	assert_true(climate.is_arid(0.2), "0.2 moisture must be classified as arid")

func test_sand_decoupling_from_elevation_via_moisture() -> void:
	var config = ContinentGeneratorConfig.new()
	var classifier = TerrainMaterialClassifierClass.new(config)

	# 1. Forest lake edge (elevated inland water table, high moisture)
	# h = 40, water_h = 40, is_lake = true, moisture = 0.85
	var forest_lake_mats = classifier.classify_v2i(40, 0, 40, false, true, 0.85)
	assert_eq(forest_lake_mats.x, MaterialDef.ID_GRASS, "Humid inland forest lake edge must spawn grass right to the water's edge")
	assert_eq(forest_lake_mats.y, MaterialDef.ID_DIRT, "Side material must be dirt")

	# 2. Arid inland lake edge (low moisture)
	# h = 40, water_h = 40, is_lake = true, moisture = 0.15
	var arid_lake_mats = classifier.classify_v2i(40, 0, 40, false, true, 0.15)
	assert_eq(arid_lake_mats.x, MaterialDef.ID_SAND, "Arid inland lake edge must spawn sand bank")

	# 3. Submerged lake bed
	var lake_bed = classifier.classify_v2i(38, 0, 40, false, true, 0.85)
	assert_eq(lake_bed.x, MaterialDef.ID_GRAVEL, "Submerged lake bed must be gravel")

	# 4. Coastal ocean beach (sea level + 1, normal moisture)
	var coastal_beach = classifier.classify_v2i(config.sea_level + 1, 0, config.sea_level, false, false, 0.50)
	assert_eq(coastal_beach.x, MaterialDef.ID_SAND, "Coastal ocean shoreline must retain sand beach")

func test_map_palette_moisture_integration() -> void:
	var palette = ContinentMapColorPaletteClass.new()

	# Humid forest lake edge: should be grass
	var humid_lake_color = palette.get_land_color(40, 0.1, 40, 24, 2, 125, 90, true, 0.85)
	assert_eq(humid_lake_color, palette.color_plains_grass, "Humid lake shore on map must be rendered as grass")

	# Arid lake edge: should be sand
	var arid_lake_color = palette.get_land_color(40, 0.1, 40, 24, 2, 125, 90, true, 0.20)
	assert_eq(arid_lake_color, palette.color_beach_sand, "Arid lake shore on map must be rendered as sand")

	# Ocean beach: should be sand
	var ocean_beach_color = palette.get_land_color(25, 0.1, 24, 24, 2, 125, 90, false, 0.50)
	assert_eq(ocean_beach_color, palette.color_beach_sand, "Ocean beach on map must be rendered as sand")
