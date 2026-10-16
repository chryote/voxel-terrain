class_name BenchStreaming
extends "res://tests/framework/benchmark_case.gd"

func bench_streamer_load_evaluation() -> void:
	var bounds = WorldBounds.new(Vector2i(256, 256), 32, 1.0)
	var streamer = ChunkStreamer.new()
	var focus = ChunkCoord.new(0, 0)
	var loaded: Dictionary = {}

	# Pre-populate 50 loaded chunks
	for i in range(-5, 5):
		for j in range(-5, 0):
			var c = ChunkCoord.new(i, j)
			loaded[c.to_key()] = c

	benchmark("streamer_evaluation_vd8", func():
		var _to_load = streamer.get_chunks_to_load(focus, loaded, 8, bounds)
		var _to_unload = streamer.get_chunks_to_unload(focus, loaded, 8)
	, 50, 5)
