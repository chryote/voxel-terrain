class_name BenchSurfaceVsArena
extends "res://tests/framework/benchmark_case.gd"

## Performance benchmark comparing Surface vs Underground Arena chunk loading pipelines.
## Measures Generation, Meshing, and Collision Baking for 100 chunks in each environment.

const ChunkLoadPipelineClass = preload("res://tests/benchmark/chunk_bench/chunk_load_pipeline.gd")
const BenchmarkChunkSelectorClass = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd")
const ChunkBenchmarkStatsClass = preload("res://tests/benchmark/chunk_bench/chunk_benchmark_stats.gd")
const ChunkBenchmarkReporterClass = preload("res://tests/benchmark/chunk_bench/chunk_benchmark_reporter.gd")

func bench_surface_vs_underground_arena_100_chunks() -> void:
	var chunk_count = 100
	var seed_val = 1337

	var world_config = WorldConfig.new()
	world_config.world_seed = seed_val
	var bounds = world_config.create_world_bounds()

	var gen = LayeredTerrainGenerator.new(seed_val)
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var baker = OffThreadCollisionBaker.new()

	var pipeline = ChunkLoadPipelineClass.new()
	var selector = BenchmarkChunkSelectorClass.new()

	# Warmup pipelines
	pipeline.warmup(bounds, gen, mesher, reg, baker)

	# 1. Select coordinates for 100 surface chunks and 100 arena chunks
	var surf_coords = selector.get_surface_chunks(chunk_count, bounds)
	var arena_coords = selector.get_arena_chunks(chunk_count, bounds, gen.cave_carver.chasm_sampler)

	print("\n[Benchmark] Selected %d surface chunks and %d underground arena chunks." % [
		surf_coords.size(), arena_coords.size()
	])

	# 2. Benchmark 100 Surface Chunks
	print("[Benchmark] Loading %d Surface Chunks..." % surf_coords.size())
	var surf_samples: Array = []
	var t_start_surf = Time.get_ticks_usec()
	for i in range(surf_coords.size()):
		var sample = pipeline.load_surface_chunk(surf_coords[i], bounds, gen, mesher, reg, baker)
		surf_samples.append(sample)
		if (i + 1) % 25 == 0 or (i + 1) == surf_coords.size():
			print("  -> Surface: %d / %d chunks loaded..." % [i + 1, surf_coords.size()])
	var surf_total_elapsed_ms = (Time.get_ticks_usec() - t_start_surf) / 1000.0

	var surf_stats = ChunkBenchmarkStatsClass.compute("Surface Overland", surf_samples)

	# 3. Benchmark 100 Underground Arena Chunks
	print("[Benchmark] Loading %d Underground Arena Chunks..." % arena_coords.size())
	var arena_samples: Array = []
	var t_start_arena = Time.get_ticks_usec()
	for i in range(arena_coords.size()):
		var sample = pipeline.load_arena_chunk(arena_coords[i], bounds, gen, mesher, reg, baker)
		arena_samples.append(sample)
		if (i + 1) % 25 == 0 or (i + 1) == arena_coords.size():
			print("  -> Arena: %d / %d chunks loaded..." % [i + 1, arena_coords.size()])
	var arena_total_elapsed_ms = (Time.get_ticks_usec() - t_start_arena) / 1000.0

	var arena_stats = ChunkBenchmarkStatsClass.compute("Underground Arena", arena_samples)

	# 4. Format and Print Comparison Report
	ChunkBenchmarkReporterClass.print_comparison(surf_stats, arena_stats)

	# 5. Record results in BenchmarkCase dictionary for test runner
	_results["surface_load_100_chunks"] = {
		"name": "surface_load_100_chunks",
		"avg_ms": surf_stats.total_stats.avg,
		"median_ms": surf_stats.total_stats.median,
		"p95_ms": surf_stats.total_stats.p95,
		"min_ms": surf_stats.total_stats.min,
		"max_ms": surf_stats.total_stats.max,
		"total_ms": surf_total_elapsed_ms,
		"iterations": surf_coords.size(),
		"chunks_per_sec": surf_stats.throughput_chunks_per_sec
	}

	_results["arena_load_100_chunks"] = {
		"name": "arena_load_100_chunks",
		"avg_ms": arena_stats.total_stats.avg,
		"median_ms": arena_stats.total_stats.median,
		"p95_ms": arena_stats.total_stats.p95,
		"min_ms": arena_stats.total_stats.min,
		"max_ms": arena_stats.total_stats.max,
		"total_ms": arena_total_elapsed_ms,
		"iterations": arena_coords.size(),
		"chunks_per_sec": arena_stats.throughput_chunks_per_sec
	}
