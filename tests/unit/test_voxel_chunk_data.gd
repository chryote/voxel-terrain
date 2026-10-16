class_name TestVoxelChunkData
extends "res://tests/framework/test_case.gd"

func test_dimensions_and_initialization() -> void:
	var data = VoxelChunkData.new(16, 64)
	assert_eq(data.chunk_size, 16)
	assert_eq(data.apron_size, 18)
	assert_eq(data.height, 64)
	assert_eq(data.get_total_voxel_count(), 18 * 64 * 18)
	assert_eq(data.get_memory_bytes(), 18 * 64 * 18)

func test_bounds_and_apron() -> void:
	var data = VoxelChunkData.new(16, 64)

	# In bounds
	assert_true(data.is_in_bounds(0, 0, 0))
	assert_true(data.is_in_bounds(15, 63, 15))
	assert_true(data.is_in_bounds(8, 32, 8))

	# Out of bounds (interior)
	assert_false(data.is_in_bounds(-1, 0, 0))
	assert_false(data.is_in_bounds(16, 0, 0))
	assert_false(data.is_in_bounds(0, -1, 0))
	assert_false(data.is_in_bounds(0, 64, 0))
	assert_false(data.is_in_bounds(0, 0, -1))
	assert_false(data.is_in_bounds(0, 0, 16))

	# Apron bounds (horizontal -1 to 16, vertical 0 to 63)
	assert_true(data.is_in_apron(-1, 0, -1))
	assert_true(data.is_in_apron(16, 63, 16))
	assert_true(data.is_in_apron(-1, 32, 8))
	assert_true(data.is_in_apron(8, 32, 16))

	# Out of apron
	assert_false(data.is_in_apron(-2, 0, 0))
	assert_false(data.is_in_apron(17, 0, 0))
	assert_false(data.is_in_apron(0, -1, 0))
	assert_false(data.is_in_apron(0, 64, 0))
	assert_false(data.is_in_apron(0, 0, -2))
	assert_false(data.is_in_apron(0, 0, 17))

func test_voxel_access_and_independence() -> void:
	var data = VoxelChunkData.new(8, 32)
	assert_eq(data.get_voxel(3, 10, 4), 0)
	assert_false(data.is_solid(3, 10, 4))

	data.set_voxel(3, 10, 4, 3) # stone
	assert_eq(data.get_voxel(3, 10, 4), 3)
	assert_true(data.is_solid(3, 10, 4))

	# Ensure neighboring voxels are not affected (no stride aliasing)
	assert_eq(data.get_voxel(4, 10, 4), 0)
	assert_eq(data.get_voxel(2, 10, 4), 0)
	assert_eq(data.get_voxel(3, 11, 4), 0)
	assert_eq(data.get_voxel(3, 9, 4), 0)
	assert_eq(data.get_voxel(3, 10, 5), 0)
	assert_eq(data.get_voxel(3, 10, 3), 0)

	# Apron voxel access
	data.set_voxel(-1, 10, 4, 1) # grass in west apron
	data.set_voxel(8, 10, 4, 2)  # dirt in east apron
	assert_eq(data.get_voxel(-1, 10, 4), 1)
	assert_eq(data.get_voxel(8, 10, 4), 2)

	# Out-of-apron queries return safe air (0)
	assert_eq(data.get_voxel(-5, 10, 4), 0)
	assert_eq(data.get_voxel(3, -5, 4), 0)
	assert_eq(data.get_voxel(3, 100, 4), 0)

func test_fill_and_fill_layer() -> void:
	var data = VoxelChunkData.new(4, 8)
	data.fill_layer(3, 3) # stone on layer 3

	for lz in range(-1, 5):
		for lx in range(-1, 5):
			assert_eq(data.get_voxel(lx, 3, lz), 3)
			assert_eq(data.get_voxel(lx, 2, lz), 0)
			assert_eq(data.get_voxel(lx, 4, lz), 0)

	data.fill(5) # fill all with snow
	assert_eq(data.get_voxel(0, 0, 0), 5)
	assert_eq(data.get_voxel(-1, 7, -1), 5)
	assert_eq(data.get_voxel(4, 7, 4), 5)

func test_highest_solid_y_with_overhang_and_cave() -> void:
	var data = VoxelChunkData.new(8, 64)

	# Empty column
	assert_eq(data.get_highest_solid_y(2, 2), -1)

	# Cave and overhang scenario:
	# Layer 10-15: Cave floor / underground stone
	# Layer 16-25: Cave void (air)
	# Layer 26-28: Overhang roof (stone/dirt)
	# Layer 29: Surface grass
	# Layer 30+: Open air
	for y in range(10, 16):
		data.set_voxel(2, y, 2, 3) # stone
	for y in range(26, 29):
		data.set_voxel(2, y, 2, 2) # dirt
	data.set_voxel(2, 29, 2, 1)    # grass

	# The highest solid voxel must be the overhang surface (29)
	assert_eq(data.get_highest_solid_y(2, 2), 29)

	# Verify the cave interior at y=20 is indeed air
	assert_eq(data.get_voxel(2, 20, 2), 0)
	assert_eq(data.get_voxel(2, 12, 2), 3)
