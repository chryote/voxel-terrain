class_name ChunkBenchmarkReporter
extends RefCounted

## Formats and presents side-by-side benchmark comparison reports
## evaluating Surface vs Underground Arena chunk loading performance.

static func print_comparison(surf_stats: RefCounted, arena_stats: RefCounted) -> String:
	var lines: Array[String] = []

	var sep = "=========================================================================================="
	var sub_sep = "------------------------------------------------------------------------------------------"

	lines.append("")
	lines.append(sep)
	lines.append(" CHUNK LOADING BENCHMARK REPORT: SURFACE vs UNDERGROUND ARENA (%d CHUNKS)" % surf_stats.count)
	lines.append(sep)

	# High-Level Summary
	var total_surf_s = surf_stats.total_duration_ms / 1000.0
	var total_arena_s = arena_stats.total_duration_ms / 1000.0
	var total_ratio = (arena_stats.total_stats.avg / surf_stats.total_stats.avg) if surf_stats.total_stats.avg > 0.0 else 0.0

	lines.append("OVERALL BATCH PERFORMANCE:")
	lines.append("  Surface (%d chunks):           %8.2f s  | Avg: %6.2f ms/chunk | %6.1f chunks/s" % [
		surf_stats.count, total_surf_s, surf_stats.total_stats.avg, surf_stats.throughput_chunks_per_sec
	])
	lines.append("  Underground Arena (%d chunks): %8.2f s  | Avg: %6.2f ms/chunk | %6.1f chunks/s" % [
		arena_stats.count, total_arena_s, arena_stats.total_stats.avg, arena_stats.throughput_chunks_per_sec
	])
	lines.append("  Performance Disparity:          Subterranean Arena is %.2fx slower than Surface" % total_ratio)
	lines.append(sub_sep)

	# Side-by-Side Stage Breakdown Table
	lines.append("DETAILED PIPELINE BREAKDOWN:")
	lines.append("Stage          | Metric  | Surface Chunk       | Arena Chunk         | Disparity / Ratio")
	lines.append("---------------+---------+---------------------+---------------------+------------------")

	_append_stage_comparison(lines, "Generation", surf_stats.gen_stats, arena_stats.gen_stats)
	lines.append("---------------+---------+---------------------+---------------------+------------------")
	_append_stage_comparison(lines, "Meshing", surf_stats.mesh_stats, arena_stats.mesh_stats)
	lines.append("---------------+---------+---------------------+---------------------+------------------")
	_append_stage_comparison(lines, "Collision Bake", surf_stats.bake_stats, arena_stats.bake_stats)
	lines.append("---------------+---------+---------------------+---------------------+------------------")
	_append_stage_comparison(lines, "TOTAL PIPELINE", surf_stats.total_stats, arena_stats.total_stats, true)
	lines.append(sub_sep)

	# Geometry Comparison Table
	lines.append("GEOMETRY COMPLEXITY COMPARISON:")
	lines.append("  Metric                      | Surface (Total / Avg)   | Arena (Total / Avg)     | Disparity")
	lines.append("  ----------------------------+-------------------------+-------------------------+----------")
	var v_ratio = (arena_stats.avg_vertices / surf_stats.avg_vertices) if surf_stats.avg_vertices > 0.0 else 0.0
	var tri_ratio = (arena_stats.avg_triangles / surf_stats.avg_triangles) if surf_stats.avg_triangles > 0.0 else 0.0
	lines.append("  Vertices                    | %7d / %6.0f verts | %7d / %6.0f verts | %5.2fx" % [
		surf_stats.total_vertices, surf_stats.avg_vertices,
		arena_stats.total_vertices, arena_stats.avg_vertices,
		v_ratio
	])
	lines.append("  Triangles                   | %7d / %6.0f tris  | %7d / %6.0f tris  | %5.2fx" % [
		surf_stats.total_triangles, surf_stats.avg_triangles,
		arena_stats.total_triangles, arena_stats.avg_triangles,
		tri_ratio
	])
	if arena_stats.total_cave_vertices > 0:
		lines.append("  Cave Subterranean Vertices  |                     N/A | %7d (%4.1f%%)   |      N/A" % [
			arena_stats.total_cave_vertices,
			(float(arena_stats.total_cave_vertices) / float(arena_stats.total_vertices)) * 100.0 if arena_stats.total_vertices > 0 else 0.0
		])
	lines.append(sep)

	var output_text = "\n".join(lines)
	print(output_text)
	return output_text

static func _append_stage_comparison(
	lines: Array[String],
	stage_name: String,
	surf: Dictionary,
	arena: Dictionary,
	is_total: bool = false
) -> void:
	var avg_ratio = (arena.avg / surf.avg) if surf.avg > 0.0 else 0.0
	var med_ratio = (arena.median / surf.median) if surf.median > 0.0 else 0.0
	var p95_ratio = (arena.p95 / surf.p95) if surf.p95 > 0.0 else 0.0

	var surf_pct_str = " (%4.1f%%)" % surf.pct if not is_total else ""
	var arena_pct_str = " (%4.1f%%)" % arena.pct if not is_total else ""

	lines.append("%-14s | Avg     | %6.2f ms%-10s | %6.2f ms%-10s | %5.2fx slower" % [
		stage_name, surf.avg, surf_pct_str, arena.avg, arena_pct_str, avg_ratio
	])
	lines.append("               | Median  | %6.2f ms            | %6.2f ms            | %5.2fx" % [
		surf.median, arena.median, med_ratio
	])
	lines.append("               | P95     | %6.2f ms            | %6.2f ms            | %5.2fx" % [
		surf.p95, arena.p95, p95_ratio
	])
	lines.append("               | Min/Max | %5.1f / %5.1f ms     | %5.1f / %5.1f ms     |      -" % [
		surf.min, surf.max, arena.min, arena.max
	])
