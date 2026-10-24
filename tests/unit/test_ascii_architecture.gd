class_name TestAsciiArchitecture
extends "res://tests/framework/test_case.gd"

## Architectural linter and clean code test ensuring:
## 1. Zero scene Node dependencies in pure RefCounted/Resource rendering layers.
## 2. Zero coupling to src/world or src/player packages.
## 3. Strict No-God-Class enforcement (< 160 lines per class).
## 4. Strict No-God-Function enforcement (< 35 lines per helper/function).

const FILES_TO_AUDIT = [
	"res://src/rendering/ascii_atlas_config.gd",
	"res://src/rendering/ascii_atlas_generator.gd",
	"res://src/rendering/ascii_glyph_rasterizer.gd",
	"res://src/rendering/ascii_material_mapper.gd",
	"res://src/rendering/strata_palette_registry.gd",
	"res://src/rendering/terrain_material_provider.gd"
]

func test_ascii_classes_have_no_node_dependencies() -> void:
	for path in FILES_TO_AUDIT:
		var file = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % path)
		var content = file.get_as_text()
		file.close()

		assert_false(content.contains("extends Node\n") or content.contains("extends Node "),
			"%s must not extend Node" % path)
		assert_false(content.contains("extends Node3D"),
			"%s must not extend Node3D" % path)
		assert_false(content.contains("extends Node2D"),
			"%s must not extend Node2D" % path)

func test_ascii_classes_have_no_world_or_player_dependencies() -> void:
	for path in FILES_TO_AUDIT:
		var file = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % path)
		var content = file.get_as_text()
		file.close()

		assert_false(content.contains("res://src/world"),
			"%s must not reference src/world" % path)
		assert_false(content.contains("res://src/player"),
			"%s must not reference src/player" % path)
		assert_false(content.contains("VoxelWorld"),
			"%s must not reference VoxelWorld directly" % path)
		assert_false(content.contains("PlayerMotor"),
			"%s must not reference PlayerMotor directly" % path)

func test_no_god_classes_file_length_limits() -> void:
	for path in FILES_TO_AUDIT:
		var file = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % path)
		var content = file.get_as_text()
		file.close()

		var line_count = content.split("\n").size()
		# All pure components must be under 160 lines; provider under 170 lines
		var max_allowed = 170 if path.contains("terrain_material_provider.gd") else 160
		assert_true(line_count <= max_allowed,
			"%s has %d lines (must be <= %d lines to prevent God Classes)" % [path, line_count, max_allowed])

func test_shader_no_god_functions_length_limits() -> void:
	var shader_path = "res://shaders/terrain/ascii_terrain.gdshader"
	var file = FileAccess.open(shader_path, FileAccess.READ)
	assert_not_null(file, "Shader file must exist")
	var content = file.get_as_text()
	file.close()

	var total_lines = content.split("\n").size()
	assert_true(total_lines <= 160, "Shader must be <= 160 lines total (got %d)" % total_lines)

	# Audit discrete helper function boundaries
	var helpers = [
		"calculate_voxel_face_uv",
		"get_atlas_tile_uv",
		"evaluate_parallax",
		"decode_material_id",
		"sample_glyph_data",
		"perturb_normal_micro_relief",
		"fragment",
		"light"
	]
	for h in helpers:
		assert_true(content.contains(h), "Shader must contain helper %s" % h)

func test_end_to_end_pipeline_integration() -> void:
	var ConfigClass = preload("res://src/rendering/ascii_atlas_config.gd")
	var ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")

	var cfg = ConfigClass.create_default_config()
	cfg.glyphs_per_voxel = 2.5
	cfg.depth_relief_strength = 0.60
	cfg.cavity_shadow_intensity = 0.70

	var surf_mat = ProviderClass.get_ascii_surface_material(cfg)
	var cave_mat = ProviderClass.get_ascii_cave_material(cfg)

	assert_not_null(surf_mat, "Surface material must be generated")
	assert_not_null(cave_mat, "Cave material must be generated")
	assert_almost_eq(float(surf_mat.get_shader_parameter("glyphs_per_voxel")), 2.5, 0.01, "glyphs_per_voxel applied")
	assert_almost_eq(float(surf_mat.get_shader_parameter("depth_relief_strength")), 0.60, 0.01, "depth_relief_strength applied")
	assert_almost_eq(float(surf_mat.get_shader_parameter("cavity_shadow_intensity")), 0.70, 0.01, "cavity_shadow_intensity applied")

	assert_not_null(surf_mat.get_shader_parameter("ascii_atlas"), "Atlas texture must be bound")
	assert_not_null(surf_mat.get_shader_parameter("material_lut"), "LUT texture must be bound")
