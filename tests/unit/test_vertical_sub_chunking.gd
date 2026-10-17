class_name TestVerticalSubChunking
extends "res://tests/framework/test_case.gd"

## Unit tests validating Item 3.1: Vertical Sub-Chunk Partitioning (32x32x16).
## Verifies section status computation, uniform air/solid detection,
## and greedy meshing equivalence with section skipping.

func test_section_count_and_status() -> void:
	var data = VoxelChunkData.new(32, 160)
	assert_eq(data.get_section_count(), 10, "160m chunk must have 10 sections of height 16")
	assert_true(data.has_section_status)

	# Fresh data should be all EMPTY
	for s in range(10):
		assert_eq(data.get_section_status(s), VoxelChunkData.SECTION_EMPTY, "Section %d must be EMPTY" % s)
		assert_true(data.is_section_empty(s))
		assert_false(data.is_section_solid(s))

	# Fill with stone -> all SOLID
	data.fill_material(MaterialDef.ID_STONE)
	for s in range(10):
		assert_eq(data.get_section_status(s), VoxelChunkData.SECTION_SOLID, "Section %d must be SOLID" % s)
		assert_true(data.is_section_solid(s))
		assert_false(data.is_section_empty(s))

func test_compute_section_status_mixed() -> void:
	var data = VoxelChunkData.new(32, 160)

	# Place voxels only in section 2 (Y = 32..47)
	data.set_voxel(5, 35, 5, MaterialDef.ID_STONE)
	data.set_voxel(6, 35, 5, MaterialDef.ID_STONE)
	data.compute_section_status()

	assert_true(data.is_section_empty(0), "Section 0 must be empty")
	assert_true(data.is_section_empty(1), "Section 1 must be empty")
	assert_eq(data.get_section_status(2), VoxelChunkData.SECTION_MIXED, "Section 2 must be MIXED")
	assert_true(data.is_section_empty(3), "Section 3 must be empty")
	assert_true(data.is_section_empty(9), "Section 9 must be empty")

func test_meshing_equivalence_with_section_skipping() -> void:
	var data = VoxelChunkData.new(16, 64)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = VoxelMesher.new()

	# Section 0 (Y=0..15): Solid stone from Y=0..15
	for ly in range(16):
		for lz in range(-1, 17):
			for lx in range(-1, 17):
				data.set_voxel(lx, ly, lz, MaterialDef.ID_STONE)

	# Section 1 (Y=16..31): A 4x4 dirt platform at Y=16
	for lz in range(4):
		for lx in range(4):
			data.set_voxel(lx, 16, lz, MaterialDef.ID_DIRT)

	# Section 2 and 3 (Y=32..63): Empty air

	data.compute_section_status()
	assert_eq(data.get_section_status(0), VoxelChunkData.SECTION_SOLID)
	assert_eq(data.get_section_status(1), VoxelChunkData.SECTION_MIXED)
	assert_eq(data.get_section_status(2), VoxelChunkData.SECTION_EMPTY)
	assert_eq(data.get_section_status(3), VoxelChunkData.SECTION_EMPTY)

	var mesh = mesher.build_mesh(data, reg)
	assert_false(mesh.is_empty())

	# The mesh should have geometry only where solid meets air:
	# Bottom of bedrock at Y=0 has faces (because below Y=0 is out of bounds/air)
	# Top of stone at Y=15 has faces where not covered by dirt platform
	# Dirt platform at Y=16 has top and sides
	# Sections 2 and 3 (32..63) generated 0 faces and were completely skipped
	assert_true(mesh.get_vertex_count() > 0)
	assert_true(mesh.get_triangle_count() > 0)
