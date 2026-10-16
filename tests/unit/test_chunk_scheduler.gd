class_name TestChunkScheduler
extends "res://tests/framework/test_case.gd"

func test_scheduler_async_completion() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen = ContinentGenerator.new(42)
	var mesher = SurfaceShellMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var scheduler = ChunkScheduler.new()

	var coord = ChunkCoord.new(0, 0)
	scheduler.schedule_chunk(coord, bounds, gen, mesher, reg)

	assert_true(scheduler.is_chunk_in_flight(coord) or scheduler.get_pending_result_count() > 0)

	# Poll until WorkerThreadPool completes (max 1000 ms)
	var results: Array[Dictionary] = []
	var attempts = 0
	while attempts < 100 and results.is_empty():
		OS.delay_msec(10)
		results = scheduler.poll_completed(1)
		attempts += 1

	assert_eq(results.size(), 1, "Should receive completed chunk from scheduler")
	var res = results[0]
	assert_true(res.coord.equals(coord))
	assert_not_null(res.data)
	assert_not_null(res.mesh_data)
	assert_false(res.mesh_data.is_empty())
	scheduler.wait_all_tasks()
