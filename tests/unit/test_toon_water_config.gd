class_name TestToonWaterConfig
extends "res://tests/framework/test_case.gd"

## Unit and architectural test for ToonWaterConfig resource.

const ConfigClass = preload("res://src/rendering/toon_water_config.gd")
const CONFIG_PATH = "res://src/rendering/toon_water_config.gd"

func test_default_config_properties() -> void:
	var cfg = ConfigClass.create_default_config()
	assert_not_null(cfg, "Default config must be instantiable")
	assert_almost_eq(cfg.foam_thickness, 0.35, 0.001, "Default foam thickness should be 0.35")
	assert_almost_eq(cfg.shallow_threshold, 1.5, 0.001, "Default shallow threshold should be 1.5")
	assert_almost_eq(cfg.deep_threshold, 5.0, 0.001, "Default deep threshold should be 5.0")
	assert_true(cfg.ripples_enabled, "Ripples should be enabled by default")
	assert_almost_eq(cfg.ripple_scale, 0.25, 0.001, "Default ripple scale should be 0.25")
	assert_almost_eq(cfg.ripple_speed, 0.08, 0.001, "Default ripple speed should be 0.08")
	assert_true(cfg.foam_color.a > 0.99, "Foam color should be fully opaque white")

func test_subterranean_preset() -> void:
	var cave_cfg = ConfigClass.create_subterranean_config()
	assert_not_null(cave_cfg, "Subterranean config should be created")
	assert_almost_eq(cave_cfg.foam_thickness, 0.25, 0.001, "Subterranean foam should be tighter (0.25)")
	assert_almost_eq(cave_cfg.shallow_threshold, 1.0, 0.001, "Subterranean shallow threshold should be 1.0")
	assert_almost_eq(cave_cfg.deep_threshold, 3.5, 0.001, "Subterranean deep threshold should be 3.5")
	# Subterranean water should have darker/muffled values than surface
	assert_true(cave_cfg.deep_color.v < 0.15, "Deep subterranean color should be dark ink")

func test_named_presets() -> void:
	var alpine = ConfigClass.create_preset("alpine_lake")
	assert_not_null(alpine, "Alpine preset must load")
	assert_almost_eq(alpine.foam_thickness, 0.40, 0.001, "Alpine foam thickness should match")

	var toxic = ConfigClass.create_preset("toxic_chasm")
	assert_not_null(toxic, "Toxic chasm preset must load")
	assert_true(toxic.shallow_color.g > toxic.shallow_color.b, "Toxic water should be predominantly green")

	var fallback = ConfigClass.create_preset("unknown_preset_fallback")
	assert_not_null(fallback, "Unknown preset must safely fall back to default")
	assert_almost_eq(fallback.foam_thickness, 0.35, 0.001, "Fallback should match default")

func test_architectural_cleanliness() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	assert_not_null(file, "Config file must exist")
	var code = file.get_as_text()
	file.close()

	assert_false(code.contains("extends Node"), "Must not extend Node")
	assert_false(code.contains("extends Node3D"), "Must not extend Node3D")
	assert_false(code.contains("res://src/world"), "Must not couple to src/world")
	assert_false(code.contains("res://src/player"), "Must not couple to src/player")

	var lines = code.split("\n").size()
	assert_true(lines <= 90, "Config class must remain <= 90 lines (got %d)" % lines)
