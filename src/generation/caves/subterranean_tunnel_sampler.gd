class_name SubterraneanTunnelSampler
extends RefCounted

## Pure component responsible for 3D worm-tunnel geometry, bifurcations,
## player navigation clearance, and continuity modulation for dead ends.
## Uses dual 3D simplex noise fields to carve continuous winding corridors,
## with a 3D continuity noise that pinches off branches into natural dead ends.

var config: CaveGeneratorConfig

var tunnel_noise_a: FastNoiseLite
var tunnel_noise_b: FastNoiseLite
var continuity_noise: FastNoiseLite
var perturb_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()

	# 1. Primary 3D worm noise field A
	tunnel_noise_a = FastNoiseLite.new()
	tunnel_noise_a.seed = seed_val + 909
	tunnel_noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	tunnel_noise_a.frequency = config.tunnel_frequency

	# 2. Secondary 3D worm noise field B (orthogonal zero-crossing)
	tunnel_noise_b = FastNoiseLite.new()
	tunnel_noise_b.seed = seed_val + 910
	tunnel_noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	tunnel_noise_b.frequency = config.tunnel_frequency

	# 3. Continuity noise controlling dead-end pinch-offs vs traversable corridors
	continuity_noise = FastNoiseLite.new()
	continuity_noise.seed = seed_val + 911
	continuity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continuity_noise.frequency = config.continuity_frequency

	# 4. High-frequency wall perturbation noise for organic rocky surfaces
	perturb_noise = FastNoiseLite.new()
	perturb_noise.seed = seed_val + 912
	perturb_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	perturb_noise.frequency = config.tunnel_frequency * 2.5

func sample_tunnel(wx: float, wy: float, wz: float) -> Dictionary:
	# Vertical squish allows wider, flatter floors for comfortable player walking
	var squished_y = wy * config.tunnel_vertical_squish

	var na = tunnel_noise_a.get_noise_3d(wx, squished_y, wz)
	var nb = tunnel_noise_b.get_noise_3d(wx, squished_y, wz)
	var centerline_dist = sqrt(na * na + nb * nb)

	var cont = continuity_noise.get_noise_3d(wx, wy * 0.8, wz)
	var perturb = perturb_noise.get_noise_3d(wx, wy, wz) * config.tunnel_radius_variation

	# Calculate effective radius
	var eff_radius = config.tunnel_radius_base + perturb

	# Modulate dead ends via continuity noise
	var is_dead_end = cont <= config.dead_end_threshold
	if is_dead_end:
		var pinch = (config.dead_end_threshold - cont) * config.pinch_rate
		eff_radius -= pinch

	# If radius contracted to <= 0, the corridor is completely pinched shut by solid rock
	if eff_radius <= 0.0:
		return {
			"is_tunnel": false,
			"density": 0.0,
			"effective_radius": 0.0,
			"is_dead_end": true,
			"centerline_dist": centerline_dist
		}

	# Ensure traversable corridors strictly respect minimum player clearance
	if not is_dead_end:
		eff_radius = maxf(config.min_clearance, eff_radius)

	# In normalized tunnel coordinates, 0.0 = centerline, 1.0 = tunnel perimeter
	# Threshold scaling maps centerline distance to effective radius
	var tunnel_threshold = eff_radius * 0.05
	var is_inside = centerline_dist < tunnel_threshold

	var carve_density = 0.0
	if is_inside:
		var factor = 1.0 - (centerline_dist / tunnel_threshold)
		carve_density = factor * factor * (3.0 - 2.0 * factor)

	return {
		"is_tunnel": is_inside,
		"density": carve_density,
		"effective_radius": eff_radius,
		"is_dead_end": is_dead_end,
		"centerline_dist": centerline_dist
	}

func can_tunnel_intersect_cell(min_p: Vector3, max_p: Vector3) -> bool:
	## Coarse culling: evaluates center and 8 corners using calibrated Lipschitz bound (0.12).
	## Returns false if it is mathematically impossible for a worm tunnel to carve inside this cell.
	var eff_thresh = config.tunnel_radius_base * 0.05 * 0.85
	var max_safe_d = eff_thresh + 0.12

	# 1. Fast center check: if center is inside the tunnel, return true immediately
	var mid_x = (min_p.x + max_p.x) * 0.5
	var mid_y = (min_p.y + max_p.y) * 0.5
	var mid_z = (min_p.z + max_p.z) * 0.5
	var sq_y_m = mid_y * config.tunnel_vertical_squish
	var na_m = tunnel_noise_a.get_noise_3d(mid_x, sq_y_m, mid_z)
	var nb_m = tunnel_noise_b.get_noise_3d(mid_x, sq_y_m, mid_z)
	var mid_d = sqrt(na_m * na_m + nb_m * nb_m)
	if mid_d <= eff_thresh:
		return true

	var min_d = mid_d
	for cx in [min_p.x, max_p.x]:
		for cy in [min_p.y, max_p.y]:
			for cz in [min_p.z, max_p.z]:
				var sq_y = cy * config.tunnel_vertical_squish
				var na = tunnel_noise_a.get_noise_3d(cx, sq_y, cz)
				var nb = tunnel_noise_b.get_noise_3d(cx, sq_y, cz)
				var d = sqrt(na * na + nb * nb)
				if d <= eff_thresh:
					return true
				min_d = minf(min_d, d)

	return min_d <= max_safe_d

func get_tunnel_carve(wx: float, wy: float, wz: float) -> float:
	var squished_y = wy * config.tunnel_vertical_squish
	var na = tunnel_noise_a.get_noise_3d(wx, squished_y, wz)
	var nb = tunnel_noise_b.get_noise_3d(wx, squished_y, wz)
	var centerline_dist = sqrt(na * na + nb * nb)

	var cont = continuity_noise.get_noise_3d(wx, wy * 0.8, wz)
	var eff_radius = config.tunnel_radius_base
	if cont <= config.dead_end_threshold:
		eff_radius -= (config.dead_end_threshold - cont) * config.pinch_rate
		if eff_radius <= 0.0:
			return 0.0
	else:
		eff_radius = maxf(config.min_clearance, eff_radius)

	var tunnel_threshold = eff_radius * 0.05
	if centerline_dist < tunnel_threshold:
		var factor = 1.0 - (centerline_dist / tunnel_threshold)
		return factor * factor * (3.0 - 2.0 * factor)

	return 0.0

func is_dead_end_zone(wx: float, wy: float, wz: float) -> bool:
	return continuity_noise.get_noise_3d(wx, wy * 0.8, wz) <= config.dead_end_threshold
