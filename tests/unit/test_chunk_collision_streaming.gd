class_name TestChunkCollisionStreaming
extends "res://tests/framework/test_case.gd"

func _create_test_mesh_data() -> MeshData:
	var c_size = 8
	var data = SurfaceChunkData.new(c_size)
	data.fill(5, 1, 2)
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	return mesher.build_mesh(data, reg)

func test_chunk_node_collision_toggle() -> void:
	var mesh_data = _create_test_mesh_data()
	var chunk_node = ChunkNode.new()
	var coord = ChunkCoord.new(0, 0)

	# Setup with collision disabled
	chunk_node.setup(coord, Vector3.ZERO, mesh_data, false)
	assert_false(chunk_node.is_collision_enabled(), "Collision should initially be disabled")
	assert_true(chunk_node.collision_shape.disabled, "CollisionShape3D should be disabled")
	assert_null(chunk_node.collision_shape.shape, "Shape should not be allocated yet when disabled")

	# Dynamically enable collision (e.g. player walked close)
	chunk_node.set_collision_enabled(true)
	assert_true(chunk_node.is_collision_enabled(), "Collision should now be enabled")
	assert_false(chunk_node.collision_shape.disabled, "CollisionShape3D should be enabled")
	assert_not_null(chunk_node.collision_shape.shape, "Trimesh shape should have been created")

	# Save shape reference to verify reuse
	var shape_ref = chunk_node.collision_shape.shape

	# Dynamically disable collision (e.g. player moved far away)
	chunk_node.set_collision_enabled(false)
	assert_false(chunk_node.is_collision_enabled(), "Collision should be disabled after leaving range")
	assert_true(chunk_node.collision_shape.disabled, "CollisionShape3D should be disabled")
	assert_eq(chunk_node.collision_shape.shape, shape_ref, "Shape resource should remain cached for reuse")

	# Re-enable: should reuse cached shape without recalculation
	chunk_node.set_collision_enabled(true)
	assert_true(chunk_node.is_collision_enabled(), "Collision should be re-enabled")
	assert_eq(chunk_node.collision_shape.shape, shape_ref, "Cached shape should be reused")

	chunk_node.free()

func test_collision_updates_when_player_moves_past_100_blocks() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.chunk_size = 32
	world.world_config.voxel_size = 1.0
	world.world_config.collision_distance_chunks = 3 # 3 * 32 = 96 blocks
	world.world_config.view_distance_chunks = 8

	world.bounds = world.world_config.create_world_bounds()
	world.generator = ContinentGenerator.new(1337)
	world.mesher = SurfaceShellMesher.new()
	world.material_registry = MaterialRegistry.create_default_registry()

	var mesh_data = _create_test_mesh_data()

	# Create a chunk at spawn (0, 0) and a chunk 4 chunks away (4, 0) -> 128 blocks away (> 100 blocks)
	var spawn_coord = ChunkCoord.new(0, 0)
	var distant_coord = ChunkCoord.new(4, 0)

	var spawn_node = ChunkNode.new()
	var distant_node = ChunkNode.new()

	world._loaded_chunks[spawn_coord.to_key()] = spawn_node
	world._loaded_chunks[distant_coord.to_key()] = distant_node

	# Initially player is at starting point (0, 0, 0)
	var focus_dummy = Node3D.new()
	focus_dummy.position = Vector3(0.0, 10.0, 0.0)
	world.focus_target = focus_dummy

	# Setup chunks as they would be after background meshing finishes while player is at spawn
	var origin_spawn = world.bounds.chunk_origin(spawn_coord)
	var origin_distant = world.bounds.chunk_origin(distant_coord)

	var dist_spawn = spawn_coord.chebyshev_distance_to(spawn_coord) # 0 <= 3 -> true
	var dist_distant = spawn_coord.chebyshev_distance_to(distant_coord) # 4 <= 3 -> false

	spawn_node.setup(spawn_coord, origin_spawn, mesh_data, dist_spawn <= world.world_config.collision_distance_chunks)
	distant_node.setup(distant_coord, origin_distant, mesh_data, dist_distant <= world.world_config.collision_distance_chunks)

	# Verify initial state: spawn chunk has collision, 128m chunk does NOT have collision
	assert_true(spawn_node.is_collision_enabled(), "Spawn chunk must have collision enabled")
	assert_false(distant_node.is_collision_enabled(), "Chunk 4 chunks away must not have collision yet")

	# Now player walks 110 blocks away towards +X (enters chunk 3: x=110, z=0)
	focus_dummy.position = Vector3(110.0, 10.0, 0.0)
	var new_focus_chunk = world.bounds.world_to_chunk(focus_dummy.position)
	assert_eq(new_focus_chunk.x, 3, "Player at x=110 should be in chunk 3")

	# Update collision
	world._update_chunk_collisions()

	# Now distant chunk at (4, 0) is distance 1 from player (3, 0), which is <= 3!
	# Its collision MUST now be enabled, so player stepping on it does not fall into void!
	assert_true(distant_node.is_collision_enabled(), "Distant chunk MUST have collision enabled after player moves > 100 blocks")

	# Spawn chunk at (0, 0) is distance 3 from (3, 0), still within collision window
	assert_true(spawn_node.is_collision_enabled(), "Spawn chunk is still within distance 3")

	# Player walks further to chunk 5 (x=165)
	focus_dummy.position = Vector3(165.0, 10.0, 0.0)
	world._update_chunk_collisions()

	# Distant chunk (4, 0) is distance 1 <= 3 -> still enabled
	assert_true(distant_node.is_collision_enabled(), "Distant chunk remains enabled near player")
	# Spawn chunk (0, 0) is now distance 5 > 3 -> disabled to save physics memory
	assert_false(spawn_node.is_collision_enabled(), "Spawn chunk collision disabled after player moves far away")

	focus_dummy.free()
	spawn_node.free()
	distant_node.free()
	world.free()
