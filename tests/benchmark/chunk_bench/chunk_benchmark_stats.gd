class_name ChunkBenchmarkStats
extends RefCounted

## Statistical calculator aggregating timing samples and geometry metrics across a chunk batch.

var name: String = ""
var count: int = 0
var total_duration_ms: float = 0.0
var throughput_chunks_per_sec: float = 0.0

var gen_stats: Dictionary = {}   # {total, avg, median, p95, min, max, pct}
var mesh_stats: Dictionary = {}  # {total, avg, median, p95, min, max, pct}
var bake_stats: Dictionary = {}  # {total, avg, median, p95, min, max, pct}
var total_stats: Dictionary = {} # {total, avg, median, p95, min, max}

var total_vertices: int = 0
var avg_vertices: float = 0.0
var total_triangles: int = 0
var avg_triangles: float = 0.0

var total_cave_vertices: int = 0
var total_cave_triangles: int = 0

static func compute(p_name: String, samples: Array) -> RefCounted:
	var stats = new()
	stats.name = p_name
	stats.count = samples.size()
	if samples.is_empty():
		return stats

	var gen_values: Array[float] = []
	var mesh_values: Array[float] = []
	var bake_values: Array[float] = []
	var total_values: Array[float] = []

	var sum_gen: float = 0.0
	var sum_mesh: float = 0.0
	var sum_bake: float = 0.0
	var sum_total: float = 0.0

	var sum_verts: int = 0
	var sum_tris: int = 0
	var sum_c_verts: int = 0
	var sum_c_tris: int = 0

	for s in samples:
		gen_values.append(s.gen_ms)
		mesh_values.append(s.mesh_ms)
		bake_values.append(s.bake_ms)
		total_values.append(s.total_ms)

		sum_gen += s.gen_ms
		sum_mesh += s.mesh_ms
		sum_bake += s.bake_ms
		sum_total += s.total_ms

		sum_verts += s.vertex_count
		sum_tris += s.triangle_count
		sum_c_verts += s.cave_vertex_count
		sum_c_tris += s.cave_triangle_count

	stats.total_duration_ms = sum_total
	if sum_total > 0.0:
		stats.throughput_chunks_per_sec = float(stats.count) / (sum_total / 1000.0)

	stats.gen_stats = _compute_series(gen_values, sum_gen, sum_total)
	stats.mesh_stats = _compute_series(mesh_values, sum_mesh, sum_total)
	stats.bake_stats = _compute_series(bake_values, sum_bake, sum_total)
	stats.total_stats = _compute_series(total_values, sum_total, sum_total)

	stats.total_vertices = sum_verts
	stats.avg_vertices = float(sum_verts) / float(stats.count)
	stats.total_triangles = sum_tris
	stats.avg_triangles = float(sum_tris) / float(stats.count)
	stats.total_cave_vertices = sum_c_verts
	stats.total_cave_triangles = sum_c_tris

	return stats

static func _compute_series(values: Array[float], sum_val: float, total_overall: float) -> Dictionary:
	var n = values.size()
	if n == 0:
		return {"total": 0.0, "avg": 0.0, "median": 0.0, "p95": 0.0, "min": 0.0, "max": 0.0, "pct": 0.0}

	var sorted_vals = values.duplicate()
	sorted_vals.sort()

	var avg = sum_val / float(n)
	var mid = n / 2
	var median = sorted_vals[mid] if n % 2 != 0 else (sorted_vals[mid - 1] + sorted_vals[mid]) / 2.0
	var p95_idx = int(round(float(n - 1) * 0.95))
	var p95 = sorted_vals[p95_idx]
	var pct = (sum_val / total_overall) * 100.0 if total_overall > 0.0 else 0.0

	return {
		"total": sum_val,
		"avg": avg,
		"median": median,
		"p95": p95,
		"min": sorted_vals[0],
		"max": sorted_vals[n - 1],
		"pct": pct
	}

func to_dict() -> Dictionary:
	return {
		"name": name,
		"chunk_count": count,
		"total_duration_ms": total_duration_ms,
		"throughput_chunks_per_sec": throughput_chunks_per_sec,
		"gen_stats": gen_stats,
		"mesh_stats": mesh_stats,
		"bake_stats": bake_stats,
		"total_stats": total_stats,
		"geometry": {
			"total_vertices": total_vertices,
			"avg_vertices": avg_vertices,
			"total_triangles": total_triangles,
			"avg_triangles": avg_triangles,
			"total_cave_vertices": total_cave_vertices,
			"total_cave_triangles": total_cave_triangles
		}
	}
