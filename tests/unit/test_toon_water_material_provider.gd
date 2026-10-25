class_name TestToonWaterMaterialProvider
extends "res://tests/framework/test_case.gd"

## Unit and architectural test for ToonWaterMaterialProvider.

const ProviderClass = preload("res://src/rendering/toon_water_material_provider.gd")
const ConfigClass = preload("res://src/rendering/toon_water_config.gd")
const PROVIDER_PATH = "res://src/rendering/toon_water_material_provider.gd"

func before_each() -> void:
	ProviderClass.reset()

func after_each() -> void:
	ProviderClass.reset()

func test_provider_creates_and_caches_surface_material() -> void:
	var mat1 = ProviderClass.get_water_material()
	assert_not_null(mat1, "Surface water material must not be null")
	assert_not_null(mat1.shader, "Material must have shader attached")

	var mat2 = ProviderClass.get_water_material()
	assert_eq(mat1, mat2, "Provider must return identical cached instance on repeated calls")
	assert_almost_eq(float(mat1.get_shader_parameter("foam_thickness")), 0.35, 0.001, "Default foam thickness applied")

func test_provider_creates_distinct_subterranean_material() -> void:
	var surf_mat = ProviderClass.get_water_material()
	var cave_mat = ProviderClass.get_subterranean_water_material()

	assert_not_null(cave_mat, "Subterranean water material must not be null")
	assert_ne(surf_mat, cave_mat, "Surface and cave water materials must be separate instances")
	assert_almost_eq(float(cave_mat.get_shader_parameter("foam_thickness")), 0.25, 0.001, "Subterranean foam applied")
	assert_almost_eq(float(cave_mat.get_shader_parameter("shallow_threshold")), 1.0, 0.001, "Subterranean shallow threshold applied")

func test_provider_updates_uniforms_with_config() -> void:
	var cfg = ConfigClass.create_default_config()
	cfg.foam_thickness = 0.55
	cfg.shallow_threshold = 2.2
	cfg.ripples_enabled = false

	var mat = ProviderClass.get_water_material(cfg)
	assert_almost_eq(float(mat.get_shader_parameter("foam_thickness")), 0.55, 0.001, "Updated foam thickness applied")
	assert_almost_eq(float(mat.get_shader_parameter("shallow_threshold")), 2.2, 0.001, "Updated shallow threshold applied")
	assert_false(bool(mat.get_shader_parameter("ripples_enabled")), "Ripples enabled toggle applied")

func test_provider_reset_clears_cache() -> void:
	var mat1 = ProviderClass.get_water_material()
	ProviderClass.reset()
	var mat2 = ProviderClass.get_water_material()
	assert_ne(mat1, mat2, "reset() must clear cached instances, producing new material instance")

func test_architectural_cleanliness_and_limits() -> void:
	var file = FileAccess.open(PROVIDER_PATH, FileAccess.READ)
	assert_not_null(file, "Provider file must exist")
	var code = file.get_as_text()
	file.close()

	assert_false(code.contains("extends Node"), "Must not extend Node")
	assert_false(code.contains("extends Node3D"), "Must not extend Node3D")
	assert_false(code.contains("res://src/world"), "Must not couple to src/world")
	assert_false(code.contains("res://src/player"), "Must not couple to src/player")

	var lines = code.split("\n").size()
	assert_true(lines <= 120, "Provider class must remain <= 120 lines (got %d)" % lines)
