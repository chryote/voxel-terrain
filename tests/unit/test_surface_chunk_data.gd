class_name TestSurfaceChunkData
extends "res://tests/framework/test_case.gd"

func test_bounds_and_apron() -> void:
	var data = SurfaceChunkData.new(16, 2)
	assert_eq(data.chunk_size, 16)
	assert_eq(data.apron_size, 18)
	assert_eq(data.shell_depth, 2)

	assert_true(data.is_in_bounds(0, 0))
	assert_true(data.is_in_bounds(15, 15))
	assert_false(data.is_in_bounds(-1, 0))
	assert_false(data.is_in_bounds(16, 0))

	assert_true(data.is_in_apron(-1, -1))
	assert_true(data.is_in_apron(16, 16))
	assert_false(data.is_in_apron(-2, 0))
	assert_false(data.is_in_apron(17, 0))

func test_height_and_material_access() -> void:
	var data = SurfaceChunkData.new(8, 3)
	data.set_height(0, 0, 42)
	data.set_top_material(0, 0, 1) # grass
	data.set_side_material(0, 0, 2) # dirt

	# Set apron value
	data.set_height(-1, 0, 40)
	data.set_top_material(-1, 0, 4) # sand

	assert_eq(data.get_height(0, 0), 42)
	assert_eq(data.get_top_material(0, 0), 1)
	assert_eq(data.get_side_material(0, 0), 2)

	assert_eq(data.get_height(-1, 0), 40)
	assert_eq(data.get_top_material(-1, 0), 4)

	# Out of apron returns safe 0
	assert_eq(data.get_height(-5, 0), 0)
	assert_eq(data.get_top_material(-5, 0), 0)

func test_fill() -> void:
	var data = SurfaceChunkData.new(4, 2)
	data.fill(20, 1, 2)
	for lz in range(-1, 5):
		for lx in range(-1, 5):
			assert_eq(data.get_height(lx, lz), 20)
			assert_eq(data.get_top_material(lx, lz), 1)
			assert_eq(data.get_side_material(lx, lz), 2)
