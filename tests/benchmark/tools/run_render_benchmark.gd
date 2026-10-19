extends SceneTree

## Standalone CLI tool to benchmark Draw Calls (RenderingServer) and Main Thread Frame Time (Process).
##
## Usage:
##   godot --rendering-driver opengl3 -s res://tests/benchmark/tools/run_render_benchmark.gd
##   godot --rendering-driver opengl3 -s res://tests/benchmark/tools/run_render_benchmark.gd -- --frames=100 --warmup=30 --mode=both --json=render_report.json

const RenderPerformanceSampleClass = preload("res://tests/benchmark/render_bench/render_performance_sample.gd")
const RenderBenchmarkStatsClass = preload("res://tests/benchmark/render_bench/render_benchmark_stats.gd")
const RenderBenchmarkReporterClass = preload("res://tests/benchmark/render_bench/render_benchmark_reporter.gd")

var frames_to_sample: int = 100
var warmup_frames: int = 30
var mode: String = "both" # "surface", "arena", or "both"
var view_distance: int = 6
var seed_val: int = 1337
var json_path: String = ""

var _current_pass: int = 0
var _total_passes: int = 1
var _is_underground_pass: bool = false
var _frame_in_pass: int = 0
var _prev_time_usec: int = 0

var _world: VoxelWorld
var _cam: Camera3D
var _root_node: Node3D

var _surface_samples: Array = []
var _arena_samples: Array = []

var _surface_stats: RenderBenchmarkStatsClass
var _arena_stats: RenderBenchmarkStatsClass

func _init() -> void:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--frames="):
			frames_to_sample = int(arg.substr(9).strip_edges())
		elif arg.begins_with("--warmup="):
			warmup_frames = int(arg.substr(9).strip_edges())
		elif arg.begins_with("--mode="):
			mode = arg.substr(7).strip_edges().to_lower()
		elif arg.begins_with("--view-distance="):
			view_distance = int(arg.substr(16).strip_edges())
		elif arg.begins_with("--seed="):
			seed_val = int(arg.substr(7).strip_edges())
		elif arg.begins_with("--json="):
			json_path = arg.substr(7).strip_edges()
		elif arg == "--help" or arg == "-h":
			_print_help()
			quit(0)
			return

	print("==========================================================================================")
	print(" Starting Rendering & Process Benchmark")
	print(" Seed: %d | Frames: %d | Warmup: %d | View Distance: %d | Mode: %s" % [
		seed_val, frames_to_sample, warmup_frames, view_distance, mode
	])
	print("==========================================================================================")

	_root_node = Node3D.new()
	root.add_child(_root_node)

	if mode == "both":
		_total_passes = 2
		_is_underground_pass = false # Start with surface
	elif mode == "arena":
		_total_passes = 1
		_is_underground_pass = true
	else:
		_total_passes = 1
		_is_underground_pass = false

	_start_pass()

func _start_pass() -> void:
	_frame_in_pass = 0
	_prev_time_usec = Time.get_ticks_usec()

	# Clean up previous world if any
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
		_world = null
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
		_cam = null

	var env_label = "Underground Arena" if _is_underground_pass else "Surface Overland"
	print("\n[%d/%d] Initializing %s environment..." % [_current_pass + 1, _total_passes, env_label])

	_world = VoxelWorld.new()
	_world.world_config = WorldConfig.new()
	_world.world_config.world_seed = seed_val
	_world.world_config.view_distance_chunks = view_distance
	_world.spawn_on_underground_arena = _is_underground_pass
	_root_node.add_child(_world)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 75.0
	_root_node.add_child(_cam)

func _process(delta: float) -> bool:
	var cur_time = Time.get_ticks_usec()
	var frame_delta_ms = (cur_time - _prev_time_usec) / 1000.0 if _prev_time_usec > 0 else 0.0
	_prev_time_usec = cur_time

	_frame_in_pass += 1

	# Align camera to spawn point on frame 1
	if _frame_in_pass == 1 and _world != null:
		var spawn_pos = _world.get_spawn_point()
		_cam.global_position = spawn_pos + Vector3(0, 3, 0)
		_cam.look_at(spawn_pos + Vector3(0, 3, -20), Vector3.UP)
		_world.focus_target = _cam

	# Slowly rotate camera to simulate realistic view frustum sweep
	if _cam != null:
		_cam.rotate_y(0.005)

	# Warmup phase: let chunks load and scene graph stabilize
	if _frame_in_pass <= warmup_frames:
		if _frame_in_pass % 10 == 0 or _frame_in_pass == warmup_frames:
			var loaded = _world.get_loaded_chunk_count() if _world != null else 0
			var dc = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			print("  -> Warmup frame %2d / %2d (Loaded Chunks: %d, Draw Calls: %d)..." % [
				_frame_in_pass, warmup_frames, loaded, dc
			])
		return false

	# Sampling phase
	var sample_idx = _frame_in_pass - warmup_frames
	var cam_pos = _cam.global_position if _cam != null else Vector3.ZERO
	var loaded_chunks = _world.get_loaded_chunk_count() if _world != null else 0

	var sample = RenderPerformanceSampleClass.capture_current_frame(
		sample_idx,
		frame_delta_ms,
		loaded_chunks,
		cam_pos,
		_is_underground_pass
	)

	if _is_underground_pass:
		_arena_samples.append(sample)
	else:
		_surface_samples.append(sample)

	if sample_idx % 25 == 0 or sample_idx == frames_to_sample:
		print("  -> Sampled frame %3d / %3d | Draw Calls: %3d | Process: %5.2f ms | Primitives: %6d" % [
			sample_idx, frames_to_sample, sample.draw_calls, sample.process_time_ms, sample.primitives
		])

	# Check pass completion
	if sample_idx >= frames_to_sample:
		_finish_current_pass()

	return false

func _finish_current_pass() -> void:
	if _is_underground_pass:
		_arena_stats = RenderBenchmarkStatsClass.compute("Underground Arena", _arena_samples, warmup_frames)
	else:
		_surface_stats = RenderBenchmarkStatsClass.compute("Surface Overland", _surface_samples, warmup_frames)

	_current_pass += 1
	if _current_pass < _total_passes:
		# Switch to next pass (Arena)
		_is_underground_pass = true
		_start_pass()
	else:
		# All passes complete: output report
		_complete_benchmark()

func _complete_benchmark() -> void:
	if mode == "both":
		RenderBenchmarkReporterClass.print_comparison(_surface_stats, _arena_stats)
	elif mode == "surface":
		_arena_stats = RenderBenchmarkStatsClass.new()
		RenderBenchmarkReporterClass.print_comparison(_surface_stats, _arena_stats)
	else:
		_surface_stats = RenderBenchmarkStatsClass.new()
		RenderBenchmarkReporterClass.print_comparison(_surface_stats, _arena_stats)

	if json_path != "":
		_export_json(json_path)

	quit(0)

func _export_json(path: String) -> void:
	var out = {
		"timestamp": Time.get_datetime_string_from_system(),
		"settings": {
			"frames_sampled": frames_to_sample,
			"warmup_frames": warmup_frames,
			"view_distance": view_distance,
			"seed": seed_val,
			"mode": mode
		},
		"surface": _surface_stats.to_dict() if _surface_stats != null else {},
		"underground_arena": _arena_stats.to_dict() if _arena_stats != null else {}
	}
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("\n[Report Exported] Saved render benchmark JSON to: %s" % path)

func _print_help() -> void:
	print("Rendering and Main Thread Process Benchmark Tool")
	print("Usage:")
	print("  godot --rendering-driver opengl3 -s res://tests/benchmark/tools/run_render_benchmark.gd -- [OPTIONS]")
	print("Options:")
	print("  --frames=N         Number of sampled frames per environment (default: 100)")
	print("  --warmup=N         Number of initial warmup frames to discard (default: 30)")
	print("  --mode=MODE        'surface', 'arena', or 'both' (default: both)")
	print("  --view-distance=N  Chunk view distance (default: 6)")
	print("  --seed=N           World generation seed (default: 1337)")
	print("  --json=PATH        Export metrics to JSON file")
	print("  --help, -h         Show this help message")
