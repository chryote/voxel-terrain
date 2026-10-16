class_name BenchMeshing
extends "res://tests/framework/benchmark_case.gd"

func bench_chunk_meshing() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	var gen = ContinentGenerator.new(1337)
	var mesher = SurfaceShellMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var data = gen.generate(ChunkCoord.new(5, 5), bounds)

	benchmark("meshing_chunk_32", func():
		var _mesh = mesher.build_mesh(data, reg)
	, 15, 3)
