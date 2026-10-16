class_name TestVolumetricContinentGenerator
extends "res://tests/framework/test_case.gd"

func test_determinism() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64

	var gen1 = VolumetricContinentGenerator.new(4242, config)
	var gen2 = VolumetricContinentGenerator.new(4242, config)

	var coord = ChunkCoord.new(0, 0)
	var data1: VoxelChunkData = gen1.generate(coord, bounds)
	var data2: VoxelChunkData = gen2.generate(coord, bounds)

	assert_eq(data1.voxels.size(), data2.voxels.size())
	assert_eq(data1.voxels, data2.voxels)

func test_different_seeds_produce_different_terrain() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64

	var gen1 = VolumetricContinentGenerator.new(111, config)
	var gen2 = VolumetricContinentGenerator.new(999, config)

	var coord = ChunkCoord.new(0, 0)
	var data1: VoxelChunkData = gen1.generate(coord, bounds)
	var data2: VoxelChunkData = gen2.generate(coord, bounds)

	assert_ne(data1.voxels, data2.voxels)

func test_bedrock_and_bounds_safety() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64
	config.bedrock_level = 2

	var gen = VolumetricContinentGenerator.new(1337, config)
	var data: VoxelChunkData = gen.generate(ChunkCoord.new(0, 0), bounds)

	# Bedrock must be solid on y=0, 1, 2 for all interior columns
	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			assert_true(data.is_solid(lx, 0, lz))
			assert_true(data.is_solid(lx, 1, lz))
			assert_true(data.is_solid(lx, 2, lz))

	# Sky near top must be air (empty)
	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			assert_eq(data.get_voxel(lx, 63, lz), VoxelMaterialClassifier.MAT_AIR)

func test_caves_and_overhangs_exist() -> void:
	# Scan inland chunks with aggressive cave/overhang settings to verify volumetric features
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 96
	config.cave_cheese_threshold = 0.40 # More common caves
	config.overhang_amplitude = 25.0
	config.overhang_threshold = 0.05

	var gen = VolumetricContinentGenerator.new(1337, config)
	var data: VoxelChunkData = gen.generate(ChunkCoord.new(0, 0), bounds)

	var found_cavity = false
	var found_multi_surface = false

	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			var surface_y = data.get_highest_solid_y(lx, lz)
			if surface_y <= config.bedrock_level + 5:
				continue

			# Check if there is an air pocket below the surface and above bedrock
			var had_air_below = false
			var had_solid_below_air = false
			for y in range(surface_y - 1, config.bedrock_level, -1):
				if data.get_voxel(lx, y, lz) == VoxelMaterialClassifier.MAT_AIR:
					had_air_below = true
				elif had_air_below and data.is_solid(lx, y, lz):
					had_solid_below_air = true
					break

			if had_air_below and had_solid_below_air:
				found_cavity = true
				break
		if found_cavity:
			break

	assert_true(found_cavity, "3D generator must produce subterranean cave cavities or overhang hollows")

func test_material_classification() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64

	var gen = VolumetricContinentGenerator.new(1337, config)
	var data: VoxelChunkData = gen.generate(ChunkCoord.new(0, 0), bounds)

	# For any inland column with surface above sea level, top voxel should be grass,
	# and voxel directly beneath should be dirt
	for lz in range(data.chunk_size):
		for lx in range(data.chunk_size):
			var top_y = data.get_highest_solid_y(lx, lz)
			if top_y > config.sea_level + config.sand_height_offset and top_y < config.stone_height:
				var top_mat = data.get_voxel(lx, top_y, lz)
				assert_eq(top_mat, VoxelMaterialClassifier.MAT_GRASS)
				if top_y > 1:
					var sub_mat = data.get_voxel(lx, top_y - 1, lz)
					assert_eq(sub_mat, VoxelMaterialClassifier.MAT_DIRT)
				return
