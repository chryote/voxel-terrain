class_name TestWormTrajectoryGenerator
extends "res://tests/framework/test_case.gd"

## Unit test suite validating Phase 2: Seeded Trajectory Synthesis (WormTrajectoryGenerator).
## Verifies seed determinism, chasm anchor discovery, slope gradient constraints,
## player clearance guarantees, and Catmull-Rom spline smoothing.

const WormTrajectoryGeneratorClass = preload("res://src/generation/caves/worm_trajectory_generator.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveGeneratorConfigClass = preload("res://src/generation/caves/cave_generator_config.gd")
const UndergroundChasmSamplerClass = preload("res://src/generation/caves/underground_chasm_sampler.gd")

func test_seed_determinism() -> void:
	var config = CaveGeneratorConfigClass.new()
	var gen1 = WormTrajectoryGeneratorClass.new(1337, config)
	var gen2 = WormTrajectoryGeneratorClass.new(1337, config)
	var gen_diff = WormTrajectoryGeneratorClass.new(9999, config)

	var start = Vector3(50.0, 45.0, 50.0)
	var end = Vector3(120.0, 10.0, 110.0)

	var traj1 = gen1.generate_trajectory_between_anchors(start, end, 1)
	var traj2 = gen2.generate_trajectory_between_anchors(start, end, 1)
	var traj_diff = gen_diff.generate_trajectory_between_anchors(start, end, 1)

	assert_eq(traj1.waypoints.size(), traj2.waypoints.size(), "Waypoint counts must be identical for same seed")
	assert_almost_eq(traj1.total_length, traj2.total_length, 0.0001, "Total lengths must match for same seed")

	for i in range(traj1.waypoints.size()):
		var p1 = traj1.waypoints[i]
		var p2 = traj2.waypoints[i]
		assert_almost_eq(p1.x, p2.x, 0.0001, "X coords must match for waypoint %d" % i)
		assert_almost_eq(p1.y, p2.y, 0.0001, "Y coords must match for waypoint %d" % i)
		assert_almost_eq(p1.z, p2.z, 0.0001, "Z coords must match for waypoint %d" % i)

	# Verify different seed produces different trajectory
	var found_diff = false
	for i in range(mini(traj1.waypoints.size(), traj_diff.waypoints.size())):
		if traj1.waypoints[i].distance_to(traj_diff.waypoints[i]) > 0.1:
			found_diff = true
			break
	assert_true(found_diff, "Different seed must produce different waypoints")

func test_chasm_anchor_discovery() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.arena_enabled = true
	var sampler = UndergroundChasmSamplerClass.new(1337, config)
	var gen = WormTrajectoryGeneratorClass.new(1337, config, sampler)

	# Find chasm anchor from a surface position
	var source_pos = Vector3(0.0, 50.0, 0.0)
	var anchor = gen.find_chasm_anchor(source_pos, 150.0, 10.0)

	assert_true(anchor.y >= float(config.chasm_min_y), "Chasm anchor Y (%f) must be >= chasm_min_y" % anchor.y)
	assert_true(anchor.y <= float(config.arena_ceiling_y), "Chasm anchor Y (%f) must be <= ceiling" % anchor.y)

	# Verify anchor column is indeed inside chasm void
	var col = ChasmColumnResult.new()
	sampler.sample_column(anchor.x, anchor.z, col)
	assert_true(col.is_chasm, "Chasm anchor column must be verified chasm void")
	assert_false(col.is_pillar, "Chasm anchor column must not be solid stone pillar")
	assert_true(anchor.y >= float(col.floor_y), "Anchor Y must be above cavern floor")
	assert_true(anchor.y <= float(col.ceil_y), "Anchor Y must be below cavern ceiling")

func test_trajectory_descent_gradient_and_bounds() -> void:
	var config = CaveGeneratorConfigClass.new()
	var gen = WormTrajectoryGeneratorClass.new(1337, config)

	var start = Vector3(0.0, 60.0, 0.0)
	var end = Vector3(100.0, 10.0, 80.0)
	var traj = gen.generate_trajectory_between_anchors(start, end, 2)

	assert_true(traj.get_segment_count() > 0, "Trajectory must contain segments")

	# Check exact endpoints
	var first_p = traj.waypoints[0]
	var last_p = traj.waypoints[traj.waypoints.size() - 1]
	assert_almost_eq(first_p.x, start.x, 0.001, "Start X must match")
	assert_almost_eq(first_p.y, start.y, 0.001, "Start Y must match")
	assert_almost_eq(first_p.z, start.z, 0.001, "Start Z must match")

	assert_almost_eq(last_p.x, end.x, 0.001, "End X must match")
	assert_almost_eq(last_p.y, end.y, 0.001, "End Y must match")
	assert_almost_eq(last_p.z, end.z, 0.001, "End Z must match")

	# Check slope gradient and bedrock clearance along all segments
	for seg in traj.segments:
		assert_true(seg.start_pos.y >= 3.5, "Segment start Y must be above bedrock (>= 3.5)")
		assert_true(seg.end_pos.y >= 3.5, "Segment end Y must be above bedrock (>= 3.5)")
		assert_true(seg.start_pos.y <= start.y + 0.1, "Segment start Y must not exceed surface elevation")
		assert_true(seg.end_pos.y <= start.y + 0.1, "Segment end Y must not exceed surface elevation")

		var h_len = Vector2(seg.end_pos.x - seg.start_pos.x, seg.end_pos.z - seg.start_pos.z).length()
		var v_len = absf(seg.end_pos.y - seg.start_pos.y)
		if h_len > 0.1:
			var slope = v_len / h_len
			# Maximum allowable pitch grade is tan(35 deg) approx 0.70
			assert_true(slope <= 0.85, "Corridor slope (%f) must be navigable and not sheer cliff" % slope)

func test_strict_player_clearance() -> void:
	var config = CaveGeneratorConfigClass.new()
	config.min_clearance = 2.2
	config.tunnel_radius_base = 3.6
	var gen = WormTrajectoryGeneratorClass.new(1337, config)

	var traj = gen.generate_trajectory_between_anchors(Vector3(0, 40, 0), Vector3(80, 8, 80), 3)

	for i in range(traj.radii.size()):
		var r = traj.radii[i]
		assert_true(r >= config.min_clearance, "Radius at waypoint %d (%f) must be >= min_clearance (%f)" % [i, r, config.min_clearance])

	for seg in traj.segments:
		assert_true(seg.start_radius >= config.min_clearance, "Segment start radius must respect clearance")
		assert_true(seg.end_radius >= config.min_clearance, "Segment end radius must respect clearance")

func test_catmull_rom_smoothing_properties() -> void:
	var gen = WormTrajectoryGeneratorClass.new(1337)
	var p0 = Vector3(0.0, 0.0, 0.0)
	var p1 = Vector3(10.0, 5.0, 0.0)
	var p2 = Vector3(20.0, 10.0, 0.0)
	var p3 = Vector3(30.0, 12.0, 0.0)

	# At t = 0.0, Catmull-Rom must evaluate to p1 exactly
	var eval_0 = gen.evaluate_catmull_rom(p0, p1, p2, p3, 0.0)
	assert_almost_eq(eval_0.x, p1.x, 0.001, "Catmull-Rom at t=0 must equal p1.x")
	assert_almost_eq(eval_0.y, p1.y, 0.001, "Catmull-Rom at t=0 must equal p1.y")

	# At t = 1.0, Catmull-Rom must evaluate to p2 exactly
	var eval_1 = gen.evaluate_catmull_rom(p0, p1, p2, p3, 1.0)
	assert_almost_eq(eval_1.x, p2.x, 0.001, "Catmull-Rom at t=1 must equal p2.x")
	assert_almost_eq(eval_1.y, p2.y, 0.001, "Catmull-Rom at t=1 must equal p2.y")

	# At t = 0.5, Catmull-Rom must be midway
	var eval_mid = gen.evaluate_catmull_rom(p0, p1, p2, p3, 0.5)
	assert_true(eval_mid.x > p1.x and eval_mid.x < p2.x, "Catmull-Rom midpoint must interpolate between p1 and p2")

func test_generate_trajectory_for_cave_mouth_data() -> void:
	var config = CaveGeneratorConfigClass.new()
	var sampler = UndergroundChasmSamplerClass.new(1337, config)
	var gen = WormTrajectoryGeneratorClass.new(1337, config, sampler)

	var mouth_data = CaveMouthDataClass.new(
		Vector3(120.0, 42.0, 80.0),
		Vector2(120.0, 80.0),
		CaveMouthDataClass.Type.TUNNEL,
		10.0,
		7.0,
		42.0
	)

	var traj = gen.generate_trajectory_for_mouth(mouth_data, 5)

	assert_not_null(traj, "Must generate valid trajectory for mouth data")
	assert_eq(traj.id, 5, "Trajectory id must match mouth_id")
	assert_true(traj.get_segment_count() > 0, "Trajectory must contain segments")
	assert_true(traj.total_length > 30.0, "Trajectory must span descent length")
	assert_almost_eq(traj.source_anchor.x, mouth_data.world_pos.x, 0.001, "Source anchor must match mouth pos")
	assert_almost_eq(traj.source_anchor.y, mouth_data.world_pos.y, 0.001, "Source anchor must match mouth pos")
