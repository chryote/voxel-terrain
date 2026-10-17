class_name TestVoxelWorldCaves
extends "res://tests/framework/test_case.gd"

func test_voxel_world_volumetric_defaults() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1

	# Calling _ready() initializes defaults
	world._ready()

	assert_not_null(world.generator, "Generator should be initialized")
	assert_true(world.generator is VolumetricTerrainGenerator, "Default generator must be VolumetricTerrainGenerator")

	assert_not_null(world.mesher, "Mesher should be initialized")
	assert_true(world.mesher is VoxelMesher, "Default mesher must be VoxelMesher")

	assert_not_null(world.cave_config, "Cave config must be initialized")

	# Verify initial chunks were created
	assert_true(world.get_loaded_chunk_count() > 0, "Initial spawn chunks must be loaded")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()

func test_voxel_world_chunk_node_geometry_and_collision() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1

	world._ready()

	var spawn_pos = world.get_spawn_point()
	var spawn_chunk = world.bounds.world_to_chunk(spawn_pos)
	var chunk_node = world._loaded_chunks.get(spawn_chunk.to_key(), null) as ChunkNode

	assert_not_null(chunk_node, "Spawn chunk node must exist in loaded chunks")
	assert_not_null(chunk_node.mesh_instance, "ChunkNode must have a MeshInstance3D")
	assert_not_null(chunk_node.mesh_instance.mesh, "MeshInstance3D must have a generated mesh")
	assert_true(chunk_node.mesh_instance.mesh.get_surface_count() > 0, "Generated mesh must have at least 1 surface")

	# Verify collision shape was created
	assert_true(chunk_node.is_collision_enabled(), "Spawn chunk must have collision enabled initially")
	assert_not_null(chunk_node.collision_shape.shape, "ConcavePolygonShape3D collision shape must be present")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()
