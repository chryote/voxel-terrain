class_name RegGeneration
extends "res://tests/framework/regression_case.gd"

var update_golden: bool = false

func test_continent_generation_snapshot() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var gen = ContinentGenerator.new(4242)

	var test_coords = [
		ChunkCoord.new(0, 0),   # Center
		ChunkCoord.new(8, 8),   # Inland / foothills
		ChunkCoord.new(15, 15)  # Coast / boundary
	]

	var snapshot: Dictionary = {}

	for coord in test_coords:
		var key = "chunk_%d_%d" % [coord.x, coord.z]
		var data = gen.generate(coord, bounds)
		var h_hash = hash_int_array(data.heights)
		var top_hash = hash_bytes(data.top_material)
		var side_hash = hash_bytes(data.side_material)

		# Also sample center height
		var center_h = data.get_height(16, 16)
		var corner_h = data.get_height(0, 0)

		snapshot[key] = {
			"heights_hash": h_hash,
			"top_mat_hash": top_hash,
			"side_mat_hash": side_hash,
			"center_height": center_h,
			"corner_height": corner_h
		}

	assert_golden("generation", snapshot, update_golden)
