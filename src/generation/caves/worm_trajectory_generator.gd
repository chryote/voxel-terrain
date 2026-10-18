class_name WormTrajectoryGenerator
extends RefCounted

## Pure algorithmic component responsible for synthesizing seeded, directed 3D worm corridor
## trajectories connecting surface cave mouths down into subterranean chasms or combat arenas.
##
## Adheres to Sustainable Game Development and Single Responsibility Principle:
## - Decoupled from mesh generation and scene tree.
## - 100% deterministic given world seed and mouth identifier.
## - Guarantees smooth walkable descent slopes (<= 30 degrees) and player clearance (>= 2.2m).

const WormTrajectoryClass = preload("res://src/generation/caves/worm_trajectory.gd")
const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const ChasmColumnResultClass = preload("res://src/generation/caves/chasm_column_result.gd")

var seed_val: int
var config: CaveGeneratorConfig
var chasm_sampler: UndergroundChasmSampler
var meander_noise: FastNoiseLite
var _chasm_col: ChasmColumnResult

func _init(
	p_seed: int = 1337,
	p_config: CaveGeneratorConfig = null,
	p_chasm_sampler: UndergroundChasmSampler = null
) -> void:
	seed_val = p_seed
	config = p_config if p_config != null else CaveGeneratorConfig.new()
	chasm_sampler = p_chasm_sampler
	_chasm_col = ChasmColumnResultClass.new()

	meander_noise = FastNoiseLite.new()
	meander_noise.seed = seed_val + 707
	meander_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	meander_noise.frequency = 0.05

## Generates a complete 3D descent trajectory for a given surface cave mouth.
func generate_trajectory_for_mouth(mouth_data: CaveMouthData, mouth_id: int = 0) -> WormTrajectory:
	if mouth_data == null:
		return null

	var source_pos = mouth_data.world_pos
	var target_pos = find_chasm_anchor(source_pos)

	var start_r = maxf(config.min_clearance, mouth_data.radius * 0.65)
	var end_r = config.tunnel_radius_base * 1.15

	return generate_trajectory_between_anchors(source_pos, target_pos, mouth_id, start_r, end_r)

## Synthesizes a smooth 3D corridor trajectory between two specified 3D anchors.
func generate_trajectory_between_anchors(
	source_anchor: Vector3,
	target_anchor: Vector3,
	mouth_id: int = 0,
	start_radius: float = 4.0,
	end_radius: float = 3.8
) -> WormTrajectory:
	var traj = WormTrajectoryClass.new(mouth_id, source_anchor, target_anchor)

	var macro_pts = generate_guided_waypoints(source_anchor, target_anchor, mouth_id)
	if macro_pts.size() < 2:
		return traj

	var smooth_pts = smooth_waypoints_catmull_rom(macro_pts, 3)
	if smooth_pts.size() < 2:
		return traj

	var count = smooth_pts.size()
	for i in range(count):
		var u = float(i) / float(count - 1)
		var r = calculate_interpolated_radius(u, start_radius, end_radius)
		traj.add_waypoint(smooth_pts[i], r)

	return traj

## Searches for the nearest subterranean chasm rift void or arena chamber anchor point.
func find_chasm_anchor(
	source_pos: Vector3,
	max_search_radius: float = 120.0,
	step_size: float = 12.0
) -> Vector3:
	if chasm_sampler == null:
		return _create_fallback_subterranean_anchor(source_pos)

	var best_pos = Vector2.ZERO
	var best_dist_sq = INF
	var best_floor_y = 6
	var best_ceil_y = 24
	var found = false

	# Scan concentric rings outward from cave mouth
	var r = step_size
	while r <= max_search_radius:
		var spoke_count = maxi(8, int(r * 0.5))
		var angle_step = TAU / float(spoke_count)
		for s in range(spoke_count):
			var angle = float(s) * angle_step
			var test_x = source_pos.x + cos(angle) * r
			var test_z = source_pos.z + sin(angle) * r

			chasm_sampler.sample_column(test_x, test_z, _chasm_col)
			if _chasm_col.is_chasm and not _chasm_col.is_pillar:
				var dist_sq = r * r
				# High-priority anchor: core combat arena
				if _chasm_col.is_arena:
					var target_y = clampf(float(_chasm_col.floor_y) + 2.5, float(config.chasm_min_y) + 2.0, float(_chasm_col.ceil_y) - 1.5)
					return Vector3(test_x, target_y, test_z)

				if dist_sq < best_dist_sq:
					best_dist_sq = dist_sq
					best_pos = Vector2(test_x, test_z)
					best_floor_y = _chasm_col.floor_y
					best_ceil_y = _chasm_col.ceil_y
					found = true
		if found:
			break
		r += step_size

	if found:
		var target_y = clampf(float(best_floor_y) + 2.5, float(config.chasm_min_y) + 2.0, float(best_ceil_y) - 1.5)
		return Vector3(best_pos.x, target_y, best_pos.y)

	return _create_fallback_subterranean_anchor(source_pos)

func _create_fallback_subterranean_anchor(source_pos: Vector3) -> Vector3:
	var fallback_y = maxf(float(config.chasm_min_y) + 4.0, source_pos.y - 25.0)
	return Vector3(source_pos.x + 30.0, fallback_y, source_pos.z + 30.0)

## Calculates progressive tunnel radius along normalized descent path [0.0..1.0].
func calculate_interpolated_radius(u: float, start_r: float, end_r: float) -> float:
	var base_r = config.tunnel_radius_base
	var r: float
	if u < 0.25:
		# Smooth transition from entrance mouth bowl down to standard tunnel radius
		var blend = u / 0.25
		r = lerpf(start_r, base_r, blend)
	elif u > 0.80:
		# Smooth expansion into chasm cavern opening
		var blend = (u - 0.80) / 0.20
		r = lerpf(base_r, end_r, blend)
	else:
		r = base_r

	return maxf(config.min_clearance, r)

## Generates macro waypoints from start to end with slope constraints and organic serpentine curl.
func generate_guided_waypoints(start_p: Vector3, end_p: Vector3, mouth_id: int) -> PackedVector3Array:
	var waypoints = PackedVector3Array()
	var delta = end_p - start_p
	var dist_xz = Vector2(delta.x, delta.z).length()
	var drop_y = start_p.y - end_p.y

	var step_dist = 8.0
	var steps = maxi(3, int(ceil(maxf(dist_xz, drop_y) / step_dist)))

	var h_dir = Vector2(delta.x, delta.z).normalized() if dist_xz > 0.001 else Vector2(1, 0)
	var perp_h = Vector3(-h_dir.y, 0.0, h_dir.x)

	for k in range(steps + 1):
		var u = float(k) / float(steps)
		var base_p = start_p.lerp(end_p, u)

		# Hermite smoothstep for gradual vertical gradient
		var smooth_u = u * u * (3.0 - 2.0 * u)
		var target_y = lerpf(start_p.y, end_p.y, smooth_u)

		# Organic lateral meander
		var meander_phase = float(k) * 18.0 + float(mouth_id * 101)
		var lateral_curl = meander_noise.get_noise_2d(meander_phase, float(mouth_id * 47))
		var meander_envelope = sin(u * PI) # Zero at endpoints, maximum in mid-section
		var max_lateral = clampf(dist_xz * 0.25, 3.0, 14.0)
		var lateral_offset = perp_h * (lateral_curl * max_lateral * meander_envelope)

		# Subtle vertical undulation
		var vert_curl = meander_noise.get_noise_2d(meander_phase + 50.0, float(mouth_id * 89))
		var vert_offset = vert_curl * 2.0 * meander_envelope
		var final_y = clampf(target_y + vert_offset, end_p.y, start_p.y)
		final_y = maxf(3.5, final_y) # Strictly above bedrock

		var wp = Vector3(base_p.x, final_y, base_p.z) + lateral_offset
		waypoints.append(wp)

	return waypoints

## Evaluates a 3D Catmull-Rom spline over control points with specified subdivisions per segment.
func smooth_waypoints_catmull_rom(control_points: PackedVector3Array, subdivisions: int = 3) -> PackedVector3Array:
	var count = control_points.size()
	if count < 2:
		return control_points

	var smoothed = PackedVector3Array()
	var subs = maxi(1, subdivisions)

	for i in range(count - 1):
		var p1 = control_points[i]
		var p2 = control_points[i + 1]
		var p0 = control_points[i - 1] if i > 0 else (p1 * 2.0 - p2)
		var p3 = control_points[i + 2] if (i + 2) < count else (p2 * 2.0 - p1)

		for s in range(subs):
			var t = float(s) / float(subs)
			var pt = evaluate_catmull_rom(p0, p1, p2, p3, t)
			# Ensure we never drop below bedrock Y=3.5
			pt.y = maxf(3.5, pt.y)
			smoothed.append(pt)

	# Ensure final destination endpoint is included exactly
	smoothed.append(control_points[count - 1])
	return smoothed

## Standard 4-point 3D Catmull-Rom cubic spline interpolation at parameter t in [0.0..1.0].
func evaluate_catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	return 0.5 * (
		(p1 * 2.0) +
		(-p0 + p2) * t +
		(p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 +
		(-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t3
	)
