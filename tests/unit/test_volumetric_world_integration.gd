class_name TestVolumetricWorldIntegration
extends "res://tests/framework/test_case.gd"

func test_voxel_world_3d_mode_instantiation() -> void:
	var world = VoxelWorld.new()
	world.use_3d_terrain = true
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(16, 16)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 2
	world.world_config.collision_distance_chunks = 1

	var vol_config = VolumetricGeneratorConfig.new()
	vol_config.chunk_height = 64
	vol_config.coast_falloff_distance = 50.0 # Small falloff for 16x16 test map
	world.generator_config = vol_config

	var focus_dummy = Node3D.new()
	world.focus_target = focus_dummy
	world.add_child(focus_dummy)

	# Run _ready()
	world._ready()

	assert_true(world.generator is VolumetricContinentGenerator, "Generator must be VolumetricContinentGenerator in 3D mode")
	assert_true(world.mesher is VoxelMesher3D, "Mesher must be VoxelMesher3D in 3D mode")
	assert_true(world.get_loaded_chunk_count() >= 9, "Initial 3x3 spawn chunks must be loaded")

	focus_dummy.free()
	world.free()

func test_spawn_point_safety_in_3d_terrain() -> void:
	var world = VoxelWorld.new()
	world.use_3d_terrain = true
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(16, 16)
	world.world_config.chunk_size = 16

	var vol_config = VolumetricGeneratorConfig.new()
	vol_config.chunk_height = 64
	vol_config.coast_falloff_distance = 50.0
	world.generator_config = vol_config

	var focus_dummy = Node3D.new()
	world.focus_target = focus_dummy
	world.add_child(focus_dummy)

	world._ready()

	var spawn = world.get_spawn_point()
	var ground_h = world.get_height_at(spawn.x, spawn.z)

	# Spawn Y must be above ground height (+1 block) and above water plane
	assert_true(spawn.y > float(world.world_config.sea_level) * world.world_config.voxel_size,
		"Spawn point must be above sea level")
	assert_true(spawn.y >= ground_h, "Spawn point must be above or at ground height")

	focus_dummy.free()
	world.free()

func test_3d_chunk_collision_trimesh_shape() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 16, 1.0)
	var config = VolumetricGeneratorConfig.new()
	config.chunk_height = 64
	var gen = VolumetricContinentGenerator.new(1337, config)
	var mesher = VoxelMesher3D.new()
	var reg = MaterialRegistry.create_default_registry()

	var coord = ChunkCoord.new(0, 0)
	var chunk_data = gen.generate(coord, bounds)
	var mesh_data = mesher.build_mesh(chunk_data, reg)

	var chunk_node = ChunkNode.new()
	chunk_node.setup(coord, Vector3.ZERO, mesh_data, true)

	assert_true(chunk_node.is_collision_enabled(), "Collision should be enabled on 3D chunk node")
	assert_not_null(chunk_node.collision_shape.shape, "ConcavePolygonShape3D must be created from 3D mesh")
	assert_true(chunk_node.collision_shape.shape is ConcavePolygonShape3D, "Shape must be ConcavePolygonShape3D")

	chunk_node.free()
