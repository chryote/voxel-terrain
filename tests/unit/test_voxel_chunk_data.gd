class_name TestVoxelChunkData
extends "res://tests/framework/test_case.gd"

func test_bounds_and_apron() -> void:
	var data = VoxelChunkData.new(16, 64)
	assert_eq(data.chunk_size, 16)
	assert_eq(data.apron_size, 18)
	assert_eq(data.max_height, 64)

	# In bounds
	assert_true(data.is_in_bounds(0, 0, 0))
	assert_true(data.is_in_bounds(15, 63, 15))
	assert_false(data.is_in_bounds(-1, 0, 0))
	assert_false(data.is_in_bounds(16, 0, 0))
	assert_false(data.is_in_bounds(0, 64, 0))

	# In apron
	assert_true(data.is_in_apron(-1, 0, -1))
	assert_true(data.is_in_apron(16, 0, 16))
	assert_false(data.is_in_apron(-2, 0, 0))
	assert_false(data.is_in_apron(17, 0, 0))

func test_voxel_and_water_access() -> void:
	var data = VoxelChunkData.new(8, 32)
	assert_eq(data.get_voxel(2, 5, 2), 0)
	assert_false(data.has_water(2, 5, 2))

	data.set_voxel(2, 5, 2, MaterialDef.ID_STONE)
	assert_eq(data.get_voxel(2, 5, 2), MaterialDef.ID_STONE)

	data.set_water(2, 5, 2, true)
	assert_true(data.has_water(2, 5, 2))

	data.set_water(2, 5, 2, false)
	assert_false(data.has_water(2, 5, 2))

func test_fill_and_clear() -> void:
	var data = VoxelChunkData.new(4, 16)
	data.fill_material(MaterialDef.ID_DIRT)
	assert_eq(data.get_voxel(0, 0, 0), MaterialDef.ID_DIRT)
	assert_eq(data.get_voxel(3, 15, 3), MaterialDef.ID_DIRT)

	data.clear()
	assert_eq(data.get_voxel(0, 0, 0), 0)
	assert_eq(data.get_voxel(3, 15, 3), 0)
