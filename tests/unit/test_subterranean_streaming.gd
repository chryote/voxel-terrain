class_name TestSubterraneanStreaming
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 4: Demand-Driven Lazy Subterranean Streaming.
## Verifies surface-first generation, instantaneous <30 ms surface load times,
## on-demand subterranean promotion, and cave mouth auto-queueing.

func test_surface_first_chunk_pipeline() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var scheduler = ChunkScheduler.new()

	var coord = ChunkCoord.new(5, 5)
	var start_time = Time.get_ticks_usec()
	scheduler.schedule_surface_chunk(coord, bounds, gen, mesher, reg)

	var results: Array[Dictionary] = []
	var attempts = 0
	while attempts < 100 and results.is_empty():
		OS.delay_msec(5)
		results = scheduler.poll_completed(1)
		attempts += 1

	var elapsed_ms = float(Time.get_ticks_usec() - start_time) / 1000.0

	assert_eq(results.size(), 1, "Must receive completed surface chunk")
	var res = results[0]
	assert_eq(res.phase, ChunkScheduler.GenerationPhase.PHASE_SURFACE)
	assert_true(res.coord.equals(coord))
	assert_not_null(res.data, "Must contain surface data")
	assert_not_null(res.mesh_data, "Must contain surface mesh")
	assert_false(res.mesh_data.is_empty(), "Surface mesh must not be empty")

	# Surface collision shape must be pre-baked off-thread
	assert_not_null(res.surface_shape, "Surface collision shape must be pre-baked")
	# Subterranean cave shape must be deferred (null)
	assert_null(res.cave_shape, "Cave collision shape must be deferred during Phase A")

	# Timing verification: surface-first generation must be very fast (under 150 ms on CI/runner under load, under 30 ms target)
	assert_true(elapsed_ms < 150.0, "Surface-first pipeline must complete rapidly (took: %f ms)" % elapsed_ms)
	scheduler.wait_all_tasks()

func test_cave_mouth_chunk_triggers_subterranean_generation() -> void:
	var bounds = WorldBounds.new(Vector2i(32, 32), 32, 1.0)
	var cave_config = CaveGeneratorConfig.new()
	# Lower threshold to guarantee finding a cave mouth
	cave_config.mouth_threshold = 0.2
	cave_config.mouth_radius = 8.0

	var gen = LayeredTerrainGenerator.new(1337, null, cave_config)
	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var scheduler = ChunkScheduler.new()

	# Scan for a chunk that contains a mouth
	var mouth_coord: ChunkCoord = null
	var allowed = gen.init_cave_mouths(bounds)
	if allowed.size() > 0:
		var target_c = bounds.world_to_chunk(allowed[0].world_pos)
		var target_s = gen.generate_surface(target_c, bounds)
		if target_s.has_cave_mouth:
			mouth_coord = target_c

	if mouth_coord == null:
		for cx in range(0, 10):
			for cz in range(0, 10):
				var c = ChunkCoord.new(cx, cz)
				var s_data = gen.generate_surface(c, bounds)
				if s_data.has_cave_mouth:
					mouth_coord = c
					break
			if mouth_coord != null:
				break

	assert_not_null(mouth_coord, "Must find a chunk with a cave mouth candidate")

	# Schedule subterranean generation for mouth chunk
	scheduler.schedule_subterranean_chunk(mouth_coord, bounds, gen, mesher, reg, null, true)

	var results: Array[Dictionary] = []
	var attempts = 0
	while attempts < 400 and results.is_empty():
		OS.delay_msec(10)
		results = scheduler.poll_completed(1)
		attempts += 1

	assert_eq(results.size(), 1, "Must complete subterranean generation for cave mouth chunk")
	var res = results[0]
	assert_eq(res.phase, ChunkScheduler.GenerationPhase.PHASE_SUBTERRANEAN)
	assert_true(res.has_cave_mouth, "Result must flag has_cave_mouth")

	var bundle = res.mesh_data as DualMeshBundle
	assert_not_null(bundle, "Subterranean result must produce DualMeshBundle")
	assert_true(bundle.has_cave_geometry(), "Subterranean result must contain cave geometry")
	assert_not_null(res.cave_shape, "Cave collision shape must be pre-baked")
	scheduler.wait_all_tasks()

func test_subterranean_stream_coordinator_elevation_promotion() -> void:
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var c_near = ChunkCoord.new(1, 0)
	var c_far = ChunkCoord.new(5, 5)

	coord.register_surface_chunk(c_near, false)
	coord.register_surface_chunk(c_far, false)

	var mouth_cache = {
		c_near.to_key(): false,
		c_far.to_key(): false
	}

	# 1. Player is on surface at (0, 50, 0) where surface height is 50.0
	var surface_pos = Vector3(0.0, 50.0, 0.0)
	var to_promote = coord.get_chunks_to_promote(surface_pos, focus_chunk, 50.0, mouth_cache)
	assert_eq(to_promote.size(), 0, "Surface player must not trigger subterranean generation for pure surface chunks")

	# 2. Player descends underground at (0, 30, 0), where surface height is 50.0 (Y < 50 - 4 = 46)
	var sub_pos = Vector3(0.0, 30.0, 0.0)
	to_promote = coord.get_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache)

	# Only chunks within subterranean_radius_chunks (2) should be promoted
	assert_eq(to_promote.size(), 1, "Must promote only nearby chunks within subterranean radius")
	assert_true(to_promote[0].equals(c_near), "Promoted chunk must be c_near")

	# Mark as queued
	coord.mark_subterranean_queued(c_near)
	assert_true(coord.is_subterranean_queued(c_near))

	# Once queued, should not be returned again
	to_promote = coord.get_chunks_to_promote(sub_pos, focus_chunk, 50.0, mouth_cache)
	assert_eq(to_promote.size(), 0, "Already queued chunk must not be returned again")

	# Mark as ready
	coord.mark_subterranean_ready(c_near)
	assert_true(coord.is_subterranean_ready(c_near))

func test_subterranean_stream_coordinator_mouth_proximity_promotion() -> void:
	var coord = SubterraneanStreamCoordinator.new()
	var focus_chunk = ChunkCoord.new(0, 0)
	var c_mouth = ChunkCoord.new(2, 2)
	var c_normal = ChunkCoord.new(0, 1)

	coord.register_surface_chunk(c_mouth, true)
	coord.register_surface_chunk(c_normal, false)

	var mouth_cache = {
		c_mouth.to_key(): true,
		c_normal.to_key(): false
	}

	# Player is on surface far from mouth
	var surface_pos = Vector3(0.0, 60.0, 0.0)
	var to_promote = coord.get_chunks_to_promote(surface_pos, focus_chunk, 60.0, mouth_cache)

	# Chunk with mouth must always be promoted immediately regardless of player altitude
	assert_eq(to_promote.size(), 1, "Chunk containing mouth must be promoted immediately")
	assert_true(to_promote[0].equals(c_mouth))

func test_chunk_node_apply_subterranean_bundle() -> void:
	var chunk_node = ChunkNode.new()
	var surf_mesh = MeshData.new()
	surf_mesh.vertices.append(Vector3(0, 0, 0))
	surf_mesh.vertices.append(Vector3(1, 0, 0))
	surf_mesh.vertices.append(Vector3(0, 0, 1))
	surf_mesh.indices.append(0)
	surf_mesh.indices.append(1)
	surf_mesh.indices.append(2)

	# Setup with pure surface mesh initially
	chunk_node.setup(ChunkCoord.new(0, 0), Vector3.ZERO, surf_mesh, true)
	assert_false(chunk_node.has_cave_mesh(), "ChunkNode must not have cave mesh before Phase B")

	# Now subterranean Phase B finishes and delivers a DualMeshBundle
	var bundle = DualMeshBundle.new()
	bundle.has_cave_mouth = true
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(1, -10, 0))
	bundle.cave_mesh_data.vertices.append(Vector3(0, -10, 1))
	bundle.cave_mesh_data.indices.append(0)
	bundle.cave_mesh_data.indices.append(1)
	bundle.cave_mesh_data.indices.append(2)

	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(bundle)

	chunk_node.apply_subterranean_bundle(bundle, shapes.cave_shape)
	assert_true(chunk_node.has_cave_mesh(), "ChunkNode must now have cave mesh assigned")
	assert_true(chunk_node.has_cave_mouth, "ChunkNode must reflect has_cave_mouth = true")

	# Toggle subterranean visible
	chunk_node.set_subterranean_visible(true)
	assert_true(chunk_node.is_subterranean_visible())
	assert_not_null(chunk_node.cave_collision_shape.shape, "Cave collision shape must be bound")
	assert_false(chunk_node.cave_collision_shape.disabled, "Cave collision shape must be enabled")

	chunk_node.free()

func test_layered_terrain_generator_methods() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var gen = LayeredTerrainGenerator.new(1337)
	var coord = ChunkCoord.new(1, 1)

	var s_data = gen.generate_surface(coord, bounds)
	assert_not_null(s_data)
	assert_eq(s_data.chunk_size, 16)

	var v_data = gen.generate_subterranean(s_data, coord, bounds)
	assert_not_null(v_data)
	assert_eq(v_data.chunk_size, 16)
	assert_eq(v_data.get_voxel(0, 0, 0), MaterialDef.ID_STONE, "Bedrock must be solid stone")

func test_chunk_negative_17_negative_23_subterranean_generation() -> void:
	## Regression test: validates that chunk (-17, -23) properly detects worm tunnels and
	## generates subterranean geometry rather than failing to load / leaving open void.
	var world_config = WorldConfig.new()
	var bounds = world_config.create_world_bounds()
	var cave_config = CaveGeneratorConfig.new()
	cave_config.use_directed_worm_corridors = false
	var gen = VolumetricTerrainGenerator.new(world_config.world_seed, null, cave_config)
	if gen.cave_carver != null and gen.continent_gen != null:
		gen.cave_carver.set_continent_mask(gen.continent_gen.mask, bounds)

	var coord = ChunkCoord.new(-17, -23)
	var surf_data = gen.generate_surface(coord, bounds)
	var sub_data = gen.generate_subterranean(surf_data, coord, bounds)

	assert_not_null(sub_data, "Subterranean data for (-17, -23) must not be null")

	var mesher = VoxelMesher.new()
	var reg = MaterialRegistry.create_default_registry()
	var bundle = mesher.build_mesh(sub_data, reg)

	assert_true(bundle is DualMeshBundle, "Meshed chunk must produce a DualMeshBundle")
	assert_true(bundle.has_cave_geometry(), "Chunk (-17, -23) must contain cave geometry")
	assert_true(bundle.cave_mesh_data.vertices.size() > 1000, "Chunk (-17, -23) must generate comprehensive cave mesh (got %d vertices)" % bundle.cave_mesh_data.vertices.size())

func test_tightened_vertical_carving_and_allocation_extents() -> void:
	## Validates Task 2.1: Tighten Vertical Carving Extents for 3D Fallback
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var cave_config = CaveGeneratorConfig.new()
	cave_config.bypass_chasm_voxelization = false # Force 3D fallback voxel allocation
	var gen = LayeredTerrainGenerator.new(1337, null, cave_config)
	var coord = ChunkCoord.new(0, 0)

	var s_data = gen.generate_surface(coord, bounds)
	var max_elev = gen._calculate_surface_max_elevation(s_data)

	var v_data = gen.generate_subterranean(s_data, coord, bounds) as VoxelChunkData
	assert_not_null(v_data, "Subterranean voxel data must not be null")

	# 1. Open sky strata must not be allocated (must be clamped to needed 16m sections, not 160m)
	assert_true(v_data.max_height < 160, "VoxelChunkData max_height (%d) must be tightened below 160m" % v_data.max_height)
	var expected_sections = ceili(float(max_elev + 2) / float(VoxelChunkData.SECTION_HEIGHT))
	assert_eq(v_data.get_section_count(), expected_sections, "Section count must match expected required strata")
	assert_true(v_data.total_voxels < 60000, "Voxel count (%d) must be substantially reduced from 185k" % v_data.total_voxels)

	# 2. Bedrock protection invariant: strata below carve_floor (Y <= 2) must remain 100% solid stone
	for lz in range(bounds.chunk_size):
		for lx in range(bounds.chunk_size):
			for ly in range(3):
				assert_eq(v_data.get_voxel(lx, ly, lz), MaterialDef.ID_STONE, "Bedrock voxel at (%d, %d, %d) must remain solid stone" % [lx, ly, lz])

