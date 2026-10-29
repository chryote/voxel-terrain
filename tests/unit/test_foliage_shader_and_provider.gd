class_name TestFoliageShaderAndProvider
extends "res://tests/framework/test_case.gd"

## Unit tests validating toon grass shader compilation, uniform bindings, and material caching.

const FoliageProviderClass = preload("res://src/rendering/foliage_material_provider.gd")
const FoliageConfigClass = preload("res://src/rendering/foliage_config.gd")
const TerrainMaterialProviderClass = preload("res://src/rendering/terrain_material_provider.gd")

func before_each() -> void:
	FoliageProviderClass.reset()
	TerrainMaterialProviderClass.reset()

func after_each() -> void:
	FoliageProviderClass.reset()
	TerrainMaterialProviderClass.reset()

func test_foliage_shader_compilation_and_features() -> void:
	var shader = load("res://shaders/foliage/toon_grass.gdshader") as Shader
	assert_not_null(shader, "Toon grass shader resource must load")
	var code = shader.code

	assert_true(code.contains("shader_type spatial;"), "Must be spatial shader")
	assert_true(code.contains("cull_disabled"), "Must be double-sided (cull_disabled)")
	assert_true(code.contains("diffuse_toon"), "Must use diffuse_toon render mode")
	assert_true(code.contains("get_bayer_4x4"), "Must contain 4x4 Bayer dither function")
	assert_true(code.contains("wind_enabled"), "Must declare wind_enabled uniform")
	assert_true(code.contains("wind_speed"), "Must declare wind_speed uniform")
	assert_true(code.contains("wind_strength"), "Must declare wind_strength uniform")
	assert_true(code.contains("distance_fade_start"), "Must declare distance_fade_start uniform")
	assert_true(code.contains("distance_fade_max"), "Must declare distance_fade_max uniform")
	assert_true(code.contains("alpha_scissor_threshold"), "Must declare alpha_scissor_threshold uniform")

func test_foliage_config_defaults() -> void:
	var cfg = FoliageConfigClass.create_default_config()
	assert_not_null(cfg, "Config instance must not be null")
	assert_true(cfg.wind_enabled, "Wind sway must be enabled by default")
	assert_almost_eq(cfg.wind_speed, 1.8, 0.01, "Default wind speed should be 1.8")
	assert_almost_eq(cfg.wind_strength, 0.08, 0.01, "Default wind strength should be 0.08")
	assert_almost_eq(cfg.distance_fade_start, 45.0, 0.1, "Default fade start should be 45.0 m")
	assert_almost_eq(cfg.distance_fade_max, 60.0, 0.1, "Default fade max should be 60.0 m")
	assert_almost_eq(cfg.alpha_scissor_threshold, 0.5, 0.01, "Default alpha scissor should be 0.5")

func test_foliage_material_provider_caching() -> void:
	var mat1 = FoliageProviderClass.get_grass_material()
	assert_not_null(mat1, "Provider must return grass material")
	assert_true(mat1 is ShaderMaterial, "Must be ShaderMaterial")

	var mat2 = FoliageProviderClass.get_grass_material()
	assert_eq(mat1, mat2, "Provider must return cached instance on repeated calls")

	FoliageProviderClass.reset()
	var mat3 = FoliageProviderClass.get_grass_material()
	assert_ne(mat1, mat3, "Provider reset must invalidate cache and create fresh instance")

func test_terrain_material_provider_grass_delegation() -> void:
	var mat = TerrainMaterialProviderClass.get_grass_material()
	assert_not_null(mat, "TerrainMaterialProvider must delegate get_grass_material()")
	assert_true(mat is ShaderMaterial, "Delegated grass material must be ShaderMaterial")
	assert_eq(mat, FoliageProviderClass.get_grass_material(), "Delegated material must match FoliageProvider instance")

func test_foliage_config_file_resource() -> void:
	assert_true(ResourceLoader.exists("res://config/foliage_config.tres"), "foliage_config.tres must exist")
	var res = load("res://config/foliage_config.tres")
	assert_not_null(res, "foliage_config.tres must load cleanly")
	assert_true(res is FoliageConfigClass, "Resource must be instance of FoliageConfig")
	assert_true(res.wind_enabled, "Wind should be enabled in resource")

func test_foliage_rendering_file_bounds() -> void:
	var files = [
		{"path": "res://src/rendering/foliage_config.gd", "max": 60},
		{"path": "res://src/rendering/foliage_material_provider.gd", "max": 90},
		{"path": "res://shaders/foliage/toon_grass.gdshader", "max": 120}
	]

	for item in files:
		var file = FileAccess.open(item.path, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % item.path)
		var text = file.get_as_text()
		file.close()

		var lines = text.split("\n").size()
		assert_true(lines <= item.max, "%s must be <= %d lines (got %d)" % [item.path, item.max, lines])

