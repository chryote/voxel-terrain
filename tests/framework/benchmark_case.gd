class_name BenchmarkCase
extends RefCounted

## Base class for performance benchmarks.

var _results: Dictionary = {} # metric_name -> {avg, median, p95, min, max, iterations, samples}

func benchmark(metric_name: String, callable: Callable, iterations: int = 20, warmup: int = 3) -> Dictionary:
	# Warmup runs
	for _w in range(warmup):
		callable.call()

	# Measured runs
	var samples: Array[float] = []
	for _i in range(iterations):
		var start_time: int = Time.get_ticks_usec()
		callable.call()
		var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
		samples.append(elapsed_ms)

	samples.sort()
	var total: float = 0.0
	for s in samples:
		total += s

	var avg: float = total / float(samples.size())
	var mid_idx: int = int(floor(float(samples.size()) / 2.0))
	var median: float = samples[mid_idx] if samples.size() % 2 != 0 else (samples[mid_idx - 1] + samples[mid_idx]) / 2.0
	var p95_idx: int = int(round(float(samples.size() - 1) * 0.95))
	var p95: float = samples[p95_idx]

	var result = {
		"name": metric_name,
		"avg_ms": avg,
		"median_ms": median,
		"p95_ms": p95,
		"min_ms": samples[0],
		"max_ms": samples[samples.size() - 1],
		"iterations": iterations
	}
	_results[metric_name] = result
	return result

func get_results() -> Dictionary:
	return _results
