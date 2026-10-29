class_name TestFoliageChunkIntegration
extends "res://tests/framework/test_case.gd"

## Integration tests validating ChunkNode foliage pooling, MultiMeshInstance3D, and distance gating.

const ChunkNodeClass = preload("res://src/world/chunk_node.gd")
const FoliageChunkDataClass = preload("res://src/core/foliage_chunk_data.gd")
const FoliageConfigClass = preload("res://src/generation/foliage_generator_config.gd")
const FoliageGeneratorClass = preload("res://src/generation/foliage_generator.gd")

func _create_sample_foliage_data() -> FoliageChunkData:
	var gen = FoliageGeneratorClass.new()
	var coord = ChunkCoord.new(0, 0)
	var s_data = SurfaceChunkData.new(8, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var cfg = FoliageConfigClass.new()
	cfg.density_probability = 1.0
	return gen.generate(coord, s_data, cfg)

func test_chunk_node_instantiates_pooled_multimesh() -> void:
	var node = ChunkNodeClass.new()
	node._ensure_nodes_exist()

	assert_not_null(node.grass_instance, "ChunkNode must possess a grass_instance MultiMeshInstance3D")
	assert_not_null(node.grass_instance.multimesh, "grass_instance must have MultiMesh allocated")
	assert_eq(node.grass_instance.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Foliage must have shadows disabled")
	assert_false(node.grass_instance.visible, "Foliage should start hidden until setup")
	node.free()

func test_chunk_node_setup_and_distance_gating() -> void:
	var node = ChunkNodeClass.new()
	var coord = ChunkCoord.new(1, 1)
	var mesh_data = MeshData.new()
	mesh_data.vertices = PackedVector3Array([Vector3(0, 20, 0), Vector3(1, 20, 0), Vector3(0, 20, 1)])
	mesh_data.indices = PackedInt32Array([0, 1, 2])
	mesh_data.foliage_data = _create_sample_foliage_data()

	# 1. Setup with foliage enabled (near camera)
	node.setup(coord, Vector3.ZERO, mesh_data, true, null, null, true)
	assert_true(node.is_foliage_enabled(), "Foliage should be active when distance enabled")
	assert_true(node.grass_instance.multimesh.instance_count > 0, "MultiMesh instance count should match foliage data")
	assert_true(node.grass_instance.visible, "MultiMeshInstance3D should be visible")

	# 2. Gate foliage off (moved to distant horizon)
	node.set_foliage_enabled(false)
	assert_false(node.is_foliage_enabled(), "Foliage should be disabled when distance gating triggers")
	assert_false(node.grass_instance.visible, "MultiMeshInstance3D must be hidden when gated off")

	# 3. Gate foliage back on (player approaches)
	node.set_foliage_enabled(true)
	assert_true(node.is_foliage_enabled(), "Foliage should be restored when player enters distance")
	assert_true(node.grass_instance.visible, "MultiMeshInstance3D must become visible again")

	node.free()

func test_chunk_node_prepare_for_pool_resets_foliage() -> void:
	var node = ChunkNodeClass.new()
	var coord = ChunkCoord.new(2, 2)
	var mesh_data = MeshData.new()
	mesh_data.vertices = PackedVector3Array([Vector3(0, 10, 0), Vector3(1, 10, 0), Vector3(0, 10, 1)])
	mesh_data.indices = PackedInt32Array([0, 1, 2])
	mesh_data.foliage_data = _create_sample_foliage_data()

	node.setup(coord, Vector3.ZERO, mesh_data, true, null, null, true)
	assert_true(node.grass_instance.visible, "Foliage should be visible after setup")

	# Recycle into pool
	node.prepare_for_pool()
	assert_false(node.grass_instance.visible, "Foliage MultiMeshInstance3D must be hidden in pool")
	assert_eq(node.grass_instance.multimesh.instance_count, 0, "MultiMesh instance count must reset to 0 in pool")
	assert_false(node.is_foliage_enabled(), "is_foliage_enabled() must return false in pool")

	node.free()

func test_scheduler_surface_pipeline_populates_foliage() -> void:
	var scheduler = ChunkScheduler.new()
	scheduler.foliage_enabled = true
	var coord = ChunkCoord.new(0, 0)
	var bounds = WorldBounds.new(Vector2i(10, 10))
	var s_data = SurfaceChunkData.new(8, 2)
	s_data.fill(20, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	# Mock generator returning s_data
	var reg = MaterialRegistry.create_default_registry()
	var mesher = SurfaceShellMesher.new()
	var gen = ContinentGenerator.new(1337)

	scheduler.schedule_surface_chunk(coord, bounds, gen, mesher, reg, true)
	var completed = scheduler.poll_completed(1)
	while completed.is_empty():
		OS.delay_msec(5)
		completed = scheduler.poll_completed(1)

	assert_eq(completed.size(), 1, "Completed result must be retrieved")
	var result = completed[0]
	var m_data = result.mesh_data
	assert_not_null(m_data, "Mesh data must be produced")
	assert_not_null(m_data.foliage_data, "Foliage data must be generated in surface pipeline")
	scheduler.clear()

func test_voxel_world_foliage_lifecycle() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.foliage_enabled = true
	world.foliage_distance_chunks = 1

	world._ready()

	var spawn_pos = world.get_spawn_point()
	var spawn_chunk = world.bounds.world_to_chunk(spawn_pos)
	var chunk_node = world._loaded_chunks.get(spawn_chunk.to_key(), null) as ChunkNode

	assert_not_null(chunk_node, "Spawn chunk node must exist in loaded chunks")
	assert_true(chunk_node.is_foliage_enabled(), "Foliage should be enabled on spawn chunk")
	assert_not_null(chunk_node.grass_instance, "Spawn chunk must have grass_instance")
	assert_not_null(chunk_node.grass_instance.multimesh, "grass_instance must have multimesh")

	# Test toggling foliage off globally
	world.foliage_enabled = false
	assert_false(chunk_node.is_foliage_enabled(), "Foliage should be disabled globally when flag is false")
	assert_false(chunk_node.grass_instance.visible, "grass_instance should be hidden when foliage is disabled")

	# Test toggling foliage back on globally
	world.foliage_enabled = true
	assert_true(chunk_node.is_foliage_enabled(), "Foliage should be re-enabled globally when flag is true")
	assert_true(chunk_node.grass_instance.visible, "grass_instance should be visible when foliage is enabled")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()
func test_chunk_node_lod_detail_transition() -> void:
	var node = ChunkNodeClass.new()
	var coord = ChunkCoord.new(0, 0)
	var mesh_data = MeshData.new()
	mesh_data.vertices = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	mesh_data.indices = PackedInt32Array([0, 1, 2])
	mesh_data.foliage_data = _create_sample_foliage_data()
	var total_instances = mesh_data.foliage_data.instance_count

	# 1. Setup in near high-detail tier (dist <= 2)
	node.setup(coord, Vector3.ZERO, mesh_data, true, null, null, true, false)
	assert_true(node.is_foliage_enabled(), "Foliage must be enabled")
	assert_false(node.is_foliage_low_detail(), "Foliage must be in high-detail tier")
	assert_eq(node.grass_instance.multimesh.mesh, ChunkNodeClass.get_shared_grass_mesh(), "Must use high-detail 3-quad mesh")
	assert_eq(node.grass_instance.multimesh.visible_instance_count, -1, "High-detail must draw all instances")

	# 2. Transition past 2 chunks into lowest-detail LOD tier (dist > 2)
	node.set_foliage_enabled(true, true)
	assert_true(node.is_foliage_enabled(), "Foliage must remain enabled in LOD tier")
	assert_true(node.is_foliage_low_detail(), "Foliage must report low-detail tier")
	assert_eq(node.grass_instance.multimesh.mesh, ChunkNodeClass.get_shared_grass_mesh_lod(), "Must switch to lowest-detail 1-quad LOD mesh")
	var expected_lod_count = maxi(1, int(float(total_instances) * ChunkNodeClass.get_shared_lod_density()))
	assert_eq(node.grass_instance.multimesh.visible_instance_count, expected_lod_count, "LOD tier must subsample instance count")

	# 3. Transition past max distance (dist > 4) -> disabled
	node.set_foliage_enabled(false, true)
	assert_false(node.is_foliage_enabled(), "Foliage must be disabled past max distance")
	assert_false(node.grass_instance.visible, "grass_instance must be hidden")

	# 4. Transition back to near camera (dist <= 2) -> full detail restored
	node.set_foliage_enabled(true, false)
	assert_true(node.is_foliage_enabled(), "Foliage must re-enable")
	assert_false(node.is_foliage_low_detail(), "High-detail restored")
	assert_eq(node.grass_instance.multimesh.mesh, ChunkNodeClass.get_shared_grass_mesh(), "High-detail mesh restored")
	assert_eq(node.grass_instance.multimesh.visible_instance_count, -1, "Full instance count restored")

	# 5. Recycling into pool cleans up detail states
	node.prepare_for_pool()
	assert_false(node.is_foliage_low_detail(), "Pool reset must clear low-detail flag")
	assert_eq(node.grass_instance.multimesh.visible_instance_count, -1, "Pool reset must clear visible_instance_count")
	node.free()

func test_voxel_world_foliage_lod_distance_tiers() -> void:
	var world = VoxelWorld.new()
	world.world_config = WorldConfig.new()
	world.world_config.map_size_chunks = Vector2i(256, 256)
	world.world_config.chunk_size = 16
	world.world_config.view_distance_chunks = 0
	world.world_config.collision_distance_chunks = 1
	world.foliage_enabled = true
	# Near tier: dist 0; Lowest detail tier: dist 1
	world.foliage_distance_chunks = 0
	world.foliage_max_distance_chunks = 1
	world.foliage_lod_density = 0.25

	world._ready()

	var spawn_pos = world.get_spawn_point()
	var spawn_chunk = world.bounds.world_to_chunk(spawn_pos)

	for key in world._loaded_chunks.keys():
		var node = world._loaded_chunks[key]
		if node is ChunkNode:
			var dist = spawn_chunk.chebyshev_distance_to(node.coord)
			if dist == 0:
				# Spawn chunk itself is in high-detail tier (dist <= 0)
				assert_true(node.is_foliage_enabled(), "Center chunk must have foliage enabled")
				assert_false(node.is_foliage_low_detail(), "Center chunk must be high detail")
			elif dist == 1:
				# Neighbor chunks are past 0 chunks, so they must render with lowest detail
				assert_true(node.is_foliage_enabled(), "Neighbor chunk within max distance must have foliage enabled")
				assert_true(node.is_foliage_low_detail(), "Neighbor chunk past near distance must render with lowest detail")
				assert_eq(node.grass_instance.multimesh.mesh, ChunkNodeClass.get_shared_grass_mesh_lod(), "Must use LOD mesh")

	if world.scheduler != null:
		world.scheduler.clear()
	world.free()
