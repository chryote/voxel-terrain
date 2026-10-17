class_name TestVoxelMesher
extends "res://tests/framework/test_case.gd"

func test_single_cube_meshing() -> void:
	var c_size = 4
	var data = VoxelChunkData.new(c_size, 8)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Single isolated cube at (1, 1, 1) has 6 faces (each 4 vertices, 2 triangles)
	# 6 faces * 4 vertices = 24 vertices, 6 * 2 = 12 triangles
	data.set_voxel(1, 1, 1, MaterialDef.ID_STONE)

	var mesh = mesher.build_mesh(data, reg)
	assert_false(mesh.is_empty(), "Mesh must not be empty")
	assert_eq(mesh.get_triangle_count(), 12, "Single cube must generate exactly 12 triangles (6 faces * 2 tris)")
	assert_eq(mesh.get_vertex_count(), 24, "Single cube must generate exactly 24 vertices (6 faces * 4 verts)")

func test_greedy_merging_flat_slab() -> void:
	var c_size = 8
	var data = VoxelChunkData.new(c_size, 8)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Fill a flat 4x4 slab at Y=0 of thickness 1 (from lx: 0..3, lz: 0..3, ly: 0)
	for lz in range(4):
		for lx in range(4):
			data.set_voxel(lx, 0, lz, MaterialDef.ID_GRASS)

	var mesh = mesher.build_mesh(data, reg)
	assert_false(mesh.is_empty())

	# A uniform 4x4 slab has:
	# 1 top quad (merged 4x4)
	# 1 bottom quad (merged 4x4)
	# 4 side quads (each 4x1)
	# Total = exactly 6 quads = 12 triangles!
	# Without greedy merging it would be 4*4*2 (top) + 4*4*2 (bottom) + 4*4*2 (sides) = 96 triangles.
	assert_eq(mesh.get_triangle_count(), 12, "4x4 flat slab must greedily merge down to exactly 12 triangles (6 quads)")
	assert_eq(mesh.get_vertex_count(), 24, "4x4 flat slab must greedily merge down to exactly 24 vertices (6 quads)")

func test_internal_face_culling() -> void:
	var c_size = 4
	var data = VoxelChunkData.new(c_size, 8)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Two adjacent cubes at (1, 1, 1) and (2, 1, 1)
	# The shared face between them (+X of cube 1, -X of cube 2) MUST be culled!
	# Cube 1 has 5 exposed faces, Cube 2 has 5 exposed faces.
	# 10 exposed faces greedily merge into:
	# Top: 1 quad (2x1)
	# Bottom: 1 quad (2x1)
	# West: 1 quad (1x1)
	# East: 1 quad (1x1)
	# South: 1 quad (2x1)
	# North: 1 quad (2x1)
	# Total = 6 quads = 12 triangles!
	data.set_voxel(1, 1, 1, MaterialDef.ID_STONE)
	data.set_voxel(2, 1, 1, MaterialDef.ID_STONE)

	var mesh = mesher.build_mesh(data, reg)
	assert_eq(mesh.get_triangle_count(), 12, "Adjacent cubes must cull internal face and merge shared sides")

func test_subterranean_water_meshing() -> void:
	var c_size = 4
	var data = VoxelChunkData.new(c_size, 8)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Place water at (1, 1, 1) and (2, 1, 1)
	data.set_water(1, 1, 1, true)
	data.set_water(2, 1, 1, true)

	var mesh = mesher.build_mesh(data, reg)
	assert_not_null(mesh.water_mesh_data, "Water mesh data should be generated")
	assert_false(mesh.water_mesh_data.is_empty(), "Water mesh should not be empty")

	# 2 adjacent water blocks greedily merge into 1 top quad (2 triangles, 4 vertices)
	assert_eq(mesh.water_mesh_data.get_triangle_count(), 2, "Adjacent water voxels must merge into 1 quad (2 tris)")

func test_polymorphic_fallback_with_surface_chunk_data() -> void:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Must accept SurfaceChunkData without error and produce valid mesh via delegation
	var mesh = mesher.build_mesh(data, reg)
	assert_not_null(mesh)
	assert_false(mesh.is_empty(), "Polymorphic surface fallback must produce non-empty mesh")
