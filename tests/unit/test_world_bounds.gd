class_name TestWorldBounds
extends "res://tests/framework/test_case.gd"

func test_dimensions_and_containment() -> void:
	var bounds = WorldBounds.new(Vector2i(256, 256), 32, 1.0)
	
	assert_eq(bounds.min_chunk_x, -128)
	assert_eq(bounds.max_chunk_x, 127)
	assert_eq(bounds.min_chunk_z, -128)
	assert_eq(bounds.max_chunk_z, 127)
	assert_eq(bounds.total_chunks(), 256 * 256)

	assert_true(bounds.contains_chunk(ChunkCoord.new(0, 0)))
	assert_true(bounds.contains_chunk(ChunkCoord.new(-128, -128)))
	assert_true(bounds.contains_chunk(ChunkCoord.new(127, 127)))
	assert_false(bounds.contains_chunk(ChunkCoord.new(-129, 0)))
	assert_false(bounds.contains_chunk(ChunkCoord.new(128, 0)))

func test_coordinate_conversions() -> void:
	var bounds = WorldBounds.new(Vector2i(64, 64), 32, 1.0)
	
	# Origin test
	var c0 = ChunkCoord.new(0, 0)
	assert_vec_almost_eq(bounds.chunk_origin(c0), Vector3(0, 0, 0))
	
	# Chunk 1, 2
	var c1 = ChunkCoord.new(1, 2)
	assert_vec_almost_eq(bounds.chunk_origin(c1), Vector3(32, 0, 64))

	# World pos to chunk
	var p1 = Vector3(35.5, 10.0, 65.5)
	var chunk_at_p1 = bounds.world_to_chunk(p1)
	assert_eq(chunk_at_p1.x, 1)
	assert_eq(chunk_at_p1.z, 2)

	# Negative coordinates
	var p_neg = Vector3(-1.0, 0.0, -32.5)
	var chunk_neg = bounds.world_to_chunk(p_neg)
	assert_eq(chunk_neg.x, -1)
	assert_eq(chunk_neg.z, -2)

func test_column_conversions() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var col = bounds.world_to_column(Vector3(10.2, 5.0, 20.8))
	assert_eq(col.x, 10)
	assert_eq(col.y, 20)

	var wpos = bounds.column_to_world(col, 5.0)
	assert_almost_eq(wpos.x, 10.5)
	assert_almost_eq(wpos.y, 5.0)
	assert_almost_eq(wpos.z, 20.5)

func test_clamping() -> void:
	var bounds = WorldBounds.new(Vector2i(8, 8), 32, 1.0)
	# min_world is -128, max_world is 128
	var outside_pos = Vector3(500.0, 10.0, -300.0)
	var clamped = bounds.clamp_position(outside_pos, 2.0)
	assert_almost_eq(clamped.x, 126.0)
	assert_almost_eq(clamped.z, -126.0)
	assert_almost_eq(clamped.y, 10.0)
