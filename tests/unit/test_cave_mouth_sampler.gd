class_name TestCaveMouthSampler
extends "res://tests/framework/test_case.gd"



func test_determinism() -> void:
	var config = CaveGeneratorConfig.new()
	var sampler1 = CaveMouthSampler.new(1337, config)
	var sampler2 = CaveMouthSampler.new(1337, config)
	var sampler_diff = CaveMouthSampler.new(9999, config)

	var sea_level = 24
	var surface_h = 45.0

	for x in [0.0, 150.0, 300.0, 750.0]:
		for z in [0.0, 150.0, 300.0, 750.0]:
			var res1 = sampler1.sample_mouth(x, z, surface_h, sea_level)
			var res2 = sampler2.sample_mouth(x, z, surface_h, sea_level)
			assert_eq(res1.is_mouth, res2.is_mouth, "Same seed must have identical mouth state at (%f, %f)" % [x, z])
			assert_almost_eq(res1.intensity, res2.intensity, 0.0001, "Same seed must have identical intensity")
			assert_almost_eq(res1.carve_depth, res2.carve_depth, 0.0001, "Same seed must have identical carve_depth")

	# Check that different seeds differ
	var found_diff = false
	for x in range(0, 1000, 50):
		var n1 = sampler1.sample_raw_noise(float(x), 0.0)
		var nd = sampler_diff.sample_raw_noise(float(x), 0.0)
		if absf(n1 - nd) > 0.05:
			found_diff = true
			break
	assert_true(found_diff, "Different seeds must produce different noise values")

func test_water_safety_margin() -> void:
	var config = CaveGeneratorConfig.new()
	config.water_safety_margin = 3.0
	var sampler = CaveMouthSampler.new(1337, config)
	var sea_level = 24

	# Scan many points with surface height submerged or close to sea level
	for submerged_h in [10.0, 20.0, 23.9, 25.0, 26.9]:
		for x in range(-500, 500, 100):
			for z in range(-500, 500, 100):
				var res = sampler.sample_mouth(float(x), float(z), submerged_h, sea_level)
				assert_false(res.is_mouth, "Mouth must NEVER generate when surface is below sea_level + margin (h=%f, sl=%d)" % [submerged_h, sea_level])
				assert_false(sampler.is_mouth_candidate(float(x), float(z), submerged_h, sea_level), "Candidate check must reject water-adjacent points")

func test_mouth_properties_and_funnel_carve() -> void:
	var config = CaveGeneratorConfig.new()
	# Temporarily set lower threshold so we can easily find a mouth within a short grid
	config.mouth_threshold = 0.2
	config.mouth_radius = 8.0
	config.max_entrance_depth = 15.0
	var sampler = CaveMouthSampler.new(1337, config)

	var sea_level = 24
	var surface_h = 50.0

	# Find a point that triggers a mouth
	var found_mouth = false
	var mouth_x = 0.0
	var mouth_z = 0.0
	var mouth_res = {}

	for x in range(0, 800, 20):
		for z in range(0, 800, 20):
			var res = sampler.sample_mouth(float(x), float(z), surface_h, sea_level)
			if res.is_mouth:
				found_mouth = true
				mouth_x = float(x)
				mouth_z = float(z)
				mouth_res = res
				break
		if found_mouth:
			break

	assert_true(found_mouth, "Must find at least one mouth with threshold 0.2")
	assert_true(mouth_res.intensity > 0.0 and mouth_res.intensity <= 1.0, "Intensity must be in (0, 1]")
	assert_true(mouth_res.carve_depth > 0.0 and mouth_res.carve_depth <= config.max_entrance_depth, "Carve depth must be within range")
	assert_almost_eq(mouth_res.bottom_y, surface_h - mouth_res.carve_depth, 0.001, "Bottom Y must be surface_h - carve_depth")
	assert_true(mouth_res.effective_radius > 0.0 and mouth_res.effective_radius <= config.mouth_radius, "Radius within range")

	# Test funnel carving at this mouth
	var mid_y = (mouth_res.bottom_y + surface_h) * 0.5
	var carve_mid = sampler.get_funnel_carve(mouth_x, mid_y, mouth_z, surface_h, sea_level)
	assert_true(carve_mid > 0.0, "Funnel carve at mid elevation must be positive (hollow air)")

	# Above surface + 2m should not be carved by funnel
	var carve_high = sampler.get_funnel_carve(mouth_x, surface_h + 10.0, mouth_z, surface_h, sea_level)
	assert_eq(carve_high, 0.0, "Funnel carve far above surface must be 0")

	# Below bottom_y should not be carved by funnel
	var carve_deep = sampler.get_funnel_carve(mouth_x, mouth_res.bottom_y - 5.0, mouth_z, surface_h, sea_level)
	assert_eq(carve_deep, 0.0, "Funnel carve below bottom_y must be 0")

func test_crust_sealed_outside_mouth() -> void:
	var config = CaveGeneratorConfig.new()
	config.mouth_threshold = 0.999 # Virtually no mouths triggered
	config.crust_depth = 4.0
	var sampler = CaveMouthSampler.new(1337, config)

	var surface_h = 60.0
	var sea_level = 24

	# At any point outside a mouth, the crust layer [surface_h - 4.0, surface_h] must be sealed
	for x in range(0, 300, 50):
		for z in range(0, 300, 50):
			for y_offset in [0.0, 1.0, 2.0, 3.0, 4.0]:
				var wy = surface_h - y_offset
				var sealed = sampler.is_crust_sealed(float(x), wy, float(z), surface_h, sea_level)
				assert_true(sealed, "Crust at Y=%f must be sealed outside of mouth" % wy)

			# Deep underground (below crust) is NOT considered sealed crust
			var subterranean_y = surface_h - 10.0
			var sealed_sub = sampler.is_crust_sealed(float(x), subterranean_y, float(z), surface_h, sea_level)
			assert_false(sealed_sub, "Deep subterranean rock is not part of protected surface crust")

func test_cave_mouth_chunk_apron_candidate_detection() -> void:
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var gen_config = ContinentGeneratorConfig.new()
	var cave_config = CaveGeneratorConfig.new()
	var generator = VolumetricTerrainGenerator.new(world_config.world_seed, gen_config, cave_config)
	generator.init_cave_mouths(bounds)

	# Chunk (81, 3) has the cave mouth, Chunk (81, 4) directly borders it in its North apron
	var c81_3 = ChunkCoord.new(81, 3)
	var c81_4 = ChunkCoord.new(81, 4)
	var s81_3 = generator.generate_surface(c81_3, bounds)
	var s81_4 = generator.generate_surface(c81_4, bounds)

	assert_true(s81_3.has_cave_mouth, "Chunk (81, 3) must have has_cave_mouth = true")
	assert_true(s81_4.has_cave_mouth, "Chunk (81, 4) must have has_cave_mouth = true due to apron mouth border")

	var sub81_4 = generator.generate_subterranean(s81_4, c81_4, bounds)
	assert_true(sub81_4 is VoxelChunkData, "Chunk (81, 4) must be promoted to VoxelChunkData")

	var mesher = VoxelMesher.new()
	var registry = MaterialRegistry.create_default_registry()
	var bundle = mesher.build_mesh(sub81_4, registry) as DualMeshBundle
	assert_not_null(bundle, "Must produce DualMeshBundle")
	assert_true(bundle.has_cave_mouth, "Bundle must have has_cave_mouth = true")

	# Check for North-facing wall at z=0 (facing 81, 3)
	var has_north_wall = false
	for i in range(bundle.vertices.size()):
		var v = bundle.vertices[i]
		var n = bundle.normals[i]
		if absf(v.z) < 0.01 and n.z < -0.9:
			has_north_wall = true
			break
	assert_true(has_north_wall, "Chunk (81, 4) must mesh a North-facing wall at z=0 to seal the cave mouth opening")
