class_name TestGraphicNovelArchitecture
extends "res://tests/framework/test_case.gd"

const ConfigClass = preload("res://src/rendering/graphic_novel_config.gd")
const ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
const PostProcessClass = preload("res://src/rendering/graphic_novel_post_process.gd")
const GeneratorClass = preload("res://src/rendering/halftone_texture_generator.gd")

func before_each() -> void:
	ProviderClass.reset()

func after_each() -> void:
	ProviderClass.reset()

func test_graphic_novel_config_defaults() -> void:
	var cfg = ConfigClass.create_default_config()
	assert_not_null(cfg, "Config instance should not be null")
	assert_true(cfg.outlines_enabled, "Outlines should be enabled by default")
	assert_almost_eq(cfg.outline_thickness, 1.2, 0.01, "Outline thickness should be 1.2")
	assert_almost_eq(cfg.lit_threshold, 0.30, 0.01, "Lit threshold should be 0.30")
	assert_almost_eq(cfg.outline_fade_start, 45.0, 0.01, "Outline fade start should be 45.0")
	assert_almost_eq(cfg.max_outline_distance, 150.0, 0.01, "Max outline distance should be 150.0")
	assert_true(cfg.sky_top_color.a > 0.9, "Sky top color should be opaque")
	assert_true(cfg.outline_color.a > 0.9, "Outline color should be opaque")

func test_sky_shader_compilation_and_code() -> void:
	var shader = load("res://shaders/sky/banded_sky.gdshader") as Shader
	assert_not_null(shader, "Sky shader resource should load")
	var code = shader.code
	assert_true(code.contains("shader_type sky;"), "Shader type should be sky")
	assert_true(code.contains("calculate_sky_band"), "Should contain modular calculate_sky_band function")
	assert_true(code.contains("calculate_sun_disk"), "Should contain modular calculate_sun_disk function")
	assert_true(code.contains("sky_top_color"), "Should expose sky_top_color uniform")

func test_outline_postprocess_shader_compilation_and_code() -> void:
	var shader = load("res://shaders/postprocess/outline_postprocess.gdshader") as Shader
	assert_not_null(shader, "Outline postprocess shader resource should load")
	var code = shader.code
	assert_true(code.contains("shader_type spatial;"), "Shader type should be spatial")
	assert_true(code.contains("hint_depth_texture"), "Should sample hint_depth_texture")
	assert_true(code.contains("hint_normal_roughness_texture"), "Should sample hint_normal_roughness_texture")
	assert_true(code.contains("get_linear_depth"), "Should contain get_linear_depth helper")
	assert_true(code.contains("evaluate_depth_edge"), "Should contain evaluate_depth_edge helper")
	assert_true(code.contains("evaluate_normal_edge"), "Should contain evaluate_normal_edge helper")

func test_halftone_terrain_shader_compilation_and_code() -> void:
	var shader = load("res://shaders/terrain/halftone_terrain.gdshader") as Shader
	assert_not_null(shader, "Terrain spatial shader resource should load")
	var code = shader.code
	assert_true(code.contains("shader_type spatial;"), "Shader type should be spatial")
	assert_true(code.contains("render_mode diffuse_toon"), "Shader should use diffuse_toon")
	assert_true(code.contains("void light()"), "Shader should override light()")
	assert_true(code.contains("quantize_light"), "Should contain quantize_light helper")
	assert_true(code.contains("evaluate_halftone"), "Should contain evaluate_halftone helper")

func test_terrain_material_provider_caching_and_uniforms() -> void:
	var cfg = ConfigClass.create_default_config()
	cfg.lit_threshold = 0.42
	cfg.halftone_scale = 0.22

	var mat1 = ProviderClass.get_surface_material(cfg)
	assert_not_null(mat1, "Surface material should not be null")
	assert_not_null(mat1.shader, "Material should have shader assigned")
	assert_almost_eq(float(mat1.get_shader_parameter("lit_threshold")), 0.42, 0.001, "Parameter lit_threshold should match config")
	assert_almost_eq(float(mat1.get_shader_parameter("halftone_scale")), 0.22, 0.001, "Parameter halftone_scale should match config")

	# Cache identity check
	var mat2 = ProviderClass.get_surface_material()
	assert_eq(mat1, mat2, "Provider must return identical cached ShaderMaterial instance for surface")

	var cave_mat = ProviderClass.get_cave_material(cfg)
	assert_not_null(cave_mat, "Cave material should not be null")
	assert_ne(mat1, cave_mat, "Surface and cave materials should be distinct instances")

	# Subterranean shadow tint should be deeper/darker than surface shadow tint
	var surface_tint = mat1.get_shader_parameter("shadow_tint") as Color
	var cave_tint = cave_mat.get_shader_parameter("shadow_tint") as Color
	assert_true(cave_tint.v < surface_tint.v, "Cave shadow tint value should be darker than surface")

func test_graphic_novel_post_process_controller() -> void:
	var controller = PostProcessClass.new()
	var cfg = ConfigClass.create_default_config()
	cfg.outline_thickness = 2.0
	cfg.outlines_enabled = true
	controller.config = cfg

	# Trigger _ready
	controller._ready()

	assert_not_null(controller.mesh_instance, "MeshInstance3D child should be created")
	assert_not_null(controller.post_material, "Post material should be created")
	assert_almost_eq(float(controller.post_material.get_shader_parameter("outline_thickness")), 2.0, 0.01, "Thickness uniform should be applied")

	# Toggle off
	controller.set_outlines_enabled(false)
	assert_false(controller.post_material.get_shader_parameter("outlines_enabled"), "Uniform should reflect disabled state")

	controller.mesh_instance.free()
	controller.free()

func test_chunk_node_uses_shader_material() -> void:
	var node = ChunkNode.new()
	node._ensure_nodes_exist()
	assert_not_null(node.mesh_instance, "Mesh instance should exist")
	assert_not_null(node.mesh_instance.material_override, "Material override should be set")
	assert_true(node.mesh_instance.material_override is ShaderMaterial, "Chunk mesh should use ShaderMaterial")

	var shared_mat = ChunkNode.get_shared_surface_material()
	assert_eq(node.mesh_instance.material_override, shared_mat, "Node should use shared surface material")
	node.free()

func test_halftone_texture_generator() -> void:
	var img = GeneratorClass.generate_dot_pattern(32, 0.3)
	assert_not_null(img, "Generated image should not be null")
	assert_eq(img.get_width(), 32, "Width should be 32")
	assert_eq(img.get_height(), 32, "Height should be 32")
	# Sample center dot (should be light/white)
	var center_pixel = img.get_pixel(16, 16)
	assert_true(center_pixel.r > 0.5, "Center dot should be bright")

func test_theme_tres_resource_file() -> void:
	var theme = load("res://config/graphic_novel_theme.tres") as Resource
	assert_not_null(theme, "graphic_novel_theme.tres should load successfully")
	assert_true(bool(theme.get("outlines_enabled")), "Outlines should be enabled in theme")
	assert_not_null(theme.get("halftone_texture"), "Halftone texture should be bound in theme")
