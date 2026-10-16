class_name TestChunkStreamer
extends "res://tests/framework/test_case.gd"

func test_load_set_and_sorting() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var streamer = ChunkStreamer.new()
	var focus = ChunkCoord.new(0, 0)
	var loaded: Dictionary = {}

	# View distance of 2 chunks
	var to_load = streamer.get_chunks_to_load(focus, loaded, 2, bounds)
	assert_true(to_load.size() > 0, "Should have chunks to load")

	# First chunk should be the center chunk (0, 0)
	assert_eq(to_load[0].x, 0)
	assert_eq(to_load[0].z, 0)

	# Verify sorted by distance
	for i in range(to_load.size() - 1):
		var d1 = focus.euclidean_distance_to(to_load[i])
		var d2 = focus.euclidean_distance_to(to_load[i + 1])
		assert_true(d1 <= d2 + 0.0001, "Chunks must be ordered by distance ascending")

func test_already_loaded_omitted() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var streamer = ChunkStreamer.new()
	var focus = ChunkCoord.new(0, 0)
	var loaded: Dictionary = {
		focus.to_key(): focus
	}

	var to_load = streamer.get_chunks_to_load(focus, loaded, 2, bounds)
	for c in to_load:
		assert_false(c.equals(focus), "Loaded chunk (0, 0) should not be in load list")

func test_unload_hysteresis() -> void:
	var streamer = ChunkStreamer.new()
	var focus = ChunkCoord.new(0, 0)
	var view_dist = 4 # view_dist + 1 = 5

	var loaded: Dictionary = {
		ChunkCoord.new(0, 0).to_key(): ChunkCoord.new(0, 0),
		ChunkCoord.new(4, 0).to_key(): ChunkCoord.new(4, 0), # dist 4 -> keep
		ChunkCoord.new(5, 0).to_key(): ChunkCoord.new(5, 0), # dist 5 -> keep (hysteresis)
		ChunkCoord.new(6, 0).to_key(): ChunkCoord.new(6, 0), # dist 6 -> unload
		ChunkCoord.new(10, 10).to_key(): ChunkCoord.new(10, 10) # dist ~14 -> unload
	}

	var to_unload = streamer.get_chunks_to_unload(focus, loaded, view_dist)
	assert_eq(to_unload.size(), 2, "Only chunks beyond hysteresis threshold should unload")

	var unloads_x = []
	for c in to_unload:
		unloads_x.append(c.x)
	assert_true(6 in unloads_x)
	assert_true(10 in unloads_x)
