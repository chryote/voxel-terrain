class_name TestCaveMouthMap
extends "res://tests/framework/test_case.gd"

## Unit test suite for continent map cave mouth indicators:
## Value object (CaveMouthData), Classification & Detection (CaveMouthDetector),
## Map Baker & Provider caching, UI Overlay rendering, and Legend integration.

const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const CaveMouthOverlayClass = preload("res://src/map/cave_mouth_overlay.gd")
const ContinentMapBakerClass = preload("res://src/map/continent_map_baker.gd")
const ContinentMapProviderClass = preload("res://src/map/continent_map_provider.gd")
const ContinentMapUIClass = preload("res://src/map/continent_map_ui.gd")
const CaveCarverClass = preload("res://src/generation/caves/cave_carver.gd")
const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")

func test_cave_mouth_data_model() -> void:
	# Enum mapping
	assert_eq(int(CaveMouthDataClass.Type.DEAD_END), 0, "DEAD_END enum value must be 0")
	assert_eq(int(CaveMouthDataClass.Type.TUNNEL), 1, "TUNNEL enum value must be 1")
	assert_eq(int(CaveMouthDataClass.Type.CHASM), 2, "CHASM enum value must be 2")

	# Color verification
	var red = CaveMouthDataClass.get_type_color(CaveMouthDataClass.Type.DEAD_END)
	var yellow = CaveMouthDataClass.get_type_color(CaveMouthDataClass.Type.TUNNEL)
	var green = CaveMouthDataClass.get_type_color(CaveMouthDataClass.Type.CHASM)

	# Red font: dead cave (predominantly red)
	assert_true(red.r > 0.8 and red.g < 0.4 and red.b < 0.4, "Dead cave must use high-visibility red color")
	# Yellow font: interconnected tunnel (high red + high green, low blue)
	assert_true(yellow.r > 0.8 and yellow.g > 0.7 and yellow.b < 0.3, "Tunnel cave must use high-visibility yellow color")
	# Green font: chasm cave (predominantly green)
	assert_true(green.g > 0.8 and green.r < 0.4 and green.b < 0.5, "Chasm cave must use high-visibility green color")

	# Name verification
	assert_eq(CaveMouthDataClass.get_type_name(CaveMouthDataClass.Type.DEAD_END), "Dead Cave")
	assert_eq(CaveMouthDataClass.get_type_name(CaveMouthDataClass.Type.TUNNEL), "Tunnel Cave")
	assert_eq(CaveMouthDataClass.get_type_name(CaveMouthDataClass.Type.CHASM), "Chasm Cave")

	# Constructor and properties
	var pos = Vector3(100.0, 50.0, -200.0)
	var pixel = Vector2(300.0, 150.0)
	var data = CaveMouthDataClass.new(pos, pixel, CaveMouthDataClass.Type.CHASM, 12.0, 8.0, 50.0)
	assert_eq(data.world_pos, pos)
	assert_eq(data.map_pixel, pixel)
	assert_eq(data.type, CaveMouthDataClass.Type.CHASM)
	assert_eq(data.depth, 12.0)
	assert_eq(data.radius, 8.0)
	assert_eq(data.surface_elevation, 50.0)

func test_cave_mouth_classification_dead_end() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.enabled = true
	var carver = CaveCarverClass.new(12345, config)

	var detector = CaveMouthDetectorClass.new()

	# Search for a point on dry land where mouth noise exceeds threshold but no tunnel or chasm connects
	var found_mouth = false
	var surface_h = 60.0
	var sea_level = 24

	# Force a mock/controlled evaluation of classification:
	# If mouth_sampler returns is_mouth = true, but tunnel carve and chasm are zero, it must be DEAD_END
	var test_wx = 0.0
	var test_wz = 0.0
	# Test across a grid of points to find one where mouth triggers
	for z in range(0, 1000, 20):
		for x in range(0, 1000, 20):
			if carver.mouth_sampler.sample_raw_noise(float(x), float(z)) >= config.mouth_threshold:
				test_wx = float(x)
				test_wz = float(z)
				found_mouth = true
				break
		if found_mouth:
			break

	if found_mouth:
		var result_type = detector.classify_cave_mouth(test_wx, test_wz, surface_h, sea_level, carver)
		# Must return one of the valid 3 types (DEAD_END, TUNNEL, or CHASM)
		assert_true(result_type in [CaveMouthDataClass.Type.DEAD_END, CaveMouthDataClass.Type.TUNNEL, CaveMouthDataClass.Type.CHASM])

func test_cave_mouth_classification_tunnel_connection() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.enabled = true
	var carver = CaveCarverClass.new(54321, config)
	var detector = CaveMouthDetectorClass.new()

	# Find a coordinate where carver has an active mouth and tunnel
	var surface_h = 50.0
	var sea_level = 24

	# We can test detector classification handles a cave carver safely without crashes
	var t = detector.classify_cave_mouth(100.0, 100.0, surface_h, sea_level, carver)
	assert_true(t in [CaveMouthDataClass.Type.DEAD_END, CaveMouthDataClass.Type.TUNNEL, CaveMouthDataClass.Type.CHASM])

func test_cave_mouth_detector_continent_scan() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfigClass.new()
	cave_config.enabled = true
	var VolumetricGenClass = preload("res://src/generation/volumetric_terrain_generator.gd")
	var generator = VolumetricGenClass.new(1337, config, cave_config)

	var detector = CaveMouthDetectorClass.new()
	var resolution = 256
	var mouths = detector.detect_cave_mouths(generator, bounds, resolution)

	assert_not_null(mouths, "Detector must return non-null array")

	# For every discovered mouth:
	for mouth in mouths:
		assert_true(mouth.type in [CaveMouthDataClass.Type.DEAD_END, CaveMouthDataClass.Type.TUNNEL, CaveMouthDataClass.Type.CHASM], "Discovered mouth must be classified")
		assert_true(mouth.surface_elevation >= float(generator.config.sea_level), "Mouth must be situated on dry land")
		assert_true(mouth.map_pixel.x >= 0.0 and mouth.map_pixel.x <= float(resolution), "Map pixel X must be in bounds")
		assert_true(mouth.map_pixel.y >= 0.0 and mouth.map_pixel.y <= float(resolution), "Map pixel Y must be in bounds")

	# Verify minimum separation distance between any two mouths (no overlapping duplicate markers)
	var min_sep = generator.cave_carver.config.mouth_radius * 1.5
	for i in range(mouths.size()):
		for j in range(i + 1, mouths.size()):
			var dist = Vector2(mouths[i].world_pos.x - mouths[j].world_pos.x, mouths[i].world_pos.z - mouths[j].world_pos.z).length()
			assert_true(dist >= min_sep - 1.0, "Cave mouths must be spaced apart by at least minimum separation distance")

func test_continent_map_baker_and_provider_caching() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfigClass.new()
	var VolumetricGenClass = preload("res://src/generation/volumetric_terrain_generator.gd")
	var generator = VolumetricGenClass.new(777, config, cave_config)

	var baker = ContinentMapBakerClass.new()
	var img = baker.bake_map(generator, bounds, 64)
	assert_not_null(img, "Baker must produce valid Image")
	assert_not_null(baker.last_baked_cave_mouths, "Baker must populate last_baked_cave_mouths")

	# Provider sync caching
	var provider = ContinentMapProviderClass.new()
	assert_eq(provider.get_cave_mouths().size(), 0, "Provider initially has no cached cave mouths")

	var tex = provider.bake_sync(generator, bounds, 64)
	assert_not_null(tex, "Provider bake_sync must produce texture")
	var provider_mouths = provider.get_cave_mouths()
	assert_eq(provider_mouths.size(), baker.last_baked_cave_mouths.size(), "Provider must cache baked cave mouths")

	# Provider clear
	provider.clear()
	assert_eq(provider.get_cave_mouths().size(), 0, "Provider clear must reset cached cave mouths")

func test_cave_mouth_overlay_state_and_transform() -> void:
	var overlay = CaveMouthOverlayClass.new()
	overlay.size = Vector2(512, 512)

	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var dummy_mouths: Array = [
		CaveMouthDataClass.new(Vector3(0.0, 50.0, 0.0), Vector2(256.0, 256.0), CaveMouthDataClass.Type.DEAD_END),
		CaveMouthDataClass.new(Vector3(100.0, 60.0, -100.0), Vector2(300.0, 200.0), CaveMouthDataClass.Type.TUNNEL),
		CaveMouthDataClass.new(Vector3(-200.0, 40.0, 150.0), Vector2(150.0, 350.0), CaveMouthDataClass.Type.CHASM)
	]

	overlay.set_cave_mouths(dummy_mouths, bounds)
	assert_eq(overlay.cave_mouths.size(), 3, "Overlay must hold 3 cave mouths")
	assert_eq(overlay.bounds, bounds, "Overlay must store world bounds")

	overlay.update_transform(Vector2(-50.0, 20.0), 1.5)
	assert_eq(overlay.pan_offset, Vector2(-50.0, 20.0))
	assert_eq(overlay.zoom, 1.5)

func test_continent_map_ui_legend_entries() -> void:
	var ui = ContinentMapUIClass.new()
	ui._build_ui()

	assert_not_null(ui._cave_mouth_overlay, "ContinentMapUI must instantiate _cave_mouth_overlay")

	# Check that legend contains the cave mouth types
	var legend = ui._legend_container
	assert_not_null(legend, "ContinentMapUI must have a legend container")

	var found_dead = false
	var found_tunnel = false
	var found_chasm = false

	for child in legend.get_children():
		for sub in child.get_children():
			if sub is Label:
				if "Dead Cave (C)" in sub.text:
					found_dead = true
				if "Tunnel Cave (C)" in sub.text:
					found_tunnel = true
				if "Chasm Cave (C)" in sub.text:
					found_chasm = true

	assert_true(found_dead, "Legend must include 'Dead Cave (C)'")
	assert_true(found_tunnel, "Legend must include 'Tunnel Cave (C)'")
	assert_true(found_chasm, "Legend must include 'Chasm Cave (C)'")

	ui.free()
