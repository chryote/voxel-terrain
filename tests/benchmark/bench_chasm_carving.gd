class_name BenchChasmCarving
extends "res://tests/framework/benchmark_case.gd"

## Performance benchmark suite for Phase 4: Subterranean Chasm Carving.
## Measures chunk carving speed across 64 subterranean chunks,
## verifying execution on worker threads stays within the target < 8 ms/chunk.

func bench_subterranean_chasm_dense() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var coord = ChunkCoord.new(3, 3)
	var s_data = gen.generate_surface(coord, bounds)

	benchmark("subterranean_chasm_dense_chunk_16", func():
		var _v = gen.generate_subterranean(s_data, coord, bounds)
	, 15, 3)

func bench_surface_generation_chunk_16() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var coord = ChunkCoord.new(3, 3)

	benchmark("surface_generation_chunk_16", func():
		var _s = gen.generate_surface(coord, bounds)
	, 15, 3)

func bench_subterranean_carve_isolated_chunk_16() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var coord = ChunkCoord.new(3, 3)
	var s_data = gen.generate_surface(coord, bounds)
	var max_h = bounds.chunk_size * 4
	var v_data = gen._populate_voxel_columns(s_data, bounds, max_h)

	benchmark("subterranean_carve_isolated_chunk_16", func():
		gen._carve_subterranean_caves(v_data, s_data, coord, bounds, max_h)
	, 20, 3)

func bench_subterranean_64_chunks_grid() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var max_h = bounds.chunk_size * 4

	# Pre-generate 64 surface chunks and solid base volumes (8x8 grid)
	var surfaces: Array[SurfaceChunkData] = []
	var voxels: Array[VoxelChunkData] = []
	var coords: Array[ChunkCoord] = []
	for cz in range(8):
		for cx in range(8):
			var c = ChunkCoord.new(cx, cz)
			coords.append(c)
			var s = gen.generate_surface(c, bounds)
			surfaces.append(s)
			voxels.append(gen._populate_voxel_columns(s, bounds, max_h))

	# Benchmark carving all 64 subterranean chunks
	benchmark("subterranean_carve_64_chunks_batch", func():
		for i in range(64):
			gen._carve_subterranean_caves(voxels[i], surfaces[i], coords[i], bounds, max_h)
	, 5, 1)
