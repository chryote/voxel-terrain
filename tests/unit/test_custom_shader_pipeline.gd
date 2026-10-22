class_name TestCustomShaderPipeline
extends "res://tests/framework/test_case.gd"

## Unit tests verifying custom shader pipeline, material configuration,
## uniform synchronization, chunk material instantiation, and fallbacks.

const TerrainMaterialConfigClass = preload("res://src/graphics/terrain_material_config.gd")
const TerrainMaterialManagerClass = preload("res://src/graphics/terrain_material_manager.gd")

func test_shader_files_exist_and_load() -> void:
	assert_true(ResourceLoader.exists("res://src/graphics/shaders/terrain.gdshader"),
		"terrain.gdshader must exist")
	assert_true(ResourceLoader.exists("res://src/graphics/shaders/terrain_water.gdshader"),
		"terrain_water.gdshader must exist")
	assert_true(ResourceLoader.exists("res://src/graphics/shaders/terrain_cave.gdshader"),
		"terrain_cave.gdshader must exist")

	var terrain_shader = load("res://src/graphics/shaders/terrain.gdshader")
	assert_not_null(terrain_shader, "terrain.gdshader must load successfully")
	assert_true(terrain_shader is Shader, "Loaded asset must be a Shader")

func test_terrain_material_config_defaults() -> void:
	var cfg = TerrainMaterialConfigClass.create_default_config()
	assert_not_null(cfg, "Default config should instantiate")

	assert_true(cfg.triplanar_scale > 0.0, "Triplanar scale must be positive")
	assert_true(cfg.triplanar_sharpness > 1.0, "Triplanar sharpness should be > 1.0")
	assert_true(cfg.slope_threshold > 0.5, "Slope threshold should default around 0.7")
	assert_true(cfg.snow_height > cfg.beach_height, "Snowline must be higher than beachline")

	# PBR colors
	assert_true(cfg.grass_color.g > cfg.grass_color.r, "Grass color should be greenish")
	assert_true(cfg.dirt_color.r > cfg.dirt_color.b, "Dirt color should be brownish")
	assert_true(cfg.snow_color.r > 0.8 and cfg.snow_color.g > 0.8, "Snow color should be near white")

func test_material_manager_instantiation_and_uniforms() -> void:
	var cfg = TerrainMaterialConfigClass.new()
	cfg.triplanar_scale = 0.35
	cfg.slope_threshold = 0.72

	var mgr = TerrainMaterialManagerClass.new(cfg)
	var surf_mat = mgr.get_shared_surface_material()
	assert_not_null(surf_mat, "Surface material must be created")
	assert_true(surf_mat is ShaderMaterial, "Surface material must be a ShaderMaterial")

	# Check synchronized uniforms
	var scale_param = surf_mat.get_shader_parameter("triplanar_scale")
	assert_almost_eq(scale_param, 0.35, 0.001, "triplanar_scale parameter must match config")

	var slope_param = surf_mat.get_shader_parameter("slope_threshold")
	assert_almost_eq(slope_param, 0.72, 0.001, "slope_threshold parameter must match config")

func test_chunk_surface_material_instantiation_with_splatmap() -> void:
	var mgr = TerrainMaterialManagerClass.new()
	var coord = ChunkCoord.new(3, -2)
	var chunk_size_world = 32.0

	# 1. Without splatmap
	var mat_no_splat = mgr.create_chunk_surface_material(coord, chunk_size_world, null)
	assert_not_null(mat_no_splat, "Chunk material without splatmap should instantiate")
	assert_false(mat_no_splat.get_shader_parameter("use_splat_map"),
		"use_splat_map must be false when splat_map is null")

	var origin_param = mat_no_splat.get_shader_parameter("chunk_origin") as Vector2
	assert_almost_eq(origin_param.x, 96.0, 0.01, "Origin X must match coord.x * chunk_size_world")
	assert_almost_eq(origin_param.y, -64.0, 0.01, "Origin Y (Z in 3D) must match coord.z * chunk_size_world")

	# 2. With dummy splatmap texture
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var dummy_tex = ImageTexture.create_from_image(img)
	var mat_with_splat = mgr.create_chunk_surface_material(coord, chunk_size_world, dummy_tex)
	assert_true(mat_with_splat.get_shader_parameter("use_splat_map"),
		"use_splat_map must be true when splat_map is provided")
	assert_eq(mat_with_splat.get_shader_parameter("splat_map"), dummy_tex,
		"splat_map parameter must be assigned the texture")

func test_fallback_standard_material() -> void:
	var mgr = TerrainMaterialManagerClass.new()
	var fallback = mgr.create_fallback_standard_material()
	assert_not_null(fallback, "Fallback material must not be null")
	assert_true(fallback is StandardMaterial3D, "Fallback must be StandardMaterial3D")
	assert_true(fallback.vertex_color_use_as_albedo, "Fallback must use vertex colors")

func test_chunk_node_material_setters() -> void:
	var node = ChunkNode.new()
	var mgr = TerrainMaterialManagerClass.new()
	var custom_mat = mgr.create_chunk_surface_material(ChunkCoord.new(0, 0), 32.0)

	node.set_surface_material(custom_mat)
	assert_eq(node.mesh_instance.material_override, custom_mat,
		"set_surface_material must update mesh_instance.material_override")

	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var splat_tex = ImageTexture.create_from_image(img)
	node.set_splat_texture(splat_tex)
	assert_true(custom_mat.get_shader_parameter("use_splat_map"),
		"set_splat_texture must enable use_splat_map on the material")
	assert_eq(custom_mat.get_shader_parameter("splat_map"), splat_tex,
		"set_splat_texture must set splat_map parameter")

	node.prepare_for_pool()
	node.queue_free()

func test_ghibli_visual_profile_defaults() -> void:
	var cfg = TerrainMaterialConfigClass.create_default_config()
	assert_not_null(cfg, "Default config should instantiate")

	# 1. Soft-Banded Cel Shading
	assert_true(cfg.cel_enabled, "Cel shading should be enabled by default for Ghibli profile")
	assert_true(cfg.cel_shadow_threshold > 0.1 and cfg.cel_shadow_threshold < 0.5,
		"Shadow threshold should be in lower mid-range")
	assert_true(cfg.cel_highlight_threshold > cfg.cel_shadow_threshold,
		"Highlight threshold must be above shadow threshold")
	assert_true(cfg.cel_softness > 0.01 and cfg.cel_softness < 0.2,
		"Softness must provide watercolor blending edge")

	# 2. Tinted Ambient Shadows
	assert_true(cfg.shadow_tint.b > cfg.shadow_tint.r,
		"Shadow tint should be cool-toned (lavender/sky blue/teal)")
	assert_true(cfg.highlight_tint.r > 1.0,
		"Highlight tint should be warm sunlit tone (> 1.0)")
	assert_true(cfg.shadow_ambient_intensity > 0.0,
		"Shadow ambient intensity should be positive")

	# 3. Triplanar Macro-Noise Hue & Saturation
	assert_true(cfg.macro_hue_shift > 0.0,
		"Macro hue shift should be enabled to break repetition")
	assert_true(cfg.macro_saturation_shift > 0.0,
		"Macro saturation shift should be enabled")

	# 4. Elevation-Based Color Gradients
	assert_true(cfg.gradient_peak_y > cfg.gradient_valley_y,
		"Gradient peak elevation must be higher than valley elevation")
	assert_true(cfg.gradient_valley_tint.b >= cfg.gradient_valley_tint.r,
		"Valley tint should be cooler")
	assert_true(cfg.gradient_peak_tint.r >= cfg.gradient_peak_tint.b,
		"Mountain peak tint should be warmer")
	assert_true(cfg.gradient_strength > 0.0,
		"Gradient strength must be active")

	# 5. Directional Rim Lighting
	assert_true(cfg.rim_enabled, "Rim lighting should be enabled")
	assert_true(cfg.rim_color.r > 0.8 and cfg.rim_color.g > 0.8,
		"Rim color should be a warm glowing outline")
	assert_true(cfg.rim_power >= 1.0, "Rim power should produce focused edge halo")
	assert_true(cfg.rim_strength > 0.0, "Rim strength should be positive")

func test_ghibli_uniform_synchronization() -> void:
	var cfg = TerrainMaterialConfigClass.new()
	cfg.cel_shadow_threshold = 0.40
	cfg.cel_highlight_threshold = 0.80
	cfg.cel_softness = 0.12
	cfg.shadow_tint = Color(0.35, 0.45, 0.75, 1.0)
	cfg.macro_hue_shift = 0.08
	cfg.macro_saturation_shift = 0.15
	cfg.gradient_valley_y = 20.0
	cfg.gradient_peak_y = 150.0
	cfg.gradient_strength = 0.60
	cfg.rim_power = 4.0
	cfg.rim_strength = 0.55

	var mgr = TerrainMaterialManagerClass.new(cfg)
	var surf_mat = mgr.get_shared_surface_material()
	assert_not_null(surf_mat, "Surface material must exist")

	assert_almost_eq(surf_mat.get_shader_parameter("cel_shadow_threshold"), 0.40, 0.001,
		"cel_shadow_threshold must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("cel_highlight_threshold"), 0.80, 0.001,
		"cel_highlight_threshold must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("cel_softness"), 0.12, 0.001,
		"cel_softness must sync")
	assert_eq(surf_mat.get_shader_parameter("shadow_tint"), Color(0.35, 0.45, 0.75, 1.0),
		"shadow_tint must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("macro_hue_shift"), 0.08, 0.001,
		"macro_hue_shift must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("macro_saturation_shift"), 0.15, 0.001,
		"macro_saturation_shift must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("gradient_valley_y"), 20.0, 0.001,
		"gradient_valley_y must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("gradient_peak_y"), 150.0, 0.001,
		"gradient_peak_y must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("gradient_strength"), 0.60, 0.001,
		"gradient_strength must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("rim_power"), 4.0, 0.001,
		"rim_power must sync")
	assert_almost_eq(surf_mat.get_shader_parameter("rim_strength"), 0.55, 0.001,
		"rim_strength must sync")

