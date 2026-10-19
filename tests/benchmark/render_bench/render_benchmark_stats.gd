class_name RenderBenchmarkStats
extends RefCounted

## Statistical calculator aggregating frame rendering metrics and main-thread timings across sampled frames.

var environment_name: String = ""
var sample_count: int = 0
var warmup_frames: int = 0
var total_duration_ms: float = 0.0

var draw_calls_stats: Dictionary = {}   # {avg, median, p95, min, max, std_dev}
var process_time_stats: Dictionary = {} # {avg, median, p95, min, max, std_dev}
var frame_delta_stats: Dictionary = {}  # {avg, median, p95, min, max, std_dev}
var primitives_stats: Dictionary = {}   # {avg, median, p95, min, max}
var objects_stats: Dictionary = {}      # {avg, median, p95, min, max}
var fps_stats: Dictionary = {}          # {avg, min, max}

var avg_loaded_chunks: float = 0.0
var max_loaded_chunks: int = 0

## Computes statistical distributions from a collection of RenderPerformanceSample instances.
static func compute(p_env_name: String, samples: Array, p_warmup_frames: int = 0) -> RefCounted:
	var stats = new()
	stats.environment_name = p_env_name
	stats.warmup_frames = p_warmup_frames
	stats.sample_count = samples.size()

	if samples.is_empty():
		return stats

	var dc_values: Array[float] = []
	var proc_values: Array[float] = []
	var delta_values: Array[float] = []
	var prim_values: Array[float] = []
	var obj_values: Array[float] = []
	var fps_values: Array[float] = []

	var sum_delta: float = 0.0
	var sum_chunks: int = 0
	var max_chunks: int = 0

	for s in samples:
		dc_values.append(float(s.draw_calls))
		proc_values.append(s.process_time_ms)
		delta_values.append(s.frame_delta_ms)
		prim_values.append(float(s.primitives))
		obj_values.append(float(s.objects_in_frame))
		fps_values.append(s.fps)

		sum_delta += s.frame_delta_ms
		sum_chunks += s.loaded_chunks
		if s.loaded_chunks > max_chunks:
			max_chunks = s.loaded_chunks

	stats.total_duration_ms = sum_delta
	stats.avg_loaded_chunks = float(sum_chunks) / float(stats.sample_count)
	stats.max_loaded_chunks = max_chunks

	stats.draw_calls_stats = _compute_series(dc_values)
	stats.process_time_stats = _compute_series(proc_values)
	stats.frame_delta_stats = _compute_series(delta_values)
	stats.primitives_stats = _compute_series(prim_values)
	stats.objects_stats = _compute_series(obj_values)
	stats.fps_stats = _compute_series(fps_values)

	return stats

static func _compute_series(values: Array[float]) -> Dictionary:
	var n = values.size()
	if n == 0:
		return {"avg": 0.0, "median": 0.0, "p95": 0.0, "min": 0.0, "max": 0.0, "std_dev": 0.0}

	var sorted_vals = values.duplicate()
	sorted_vals.sort()

	var sum_val: float = 0.0
	for v in sorted_vals:
		sum_val += v
	var avg = sum_val / float(n)

	var mid = n / 2
	var median = sorted_vals[mid] if n % 2 != 0 else (sorted_vals[mid - 1] + sorted_vals[mid]) / 2.0
	var p95_idx = int(round(float(n - 1) * 0.95))
	var p95 = sorted_vals[p95_idx]

	# Standard deviation
	var variance_sum: float = 0.0
	for v in sorted_vals:
		var diff = v - avg
		variance_sum += diff * diff
	var std_dev = sqrt(variance_sum / float(n))

	return {
		"avg": avg,
		"median": median,
		"p95": p95,
		"min": sorted_vals[0],
		"max": sorted_vals[n - 1],
		"std_dev": std_dev
	}

func to_dict() -> Dictionary:
	return {
		"environment": environment_name,
		"sample_count": sample_count,
		"warmup_frames": warmup_frames,
		"total_duration_ms": total_duration_ms,
		"draw_calls": draw_calls_stats,
		"process_time_ms": process_time_stats,
		"frame_delta_ms": frame_delta_stats,
		"primitives": primitives_stats,
		"objects_in_frame": objects_stats,
		"fps": fps_stats,
		"avg_loaded_chunks": avg_loaded_chunks,
		"max_loaded_chunks": max_loaded_chunks
	}
