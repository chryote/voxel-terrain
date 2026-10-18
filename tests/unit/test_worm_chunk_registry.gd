class_name TestWormChunkRegistry
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 3: Exact Chunk & Section Rasterizer (WormChunkRegistry).
## Verifies 3D capsule chunk rasterization, 16m vertical section bitmasks,
## ordered descent routes, zero false positives, and segment spatial filtering.

const WormChunkRegistryClass = preload("res://src/generation/caves/worm_chunk_registry.gd")
const WormTrajectoryClass = preload("res://src/generation/caves/worm_trajectory.gd")
const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")

func test_chunk_registration_and_containment() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0) # 16m chunk size
	var traj = WormTrajectoryClass.new(1, Vector3(8.0, 50.0, 8.0), Vector3(40.0, 10.0, 40.0))

	# Trajectory from Chunk (0, 0) to Chunk (2, 2)
	traj.add_waypoint(Vector3(8.0, 50.0, 8.0), 3.0)
	traj.add_waypoint(Vector3(24.0, 30.0, 24.0), 3.5)
	traj.add_waypoint(Vector3(40.0, 10.0, 40.0), 4.0)

	var route = registry.register_trajectory(traj)

	assert_true(route.size() >= 3, "Descent route must contain at least 3 chunks")
	assert_true(registry.has_chunk(ChunkCoord.new(0, 0)), "Chunk (0, 0) must be registered")
	assert_true(registry.has_chunk(ChunkCoord.new(1, 1)), "Chunk (1, 1) must be registered")
	assert_true(registry.has_chunk(ChunkCoord.new(2, 2)), "Chunk (2, 2) must be registered")

	# Distant chunks must be strictly false (0% false positives)
	assert_false(registry.has_chunk(ChunkCoord.new(10, 10)), "Distant chunk (10, 10) must be false")
	assert_false(registry.has_chunk(ChunkCoord.new(-5, -5)), "Distant chunk (-5, -5) must be false")
	assert_false(registry.has_chunk(ChunkCoord.new(0, 5)), "Distant chunk (0, 5) must be false")

func test_exact_voxel_containment_invariant() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0)
	var traj = WormTrajectoryClass.new(1)

	# Diagonal winding corridor
	traj.add_waypoint(Vector3(5.0, 45.0, 5.0), 3.0)
	traj.add_waypoint(Vector3(25.0, 35.0, 15.0), 3.5)
	traj.add_waypoint(Vector3(35.0, 25.0, 35.0), 3.5)
	traj.add_waypoint(Vector3(55.0, 15.0, 55.0), 4.0)

	registry.register_trajectory(traj)

	# Every single sample along the trajectory spine MUST map to a registered chunk
	var sample_dist = 0.0
	while sample_dist <= traj.total_length:
		var pt = traj.sample_point_at_distance(sample_dist)
		var c = registry.world_to_chunk(pt)
		assert_true(registry.has_chunk(c), "Spine point at dist %f (%v) must map to registered chunk (%d, %d)" % [sample_dist, pt, c.x, c.z])
		sample_dist += 2.0

func test_vertical_section_bitmask() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0)
	var traj = WormTrajectoryClass.new(1)

	# Confined strictly to Chunk (0, 0) [X=0..16, Z=0..16]
	# Elevation spans Y=20.0 to Y=38.0 (Section 1: Y=16..32, Section 2: Y=32..48)
	traj.add_waypoint(Vector3(8.0, 38.0, 8.0), 2.0)
	traj.add_waypoint(Vector3(8.0, 20.0, 8.0), 2.0)

	registry.register_trajectory(traj)
	var coord = ChunkCoord.new(0, 0)

	# Section 1 (Y=16..32) and Section 2 (Y=32..48) must be active
	assert_true(registry.is_section_active(coord, 1), "Section 1 (16..32m) must be active")
	assert_true(registry.is_section_active(coord, 2), "Section 2 (32..48m) must be active")

	# Section 0 (Y=0..16) must be INACTIVE because Y_min is 20.0 - 2.0 = 18.0 > 16.0
	assert_false(registry.is_section_active(coord, 0), "Section 0 (0..16m) must be inactive")

	# Higher sections (Y >= 48) must be INACTIVE
	assert_false(registry.is_section_active(coord, 3), "Section 3 (48..64m) must be inactive")
	assert_false(registry.is_section_active(coord, 4), "Section 4 (64..80m) must be inactive")

	var active_indices = registry.get_active_section_indices(coord)
	assert_eq(active_indices.size(), 2, "Exactly 2 sections must be active")
	assert_true(active_indices.has(1), "Active indices must contain 1")
	assert_true(active_indices.has(2), "Active indices must contain 2")

func test_ordered_descent_route() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0)
	var traj = WormTrajectoryClass.new(10)

	var start_p = Vector3(8.0, 60.0, 8.0) # In Chunk (0, 0)
	var end_p = Vector3(56.0, 10.0, 56.0)  # In Chunk (3, 3)

	traj.add_waypoint(start_p, 3.5)
	traj.add_waypoint(Vector3(24.0, 45.0, 24.0), 3.5)
	traj.add_waypoint(Vector3(40.0, 28.0, 40.0), 3.5)
	traj.add_waypoint(end_p, 3.5)

	registry.register_trajectory(traj)
	var route = registry.get_corridor_route(10)

	assert_true(route.size() >= 4, "Route must contain multiple sequential chunks")

	# First chunk must be entrance chunk (0, 0)
	assert_eq(route[0].x, 0, "First chunk X must be 0")
	assert_eq(route[0].z, 0, "First chunk Z must be 0")

	# Last chunk must be destination chunk (3, 3)
	var last_c = route[route.size() - 1]
	assert_eq(last_c.x, 3, "Last chunk X must be 3")
	assert_eq(last_c.z, 3, "Last chunk Z must be 3")

	# Verify continuous adjacency: each chunk must be Chebyshev distance <= 1 from predecessor
	for i in range(1, route.size()):
		var prev = route[i - 1]
		var curr = route[i]
		var dx = absi(curr.x - prev.x)
		var dz = absi(curr.z - prev.z)
		assert_true(maxi(dx, dz) <= 1, "Sequential chunks in descent route must be adjacent neighbors")

func test_multiple_trajectories_coexistence() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0)

	# Corridor 1 near origin
	var traj1 = WormTrajectoryClass.new(1)
	traj1.add_waypoint(Vector3(8, 40, 8), 3.0)
	traj1.add_waypoint(Vector3(24, 10, 24), 3.0)
	registry.register_trajectory(traj1)

	# Corridor 2 in negative quadrant
	var traj2 = WormTrajectoryClass.new(2)
	traj2.add_waypoint(Vector3(-24, 40, -24), 3.0)
	traj2.add_waypoint(Vector3(-40, 10, -40), 3.0)
	registry.register_trajectory(traj2)

	assert_true(registry.has_chunk(ChunkCoord.new(0, 0)), "Corridor 1 start chunk must be registered")
	assert_true(registry.has_chunk(ChunkCoord.new(1, 1)), "Corridor 1 end chunk must be registered")

	assert_true(registry.has_chunk(ChunkCoord.new(-2, -2)), "Corridor 2 start chunk must be registered")
	assert_true(registry.has_chunk(ChunkCoord.new(-3, -3)), "Corridor 2 end chunk must be registered")

	var route1 = registry.get_corridor_route(1)
	var route2 = registry.get_corridor_route(2)
	assert_true(route1.size() >= 2, "Route 1 must be registered")
	assert_true(route2.size() >= 2, "Route 2 must be registered")
	assert_false(route1[0].equals(route2[0]), "Routes must be distinct")

func test_segments_per_chunk_filtering() -> void:
	var registry = WormChunkRegistryClass.new(16, 1.0, 16.0)
	var traj = WormTrajectoryClass.new(1)

	# Segment 0: inside Chunk (0, 0) [X=2..12, Z=8]
	# Segment 1: transitions from Chunk (0, 0) to Chunk (2, 0) [X=12..36, Z=8]
	traj.add_waypoint(Vector3(2.0, 30.0, 8.0), 2.0)
	traj.add_waypoint(Vector3(12.0, 30.0, 8.0), 2.0)
	traj.add_waypoint(Vector3(40.0, 30.0, 8.0), 2.0)

	registry.register_trajectory(traj)

	# Chunk (0, 0) contains Segment 0 and Segment 1
	var segs_c0 = registry.get_segments_for_chunk(ChunkCoord.new(0, 0))
	assert_eq(segs_c0.size(), 2, "Chunk (0, 0) must contain both segments")

	# Chunk (2, 0) [X=32..48] contains ONLY Segment 1
	var segs_c2 = registry.get_segments_for_chunk(ChunkCoord.new(2, 0))
	assert_eq(segs_c2.size(), 1, "Chunk (2, 0) must contain only segment 1")
	assert_eq(segs_c2[0], traj.get_segment(1), "Segment in Chunk (2, 0) must be segment 1")
