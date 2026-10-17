class_name TestVolumetricTerrainGenerator
extends "res://tests/framework/test_case.gd"

func test_generate_and_determinism() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var coord = ChunkCoord.new(0, 0)

	var gen1 = VolumetricTerrainGenerator.new(1337)
	var gen2 = VolumetricTerrainGenerator.new(1337)

	var v_data1 = gen1.generate(coord, bounds) as VoxelChunkData
	var v_data2 = gen2.generate(coord, bounds) as VoxelChunkData

	assert_not_null(v_data1, "Generation must return non-null VoxelChunkData")
	assert_not_null(v_data2, "Generation must return non-null VoxelChunkData")
	assert_eq(v_data1.chunk_size, 16)

	# Voxel buffers must be bit-for-bit identical for same seed
	assert_eq(v_data1.voxels.size(), v_data2.voxels.size(), "Voxel buffers must match size")
	assert_eq(v_data1.voxels, v_data2.voxels, "Voxel buffers must match exactly for identical seeds")

func test_surface_and_bedrock_integrity() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var coord = ChunkCoord.new(0, 0)
	var gen = VolumetricTerrainGenerator.new(1337)

	var v_data = gen.generate(coord, bounds) as VoxelChunkData

	# Bedrock at Y=0,1,2 must be solid rock (ID_STONE) across all columns
	for lz in range(16):
		for lx in range(16):
			assert_eq(v_data.get_voxel(lx, 0, lz), MaterialDef.ID_STONE, "Bedrock at Y=0 must be solid stone")
			assert_eq(v_data.get_voxel(lx, 1, lz), MaterialDef.ID_STONE, "Bedrock at Y=1 must be solid stone")
			assert_eq(v_data.get_voxel(lx, 2, lz), MaterialDef.ID_STONE, "Bedrock at Y=2 must be solid stone")

			# Sky at Y=159 must be air
			assert_eq(v_data.get_voxel(lx, 159, lz), MaterialDef.ID_AIR, "High sky must be empty air")

func test_query_interface_delegation() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen = VolumetricTerrainGenerator.new(1337)

	var h = gen.height_at(Vector2i(0, 0), bounds)
	assert_true(h > 0 and h < 256, "height_at must return reasonable elevation")

	var wh = gen.water_height_at(Vector2i(0, 0), bounds)
	assert_true(wh >= 0, "water_height_at must return valid water elevation")
