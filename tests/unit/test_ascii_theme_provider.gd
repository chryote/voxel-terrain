class_name TestAsciiThemeProvider
extends "res://tests/framework/test_case.gd"

const ProviderClass = preload("res://src/rendering/terrain_material_provider.gd")
const AsciiConfigClass = preload("res://src/rendering/ascii_atlas_config.gd")
const GraphicNovelConfigClass = preload("res://src/rendering/graphic_novel_config.gd")

func before_each() -> void:
	ProviderClass.reset()

func after_each() -> void:
	ProviderClass.reset()

func test_provider_creates_ascii_surface_material() -> void:
	var cfg = AsciiConfigClass.create_default_config()
	cfg.glyphs_per_voxel = 3.0
	cfg.depth_relief_strength = 0.65

	var mat = ProviderClass.get_ascii_surface_material(cfg)
	assert_not_null(mat, "ASCII surface material must not be null")
	assert_not_null(mat.shader, "Material must have shader assigned")
	assert_almost_eq(float(mat.get_shader_parameter("glyphs_per_voxel")), 3.0, 0.01, "glyphs_per_voxel parameter must match")
	assert_almost_eq(float(mat.get_shader_parameter("depth_relief_strength")), 0.65, 0.01, "depth_relief_strength must match")

func test_provider_caches_ascii_surface_material() -> void:
	var mat1 = ProviderClass.get_ascii_surface_material()
	var mat2 = ProviderClass.get_ascii_surface_material()
	assert_eq(mat1, mat2, "Provider must return identical cached material instance")

func test_provider_creates_distinct_cave_material() -> void:
	var surf_mat = ProviderClass.get_ascii_surface_material()
	var cave_mat = ProviderClass.get_ascii_cave_material()

	assert_not_null(cave_mat, "Cave material must not be null")
	assert_ne(surf_mat, cave_mat, "Surface and cave materials must be distinct instances")

	var surf_tint = surf_mat.get_shader_parameter("shadow_tint") as Color
	var cave_tint = cave_mat.get_shader_parameter("shadow_tint") as Color
	assert_true(cave_tint.v < surf_tint.v, "Cave shadow tint must be darker than surface tint")

func test_provider_polymorphic_dispatch() -> void:
	var ascii_cfg = AsciiConfigClass.create_default_config()
	var ascii_mat = ProviderClass.get_surface_material(ascii_cfg)
	assert_true(ascii_mat.shader.resource_path.contains("ascii_terrain.gdshader"), "Should dispatch to ascii shader")

	var hn_cfg = GraphicNovelConfigClass.create_default_config()
	var hn_mat = ProviderClass.get_surface_material(hn_cfg)
	assert_true(hn_mat.shader.resource_path.contains("halftone_terrain.gdshader"), "Should dispatch to halftone shader")

func test_ascii_theme_tres_resource_file() -> void:
	var res = load("res://config/ascii_terrain_theme.tres") as Resource
	assert_not_null(res, "Theme .tres resource must load successfully")
	assert_almost_eq(res.glyphs_per_voxel, 10.0, 0.01, "Theme glyphs_per_voxel should be 10.0")
	assert_almost_eq(res.depth_relief_strength, 0.15, 0.01, "Theme depth_relief_strength should be 0.15")
	assert_not_null(res.atlas_texture, "Theme should have atlas_texture assigned")
	assert_not_null(res.material_glyph_lut, "Theme should have material_glyph_lut assigned")

func test_chunk_node_shared_material_binding() -> void:
	var surf_mat = ProviderClass.get_ascii_surface_material()
	var cave_mat = ProviderClass.get_ascii_cave_material()

	ChunkNode.configure_shared_materials(surf_mat, cave_mat)
	var node = ChunkNode.new()
	node._ensure_nodes_exist()

	assert_eq(node.mesh_instance.material_override, surf_mat, "ChunkNode surface mesh must use configured shared material")
	assert_eq(node.cave_mesh_instance.material_override, cave_mat, "ChunkNode cave mesh must use configured cave material")

	# Clean up node
	node.free()
