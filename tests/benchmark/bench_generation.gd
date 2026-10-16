class_name BenchGeneration
extends "res://tests/framework/benchmark_case.gd"

func bench_chunk_generation() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var gen = ContinentGenerator.new(1337)
	var coord = ChunkCoord.new(5, 5)

	benchmark("generation_chunk_32", func():
		var _data = gen.generate(coord, bounds)
	, 15, 3)
