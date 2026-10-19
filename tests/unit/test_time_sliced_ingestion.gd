class_name TestTimeSlicedIngestion
extends "res://tests/framework/test_case.gd"

func _create_test_mesh_data() -> MeshData:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, 1, 2)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	return mesher.build_mesh(data, reg)

func _setup_test_world() -> VoxelWorld:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.chunk_size = 32
	world.world_config.voxel_size = 1.0
	world.world_config.collision_distance_chunks = 3
	world.world_config.view_distance_chunks = 8
	world.world_config.max_mesh_apply_budget_ms = 1.0

	world.bounds = world.world_config.create_world_bounds()
	world.generator = ContinentGenerator.new(1337)
	world.mesher = SurfaceShellMesher.new()
	world.material_registry = MaterialRegistry.create_default_registry()
	world.scheduler = ChunkScheduler.new()
	world.streamer = ChunkStreamer.new()

	var chunks_root = Node3D.new()
	chunks_root.name = "ChunksRoot"
	world.add_child(chunks_root)
	world._chunks_root = chunks_root

	return world

func test_world_config_has_budget_setting() -> void:
	var cfg = WorldConfig.new()
	assert_eq(cfg.max_mesh_apply_budget_ms, 1.0, "Default apply budget should be 1.0 ms")
	cfg.max_mesh_apply_budget_ms = 0.5
	assert_eq(cfg.max_mesh_apply_budget_ms, 0.5, "Budget should be modifiable")

func test_process_completed_chunks_respects_time_budget() -> void:
	var world = _setup_test_world()
	var mesh_data = _create_test_mesh_data()
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)

	# Queue 4 completed chunks
	for i in range(4):
		var coord = ChunkCoord.new(i, 0)
		var item = {
			"phase": ChunkScheduler.GenerationPhase.PHASE_SURFACE,
			"coord": coord,
			"data": null,
			"mesh_data": mesh_data,
			"surface_shape": shapes.surface_shape,
			"cave_shape": null,
			"has_cave_mouth": false
		}
		world._pending_completed_chunks.append(item)

	assert_eq(world.get_pending_completed_chunk_count(), 4, "Queue should contain 4 items")

	# Set practically 0 budget (0.0001 ms = 0 usec) so it stops after processing minimum 1 chunk
	world.world_config.max_mesh_apply_budget_ms = 0.0001
	world._process_completed_chunks()

	# Exactly 1 chunk should have been processed (guaranteed minimum), leaving 3 in pending queue
	assert_eq(world.get_loaded_chunk_count(), 1, "Exactly 1 chunk should be loaded on frame 1")
	assert_eq(world.get_pending_completed_chunk_count(), 3, "3 chunks should remain pending for next frames")

	# Now give generous budget to process the rest
	world.world_config.max_mesh_apply_budget_ms = 100.0
	world._process_completed_chunks()

	assert_eq(world.get_loaded_chunk_count(), 4, "All 4 chunks should now be loaded")
	assert_eq(world.get_pending_completed_chunk_count(), 0, "Pending queue should be completely empty")

	world.free()

func test_unloading_prunes_pending_completed_chunks() -> void:
	var world = _setup_test_world()
	var mesh_data = _create_test_mesh_data()
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)

	var coord_keep = ChunkCoord.new(0, 0)
	var coord_drop = ChunkCoord.new(10, 10)

	world._pending_completed_chunks.append({
		"phase": ChunkScheduler.GenerationPhase.PHASE_SURFACE,
		"coord": coord_keep,
		"data": null,
		"mesh_data": mesh_data,
		"surface_shape": shapes.surface_shape,
		"cave_shape": null,
		"has_cave_mouth": false
	})
	world._pending_completed_chunks.append({
		"phase": ChunkScheduler.GenerationPhase.PHASE_SURFACE,
		"coord": coord_drop,
		"data": null,
		"mesh_data": mesh_data,
		"surface_shape": shapes.surface_shape,
		"cave_shape": null,
		"has_cave_mouth": false
	})

	assert_eq(world.get_pending_completed_chunk_count(), 2)

	# Simulate focus at (0, 0) and distant chunk at (10, 10) unloaded
	var focus_dummy = Node3D.new()
	focus_dummy.position = Vector3.ZERO
	world.focus_target = focus_dummy

	# Mark (10, 10) as loaded so streamer detects it as to_unload
	var dummy_node = ChunkNode.new()
	world._loaded_chunks[coord_drop.to_key()] = dummy_node

	world._update_streaming()

	# The pending queue should have purged coord_drop
	assert_eq(world.get_pending_completed_chunk_count(), 1)
	assert_true(world._pending_completed_chunks[0].coord.equals(coord_keep))

	world.free()
