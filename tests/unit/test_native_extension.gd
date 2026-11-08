class_name TestNativeExtension
extends "res://tests/framework/test_case.gd"

## Validates Phase 0 of the C++ GDExtension rollout:
## - ClassDB registration of GDExtension types
## - Native instantiation and method binding
## - Direct execution of vendored FastNoiseLite.h in C++

func test_native_extension_loaded() -> void:
	assert_true(ClassDB.class_exists("TerrainNativeCore"), "TerrainNativeCore should be registered in ClassDB")
	var native = ClassDB.instantiate("TerrainNativeCore")
	assert_not_null(native, "TerrainNativeCore should instantiate")
	assert_true(native.is_native_active(), "is_native_active() should return true")
	assert_true(native.get_version().contains("godot-cpp"), "Version string should reference godot-cpp")

	assert_true(ClassDB.class_exists("OffThreadCollisionBakerNative"), "OffThreadCollisionBakerNative should be in ClassDB")
	var native_baker = ClassDB.instantiate("OffThreadCollisionBakerNative")
	assert_not_null(native_baker, "OffThreadCollisionBakerNative should instantiate from ClassDB")

	assert_true(ClassDB.class_exists("VoxelChunkDataNative"), "VoxelChunkDataNative should be in ClassDB")
	var native_vdata = ClassDB.instantiate("VoxelChunkDataNative")
	assert_not_null(native_vdata, "VoxelChunkDataNative should instantiate from ClassDB")

func test_off_thread_collision_baker_native() -> void:
	var baker = OffThreadCollisionBaker.new()
	assert_not_null(baker, "OffThreadCollisionBaker should instantiate")

	var mesh = MeshData.new()
	mesh.vertices.append(Vector3(0, 0, 0))
	mesh.vertices.append(Vector3(1, 0, 0))
	mesh.vertices.append(Vector3(0, 0, 1))
	mesh.indices.append(0)
	mesh.indices.append(1)
	mesh.indices.append(2)

	var shape = baker.bake_shape(mesh)
	assert_not_null(shape, "Native baker must generate ConcavePolygonShape3D")
	assert_true(shape.backface_collision, "Shape must have backface collision enabled")
	assert_eq(shape.get_faces().size(), 3, "1 triangle must generate 3 face vertices")
	assert_eq(shape.get_faces()[0], Vector3(0, 0, 0))
	assert_eq(shape.get_faces()[1], Vector3(1, 0, 0))
	assert_eq(shape.get_faces()[2], Vector3(0, 0, 1))

func test_voxel_chunk_data_native() -> void:
	var data = VoxelChunkData.new(16, 64)
	assert_eq(data.chunk_size, 16)
	assert_eq(data.apron_size, 18)
	assert_eq(data.max_height, 64)

	# Bounds and apron checks
	assert_true(data.is_in_bounds(0, 0, 0))
	assert_true(data.is_in_bounds(15, 63, 15))
	assert_false(data.is_in_bounds(-1, 0, 0))
	assert_false(data.is_in_bounds(16, 0, 0))
	assert_true(data.is_in_apron(-1, 0, -1))
	assert_true(data.is_in_apron(16, 0, 16))

	# Set/get voxel
	assert_eq(data.get_voxel(2, 5, 2), 0)
	data.set_voxel(2, 5, 2, MaterialDef.ID_STONE)
	assert_eq(data.get_voxel(2, 5, 2), MaterialDef.ID_STONE)

	# Water access
	assert_false(data.has_water(2, 5, 2))
	data.set_water(2, 5, 2, true)
	assert_true(data.has_water(2, 5, 2))

	# Section status: 64m height / 16 = 4 sections
	assert_eq(data.get_section_count(), 4)
	data.compute_section_status()
	# Section 0 (Y=0..15) has voxel at Y=5, so it must be MIXED
	assert_eq(data.get_section_status(0), VoxelChunkData.SECTION_MIXED)
	assert_true(data.is_section_empty(1))
	assert_true(data.is_section_empty(2))
	assert_true(data.is_section_empty(3))

	# Fill material -> all solid
	data.fill_material(MaterialDef.ID_STONE)
	assert_true(data.is_section_solid(0))
	assert_true(data.is_section_solid(1))
	assert_true(data.is_section_solid(2))
	assert_true(data.is_section_solid(3))

	# Clear
	data.clear()
	assert_eq(data.get_voxel(2, 5, 2), 0)
	assert_true(data.is_section_empty(0))

func test_vendored_fast_noise_lite() -> void:
	var native = ClassDB.instantiate("TerrainNativeCore")
	assert_not_null(native, "TerrainNativeCore should instantiate")
	var sample_a = native.sample_test_noise(10.5, 20.25, 1337)
	var sample_b = native.sample_test_noise(10.5, 20.25, 1337)
	var sample_c = native.sample_test_noise(99.0, -42.0, 1337)

	assert_true(sample_a >= -1.0 and sample_a <= 1.0, "Noise sample A must be within [-1.0, 1.0]")
	assert_eq(sample_a, sample_b, "Noise sampling with same coordinates and seed must be deterministic")
	assert_true(sample_a != sample_c, "Noise sampling different coordinates should produce different values")

