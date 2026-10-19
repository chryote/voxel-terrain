class_name TestRenderBenchmarkTooling
extends "res://tests/framework/test_case.gd"

## Unit tests verifying the Render Benchmark Tooling (RenderPerformanceSample, RenderBenchmarkStats, RenderBenchmarkReporter).

const RenderPerformanceSampleClass = preload("res://tests/benchmark/render_bench/render_performance_sample.gd")
const RenderBenchmarkStatsClass = preload("res://tests/benchmark/render_bench/render_benchmark_stats.gd")
const RenderBenchmarkReporterClass = preload("res://tests/benchmark/render_bench/render_benchmark_reporter.gd")

func test_render_performance_sample_initialization() -> void:
	var sample = RenderPerformanceSampleClass.new(
		12,       # frame_index
		45,       # draw_calls
		2.34,     # process_time_ms
		6.25,     # frame_delta_ms
		0.85,     # physics_time_ms
		15200,    # primitives
		45,       # objects_in_frame
		25,       # loaded_chunks
		Vector3(10, 20, 30), # camera_position
		false,    # is_underground
		160.0     # fps
	)

	assert_eq(sample.frame_index, 12)
	assert_eq(sample.draw_calls, 45)
	assert_almost_eq(sample.process_time_ms, 2.34, 0.001)
	assert_almost_eq(sample.frame_delta_ms, 6.25, 0.001)
	assert_almost_eq(sample.physics_time_ms, 0.85, 0.001)
	assert_eq(sample.primitives, 15200)
	assert_eq(sample.objects_in_frame, 45)
	assert_eq(sample.loaded_chunks, 25)
	assert_eq(sample.camera_position, Vector3(10, 20, 30))
	assert_false(sample.is_underground)
	assert_almost_eq(sample.fps, 160.0, 0.001)

	var d = sample.to_dict()
	assert_eq(d["draw_calls"], 45)
	assert_eq(d["primitives"], 15200)
	assert_eq(d["is_underground"], false)

func test_render_performance_sample_capture_current_frame() -> void:
	var sample = RenderPerformanceSampleClass.capture_current_frame(
		5,
		16.66,
		10,
		Vector3(0, 5, 0),
		true
	)

	assert_eq(sample.frame_index, 5)
	assert_almost_eq(sample.frame_delta_ms, 16.66, 0.01)
	assert_eq(sample.loaded_chunks, 10)
	assert_eq(sample.is_underground, true)
	assert_true(sample.draw_calls >= 0, "Draw calls should be non-negative")
	assert_true(sample.process_time_ms >= 0.0, "Process time should be non-negative")

func test_render_benchmark_stats_empty_samples() -> void:
	var stats = RenderBenchmarkStatsClass.compute("Empty Test", [])
	assert_eq(stats.environment_name, "Empty Test")
	assert_eq(stats.sample_count, 0)
	assert_eq(stats.draw_calls_stats.get("avg", 0.0), 0.0)

func test_render_benchmark_stats_calculation() -> void:
	var samples: Array = []
	# Create synthetic samples with varying draw calls and process times
	for i in range(10):
		var dc = 10 + i * 2        # 10, 12, 14, 16, 18, 20, 22, 24, 26, 28
		var proc = 1.0 + float(i) * 0.5 # 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5
		var prims = 1000 * (i + 1)
		var s = RenderPerformanceSampleClass.new(
			i,
			dc,
			proc,
			6.25,
			0.5,
			prims,
			dc,
			15,
			Vector3.ZERO,
			false,
			144.0
		)
		samples.append(s)

	var stats = RenderBenchmarkStatsClass.compute("Synthetic Overland", samples, 5)
	assert_eq(stats.sample_count, 10)
	assert_eq(stats.warmup_frames, 5)
	assert_eq(stats.avg_loaded_chunks, 15.0)

	# Draw Calls: sum = 190, avg = 19.0, min = 10, max = 28, median = (18+20)/2 = 19.0
	assert_almost_eq(stats.draw_calls_stats["avg"], 19.0, 0.01)
	assert_almost_eq(stats.draw_calls_stats["min"], 10.0, 0.01)
	assert_almost_eq(stats.draw_calls_stats["max"], 28.0, 0.01)
	assert_almost_eq(stats.draw_calls_stats["median"], 19.0, 0.01)
	assert_true(stats.draw_calls_stats["std_dev"] > 0.0, "Std dev must be positive")

	# Process Times: min = 1.0, max = 5.5, avg = 3.25
	assert_almost_eq(stats.process_time_stats["min"], 1.0, 0.01)
	assert_almost_eq(stats.process_time_stats["max"], 5.5, 0.01)
	assert_almost_eq(stats.process_time_stats["avg"], 3.25, 0.01)

	var d = stats.to_dict()
	assert_eq(d["environment"], "Synthetic Overland")
	assert_eq(d["sample_count"], 10)
	assert_true(d.has("draw_calls"))
	assert_true(d.has("process_time_ms"))

func test_render_benchmark_reporter_formatting() -> void:
	var s_samples: Array = []
	var a_samples: Array = []
	for i in range(5):
		s_samples.append(RenderPerformanceSampleClass.new(i, 20, 2.0, 6.0, 0.5, 10000, 20, 10, Vector3.ZERO, false, 144.0))
		a_samples.append(RenderPerformanceSampleClass.new(i, 35, 3.5, 8.0, 0.5, 8000, 35, 10, Vector3.ZERO, true, 120.0))

	var s_stats = RenderBenchmarkStatsClass.compute("Surface Test", s_samples)
	var a_stats = RenderBenchmarkStatsClass.compute("Arena Test", a_samples)

	var text = RenderBenchmarkReporterClass.print_comparison(s_stats, a_stats)
	assert_true(text.contains("RENDERING & PROCESS BENCHMARK REPORT"), "Report header should be present")
	assert_true(text.contains("Draw Calls (Rendering)"), "Draw calls row should be present")
	assert_true(text.contains("Process Time (Engine)"), "Process time row should be present")
	assert_true(text.contains("160 FPS"), "Target FPS budget row should be present")
