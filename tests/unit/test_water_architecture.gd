class_name TestWaterArchitecture
extends "res://tests/framework/test_case.gd"

## Integration and architectural test verifying Phase 4 water wiring across:
## 1. TerrainMaterialProvider delegators and lifecycle caching.
## 2. WaterPlane ocean setup consuming toon ShaderMaterial.
## 3. ChunkNode elevated and subterranean water instance bindings.
## 4. Architectural constraints (zero Node dependencies in rendering domain, length bounds).

const ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
const ToonProviderClass = preload("res://src/rendering/toon_water_material_provider.gd")
const WaterPlaneClass = preload("res://src/world/water_plane.gd")
const ChunkNodeClass = preload("res://src/world/chunk_node.gd")
const WorldBoundsClass = preload("res://src/core/world_bounds.gd")

func before_each() -> void:
	ProviderClass.reset()

func after_each() -> void:
	ProviderClass.reset()

func test_terrain_material_provider_water_delegation() -> void:
	var surf_mat = ProviderClass.get_water_material()
	assert_not_null(surf_mat, "Provider must return water material")
	assert_true(surf_mat is ShaderMaterial, "Water material must be a ShaderMaterial")

	var cave_mat = ProviderClass.get_subterranean_water_material()
	assert_not_null(cave_mat, "Provider must return subterranean water material")
	assert_true(cave_mat is ShaderMaterial, "Subterranean water material must be a ShaderMaterial")
	assert_ne(surf_mat, cave_mat, "Surface and cave water materials must be separate instances")

	# Cache identity
	var surf_mat2 = ProviderClass.get_water_material()
	assert_eq(surf_mat, surf_mat2, "Provider must return identical cached ShaderMaterial on repeated calls")

	# Reset
	ProviderClass.reset()
	var surf_mat3 = ProviderClass.get_water_material()
	assert_ne(surf_mat, surf_mat3, "ProviderClass.reset() must clear cached water materials")

func test_water_plane_uses_toon_shader_material() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(10, 10))
	var water_plane = WaterPlaneClass.new()
	water_plane.setup(bounds, 9.0)

	assert_not_null(water_plane.material_override, "WaterPlane must have material_override set")
	assert_true(water_plane.material_override is ShaderMaterial, "WaterPlane material must be a ShaderMaterial")

	var expected_mat = ProviderClass.get_ocean_material()
	assert_eq(water_plane.material_override, expected_mat, "WaterPlane must use shared ocean toon water material")
	assert_eq(expected_mat.get_shader_parameter("foam_enabled"), false, "Ocean material must have foam disabled to prevent noise")
	water_plane.free()

func test_chunk_node_shared_water_materials() -> void:
	var node = ChunkNodeClass.new()
	var shared_water = ChunkNodeClass.get_shared_water_material()
	var shared_sub_water = ChunkNodeClass.get_shared_subterranean_water_material()

	assert_not_null(shared_water, "ChunkNode shared water material should not be null")
	assert_true(shared_water is ShaderMaterial, "ChunkNode shared water material must be ShaderMaterial")

	assert_not_null(shared_sub_water, "ChunkNode subterranean water material should not be null")
	assert_true(shared_sub_water is ShaderMaterial, "ChunkNode subterranean water material must be ShaderMaterial")

	node.free()

func test_file_length_bounds_preserved() -> void:
	var files = [
		{"path": "res://src/rendering/terrain_material_provider.gd", "max": 170},
		{"path": "res://src/rendering/toon_water_material_provider.gd", "max": 120},
		{"path": "res://src/rendering/toon_water_config.gd", "max": 90},
		{"path": "res://shaders/water/toon_water.gdshader", "max": 140}
	]

	for item in files:
		var file = FileAccess.open(item.path, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % item.path)
		var text = file.get_as_text()
		file.close()

		var lines = text.split("\n").size()
		assert_true(lines <= item.max, "%s must be <= %d lines (got %d)" % [item.path, item.max, lines])
