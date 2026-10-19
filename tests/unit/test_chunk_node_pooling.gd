class_name TestChunkNodePooling
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

func test_chunk_node_prepare_for_pool() -> void:
	var node = ChunkNode.new()
	var coord = ChunkCoord.new(2, 3)
	var mesh_data = _create_test_mesh_data()
	var baker = OffThreadCollisionBaker.new()
	var shapes = baker.bake_shapes_for_bundle(mesh_data)

	node.setup(coord, Vector3(64, 0, 96), mesh_data, true, shapes.surface_shape, shapes.cave_shape)
	assert_true(node.visible, "Node should be visible when set up")
	assert_not_null(node.mesh_instance.mesh, "Mesh should be present")
	assert_not_null(node.collision_shape.shape, "Collision shape should be bound")
	assert_false(node.collision_shape.disabled, "Collision should be enabled")

	# Prepare for pool
	node.prepare_for_pool()

	assert_null(node.coord, "Coord should be cleared")
	assert_false(node.has_cave_mouth, "Cave mouth flag should be reset")
	assert_false(node.visible, "Node should be hidden when in pool")
	assert_null(node.mesh_instance.mesh, "Mesh instance should be cleared")
	assert_null(node.cave_mesh_instance.mesh, "Cave mesh should be cleared")
	assert_false(node.cave_mesh_instance.visible, "Cave mesh should be hidden")
	assert_null(node.collision_shape.shape, "Collision shape should be cleared")
	assert_true(node.collision_shape.disabled, "Collision shape should be disabled")
	assert_null(node.cave_collision_shape.shape, "Cave collision shape should be cleared")
	assert_true(node.cave_collision_shape.disabled, "Cave collision shape should be disabled")
	assert_null(node._cached_prebaked_surface_shape, "Surface shape cache should be cleared")
	assert_null(node._cached_prebaked_cave_shape, "Cave shape cache should be cleared")

	node.free()

func test_voxel_world_acquires_from_pool_when_available() -> void:
	var world = _setup_test_world()

	# Create a pooled node and push it into the world pool
	var pooled_node = ChunkNode.new()
	world._chunks_root.add_child(pooled_node)
	pooled_node.prepare_for_pool()
	world._chunk_node_pool.push_back(pooled_node)

	assert_eq(world.get_pooled_chunk_count(), 1, "Pool should have 1 node available")

	var coord = ChunkCoord.new(5, 7)
	var acquired = world._acquire_chunk_node(coord)

	assert_eq(acquired, pooled_node, "Acquired node must be the reused instance from the pool")
	assert_eq(world.get_pooled_chunk_count(), 0, "Pool should now be empty")
	assert_eq(acquired.name, "Chunk_5_7", "Acquired node name should be updated")
	assert_true(acquired.visible, "Acquired node should be made visible")

	world.free()

func test_voxel_world_recycles_unloaded_chunks() -> void:
	var world = _setup_test_world()
	var coord = ChunkCoord.new(1, 1)

	# Acquire a chunk node and register as loaded
	var node = world._acquire_chunk_node(coord)
	world._loaded_chunks[coord.to_key()] = node
	assert_eq(world.get_loaded_chunk_count(), 1)
	assert_eq(world.get_pooled_chunk_count(), 0)

	# Recycle the chunk node
	world._recycle_chunk_node(node)
	world._loaded_chunks.erase(coord.to_key())

	assert_eq(world.get_loaded_chunk_count(), 0)
	assert_eq(world.get_pooled_chunk_count(), 1, "Pool must now contain the recycled node")
	assert_false(node.visible, "Recycled node must be hidden")

	# Re-acquiring for a different chunk should reuse the same instance
	var next_coord = ChunkCoord.new(9, 9)
	var reused_node = world._acquire_chunk_node(next_coord)
	assert_eq(reused_node, node, "Pool must reuse the recycled node instance")
	assert_eq(world.get_pooled_chunk_count(), 0)

	world.free()

func test_voxel_world_cleanup_chunk_pool() -> void:
	var world = _setup_test_world()

	for i in range(3):
		var n = ChunkNode.new()
		world._chunks_root.add_child(n)
		n.prepare_for_pool()
		world._chunk_node_pool.push_back(n)

	assert_eq(world.get_pooled_chunk_count(), 3)

	world._cleanup_chunk_pool()
	assert_eq(world.get_pooled_chunk_count(), 0, "Pool should be cleared after cleanup")

	world.free()
