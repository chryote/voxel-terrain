extends SceneTree

## Standalone CLI executable benchmark tool comparing Surface vs Underground Arena chunk loading.
## Usage:
##   godot --headless --script tests/benchmark/tools/run_surface_vs_arena.gd
##   godot --headless --script tests/benchmark/tools/run_surface_vs_arena.gd -- --chunks=100 --seed=1337 --json=report.json

const ChunkLoadPipelineClass = preload("res://tests/benchmark/chunk_bench/chunk_load_pipeline.gd")
const BenchmarkChunkSelectorClass = preload("res://tests/benchmark/chunk_bench/benchmark_chunk_selector.gd")
const ChunkBenchmarkStatsClass = preload("res://tests/benchmark/chunk_bench/chunk_benchmark_stats.gd")
const ChunkBenchmarkReporterClass = preload("res://tests/benchmark/chunk_bench/chunk_benchmark_reporter.gd")

func _init() -> void:
	var chunk_count = 100
	var seed_val = 1337
	var json_path = ""

	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--chunks="):
			chunk_count = int(arg.substr(9).strip_edges())
		elif arg.begins_with("--seed="):
			seed_val = int(arg.substr(7).strip_edges())
		elif arg.begins_with("--json="):
			json_path = arg.substr(7).strip_edges()
		elif arg == "--help" or arg == "-h":
			_print_help()
			quit(0)
			return

	print("==========================================================================================")
	print(" Starting Benchmark: Surface vs Underground Arena Chunk Loading")
	print(" Seed: %d | Target Chunk Count: %d" % [seed_val, chunk_count])
	print("==========================================================================================")

	var world_config = WorldConfig.new()
	world_config.world_seed = seed_val
	var bounds = world_config.create_world_bounds()

	var gen = LayeredTerrainGenerator.new(seed_val)
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var baker = OffThreadCollisionBaker.new()

	var pipeline = ChunkLoadPipelineClass.new()
	var selector = BenchmarkChunkSelectorClass.new()

	print("\n[1/4] Warming up pipelines...")
	pipeline.warmup(bounds, gen, mesher, reg, baker)

	print("[2/4] Selecting coordinates...")
	var surf_coords = selector.get_surface_chunks(chunk_count, bounds)
	var arena_coords = selector.get_arena_chunks(chunk_count, bounds, gen.cave_carver.chasm_sampler)
	print("  Selected %d surface chunks and %d underground arena chunks." % [surf_coords.size(), arena_coords.size()])

	print("\n[3/4] Benchmarking %d Surface Chunks..." % surf_coords.size())
	var surf_samples: Array = []
	var t0 = Time.get_ticks_usec()
	for i in range(surf_coords.size()):
		var sample = pipeline.load_surface_chunk(surf_coords[i], bounds, gen, mesher, reg, baker)
		surf_samples.append(sample)
		if (i + 1) % 25 == 0 or (i + 1) == surf_coords.size():
			print("  -> Surface: %d / %d chunks loaded..." % [i + 1, surf_coords.size()])
	var surf_elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var surf_stats = ChunkBenchmarkStatsClass.compute("Surface Overland", surf_samples)
	print("  Surface finished in %.2f s (Avg: %.2f ms/chunk)" % [surf_elapsed_ms / 1000.0, surf_stats.total_stats.avg])

	print("\n[4/4] Benchmarking %d Underground Arena Chunks..." % arena_coords.size())
	var arena_samples: Array = []
	t0 = Time.get_ticks_usec()
	for i in range(arena_coords.size()):
		var sample = pipeline.load_arena_chunk(arena_coords[i], bounds, gen, mesher, reg, baker)
		arena_samples.append(sample)
		if (i + 1) % 25 == 0 or (i + 1) == arena_coords.size():
			print("  -> Arena: %d / %d chunks loaded..." % [i + 1, arena_coords.size()])
	var arena_elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var arena_stats = ChunkBenchmarkStatsClass.compute("Underground Arena", arena_samples)
	print("  Arena finished in %.2f s (Avg: %.2f ms/chunk)" % [arena_elapsed_ms / 1000.0, arena_stats.total_stats.avg])

	ChunkBenchmarkReporterClass.print_comparison(surf_stats, arena_stats)

	if json_path != "":
		_export_json(json_path, surf_stats, arena_stats)

	quit(0)

func _print_help() -> void:
	print("Surface vs Underground Arena Chunk Loading Benchmark")
	print("Usage:")
	print("  godot --headless --script tests/benchmark/tools/run_surface_vs_arena.gd -- [OPTIONS]")
	print("Options:")
	print("  --chunks=N     Number of chunks to load for each environment (default: 100)")
	print("  --seed=N       World generation seed (default: 1337)")
	print("  --json=PATH    Export metrics report to JSON file")
	print("  --help, -h     Show this help message")

func _export_json(path: String, surf_stats: RefCounted, arena_stats: RefCounted) -> void:
	var out = {
		"timestamp": Time.get_datetime_string_from_system(),
		"surface": surf_stats.to_dict(),
		"underground_arena": arena_stats.to_dict(),
		"disparity": {
			"total_ratio": arena_stats.total_stats.avg / surf_stats.total_stats.avg if surf_stats.total_stats.avg > 0 else 0.0,
			"gen_ratio": arena_stats.gen_stats.avg / surf_stats.gen_stats.avg if surf_stats.gen_stats.avg > 0 else 0.0,
			"mesh_ratio": arena_stats.mesh_stats.avg / surf_stats.mesh_stats.avg if surf_stats.mesh_stats.avg > 0 else 0.0,
			"bake_ratio": arena_stats.bake_stats.avg / surf_stats.bake_stats.avg if surf_stats.bake_stats.avg > 0 else 0.0
		}
	}
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("\n[Report Exported] Saved benchmark JSON to: %s" % path)
