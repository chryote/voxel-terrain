class_name TestCaveSwitch
extends "res://tests/framework/test_case.gd"

## Unit tests verifying that cave generation and subterranean level streaming
## can be cleanly turned off like a master switch without affecting surface terrain.

func test_cave_mouth_sampler_disabled() -> void:
	var config = CaveGeneratorConfig.new()
	config.enabled = false
	var mouth_sampler = CaveMouthSampler.new(1337, config)

	# Even at high-altitude dry land, no mouth candidate should be detected
	var candidate = mouth_sampler.is_mouth_candidate(100.0, 100.0, 60.0, 24)
	assert_false(candidate, "Cave mouth candidates must not be detected when caves are disabled")

	var mouth_info = mouth_sampler.sample_mouth(100.0, 100.0, 60.0, 24)
	assert_false(mouth_info.is_mouth, "sample_mouth must return is_mouth: false when disabled")

	var cell_intersect = mouth_sampler.can_mouth_intersect_cell(
		Vector3(0, 40, 0), Vector3(10, 60, 10), 60.0, 24
	)
	assert_false(cell_intersect, "Mouth cell intersection must be false when disabled")

func test_cave_carver_disabled() -> void:
	var config = CaveGeneratorConfig.new()
	config.enabled = false
	var carver = CaveCarver.new(1337, config)
	var surface_h = 50.0
	var sea_level = 24

	# Sky above surface remains air (1.0)
	var sky_density = carver.sample_carve_density(0.0, 60.0, 0.0, surface_h, sea_level)
	assert_almost_eq(sky_density, 1.0, 0.001, "Sky above surface must remain air")

	# Subterranean strata must remain solid (0.0) everywhere
	for y in range(3, 48, 5):
		var density = carver.sample_carve_density(0.0, float(y), 0.0, surface_h, sea_level)
		assert_almost_eq(density, 0.0, 0.001, "Underground density at Y=%d must be 0.0 (solid)" % y)
		assert_false(carver.is_carved(0.0, float(y), 0.0, surface_h, sea_level),
			"Voxel at Y=%d must not be carved" % y)
		assert_false(carver.is_subterranean_water(0.0, float(y), 0.0, surface_h, sea_level),
			"Subterranean water must not spawn when caves are disabled")

	# Coarse status must be STATUS_SOLID for all underground cells
	var status = carver.sample_coarse_cell_status(
		Vector3(0, 10, 0), Vector3(4, 14, 4), surface_h, surface_h, sea_level
	)
	assert_eq(status, CaveCarver.STATUS_SOLID, "Underground coarse cells must be STATUS_SOLID when disabled")

func test_layered_generator_and_mesher_disabled() -> void:
	var cave_config = CaveGeneratorConfig.new()
	cave_config.enabled = false
	var gen_config = ContinentGeneratorConfig.new()
	var gen = LayeredTerrainGenerator.new(1337, gen_config, cave_config)
	var bounds = WorldBounds.new(Vector2i(256, 256), 16, 1.0)
	var coord = ChunkCoord.new(10, 10)

	var s_data = gen.generate_surface(coord, bounds)
	assert_false(s_data.has_cave_mouth, "Surface chunk must not contain cave mouth when disabled")

	var v_data = gen.generate_subterranean(s_data, coord, bounds)
	assert_false(v_data.has_cave_mouth, "VoxelChunkData must not report cave mouth when disabled")

	# Every underground voxel must be solid stone/bedrock (no carved air voids)
	var air_count = 0
	for lz in range(16):
		for lx in range(16):
			var surf = v_data.get_surface_height(lx, lz)
			for ly in range(3, surf - 3):
				if v_data.get_voxel(lx, ly, lz) == 0:
					air_count += 1
	assert_eq(air_count, 0, "No subterranean air voxels should exist when caves are disabled")

	# Meshing Phase A SurfaceChunkData directly produces purely surface mesh with 0 cave geometry
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var s_mesh = mesher.build_mesh(s_data, reg)
	assert_not_null(s_mesh, "Mesher must build mesh for surface chunk")
	if s_mesh is DualMeshBundle:
		assert_false((s_mesh as DualMeshBundle).has_cave_geometry(), "Surface mesh must have 0 cave geometry")

func test_subterranean_stream_coordinator_switch() -> void:
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var chunk_near = ChunkCoord.new(1, 0)
	coord.register_surface_chunk(chunk_near, false)

	# 1. When enabled, descending underground promotes nearby chunk
	coord.enabled = true
	var mouth_cache: Dictionary = {}
	var to_promote = coord.get_chunks_to_promote(Vector3(0, 10, 0), focus_chunk, 50.0, mouth_cache)
	assert_eq(to_promote.size(), 1, "Must promote chunks when enabled and player is underground")

	# 2. When disabled, coordinator never promotes chunks
	coord.enabled = false
	to_promote = coord.get_chunks_to_promote(Vector3(0, 10, 0), focus_chunk, 50.0, mouth_cache)
	assert_eq(to_promote.size(), 0, "Must not promote chunks when coordinator is disabled")

func test_voxel_world_switch_synchronization() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.caves_enabled = false
	world.caves_enabled = false

	world._ready()

	assert_false(world.cave_config.enabled, "cave_config.enabled must be synchronized to false")
	assert_false(world.subterranean_coordinator.enabled, "subterranean_coordinator.enabled must be synchronized to false")

	# Test dynamic toggle back to true and false
	world.caves_enabled = true
	assert_true(world.cave_config.enabled, "cave_config.enabled must update on property toggle")
	assert_true(world.subterranean_coordinator.enabled, "subterranean_coordinator.enabled must update on property toggle")

	world.caves_enabled = false
	assert_false(world.cave_config.enabled, "cave_config.enabled must update back to false")
	assert_false(world.subterranean_coordinator.enabled, "subterranean_coordinator.enabled must update back to false")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()
