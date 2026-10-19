class_name RenderBenchmarkReporter
extends RefCounted

## Formats and presents side-by-side rendering and main thread performance benchmark reports.

static func print_comparison(surf_stats: RefCounted, arena_stats: RefCounted) -> String:
	var lines: Array[String] = []

	var sep = "=========================================================================================="
	var sub_sep = "------------------------------------------------------------------------------------------"

	lines.append("")
	lines.append(sep)
	lines.append(" RENDERING & PROCESS BENCHMARK REPORT: SURFACE vs UNDERGROUND ARENA")
	lines.append(" Sampled Frames: %d Surface | %d Arena (Warmup: %d frames)" % [
		surf_stats.sample_count, arena_stats.sample_count, surf_stats.warmup_frames
	])
	lines.append(sep)

	# High-level overview
	lines.append("OVERALL RENDERING OVERVIEW:")
	lines.append("  Surface Overland:       Avg Draw Calls: %4.1f | Process Time: %5.2f ms | Prims: %6.0f" % [
		surf_stats.draw_calls_stats.get("avg", 0.0),
		surf_stats.process_time_stats.get("avg", 0.0),
		surf_stats.primitives_stats.get("avg", 0.0)
	])
	lines.append("  Underground Arena:      Avg Draw Calls: %4.1f | Process Time: %5.2f ms | Prims: %6.0f" % [
		arena_stats.draw_calls_stats.get("avg", 0.0),
		arena_stats.process_time_stats.get("avg", 0.0),
		arena_stats.primitives_stats.get("avg", 0.0)
	])

	var dc_ratio = (arena_stats.draw_calls_stats.get("avg", 0.0) / surf_stats.draw_calls_stats.get("avg", 1.0)) if surf_stats.draw_calls_stats.get("avg", 0.0) > 0.0 else 0.0
	var proc_ratio = (arena_stats.process_time_stats.get("avg", 0.0) / surf_stats.process_time_stats.get("avg", 1.0)) if surf_stats.process_time_stats.get("avg", 0.0) > 0.0 else 0.0

	lines.append("  Disparity Ratios:       Draw Calls: %.2fx | Main Thread Process: %.2fx" % [dc_ratio, proc_ratio])
	lines.append(sub_sep)

	# Metric Breakdown Table
	lines.append("DETAILED RENDERING & PROCESS BREAKDOWN:")
	lines.append("Metric                    | Measure | Surface Overland    | Underground Arena   | Disparity / Ratio")
	lines.append("--------------------------+---------+---------------------+---------------------+------------------")

	_append_metric_rows(lines, "Draw Calls (Rendering)", surf_stats.draw_calls_stats, arena_stats.draw_calls_stats, "%5.1f calls")
	lines.append("--------------------------+---------+---------------------+---------------------+------------------")
	_append_metric_rows(lines, "Process Time (Engine)", surf_stats.process_time_stats, arena_stats.process_time_stats, "%6.2f ms   ")
	lines.append("--------------------------+---------+---------------------+---------------------+------------------")
	_append_metric_rows(lines, "Frame Delta (Measured)", surf_stats.frame_delta_stats, arena_stats.frame_delta_stats, "%6.2f ms   ")
	lines.append("--------------------------+---------+---------------------+---------------------+------------------")
	_append_metric_rows(lines, "Primitives / Triangles", surf_stats.primitives_stats, arena_stats.primitives_stats, "%7.0f prims")
	lines.append(sub_sep)

	# Frame Budget Headroom Analysis
	lines.append("MAIN THREAD TARGET FPS BUDGET HEADROOM:")
	lines.append("Target Framerate | Frame Budget | Surface Process Cost | Arena Process Cost | Status (Surface / Arena)")
	lines.append("-----------------+--------------+----------------------+--------------------+-------------------------")
	_append_budget_row(lines, " 60 FPS", 16.67, surf_stats.process_time_stats.get("avg", 0.0), arena_stats.process_time_stats.get("avg", 0.0))
	_append_budget_row(lines, "120 FPS",  8.33, surf_stats.process_time_stats.get("avg", 0.0), arena_stats.process_time_stats.get("avg", 0.0))
	_append_budget_row(lines, "144 FPS",  6.94, surf_stats.process_time_stats.get("avg", 0.0), arena_stats.process_time_stats.get("avg", 0.0))
	_append_budget_row(lines, "160 FPS",  6.25, surf_stats.process_time_stats.get("avg", 0.0), arena_stats.process_time_stats.get("avg", 0.0))
	lines.append(sep)

	var output_text = "\n".join(lines)
	print(output_text)
	return output_text

static func _append_metric_rows(
	lines: Array[String],
	metric_name: String,
	surf: Dictionary,
	arena: Dictionary,
	fmt: String
) -> void:
	var s_avg = surf.get("avg", 0.0)
	var a_avg = arena.get("avg", 0.0)
	var ratio_avg = (a_avg / s_avg) if s_avg > 0.0 else 0.0

	var s_med = surf.get("median", 0.0)
	var a_med = arena.get("median", 0.0)
	var ratio_med = (a_med / s_med) if s_med > 0.0 else 0.0

	var s_p95 = surf.get("p95", 0.0)
	var a_p95 = arena.get("p95", 0.0)
	var ratio_p95 = (a_p95 / s_p95) if s_p95 > 0.0 else 0.0

	var s_avg_str = fmt % s_avg
	var a_avg_str = fmt % a_avg
	var s_med_str = fmt % s_med
	var a_med_str = fmt % a_med
	var s_p95_str = fmt % s_p95
	var a_p95_str = fmt % a_p95
	var s_min_str = fmt % surf.get("min", 0.0)
	var s_max_str = fmt % surf.get("max", 0.0)
	var a_min_str = fmt % arena.get("min", 0.0)
	var a_max_str = fmt % arena.get("max", 0.0)

	lines.append("%-25s | Avg     | %s         | %s         | %5.2fx" % [metric_name, s_avg_str, a_avg_str, ratio_avg])
	lines.append("                          | Median  | %s         | %s         | %5.2fx" % [s_med_str, a_med_str, ratio_med])
	lines.append("                          | P95     | %s         | %s         | %5.2fx" % [s_p95_str, a_p95_str, ratio_p95])
	lines.append("                          | Min/Max | %s / %s | %s / %s |      -" % [s_min_str, s_max_str, a_min_str, a_max_str])

static func _append_budget_row(
	lines: Array[String],
	label: String,
	budget_ms: float,
	surf_proc_ms: float,
	arena_proc_ms: float
) -> void:
	var s_ok = surf_proc_ms <= budget_ms
	var a_ok = arena_proc_ms <= budget_ms
	var s_pct = (surf_proc_ms / budget_ms) * 100.0 if budget_ms > 0 else 0.0
	var a_pct = (arena_proc_ms / budget_ms) * 100.0 if budget_ms > 0 else 0.0

	var status = "%s (%3.0f%%) / %s (%3.0f%%)" % [
		"OK" if s_ok else "OVER", s_pct,
		"OK" if a_ok else "OVER", a_pct
	]

	lines.append("%-16s | %5.2f ms    | %5.2f ms              | %5.2f ms             | %s" % [
		label, budget_ms, surf_proc_ms, arena_proc_ms, status
	])
