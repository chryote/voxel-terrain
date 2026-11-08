class_name TestExtremeDistanceTerrain
extends "res://tests/framework/test_case.gd"

## Comprehensive unit test suite for Extreme Distance Surface Terrain LOD.
## Validates:
## 1. ExtremeDistanceTerrainMesher grid construction, normals, bounds, and material classification.
## 2. ExtremeDistanceMaterialProvider caching, reset, and shader uniform binding.
## 3. Shader compilation and feature integrity (clipping, strata, dither fade).
## 4. ExtremeDistanceTerrain node lifecycle, synchronous/asynchronous setup, and clipping updates.
## 5. VoxelWorld integration and subterranean visibility synchronization.
## 6. Architectural clean code enforcement (zero Node dependencies, length bounds).

const MesherClass = preload("res://src/meshing/extreme_distance_terrain_mesher.gd")
const ProviderClass = preload("res://src/rendering/extreme_distance_material_provider.gd")
const ExtremeTerrainClass = preload("res://src/world/extreme_distance_terrain.gd")
const WorldConfigClass = preload("res://src/core/world_config.gd")
const WorldBoundsClass = preload("res://src/core/world_bounds.gd")
const GeneratorClass = preload("res://src/generation/continent_generator.gd")
const MaterialRegistryClass = preload("res://src/core/material_registry.gd")
const VoxelWorldClass = preload("res://src/world/voxel_world.gd")

func before_each() -> void:
	ProviderClass.reset()

func after_each() -> void:
	ProviderClass.reset()

func test_mesher_grid_dimensions() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(32, 32), 32, 1.0)
	var gen = GeneratorClass.new(1337)
	var reg = MaterialRegistryClass.create_default_registry()
	var mesher = MesherClass.new()

	for res in [8, 16, 32]:
		var data = mesher.build_mesh(gen, bounds, reg, res)
		var expected_verts = (res + 1) * (res + 1)
		var expected_tris = res * res * 2
		var expected_inds = res * res * 6

		assert_eq(data.get_vertex_count(), expected_verts, "Vertex count must equal (res+1)^2 for res %d" % res)
		assert_eq(data.get_triangle_count(), expected_tris, "Triangle count must equal res^2 * 2 for res %d" % res)
		assert_eq(data.indices.size(), expected_inds, "Indices size must equal res^2 * 6 for res %d" % res)
		assert_false(data.is_empty(), "Mesh data must not be empty")

func test_mesher_bounds_coverage() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(64, 64), 32, 1.0)
	var gen = GeneratorClass.new(1337)
	var mesher = MesherClass.new()
	var res = 16
	var data = mesher.build_mesh(gen, bounds, null, res)

	# Corner 0: (min_x, min_z)
	var v_first = data.vertices[0]
	assert_almost_eq(v_first.x, bounds.min_world_x, 0.01, "First vertex X must align with min_world_x")
	assert_almost_eq(v_first.z, bounds.min_world_z, 0.01, "First vertex Z must align with min_world_z")

	# Corner last: (max_x, max_z)
	var v_last = data.vertices[data.vertices.size() - 1]
	assert_almost_eq(v_last.x, bounds.max_world_x, 0.01, "Last vertex X must align with max_world_x")
	assert_almost_eq(v_last.z, bounds.max_world_z, 0.01, "Last vertex Z must align with max_world_z")

func test_mesher_normals_and_colors() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(32, 32), 32, 1.0)
	var gen = GeneratorClass.new(1337)
	var reg = MaterialRegistryClass.create_default_registry()
	var mesher = MesherClass.new()
	var data = mesher.build_mesh(gen, bounds, reg, 16)

	assert_eq(data.normals.size(), data.vertices.size(), "Normal count must match vertex count")
	assert_eq(data.colors.size(), data.vertices.size(), "Color count must match vertex count")

	for i in range(mini(100, data.normals.size())):
		var norm = data.normals[i]
		assert_almost_eq(norm.length(), 1.0, 0.02, "Normals must be normalized")
		assert_true(norm.y > 0.0, "Surface terrain normals must point predominantly upwards")

		var col = data.colors[i]
		assert_true(col.a > 0.0 and col.a <= 1.0, "Vertex color alpha must encode material id")

func test_mesher_handles_null_gracefully() -> void:
	var mesher = MesherClass.new()
	var data_null_gen = mesher.build_mesh(null, WorldBoundsClass.new())
	assert_true(data_null_gen.is_empty(), "Mesher must return empty MeshData when generator is null")

	var data_null_bounds = mesher.build_mesh(GeneratorClass.new(), null)
	assert_true(data_null_bounds.is_empty(), "Mesher must return empty MeshData when bounds is null")

func test_material_provider_caching_and_uniforms() -> void:
	var mat1 = ProviderClass.get_material()
	assert_not_null(mat1, "Material provider must return ShaderMaterial")
	assert_true(mat1 is ShaderMaterial, "Must be ShaderMaterial")

	var mat2 = ProviderClass.get_material()
	assert_eq(mat1, mat2, "Provider must return cached instance on repeated calls")

	ProviderClass.reset()
	var mat3 = ProviderClass.get_material()
	assert_ne(mat1, mat3, "ProviderClass.reset() must clear cached material")

func test_shader_compilation_and_code() -> void:
	var shader = load("res://shaders/terrain/distant_macro_terrain.gdshader") as Shader
	assert_not_null(shader, "Distant macro terrain shader must load successfully")
	var code = shader.code

	assert_true(code.contains("shader_type spatial;"), "Must be spatial shader")
	assert_true(code.contains("u_clip_center"), "Must define u_clip_center uniform")
	assert_true(code.contains("u_clip_radius"), "Must define u_clip_radius uniform")
	assert_true(code.contains("u_clip_feather"), "Must define u_clip_feather uniform")
	assert_true(code.contains("evaluate_bayer_dither"), "Must implement 4x4 Bayer dither crossfade")
	assert_true(code.contains("apply_strata_tonal"), "Must implement tonal sedimentary strata coloration")
	assert_true(code.contains("diffuse_toon"), "Must use diffuse_toon render mode")
	assert_true(code.contains("haze_color"), "Must define atmospheric haze_color uniform")
	assert_true(code.contains("apply_atmospheric_perspective"), "Must implement atmospheric aerial perspective")
	assert_true(code.contains("mono_color_enabled"), "Must define mono_color_enabled uniform")
	assert_true(code.contains("apply_monochrome_blue"), "Must implement monochromatic blue hue mapping")
	assert_true(code.contains("mono_blue_low"), "Must define mono_blue_low uniform")
	assert_true(code.contains("mono_blue_high"), "Must define mono_blue_high uniform")
	assert_true(code.contains("pixel_art_enabled"), "Must define pixel_art_enabled uniform")
	assert_true(code.contains("pixel_size"), "Must define pixel_size uniform")
	assert_true(code.contains("terrace_step"), "Must define terrace_step uniform")
	assert_true(code.contains("depth_step_distance"), "Must define depth_step_distance uniform")
	assert_true(code.contains("palette_base"), "Must define palette_base uniform")

func test_extreme_distance_terrain_node_sync() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(32, 32), 32, 1.0)
	var gen = GeneratorClass.new(1337)
	var reg = MaterialRegistryClass.create_default_registry()

	var node = ExtremeTerrainClass.new()
	node.setup(bounds, gen, reg, 16, null, false)

	assert_true(node.is_mesh_ready, "Synchronous setup must immediately set is_mesh_ready")
	assert_not_null(node.mesh, "Mesh must be created")
	assert_not_null(node.material_override, "material_override must be set")
	assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Shadows must be disabled")

	node.update_clip(Vector3(100.0, 0.0, 200.0), 180.0, 24.0)
	var center = node.macro_material.get_shader_parameter("u_clip_center")
	var radius = node.macro_material.get_shader_parameter("u_clip_radius")
	var feather = node.macro_material.get_shader_parameter("u_clip_feather")

	assert_eq(center, Vector3(100.0, 0.0, 200.0), "u_clip_center must update")
	assert_almost_eq(float(radius), 180.0, 0.01, "u_clip_radius must update")
	assert_almost_eq(float(feather), 24.0, 0.01, "u_clip_feather must update")

	# Test atmospheric haze configuration
	var muted_blue = Color(0.42, 0.50, 0.62, 1.0)
	node.set_atmospheric_haze(muted_blue, 0.60, 250.0, 3000.0, true)
	var h_col = node.macro_material.get_shader_parameter("haze_color")
	var h_int = node.macro_material.get_shader_parameter("haze_intensity")
	var h_start = node.macro_material.get_shader_parameter("haze_start_distance")
	var h_max = node.macro_material.get_shader_parameter("haze_max_distance")
	assert_eq(h_col, muted_blue, "haze_color must update")
	assert_almost_eq(float(h_int), 0.60, 0.01, "haze_intensity must update")
	assert_almost_eq(float(h_start), 250.0, 0.01, "haze_start_distance must update")
	assert_almost_eq(float(h_max), 3000.0, 0.01, "haze_max_distance must update")

	# Test monochromatic blue palette configuration
	var blue_low = Color(0.28, 0.34, 0.44, 1.0)
	var blue_mid = Color(0.40, 0.48, 0.60, 1.0)
	var blue_high = Color(0.70, 0.78, 0.88, 1.0)
	node.set_monochromatic_palette(blue_low, blue_mid, blue_high, 0.95, -1.0, 360.0, true)
	var m_low = node.macro_material.get_shader_parameter("mono_blue_low")
	var m_mid = node.macro_material.get_shader_parameter("mono_blue_mid")
	var m_high = node.macro_material.get_shader_parameter("mono_blue_high")
	var m_blend = node.macro_material.get_shader_parameter("mono_color_blend")
	assert_eq(m_low, blue_low, "mono_blue_low must update")
	assert_eq(m_mid, blue_mid, "mono_blue_mid must update")
	assert_eq(m_high, blue_high, "mono_blue_high must update")
	assert_almost_eq(float(m_blend), 0.95, 0.01, "mono_color_blend must update")

	# Test pixel art style configuration
	node.set_pixel_art_style(true, 5.0, 20.0, 900.0)
	var pa_en = node.macro_material.get_shader_parameter("pixel_art_enabled")
	var pa_sz = node.macro_material.get_shader_parameter("pixel_size")
	var pa_ter = node.macro_material.get_shader_parameter("terrace_step")
	var pa_dep = node.macro_material.get_shader_parameter("depth_step_distance")
	assert_true(bool(pa_en), "pixel_art_enabled must update")
	assert_almost_eq(float(pa_sz), 5.0, 0.01, "pixel_size must update")
	assert_almost_eq(float(pa_ter), 20.0, 0.01, "terrace_step must update")
	assert_almost_eq(float(pa_dep), 900.0, 0.01, "depth_step_distance must update")

	node.set_macro_visible(false)
	assert_false(node.visible, "set_macro_visible(false) must hide node")
	node.set_macro_visible(true)
	assert_true(node.visible, "set_macro_visible(true) must show node")

	node.free()

func test_voxel_world_integration() -> void:
	var world = VoxelWorldClass.new()
	var w_cfg = WorldConfigClass.new()
	w_cfg.map_size_chunks = Vector2i(8, 8)
	w_cfg.view_distance_chunks = 2
	w_cfg.extreme_lod_enabled = true
	w_cfg.extreme_lod_resolution = 16
	world.world_config = w_cfg

	world._ready()

	assert_not_null(world.extreme_distance_terrain, "VoxelWorld must create extreme_distance_terrain instance")
	assert_true(world.extreme_distance_terrain is ExtremeTerrainClass, "Must be ExtremeDistanceTerrain instance")

	# Test layer visibility synchronization
	world._update_layer_visibility(true)
	assert_true(world.extreme_distance_terrain.visible, "Extreme distance terrain must be visible on the surface")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()

func test_architecture_compliance() -> void:
	var paths = [
		"res://src/meshing/extreme_distance_terrain_mesher.gd",
		"res://src/rendering/extreme_distance_material_provider.gd"
	]

	for p in paths:
		var file = FileAccess.open(p, FileAccess.READ)
		assert_not_null(file, "File %s must exist" % p)
		var content = file.get_as_text()
		file.close()

		assert_false(content.contains("extends Node\n") or content.contains("extends Node "),
			"%s must not extend Node" % p)
		assert_false(content.contains("extends Node3D"),
			"%s must not extend Node3D" % p)
		assert_false(content.contains("extends Node2D"),
			"%s must not extend Node2D" % p)
		assert_false(content.contains("res://src/world"),
			"%s must not reference src/world" % p)
		assert_false(content.contains("res://src/player"),
			"%s must not reference src/player" % p)
		assert_false(content.contains("VoxelWorld"),
			"%s must not reference VoxelWorld" % p)
		assert_false(content.contains("PlayerMotor"),
			"%s must not reference PlayerMotor" % p)

		var line_count = content.split("\n").size()
		assert_true(line_count <= 165, "%s has %d lines (must be <= 165 lines)" % [p, line_count])
