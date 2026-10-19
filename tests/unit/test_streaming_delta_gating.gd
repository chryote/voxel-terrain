class_name TestStreamingDeltaGating
extends "res://tests/framework/test_case.gd"

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

	var focus_dummy = Node3D.new()
	focus_dummy.position = Vector3(10.0, 30.0, 10.0)
	world.focus_target = focus_dummy

	return world

func test_streaming_runs_on_initial_call() -> void:
	var world = _setup_test_world()

	assert_null(world._last_streaming_chunk, "Initial streaming chunk should be null")
	world._update_streaming()

	assert_not_null(world._last_streaming_chunk, "Streaming chunk should be set after first update")
	assert_eq(world._last_streaming_position, Vector3(10.0, 30.0, 10.0))

	world.free()

func test_streaming_skips_when_stationary_or_small_movement() -> void:
	var world = _setup_test_world()

	# First evaluation
	world._update_streaming()
	var initial_pos = world._last_streaming_position

	# Move focus target 1.5 meters (< 4.0 meters threshold, same chunk)
	world.focus_target.position = Vector3(11.5, 30.0, 10.0)
	world._update_streaming()

	# Gating should have skipped update: _last_streaming_position unchanged
	assert_eq(world._last_streaming_position, initial_pos, "Streaming should have been skipped on micro-movement")

	world.free()

func test_streaming_triggers_when_distance_threshold_exceeded() -> void:
	var world = _setup_test_world()

	world._update_streaming()
	var initial_pos = world._last_streaming_position

	# Move focus target 5.0 meters (> 4.0 meters threshold, same chunk 0,0)
	world.focus_target.position = Vector3(15.0, 30.0, 10.0)
	world._update_streaming()

	# Should have evaluated because delta >= 4.0 meters
	assert_ne(world._last_streaming_position, initial_pos, "Streaming should have evaluated after 5m movement")
	assert_eq(world._last_streaming_position, Vector3(15.0, 30.0, 10.0))

	world.free()

func test_streaming_triggers_when_chunk_boundary_crossed() -> void:
	var world = _setup_test_world()

	world._update_streaming()
	assert_eq(world._last_streaming_chunk.x, 0)

	# Cross boundary into chunk 1 (x >= 32.0)
	world.focus_target.position = Vector3(35.0, 30.0, 10.0)
	world._update_streaming()

	assert_eq(world._last_streaming_chunk.x, 1, "Streaming must re-evaluate when crossing chunk boundary")

	world.free()

func test_streaming_triggers_on_force() -> void:
	var world = _setup_test_world()

	world._update_streaming()

	# Micro-movement (0.2 m)
	world.focus_target.position = Vector3(10.2, 30.0, 10.0)

	# Force update must ignore gating
	world._update_streaming(true)
	assert_eq(world._last_streaming_position, Vector3(10.2, 30.0, 10.0), "Forced update must bypass delta gating")

	world.free()
