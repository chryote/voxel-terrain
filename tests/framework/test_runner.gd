class_name TestRunner
extends RefCounted

## Test discovery, execution, reporting, and CLI runner.

var suite: String = "all"
var filter: String = ""
var update_golden: bool = false
var update_baseline: bool = false
var strict: bool = false
var json_output_path: String = ""

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var total_assertions: int = 0
var start_time_ms: int = 0

var test_results: Array[Dictionary] = []
var benchmark_results: Dictionary = {}

func parse_arguments(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with("--suite="):
			suite = arg.substr(8).strip_edges().to_lower()
		elif arg.begins_with("--filter="):
			filter = arg.substr(9).strip_edges().to_lower()
		elif arg == "--update-golden":
			update_golden = true
		elif arg == "--update-baseline":
			update_baseline = true
		elif arg == "--strict":
			strict = true
		elif arg.begins_with("--json="):
			json_output_path = arg.substr(7).strip_edges()

func run_all() -> int:
	start_time_ms = Time.get_ticks_msec()
	print("==================================================")
	print(" Running Test Runner")
	print(" Suite: %s | Filter: '%s' | Strict: %s" % [suite, filter, str(strict)])
	print("==================================================")

	var run_unit = (suite == "all" or suite == "unit")
	var run_bench = (suite == "all" or suite == "benchmark")
	var run_reg = (suite == "all" or suite == "regression")

	if run_unit:
		print("\n--- [UNIT TESTS] ---")
		_run_directory("res://tests/unit", "unit")

	if run_reg:
		print("\n--- [REGRESSION TESTS] ---")
		_run_directory("res://tests/regression", "regression")

	if run_bench:
		print("\n--- [BENCHMARKS] ---")
		_run_directory("res://tests/benchmark", "benchmark")
		_handle_benchmarks()

	var elapsed_s = (Time.get_ticks_msec() - start_time_ms) / 1000.0

	print("\n==================================================")
	print(" SUMMARY")
	print(" Total tests: %d" % total_tests)
	print(" Passed:      %d" % passed_tests)
	print(" Failed:      %d" % failed_tests)
	print(" Assertions:  %d" % total_assertions)
	print(" Duration:    %.2f s" % elapsed_s)
	print("==================================================")

	if json_output_path != "":
		_export_json(elapsed_s)

	if failed_tests > 0:
		print("RESULT: FAILED")
		return 1
	else:
		print("RESULT: PASSED")
		return 0

func _run_directory(path: String, category: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		print("Directory not found (or empty): %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var file_path = path.path_join(file_name)
			if filter == "" or filter in file_name.to_lower():
				_run_test_file(file_path, category)
		file_name = dir.get_next()
	dir.list_dir_end()

func _run_test_file(file_path: String, category: String) -> void:
	var script = load(file_path)
	if script == null or not (script is GDScript):
		print("Failed to load script: %s" % file_path)
		return

	var instance = script.new()
	if instance == null:
		print("Failed to instantiate: %s" % file_path)
		return

	var methods = script.get_script_method_list()
	for m in methods:
		var method_name: String = m["name"]
		var should_run = false
		if category == "unit" and method_name.begins_with("test_"):
			should_run = true
		elif category == "regression" and (method_name.begins_with("test_") or method_name.begins_with("reg_")):
			should_run = true
		elif category == "benchmark" and (method_name.begins_with("test_") or method_name.begins_with("bench_")):
			should_run = true

		if not should_run:
			continue

		var full_test_name = "%s::%s" % [file_path.get_file(), method_name]
		if filter != "" and not (filter in full_test_name.to_lower()):
			continue

		total_tests += 1
		
		# Set golden update flag if instance supports it
		if instance is RegressionCase:
			instance.set("update_golden", update_golden)

		if instance.has_method("reset_test_state"):
			instance.call("reset_test_state")

		var start_t = Time.get_ticks_usec()
		var test_error: String = ""

		if instance.has_method("before_each"):
			instance.call("before_each")

		instance.call(method_name)

		if instance.has_method("after_each"):
			instance.call("after_each")

		var test_duration_ms = (Time.get_ticks_usec() - start_t) / 1000.0

		var failures: Array[String] = []
		var assertions_in_test: int = 0
		if instance.has_method("get_failures"):
			failures = instance.call("get_failures")
		if instance.has_method("get_assertions_count"):
			assertions_in_test = instance.call("get_assertions_count")
			total_assertions += assertions_in_test

		if failures.size() == 0:
			passed_tests += 1
			print("  [PASS] %s (%.2f ms)" % [full_test_name, test_duration_ms])
			test_results.append({
				"name": full_test_name,
				"status": "PASS",
				"duration_ms": test_duration_ms,
				"failures": []
			})
		else:
			failed_tests += 1
			print("  [FAIL] %s (%.2f ms)" % [full_test_name, test_duration_ms])
			for f in failures:
				print("         -> %s" % f)
			test_results.append({
				"name": full_test_name,
				"status": "FAIL",
				"duration_ms": test_duration_ms,
				"failures": failures
			})

		if instance is BenchmarkCase:
			var res = instance.call("get_results")
			for k in res.keys():
				benchmark_results[k] = res[k]

func _handle_benchmarks() -> void:
	if benchmark_results.is_empty():
		return

	var baseline_path = "res://tests/benchmark/baseline.json"
	if update_baseline:
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("tests/benchmark"):
			dir.make_dir_recursive("tests/benchmark")
		var f = FileAccess.open(baseline_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(benchmark_results, "  "))
			f.close()
			print("  [BASELINE UPDATED] Saved benchmark baseline to: %s" % baseline_path)
		return

	# If baseline exists, check for performance regressions
	if FileAccess.file_exists(baseline_path):
		var f = FileAccess.open(baseline_path, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var json = JSON.new()
			if json.parse(txt) == OK and (json.data is Dictionary):
				var baseline = json.data
				print("\n  [BENCHMARK COMPARISON VS BASELINE]")
				for k in benchmark_results.keys():
					var cur = benchmark_results[k]
					if baseline.has(k):
						var base = baseline[k]
						var cur_avg = cur.get("avg_ms", 0.0)
						var base_avg = base.get("avg_ms", 0.0)
						var diff_pct = ((cur_avg - base_avg) / base_avg) * 100.0 if base_avg > 0 else 0.0
						var status_str = "OK"
						if diff_pct > 20.0:
							status_str = "SLOWER (+%.1f%%)" % diff_pct
							if strict:
								failed_tests += 1
								print("    [FAIL - BENCHMARK REGRESSION] %s: cur=%.3f ms vs base=%.3f ms (+%.1f%%)" % [k, cur_avg, base_avg, diff_pct])
							else:
								print("    [WARN - BENCHMARK SLOWER] %s: cur=%.3f ms vs base=%.3f ms (+%.1f%%)" % [k, cur_avg, base_avg, diff_pct])
						else:
							print("    [PASS] %s: cur=%.3f ms (baseline=%.3f ms, %+.1f%%)" % [k, cur_avg, base_avg, diff_pct])
					else:
						print("    [NEW] %s: cur=%.3f ms (no baseline)" % [k, cur.get("avg_ms", 0.0)])

func _export_json(elapsed_s: float) -> void:
	var out = {
		"total_tests": total_tests,
		"passed_tests": passed_tests,
		"failed_tests": failed_tests,
		"total_assertions": total_assertions,
		"duration_seconds": elapsed_s,
		"tests": test_results,
		"benchmarks": benchmark_results
	}
	var f = FileAccess.open(json_output_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("Exported test report to: %s" % json_output_path)
