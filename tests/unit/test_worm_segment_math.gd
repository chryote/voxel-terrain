class_name TestWormSegmentMath
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 1: Core Mathematical Spline & Segment Classes.
## Verifies 3D line segment distance, projection factors, tapered radius interpolation,
## capsule-AABB intersection math, and multi-segment trajectory management.

const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")
const WormTrajectoryClass = preload("res://src/generation/caves/worm_trajectory.gd")

func test_segment_initialization_and_properties() -> void:
	var start = Vector3(10.0, 20.0, 30.0)
	var end = Vector3(10.0, 20.0, 40.0) # Length 10 along +Z
	var seg = WormCorridorSegmentClass.new(start, end, 3.0, 5.0, 0.5)

	assert_eq(seg.start_pos, start, "Start pos must match")
	assert_eq(seg.end_pos, end, "End pos must match")
	assert_almost_eq(seg.length, 10.0, 0.001, "Length must be 10.0")
	assert_almost_eq(seg.direction.z, 1.0, 0.001, "Direction must be +Z")
	assert_almost_eq(seg.start_radius, 3.0, 0.001, "Start radius must match")
	assert_almost_eq(seg.end_radius, 5.0, 0.001, "End radius must match")
	assert_almost_eq(seg.max_radius, 5.0, 0.001, "Max radius must be 5.0")

	# Check AABB contains both end spheres plus margin
	assert_true(seg.aabb.has_point(start), "AABB must enclose start pos")
	assert_true(seg.aabb.has_point(end), "AABB must enclose end pos")
	assert_true(seg.aabb.has_point(start + Vector3(3.0, 0, 0)), "AABB must enclose start radius sphere")
	assert_true(seg.aabb.has_point(end + Vector3(5.0, 0, 0)), "AABB must enclose end radius sphere")

func test_degenerate_zero_length_segment() -> void:
	var p = Vector3(5.0, 5.0, 5.0)
	var seg = WormCorridorSegmentClass.new(p, p, 3.0, 3.0)

	assert_almost_eq(seg.length, 0.0, 0.001, "Degenerate segment must have length 0.0")
	assert_almost_eq(seg.get_projection_factor(Vector3(10.0, 10.0, 10.0)), 0.0, 0.001, "Projection on degenerate segment must be 0.0")
	assert_almost_eq(seg.distance_to_point(Vector3(5.0, 8.0, 5.0)), 3.0, 0.001, "Distance to degenerate segment must be point distance")

func test_point_projection_and_distance() -> void:
	var start = Vector3(0.0, 0.0, 0.0)
	var end = Vector3(10.0, 0.0, 0.0) # Length 10 along +X
	var seg = WormCorridorSegmentClass.new(start, end, 3.0, 3.0)

	# 1. Point at midpoint (5, 0, 0)
	assert_almost_eq(seg.get_projection_factor(Vector3(5.0, 0.0, 0.0)), 0.5, 0.001, "Midpoint projection must be 0.5")
	assert_almost_eq(seg.distance_to_point(Vector3(5.0, 0.0, 0.0)), 0.0, 0.001, "Distance to point on line must be 0.0")

	# 2. Point perpendicular to midpoint at (5, 4, 0)
	assert_almost_eq(seg.get_projection_factor(Vector3(5.0, 4.0, 0.0)), 0.5, 0.001, "Perpendicular point must project to 0.5")
	assert_almost_eq(seg.distance_to_point(Vector3(5.0, 4.0, 0.0)), 4.0, 0.001, "Distance to (5,4,0) must be 4.0")

	# 3. Point clamped before start at (-5, 3, 0)
	assert_almost_eq(seg.get_projection_factor(Vector3(-5.0, 3.0, 0.0)), 0.0, 0.001, "Point before start must clamp to 0.0")
	assert_almost_eq(seg.distance_to_point(Vector3(-4.0, 3.0, 0.0)), 5.0, 0.001, "Distance to (-4,3,0) from (0,0,0) must be 5.0")

	# 4. Point clamped after end at (14, 3, 0)
	assert_almost_eq(seg.get_projection_factor(Vector3(14.0, 3.0, 0.0)), 1.0, 0.001, "Point after end must clamp to 1.0")
	assert_almost_eq(seg.distance_to_point(Vector3(14.0, 3.0, 0.0)), 5.0, 0.001, "Distance to (14,3,0) from (10,0,0) must be 5.0")

func test_radius_interpolation_and_surface_distance() -> void:
	var start = Vector3(0.0, 0.0, 0.0)
	var end = Vector3(10.0, 0.0, 0.0)
	var seg = WormCorridorSegmentClass.new(start, end, 2.0, 6.0) # Radius tapers 2.0 -> 6.0

	# Interpolation along axis
	assert_almost_eq(seg.get_interpolated_radius(Vector3(0.0, 0.0, 0.0)), 2.0, 0.001, "Start radius must be 2.0")
	assert_almost_eq(seg.get_interpolated_radius(Vector3(5.0, 0.0, 0.0)), 4.0, 0.001, "Mid radius must be 4.0")
	assert_almost_eq(seg.get_interpolated_radius(Vector3(10.0, 0.0, 0.0)), 6.0, 0.001, "End radius must be 6.0")

	# Distance to surface at midpoint (where radius = 4.0):
	# Point inside void at (5, 2, 0) -> dist = 2, radius = 4 -> signed dist = 2 - 4 = -2.0
	assert_almost_eq(seg.distance_to_surface(Vector3(5.0, 2.0, 0.0)), -2.0, 0.001, "Inside tunnel must have negative surface distance")

	# Point on perimeter at (5, 4, 0) -> dist = 4, radius = 4 -> signed dist = 0.0
	assert_almost_eq(seg.distance_to_surface(Vector3(5.0, 4.0, 0.0)), 0.0, 0.001, "Perimeter must have 0 surface distance")

	# Point outside in solid rock at (5, 7, 0) -> dist = 7, radius = 4 -> signed dist = +3.0
	assert_almost_eq(seg.distance_to_surface(Vector3(5.0, 7.0, 0.0)), 3.0, 0.001, "Outside tunnel must have positive surface distance")

func test_segment_aabb_intersection() -> void:
	var start = Vector3(0.0, 10.0, 0.0)
	var end = Vector3(20.0, 10.0, 0.0) # Along +X at Y=10
	var seg = WormCorridorSegmentClass.new(start, end, 3.0, 3.0)

	# 1. AABB directly intersecting the segment centerline
	var box_center = AABB(Vector3(5.0, 8.0, -2.0), Vector3(4.0, 4.0, 4.0))
	assert_true(seg.intersects_aabb(box_center), "Box enclosing part of centerline must intersect")

	# 2. AABB distant from segment
	var box_far = AABB(Vector3(50.0, 50.0, 50.0), Vector3(10.0, 10.0, 10.0))
	assert_false(seg.intersects_aabb(box_far), "Distant box must not intersect")

	# 3. AABB touching the tunnel radius envelope (e.g., at Y=12.5, radius=3.0 reaches Y=13.0)
	var box_touch = AABB(Vector3(10.0, 12.0, -1.0), Vector3(2.0, 2.0, 2.0))
	assert_true(seg.intersects_aabb(box_touch), "Box touching tunnel radius envelope must intersect")

	# 4. AABB outside tunnel radius (at Y=14.5, radius=3.0 only reaches Y=13.0)
	var box_miss = AABB(Vector3(10.0, 14.5, -1.0), Vector3(2.0, 2.0, 2.0))
	assert_false(seg.intersects_aabb(box_miss), "Box outside tunnel radius must not intersect")

func test_trajectory_construction_and_continuity() -> void:
	var traj = WormTrajectoryClass.new(1, Vector3(0, 50, 0), Vector3(100, 10, 100))

	# Add 4 sequential waypoints forming 3 contiguous segments
	traj.add_waypoint(Vector3(0.0, 50.0, 0.0), 3.0)
	traj.add_waypoint(Vector3(20.0, 40.0, 0.0), 3.5)
	traj.add_waypoint(Vector3(50.0, 25.0, 0.0), 4.0)
	traj.add_waypoint(Vector3(80.0, 10.0, 0.0), 4.5)

	assert_eq(traj.get_segment_count(), 3, "4 waypoints must generate 3 segments")
	assert_eq(traj.waypoints.size(), 4, "Must contain 4 waypoints")
	assert_eq(traj.radii.size(), 4, "Must contain 4 radii")

	# Verify continuous connectivity: end of segment i must equal start of segment i+1
	for i in range(traj.get_segment_count() - 1):
		var seg_a = traj.get_segment(i)
		var seg_b = traj.get_segment(i + 1)
		assert_eq(seg_a.end_pos, seg_b.start_pos, "Segment endpoints must connect continuously")
		assert_almost_eq(seg_a.end_radius, seg_b.start_radius, 0.001, "Radii must be continuous across junctions")

	# Verify total length
	var expected_len = 0.0
	for seg in traj.segments:
		expected_len += seg.length
	assert_almost_eq(traj.total_length, expected_len, 0.001, "Total length must match sum of segment lengths")
	assert_true(traj.total_length > 80.0, "Total length must exceed straight delta")

func test_trajectory_distance_and_surface_query() -> void:
	var traj = WormTrajectoryClass.new(1)
	traj.add_waypoint(Vector3(0.0, 0.0, 0.0), 3.0)
	traj.add_waypoint(Vector3(20.0, 0.0, 0.0), 3.0)
	traj.add_waypoint(Vector3(20.0, 0.0, 20.0), 3.0)

	# Point near segment 0 (10, 2, 0)
	var p1 = Vector3(10.0, 2.0, 0.0)
	assert_almost_eq(traj.distance_to_point(p1), 2.0, 0.001, "Distance to segment 0 must be 2.0")
	assert_almost_eq(traj.distance_to_surface(p1), -1.0, 0.001, "Surface distance must be 2.0 - 3.0 = -1.0")

	# Point near segment 1 (20, 0, 15)
	var p2 = Vector3(20.0, 0.0, 15.0)
	assert_almost_eq(traj.distance_to_point(p2), 0.0, 0.001, "Point on segment 1 must have distance 0.0")

func test_trajectory_sampling_along_spine() -> void:
	var traj = WormTrajectoryClass.new(1)
	traj.add_waypoint(Vector3(0.0, 0.0, 0.0), 3.0)
	traj.add_waypoint(Vector3(10.0, 0.0, 0.0), 3.0) # Length 10
	traj.add_waypoint(Vector3(10.0, 0.0, 20.0), 3.0) # Length 20 (total 30)

	assert_almost_eq(traj.total_length, 30.0, 0.001, "Total length must be 30.0")

	# Sample at distance 0
	var p_start = traj.sample_point_at_distance(0.0)
	assert_eq(p_start, Vector3(0.0, 0.0, 0.0), "Sample at 0 must be start")

	# Sample at distance 5 (mid of segment 0)
	var p_mid1 = traj.sample_point_at_distance(5.0)
	assert_eq(p_mid1, Vector3(5.0, 0.0, 0.0), "Sample at 5 must be (5,0,0)")

	# Sample at distance 10 (junction)
	var p_junc = traj.sample_point_at_distance(10.0)
	assert_eq(p_junc, Vector3(10.0, 0.0, 0.0), "Sample at 10 must be (10,0,0)")

	# Sample at distance 20 (mid of segment 1)
	var p_mid2 = traj.sample_point_at_distance(20.0)
	assert_eq(p_mid2, Vector3(10.0, 0.0, 10.0), "Sample at 20 must be (10,0,10)")

	# Sample at distance 30 (end)
	var p_end = traj.sample_point_at_distance(30.0)
	assert_eq(p_end, Vector3(10.0, 0.0, 20.0), "Sample at 30 must be (10,0,20)")

func test_trajectory_aabb_culling() -> void:
	var traj = WormTrajectoryClass.new(1)
	traj.add_waypoint(Vector3(0.0, 0.0, 0.0), 3.0)
	traj.add_waypoint(Vector3(50.0, 0.0, 0.0), 3.0)

	var hit_box = AABB(Vector3(20.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	assert_true(traj.intersects_aabb(hit_box), "Traversing box must intersect trajectory")

	var miss_box = AABB(Vector3(20.0, 20.0, 20.0), Vector3(2.0, 2.0, 2.0))
	assert_false(traj.intersects_aabb(miss_box), "Distant box must not intersect trajectory")
