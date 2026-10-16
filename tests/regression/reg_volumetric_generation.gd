class_name RegVolumetricGeneration
extends "res://tests/framework/regression_case.gd"

## Golden regression snapshot for 3D volumetric terrain generation.

var update_golden: bool = false

func test_volumetric_generation_snapshot() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64
	var gen = VolumetricContinentGenerator.new(4242, config)

	var test_coords = [
		ChunkCoord.new(0, 0),
		ChunkCoord.new(4, 4)
	]

	var snapshot: Dictionary = {}

	for coord in test_coords:
		var key = "chunk_%d_%d" % [coord.x, coord.z]
		var data: VoxelChunkData = gen.generate(coord, bounds)
		var v_hash = hash_bytes(data.voxels)
		var center_top_y = data.get_highest_solid_y(8, 8)
		var corner_top_y = data.get_highest_solid_y(0, 0)

		snapshot[key] = {
			"voxels_hash": v_hash,
			"center_highest_solid_y": center_top_y,
			"corner_highest_solid_y": corner_top_y
		}

	assert_golden("volumetric_generation", snapshot, update_golden)
