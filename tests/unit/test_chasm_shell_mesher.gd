class_name TestChasmShellMesher
extends "res://tests/framework/test_case.gd"

## Unit test suite for Phase 2.1: Bypass 3D Voxelization Pattern for Chasms.
## Validates ChasmChunkData virtual voxel access, ChasmShellMesher 2D greedy floor/ceiling passes,
## inverted downward ceiling normals, vertical curtain wall generation, and subterranean water.

const ChasmChunkData = preload("res://src/core/chasm_chunk_data.gd")
const ChasmShellMesher = preload("res://src/meshing/chasm_shell_mesher.gd")

func test_chasm_chunk_data_virtual_voxels() -> void:
	var s_data = SurfaceChunkData.new(16)
	s_data.fill(50, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var chasm_data = ChasmChunkData.new(16, 160, s_data)
	chasm_data.chasm_water_level = 10

	# Mark column (5, 5) as chasm void between Y=6 and Y=20
	chasm_data.set_floor(5, 5, 6)
	chasm_data.set_ceil(5, 5, 20)
	chasm_data.set_flags(5, 5, ChasmChunkData.FLAG_CHASM)
	chasm_data.set_column_material(5, 5, MaterialDef.ID_CHASM_BASALT)
	chasm_data.has_chasm = true

	# 1. Bedrock protection: Y=0..2 must be solid stone
	for y in range(0, 3):
		assert_eq(chasm_data.get_voxel(5, y, 5), MaterialDef.ID_STONE, "Bedrock must remain solid stone")

	# 2. Floor voxel at Y=6 must be basalt
	assert_eq(chasm_data.get_voxel(5, 6, 5), MaterialDef.ID_CHASM_BASALT, "Chasm floor must be basalt")

	# 3. Chasm air void Y=7..19 must be hollow air (0)
	for y in range(7, 20):
		assert_eq(chasm_data.get_voxel(5, y, 5), 0, "Chasm void at Y=%d must be 0 (air)" % y)

	# 4. Ceiling voxel at Y=20 must be solid basalt/wall
	assert_eq(chasm_data.get_voxel(5, 20, 5), MaterialDef.ID_CHASM_BASALT, "Chasm ceiling must be basalt")

	# 5. Overburden solid rock at Y=30 must be solid stone
	assert_eq(chasm_data.get_voxel(5, 30, 5), MaterialDef.ID_STONE, "Overburden rock must be solid stone")

	# 6. Surface voxel at Y=50 must be top material (grass)
	assert_eq(chasm_data.get_voxel(5, 50, 5), MaterialDef.ID_GRASS, "Surface must be grass")

	# 7. Sky voxel above surface Y=51 must be air (0)
	assert_eq(chasm_data.get_voxel(5, 51, 5), 0, "Sky must be air")

	# 8. Subterranean water check: Y=7..10 must report has_water = true
	for y in range(7, 11):
		assert_true(chasm_data.has_water(5, y, 5), "Void below water_level must be water")
	# Above water_level (Y=11) must not be water
	assert_false(chasm_data.has_water(5, 11, 5), "Void above water_level must not be water")

func test_chasm_shell_mesher_floor_and_ceiling() -> void:
	var s_data = SurfaceChunkData.new(16)
	s_data.fill(50, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var chasm_data = ChasmChunkData.new(16, 160, s_data)
	chasm_data.has_chasm = true

	# Fill a flat 16x16 chasm chamber: floor Y=8, ceiling Y=24
	for lz in range(-1, 17):
		for lx in range(-1, 17):
			chasm_data.set_floor(lx, lz, 8)
			chasm_data.set_ceil(lx, lz, 24)
			chasm_data.set_flags(lx, lz, ChasmChunkData.FLAG_CHASM)
			chasm_data.set_column_material(lx, lz, MaterialDef.ID_CHASM_BASALT)

	var mesher = ChasmShellMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var mesh = mesher.build_mesh(chasm_data, reg)

	assert_true(mesh is DualMeshBundle, "ChasmShellMesher must produce DualMeshBundle")
	var bundle = mesh as DualMeshBundle

	assert_true(bundle.has_cave_geometry(), "Bundle must contain cave geometry")
	var cave = bundle.cave_mesh_data

	# With 2D greedy merging across a flat 16x16 chamber with no walls:
	# Floor should merge into a single 16x16 quad (2 triangles)!
	# Ceiling should merge into a single 16x16 quad (2 triangles)!
	# Total cave triangles: 4 triangles! (compared to 1,024 triangles without greedy merging!)
	assert_eq(cave.get_triangle_count(), 4, "Flat 16x16 chamber should merge into 4 triangles (2 floor + 2 ceiling)")

	# Verify upward normal for floor and downward normal for ceiling
	var found_up = false
	var found_down = false
	for norm in cave.normals:
		if norm.is_equal_approx(Vector3.UP):
			found_up = true
		elif norm.is_equal_approx(Vector3.DOWN):
			found_down = true

	assert_true(found_up, "Cave mesh must have upward facing floor normals")
	assert_true(found_down, "Cave mesh must have downward facing ceiling normals")

func test_chasm_shell_mesher_vertical_curtain_walls() -> void:
	var s_data = SurfaceChunkData.new(16)
	s_data.fill(50, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var chasm_data = ChasmChunkData.new(16, 160, s_data)
	chasm_data.has_chasm = true

	# Create a 4x4 chasm void pit inside a solid chunk (from x=4..7, z=4..7)
	for lz in range(4, 8):
		for lx in range(4, 8):
			chasm_data.set_floor(lx, lz, 6)
			chasm_data.set_ceil(lx, lz, 20)
			chasm_data.set_flags(lx, lz, ChasmChunkData.FLAG_CHASM)
			chasm_data.set_column_material(lx, lz, MaterialDef.ID_CHASM_BASALT)

	var mesher = ChasmShellMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var bundle = mesher.build_mesh(chasm_data, reg) as DualMeshBundle

	assert_true(bundle.has_cave_geometry(), "Pit must have cave geometry")
	var cave = bundle.cave_mesh_data

	# Pit has:
	# 1 merged floor quad (2 tris)
	# 1 merged ceiling quad (2 tris)
	# 4 vertical curtain walls around perimeter:
	# - West wall (x=4 facing +X): 1 merged 4m wide quad (2 tris)
	# - East wall (x=8 facing -X): 1 merged 4m wide quad (2 tris)
	# - North wall (z=4 facing +Z): 1 merged 4m wide quad (2 tris)
	# - South wall (z=8 facing -Z): 1 merged 4m wide quad (2 tris)
	# Total cave triangles: 2 + 2 + 8 = 12 triangles!
	assert_eq(cave.get_triangle_count(), 12, "4x4 pit with greedy curtain walls should produce 12 triangles")

	# Verify curtain wall lateral normals exist
	var found_left = false
	var found_right = false
	var found_back = false
	var found_forward = false

	for norm in cave.normals:
		if norm.is_equal_approx(Vector3.LEFT): found_left = true
		if norm.is_equal_approx(Vector3.RIGHT): found_right = true
		if norm.is_equal_approx(Vector3.BACK): found_back = true
		if norm.is_equal_approx(Vector3.FORWARD): found_forward = true

	assert_true(found_left and found_right and found_back and found_forward, "Curtain walls must contain all 4 cardinal inward normals")

func test_voxel_mesher_delegation_to_chasm_shell_mesher() -> void:
	var s_data = SurfaceChunkData.new(16)
	s_data.fill(50, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var chasm_data = ChasmChunkData.new(16, 160, s_data)
	chasm_data.has_chasm = true
	chasm_data.set_floor(5, 5, 8)
	chasm_data.set_ceil(5, 5, 22)
	chasm_data.set_flags(5, 5, ChasmChunkData.FLAG_CHASM)

	var voxel_mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()

	# Polymorphic call to VoxelMesher.build_mesh with ChasmChunkData
	var res = voxel_mesher.build_mesh(chasm_data, reg)
	assert_true(res is DualMeshBundle, "VoxelMesher must delegate ChasmChunkData to ChasmShellMesher")
	var bundle = res as DualMeshBundle
	assert_true(bundle.has_cave_geometry(), "Delegated bundle must contain cave geometry")
