class_name TestContinentGenerator
extends "res://tests/framework/test_case.gd"

func test_determinism() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen1 = ContinentGenerator.new(999)
	var gen2 = ContinentGenerator.new(999)

	var coord = ChunkCoord.new(0, 0)
	var data1 = gen1.generate(coord, bounds)
	var data2 = gen2.generate(coord, bounds)

	assert_eq(data1.heights.size(), data2.heights.size(), "Height array sizes must match")
	for i in range(data1.heights.size()):
		assert_eq(data1.heights[i], data2.heights[i], "Heights at index %d must match for same seed" % i)
		assert_eq(data1.top_material[i], data2.top_material[i], "Top materials at %d must match" % i)
		assert_eq(data1.side_material[i], data2.side_material[i], "Side materials at %d must match" % i)

func test_different_seeds_produce_different_terrain() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen1 = ContinentGenerator.new(111)
	var gen2 = ContinentGenerator.new(222)

	var coord = ChunkCoord.new(0, 0)
	var data1 = gen1.generate(coord, bounds)
	var data2 = gen2.generate(coord, bounds)

	var differences = 0
	for i in range(data1.heights.size()):
		if data1.heights[i] != data2.heights[i]:
			differences += 1
	assert_true(differences > 10, "Different seeds should produce different terrain (diffs: %d)" % differences)

func test_height_bounds_and_apron() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen = ContinentGenerator.new(555)

	# Generate corner chunk that borders map edge
	var corner_coord = ChunkCoord.new(bounds.max_chunk_x, bounds.max_chunk_z)
	var data = gen.generate(corner_coord, bounds)

	for lz in range(-1, 17):
		for lx in range(-1, 17):
			var h = data.get_height(lx, lz)
			assert_true(h >= gen.config.seabed_level, "Height %d must be >= seabed_level %d" % [h, gen.config.seabed_level])
			assert_true(h <= 255, "Height %d must be <= 255" % h)
