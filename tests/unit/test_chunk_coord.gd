class_name TestChunkCoord
extends "res://tests/framework/test_case.gd"

func test_equality_and_coordinates() -> void:
	var c1 = ChunkCoord.new(10, -5)
	var c2 = ChunkCoord.new(10, -5)
	var c3 = ChunkCoord.new(10, 5)

	assert_true(c1.equals(c2), "Equal coords should match")
	assert_false(c1.equals(c3), "Unequal coords should not match")
	assert_false(c1.equals(null), "Null should not match")
	assert_eq(c1.x, 10, "X coordinate should be 10")
	assert_eq(c1.z, -5, "Z coordinate should be -5")

func test_key_roundtrip() -> void:
	var test_pairs = [
		Vector2i(0, 0),
		Vector2i(1, 1),
		Vector2i(-1, -1),
		Vector2i(128, -256),
		Vector2i(-32768, 32767),
		Vector2i(2147483, -2147483)
	]

	for pair in test_pairs:
		var c = ChunkCoord.new(pair.x, pair.y)
		var key = c.to_key()
		var restored = ChunkCoord.from_key(key)
		assert_eq(restored.x, c.x, "Restored X should match for %s" % str(pair))
		assert_eq(restored.z, c.z, "Restored Z should match for %s" % str(pair))

func test_distances() -> void:
	var c1 = ChunkCoord.new(0, 0)
	var c2 = ChunkCoord.new(3, 4)

	assert_eq(c1.manhattan_distance_to(c2), 7, "Manhattan distance should be 7")
	assert_eq(c1.chebyshev_distance_to(c2), 4, "Chebyshev distance should be 4")
	assert_almost_eq(c1.euclidean_distance_to(c2), 5.0, 0.0001, "Euclidean distance should be 5.0")
