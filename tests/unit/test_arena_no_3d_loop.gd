class_name TestArenaNo3DLoop
extends "res://tests/framework/test_case.gd"

## Unit test suite strictly forbidding underground arena chasm chunks from using the expensive 3D voxel loop.
## Ensures all chunks intersecting battle arena floors, spectator ledges, and perimeter dome structures
## generate via the high-speed 2.5D ChasmChunkData pipeline (<15ms) and bypass 185k voxel arrays.

const ChasmChunkDataClass = preload("res://src/core/chasm_chunk_data.gd")
const VoxelChunkDataClass = preload("res://src/core/voxel_chunk_data.gd")
const BenchmarkChunkSelectorClass = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd")

func test_forbid_3d_loop_in_all_arena_chunks() -> void:
	## Scans the world to locate multiple actual arena anchors.
	## Forbids any subterranean chunk containing arena columns from using VoxelChunkData.
	var seed_val = 1337
	var world_config = WorldConfig.new()
	world_config.world_seed = seed_val
	var bounds = world_config.create_world_bounds()
	var gen = LayeredTerrainGenerator.new(seed_val)
	var sampler = gen.cave_carver.chasm_sampler

	var col = ChasmColumnResult.new()
	var c_size = bounds.chunk_size

	# Discover arena anchor coordinates across world
	var arena_centers: Array[ChunkCoord] = []
	for cz in range(-30, 31, 3):
		for cx in range(-30, 31, 3):
			var center_wx = float(cx * c_size + (c_size / 2)) * bounds.voxel_size
			var center_wz = float(cz * c_size + (c_size / 2)) * bounds.voxel_size
			sampler.sample_column(center_wx, center_wz, col)
			if col.is_arena and col.raw_rift >= (gen.cave_config.arena_rift_threshold + 0.02):
				arena_centers.append(ChunkCoord.new(cx, cz))
				if arena_centers.size() >= 3:
					break
		if arena_centers.size() >= 3:
			break

	assert_true(arena_centers.size() > 0, "Must locate at least one arena center in the world")

	# For each arena center, test a 3x3 chunk neighborhood covering the entire arena complex
	var tested_arena_chunks = 0
	for center in arena_centers:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var coord = ChunkCoord.new(center.x + dx, center.z + dz)
				var min_wx = float(coord.x * c_size) * bounds.voxel_size
				var min_wz = float(coord.z * c_size) * bounds.voxel_size
				var max_wx = float((coord.x + 1) * c_size) * bounds.voxel_size
				var max_wz = float((coord.z + 1) * c_size) * bounds.voxel_size

				# Check if this chunk intersects the arena
				if sampler.can_arena_intersect_box(min_wx, min_wz, max_wx, max_wz):
					var s_data = gen.generate_surface(coord, bounds)
					var sub_data = gen.generate_subterranean(s_data, coord, bounds)

					assert_not_null(sub_data, "Subterranean chunk data must exist at %s" % coord)

					# HARD FORBID: Must NEVER use expensive 3D VoxelChunkData
					assert_false(
						sub_data is VoxelChunkDataClass,
						"VIOLATION: Arena chunk at (%d, %d) must NOT use expensive 3D VoxelChunkData loop!" % [coord.x, coord.z]
					)
					assert_true(
						sub_data is ChasmChunkDataClass,
						"Arena chunk at (%d, %d) must use high-speed 2.5D ChasmChunkData" % [coord.x, coord.z]
					)
					tested_arena_chunks += 1

	assert_true(tested_arena_chunks >= 3, "Must test and enforce 3D loop prohibition across multiple arena chunks (tested %d)" % tested_arena_chunks)

func test_forbid_3d_loop_in_spectator_ledges_and_perimeter() -> void:
	## Validates that arena perimeter chunks containing spectator ledges (0.80 <= rift < 0.82)
	## or arena transition borders are strictly dispatched to ChasmChunkData.
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var gen = LayeredTerrainGenerator.new(1337)
	var selector = BenchmarkChunkSelectorClass.new()
	var arena_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)

	assert_not_null(arena_coord, "Must locate arena center chunk")

	var c_size = bounds.chunk_size
	var sampler = gen.cave_carver.chasm_sampler

	var checked_perimeter_chunks = 0
	# Test chunks in concentric rings around arena center
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var coord = ChunkCoord.new(arena_coord.x + dx, arena_coord.z + dz)
			var min_wx = float(coord.x * c_size) * bounds.voxel_size
			var min_wz = float(coord.z * c_size) * bounds.voxel_size
			var max_wx = float((coord.x + 1) * c_size) * bounds.voxel_size
			var max_wz = float((coord.z + 1) * c_size) * bounds.voxel_size

			if sampler.can_arena_intersect_box(min_wx, min_wz, max_wx, max_wz):
				var s_data = gen.generate_surface(coord, bounds)
				var sub_data = gen.generate_subterranean(s_data, coord, bounds)

				assert_true(sub_data is ChasmChunkDataClass, "Perimeter arena chunk at (%d, %d) must be ChasmChunkData" % [coord.x, coord.z])
				assert_false(sub_data is VoxelChunkDataClass, "Perimeter arena chunk must never allocate 185k voxel array")
				checked_perimeter_chunks += 1

	assert_true(checked_perimeter_chunks >= 1, "Must verify perimeter chunks (checked %d)" % checked_perimeter_chunks)

func test_arena_tunnel_culling_in_core_cell() -> void:
	## Validates that SubterraneanTunnelSampler.can_tunnel_intersect_cell()
	## returns false inside core arena cells where worm tunnels are pinched off.
	var gen = LayeredTerrainGenerator.new(1337)
	var bounds = WorldConfig.new().create_world_bounds()
	var selector = BenchmarkChunkSelectorClass.new()
	var arena_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)

	# Locate a core cell inside the arena where suppression reaches 0.0
	var c_size = bounds.chunk_size
	var core_wx = float(arena_coord.x * c_size + 12) * bounds.voxel_size
	var core_wz = float(arena_coord.z * c_size + 12) * bounds.voxel_size
	var cell_min = Vector3(core_wx - 2.0, 6.0, core_wz - 2.0)
	var cell_max = Vector3(core_wx + 2.0, 26.0, core_wz + 2.0)

	var tunnel_sampler = gen.cave_carver.tunnel_sampler
	var can_intersect = tunnel_sampler.can_tunnel_intersect_cell(cell_min, cell_max)

	assert_false(
		can_intersect,
		"can_tunnel_intersect_cell must return false inside core combat arena due to mathematical tunnel suppression"
	)

func test_arena_chasm_meshing_performance_and_geometry() -> void:
	## Validates that arena chunks mesh via ChasmShellMesher in < 25ms,
	## completely bypassing the ~280ms cubic greedy mesher, while producing full geometry.
	var bounds = WorldConfig.new().create_world_bounds()
	var gen = LayeredTerrainGenerator.new(1337)
	var selector = BenchmarkChunkSelectorClass.new()
	var arena_coord = selector.find_arena_center(gen.cave_carver.chasm_sampler, bounds)

	var s_data = gen.generate_surface(arena_coord, bounds)
	var sub_data = gen.generate_subterranean(s_data, arena_coord, bounds)
	assert_true(sub_data is ChasmChunkDataClass, "Must be ChasmChunkData")

	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()

	var t0 = Time.get_ticks_usec()
	var bundle = mesher.build_mesh(sub_data, reg) as DualMeshBundle
	var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0

	assert_not_null(bundle, "Meshing must produce DualMeshBundle")
	assert_true(elapsed_ms < 25.0, "Arena meshing must be < 25ms via ChasmShellMesher (measured %.2f ms)" % elapsed_ms)
	assert_true(bundle.has_cave_geometry(), "Arena must contain cave geometry")
	assert_true(bundle.cave_mesh_data.get_vertex_count() > 0, "Must have cave vertices")
	assert_true(bundle.cave_mesh_data.get_triangle_count() > 0, "Must have cave triangles")

	# Physics collision baking validation (< 10ms concave trimesh)
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(bundle, true)
	assert_not_null(shapes.cave_shape, "Must produce valid physics cave collision shape")
