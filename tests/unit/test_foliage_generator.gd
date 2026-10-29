class_name TestFoliageGenerator
extends "res://tests/framework/test_case.gd"

## Unit tests validating off-thread procedural foliage scattering, determinism, and buffer packing.

const FoliageChunkDataClass = preload("res://src/core/foliage_chunk_data.gd")
const FoliageConfigClass = preload("res://src/generation/foliage_generator_config.gd")
const FoliageGeneratorClass = preload("res://src/generation/foliage_generator.gd")

func test_null_or_disabled_generation() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var s_data = SurfaceChunkData.new(8, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	# Null inputs
	var res_null_data = gen.generate(coord, null)
	assert_true(res_null_data.is_empty(), "Null surface data must return empty foliage data")

	var res_null_coord = gen.generate(null, s_data)
	assert_true(res_null_coord.is_empty(), "Null coord must return empty foliage data")

	# Disabled config
	var cfg = FoliageConfigClass.new()
	cfg.enabled = false
	var res_disabled = gen.generate(coord, s_data, cfg)
	assert_true(res_disabled.is_empty(), "Disabled config must return empty foliage data")

func test_material_filtering_only_grass() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(1, 2)
	var cfg = FoliageConfigClass.new()
	cfg.density_probability = 1.0 # Guarantee 100% placement on matches

	# Fill with non-grass materials (stone & dirt)
	var non_grass_data = SurfaceChunkData.new(8, 2)
	non_grass_data.fill(15, MaterialDef.ID_STONE, MaterialDef.ID_DIRT)
	var res_non_grass = gen.generate(coord, non_grass_data, cfg)
	assert_eq(res_non_grass.instance_count, 0, "Stone and dirt must never spawn grass foliage")
	assert_eq(res_non_grass.transform_buffer.size(), 0, "Non-grass buffer must remain empty")

	# Fill with grass material (ID 1)
	var grass_data = SurfaceChunkData.new(8, 2)
	grass_data.fill(15, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)
	var res_grass = gen.generate(coord, grass_data, cfg)
	assert_true(res_grass.instance_count > 0, "Grass blocks must spawn foliage instances")
	assert_eq(res_grass.transform_buffer.size(), res_grass.instance_count * 12, "Buffer size must match count * 12 floats")

func test_scatter_determinism() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(5, -3)
	var cfg = FoliageConfigClass.new()
	cfg.world_seed = 98765

	var s_data = SurfaceChunkData.new(16, 2)
	s_data.fill(30, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var run1 = gen.generate(coord, s_data, cfg)
	var run2 = gen.generate(coord, s_data, cfg)

	assert_eq(run1.instance_count, run2.instance_count, "Identical seed and coordinates must produce identical instance counts")
	assert_eq(run1.transform_buffer.size(), run2.transform_buffer.size(), "Transform buffers must have identical float count")

	# Byte-by-byte buffer comparison
	var matches: bool = true
	for i in range(run1.transform_buffer.size()):
		if not is_equal_approx(run1.transform_buffer[i], run2.transform_buffer[i]):
			matches = false
			break
	assert_true(matches, "Transform buffers must match identically across repeated generation runs")

func test_transform_bounds_and_height() -> void:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var cfg = FoliageConfigClass.new()
	cfg.density_probability = 1.0

	var s_data = SurfaceChunkData.new(8, 2)
	for lz in range(8):
		for lx in range(8):
			s_data.set_height(lx, lz, 20 + lx)
			s_data.set_top_material(lx, lz, MaterialDef.ID_GRASS)

	var res = gen.generate(coord, s_data, cfg)
	assert_true(res.instance_count > 0, "Must generate instances")

	for i in range(res.instance_count):
		var t = res.get_instance_transform(i)
		assert_true(t.origin.x >= 0.0, "Instance X must be >= 0")
		assert_true(t.origin.x <= 8.0, "Instance X must be <= chunk_size")
		assert_true(t.origin.z >= 0.0, "Instance Z must be >= 0")
		assert_true(t.origin.z <= 8.0, "Instance Z must be <= chunk_size")

		# Height should correspond to integer block top
		var col_x = clampi(int(floor(t.origin.x)), 0, 7)
		var col_z = clampi(int(floor(t.origin.z)), 0, 7)
		var expected_h = float(s_data.get_height(col_x, col_z))
		assert_eq(t.origin.y, expected_h, "Instance Y must exactly anchor on surface height")

func test_foliage_architecture_purity() -> void:
	var files = [
		"res://src/core/foliage_chunk_data.gd",
		"res://src/generation/foliage_generator_config.gd",
		"res://src/generation/foliage_generator.gd"
	]

	for path in files:
		var file = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "File must exist: %s" % path)
		var content = file.get_as_text()
		file.close()

		assert_false("extends Node\n" in content, "%s must not extend Node" % path)
		assert_false("extends Node3D" in content, "%s must not extend Node3D" % path)
		assert_false("res://src/world" in content, "%s must not reference src/world" % path)
		assert_false("res://src/player" in content, "%s must not reference src/player" % path)
		assert_true(content.split("\n").size() < 140, "%s must be under 140 lines" % path)
