class_name TestWormPipelineOptimization
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 5: Generator & Streaming Pipeline Optimization.
## Verifies:
## 1. Instantaneous 2.5D bypass in LayeredTerrainGenerator for non-corridor chunks.
## 2. Vertical 3D voxel allocation tightening to active sections in corridor chunks.
## 3. Sequential corridor descent route pre-streaming in SubterraneanStreamCoordinator.

const LayeredTerrainGeneratorClass = preload("res://src/generation/layered_terrain_generator.gd")
const SubterraneanStreamCoordinatorClass = preload("res://src/streaming/subterranean_stream_coordinator.gd")
const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const WorldBoundsClass = preload("res://src/core/world_bounds.gd")
const VoxelChunkDataClass = preload("res://src/core/voxel_chunk_data.gd")
const ChasmChunkDataClass = preload("res://src/core/chasm_chunk_data.gd")

func test_instantaneous_bypass_for_non_corridor_chunks() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(16, 16), 16, 1.0)
	var config = CaveGeneratorConfigClass.new()
	var gen = LayeredTerrainGeneratorClass.new(1337, null, config)
	gen._mouths_initialized = true # Prevent automatic continent detection from overwriting test mouth

	# Register a single corridor at (3, 3)
	var mouth = CaveMouthDataClass.new(
		Vector3(48.0, 40.0, 48.0),
		Vector2(48.0, 48.0),
		CaveMouthDataClass.Type.TUNNEL,
		10.0,
		7.0,
		40.0
	)
	gen.cave_carver.set_allowed_mouths([mouth])

	# Non-corridor chunk at (10, 10) far away from mouth
	var non_corridor_coord = ChunkCoord.new(10, 10)
	assert_false(gen.cave_carver.worm_registry.has_chunk(non_corridor_coord), "Chunk (10, 10) must not be registered")

	var s_data = gen.generate_surface(non_corridor_coord, bounds)
	var sub_data = gen.generate_subterranean(s_data, non_corridor_coord, bounds)

	# Non-corridor chunk must bypass 3D voxel array and return ChasmChunkData
	assert_not_null(sub_data, "Subterranean data must exist")
	assert_true(sub_data is ChasmChunkDataClass, "Non-corridor chunk must bypass 3D voxelization to 2.5D ChasmChunkData")

func test_vertical_allocation_tightened_to_active_sections() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(16, 16), 16, 1.0)
	var config = CaveGeneratorConfigClass.new()
	config.bypass_chasm_voxelization = false # Ensure chunk generates as VoxelChunkData
	var gen = LayeredTerrainGeneratorClass.new(1337, null, config)
	gen._mouths_initialized = true # Prevent continent detection from overwriting test mouth

	# Synthesize a multi-chunk trajectory from (0, 35, 0) to (60, 15, 60)
	var traj = gen.cave_carver.worm_generator.generate_trajectory_between_anchors(
		Vector3(0.0, 35.0, 0.0),
		Vector3(60.0, 15.0, 60.0),
		0,
		4.0,
		3.8
	)
	var route = gen.cave_carver.worm_registry.register_trajectory(traj)
	assert_true(route.size() >= 3, "Corridor route must have multiple descent chunks")

	var reg = gen.cave_carver.worm_registry

	# Pick a descent chunk that does NOT have the mouth entrance itself (route[1])
	var tunnel_chunk = route[1]
	assert_true(reg.has_chunk(tunnel_chunk), "Descent chunk must be in worm registry")

	var s_data = gen.generate_surface(tunnel_chunk, bounds)
	# Force has_cave_mouth to false on this intermediate corridor chunk
	s_data.has_cave_mouth = false

	var v_data = gen.generate_subterranean(s_data, tunnel_chunk, bounds) as VoxelChunkDataClass
	assert_not_null(v_data, "Voxel chunk data must be generated")

	# Check active section mask
	var mask = reg.get_active_section_mask(tunnel_chunk)
	assert_true(mask > 0, "Corridor chunk must have non-zero section mask")

	# Calculate expected tightened max_height
	var highest_section = 0
	var temp = mask
	var bit = 0
	while temp > 0:
		if (temp & 1) != 0:
			highest_section = bit
		temp = temp >> 1
		bit += 1
	var tunnel_top = (highest_section + 1) * int(reg.section_height)
	var chasm_top = maxi(config.chasm_max_y + 4, config.arena_ceiling_y)
	var expected_needed = ceili(float(maxi(tunnel_top, chasm_top) + 2) / 16.0) * 16

	# VoxelChunkData max_height must be tightened and not wastefully allocate full height
	assert_true(v_data.max_height <= expected_needed, "Allocated max_height (%d) must be tightened to needed strata (<= %d)" % [v_data.max_height, expected_needed])
	assert_true(v_data.max_height < 160, "Must be substantially less than full 160m ceiling")

func test_coordinator_corridor_route_sequential_promotion() -> void:
	var bounds = WorldBoundsClass.new(Vector2i(16, 16), 16, 1.0)
	var config = CaveGeneratorConfigClass.new()
	var carver = preload("res://src/generation/caves/cave_carver.gd").new(1337, config)

	# Generate a trajectory from (0, 50, 0) in Chunk (0, 0) to (64, 15, 64) in Chunk (4, 4)
	var traj = carver.worm_generator.generate_trajectory_between_anchors(
		Vector3(0.0, 50.0, 0.0),
		Vector3(64.0, 15.0, 64.0),
		0,
		4.5,
		3.8
	)
	var route = carver.worm_registry.register_trajectory(traj)
	assert_true(route.size() >= 3, "Corridor route must have at least 3 descent chunks for tiering test")

	var reg = carver.worm_registry
	var c_mouth = route[0]
	var c_step1 = route[1]
	var c_step2 = route[2]

	var coord = SubterraneanStreamCoordinatorClass.new()
	coord.worm_registry = reg

	# Register surface chunks along route and peripheral chunks
	for c in route:
		coord.register_surface_chunk(c, c.equals(c_mouth))

	var c_peripheral = ChunkCoord.new(c_mouth.x + 2, c_mouth.z + 2)
	coord.register_surface_chunk(c_peripheral, false)

	var mouth_cache = {
		c_mouth.to_key(): true,
		c_step1.to_key(): false,
		c_step2.to_key(): false,
		c_peripheral.to_key(): false
	}

	# Player approaching cave mouth (standing at c_mouth, on surface Y=45)
	var player_pos = Vector3(float(c_mouth.x * 16) + 8.0, 45.0, float(c_mouth.z * 16) + 8.0)
	var tiers = coord.get_tiered_chunks_to_promote(player_pos, c_mouth, 45.0, mouth_cache)

	var tier1 = tiers["tier1"]
	var tier2 = tiers["tier2"]
	var tier3 = tiers["tier3"]

	# Route chunk 0 (mouth) and route chunk 1 (first descent step) must be in Tier 1 (Immediate)
	var has_mouth_t1 = false
	var has_step1_t1 = false
	for c in tier1:
		if c.equals(c_mouth):
			has_mouth_t1 = true
		if c.equals(c_step1):
			has_step1_t1 = true

	assert_true(has_mouth_t1, "Mouth chunk must be in Tier 1")
	assert_true(has_step1_t1, "First descent chunk along corridor route must be in Tier 1")

	# Route chunk 2 (deeper corridor descent) must be in Tier 2 (Pre-stream)
	var has_step2_t2 = false
	for c in tier2:
		if c.equals(c_step2):
			has_step2_t2 = true

	assert_true(has_step2_t2, "Subsequent corridor descent chunks must be pre-streamed in Tier 2")

	# Peripheral non-corridor chunk must not be in Tier 1
	for c in tier1:
		assert_false(c.equals(c_peripheral), "Peripheral non-corridor chunk must not be in Tier 1")

func test_coordinator_fallback_when_worm_registry_null() -> void:
	var coord = SubterraneanStreamCoordinatorClass.new()
	coord.worm_registry = null # Null registry fallback

	var focus_chunk = ChunkCoord.new(0, 0)
	var c_mouth = ChunkCoord.new(0, 0)
	var c_neighbor = ChunkCoord.new(1, 0)

	coord.register_surface_chunk(c_mouth, true)
	coord.register_surface_chunk(c_neighbor, false)

	var mouth_cache = {
		c_mouth.to_key(): true,
		c_neighbor.to_key(): false
	}

	var tiers = coord.get_tiered_chunks_to_promote(Vector3(0, 50, 0), focus_chunk, 50.0, mouth_cache)
	assert_true(tiers["tier1"].size() > 0, "Fallback must still promote mouth chunk in Tier 1")
	assert_eq(tiers["tier1"][0].x, 0, "Tier 1 chunk must be mouth chunk")
