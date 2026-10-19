class_name SubterraneanTunnelSampler
extends RefCounted

## Pure component responsible for 3D worm-tunnel geometry, bifurcations,
## player navigation clearance, and continuity modulation for dead ends.
## Uses dual 3D simplex noise fields to carve continuous winding corridors,
## with a 3D continuity noise that pinches off branches into natural dead ends.

const WormChunkRegistryClass = preload("res://src/generation/caves/worm_chunk_registry.gd")
const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")

var config: CaveGeneratorConfig
var chasm_sampler: UndergroundChasmSampler = null
var worm_registry: WormChunkRegistry = null

var tunnel_noise_a: FastNoiseLite
var tunnel_noise_b: FastNoiseLite
var continuity_noise: FastNoiseLite
var perturb_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null, p_chasm_sampler: UndergroundChasmSampler = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()
	chasm_sampler = p_chasm_sampler

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
 
func set_chasm_sampler(p_chasm_sampler: UndergroundChasmSampler) -> void:
	chasm_sampler = p_chasm_sampler

func set_worm_registry(p_registry: WormChunkRegistry) -> void:
	worm_registry = p_registry

func get_arena_suppression(wx: float, wz: float) -> float:
	## Smooth Hermite suppression factor [0.0..1.0] for worm tunnels approaching core combat arenas.
	## Returns 0.0 inside core arenas, 1.0 outside arena zone, and a continuous Hermite curve in-between.
	if chasm_sampler == null or not config.arena_enabled:
		return 1.0

	var fade_start = config.arena_rift_threshold - 0.04
	var warp_margin = chasm_sampler.get_wall_warp_margin()
	var unwarped_rift = chasm_sampler.sample_unwarped_rift(wx, wz)
	if unwarped_rift < (fade_start - warp_margin):
		return 1.0

	var warped_pos = chasm_sampler.get_warped_coordinates(wx, wz)
	var raw_rift = chasm_sampler.sample_rift_mask(warped_pos.x, warped_pos.y)
	if raw_rift <= fade_start:
		return 1.0
	if raw_rift >= config.arena_rift_threshold:
		return 0.0

	var blend = (raw_rift - fade_start) / 0.04
	return 1.0 - (blend * blend * (3.0 - 2.0 * blend))

func sample_tunnel(wx: float, wy: float, wz: float) -> Dictionary:
	var arena_supp = get_arena_suppression(wx, wz)

	if (config == null or config.use_directed_worm_corridors) and worm_registry != null and worm_registry.get_registered_chunk_count() > 0:
		var c = worm_registry.world_to_chunk(Vector3(wx, wy, wz))
		var segs = worm_registry.get_segments_for_chunk(c)
		if segs.is_empty():
			return {
				"is_tunnel": false,
				"density": 0.0,
				"effective_radius": 0.0,
				"is_dead_end": false,
				"centerline_dist": INF
			}

		var p = Vector3(wx, wy, wz)
		var min_dist = INF
		var eff_radius = config.tunnel_radius_base
		for seg in segs:
			var d = seg.distance_to_point(p)
			if d < min_dist:
				min_dist = d
				eff_radius = seg.get_interpolated_radius(p)

		if arena_supp < 1.0:
			eff_radius *= arena_supp

		if eff_radius <= 0.0:
			return {
				"is_tunnel": false,
				"density": 0.0,
				"effective_radius": 0.0,
				"is_dead_end": true,
				"centerline_dist": min_dist
			}

		var perturb = perturb_noise.get_noise_3d(wx, wy, wz) * config.tunnel_radius_variation
		var final_radius = eff_radius + perturb
		var is_inside = min_dist < final_radius
		var carve_density = 0.0
		if is_inside:
			var factor = 1.0 - (min_dist / final_radius)
			carve_density = factor * factor * (3.0 - 2.0 * factor)

		return {
			"is_tunnel": is_inside,
			"density": carve_density,
			"effective_radius": eff_radius,
			"is_dead_end": false,
			"centerline_dist": min_dist
		}

	# Vertical squish allows wider, flatter floors for comfortable player walking
	var squished_y = wy * config.tunnel_vertical_squish

	var na = tunnel_noise_a.get_noise_3d(wx, squished_y, wz)
	var nb = tunnel_noise_b.get_noise_3d(wx, squished_y, wz)
	var centerline_dist = sqrt(na * na + nb * nb)

	var cont = continuity_noise.get_noise_3d(wx, wy * 0.8, wz)
	var perturb = perturb_noise.get_noise_3d(wx, wy, wz) * config.tunnel_radius_variation

	# Calculate effective radius
	var eff_radius = config.tunnel_radius_base + perturb
	var is_pinched = false

	# Modulate dead ends via continuity noise
	var is_dead_end = cont <= config.dead_end_threshold
	if is_dead_end:
		var pinch = (config.dead_end_threshold - cont) * config.pinch_rate
		eff_radius -= pinch
		is_pinched = true

	# Smooth arena suppression: tapers worm tunnels before reaching arena boundary
	arena_supp = get_arena_suppression(wx, wz)
	if arena_supp < 1.0:
		eff_radius *= arena_supp
		is_pinched = true
		if arena_supp <= 0.0:
			is_dead_end = true

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
	if not is_pinched:
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

func can_tunnel_intersect_chunk(coord: ChunkCoord, min_p: Vector3 = Vector3.ZERO, max_p: Vector3 = Vector3.ZERO) -> bool:
	## O(1) query checking if a chunk column or specific vertical range intersects any registered worm tunnel.
	if (config == null or config.use_directed_worm_corridors) and worm_registry != null and worm_registry.get_registered_chunk_count() > 0:
		if coord == null or not worm_registry.has_chunk(coord):
			return false
		if min_p != Vector3.ZERO or max_p != Vector3.ZERO:
			var s_min = maxi(0, floori(min_p.y / worm_registry.section_height))
			var s_max = maxi(0, floori(max_p.y / worm_registry.section_height))
			for s in range(s_min, s_max + 1):
				if worm_registry.is_section_active(coord, s):
					return true
			return false
		return true

	# Fallback when no worm registry is populated
	if min_p == Vector3.ZERO and max_p == Vector3.ZERO:
		return true
	return can_tunnel_intersect_cell(min_p, max_p)

func can_tunnel_intersect_cell(min_p: Vector3, max_p: Vector3) -> bool:
	## Coarse culling: evaluates center and corners using calibrated Lipschitz bounds.
	## Returns false if it is mathematically impossible for a worm tunnel to carve inside this cell.
	if max_p.y <= min_p.y or max_p.x <= min_p.x or max_p.z <= min_p.z:
		return false

	if (config == null or config.use_directed_worm_corridors) and worm_registry != null and worm_registry.get_registered_chunk_count() > 0:
		var c_min = worm_registry.world_to_chunk(min_p)
		var c_max = worm_registry.world_to_chunk(max_p)
		var cell_box = AABB(min_p, max_p - min_p)
		for cz in range(c_min.z, c_max.z + 1):
			for cx in range(c_min.x, c_max.x + 1):
				var coord = ChunkCoord.new(cx, cz)
				if worm_registry.has_chunk(coord):
					var segs = worm_registry.get_segments_for_chunk(coord)
					for seg in segs:
						if seg.intersects_aabb(cell_box):
							return true
		return false

	var span_x = max_p.x - min_p.x
	var span_y = max_p.y - min_p.y
	var span_z = max_p.z - min_p.z

	# Fast-path check: does this cell volume touch any arena suppression zone?
	var has_arena_influence = false
	if chasm_sampler != null and config.arena_enabled:
		var mid_x_c = (min_p.x + max_p.x) * 0.5
		var mid_z_c = (min_p.z + max_p.z) * 0.5
		var unwarped = chasm_sampler.sample_unwarped_rift(mid_x_c, mid_z_c)
		var half_diag = Vector2(span_x, span_z).length() * 0.5
		var margin = (half_diag + chasm_sampler.get_wall_warp_margin()) * config.chasm_rift_frequency * 2.5 + 0.05
		if unwarped >= (config.arena_rift_threshold - 0.04 - margin):
			has_arena_influence = true
			# If the entire cell is in the core arena (suppression <= 0.0), tunnels cannot exist
			if get_arena_suppression(mid_x_c, mid_z_c) <= 0.0:
				if get_arena_suppression(min_p.x, min_p.z) <= 0.0 and \
				   get_arena_suppression(max_p.x, min_p.z) <= 0.0 and \
				   get_arena_suppression(min_p.x, max_p.z) <= 0.0 and \
				   get_arena_suppression(max_p.x, max_p.z) <= 0.0:
					return false

	var eff_thresh = config.tunnel_radius_base * 0.05 * 0.85

	# Path A: Standard fast-path when outside arena influence (>99% of cells in the world)
	if not has_arena_influence:
		if span_x <= 4.1 and span_y <= 4.1 and span_z <= 4.1:
			var max_safe_d = eff_thresh + 0.12
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

		var step_x = minf(8.0, span_x)
		var step_y = minf(8.0, span_y)
		var step_z = minf(8.0, span_z)
		var max_safe_d = eff_thresh + 0.25

		var y = min_p.y
		while y <= max_p.y:
			var sq_y = y * config.tunnel_vertical_squish
			var z = min_p.z
			while z <= max_p.z:
				var x = min_p.x
				while x <= max_p.x:
					var na = tunnel_noise_a.get_noise_3d(x, sq_y, z)
					var nb = tunnel_noise_b.get_noise_3d(x, sq_y, z)
					var d = sqrt(na * na + nb * nb)
					if d <= max_safe_d:
						return true
					x += step_x
				z += step_z
			y += step_y

		return false

	# Path B: Arena influence active — scale thresholds by 2D suppression factor
	if span_x <= 4.1 and span_y <= 4.1 and span_z <= 4.1:
		var mid_x = (min_p.x + max_p.x) * 0.5
		var mid_y = (min_p.y + max_p.y) * 0.5
		var mid_z = (min_p.z + max_p.z) * 0.5
		var mid_supp = get_arena_suppression(mid_x, mid_z)

		if mid_supp > 0.0:
			var sq_y_m = mid_y * config.tunnel_vertical_squish
			var na_m = tunnel_noise_a.get_noise_3d(mid_x, sq_y_m, mid_z)
			var nb_m = tunnel_noise_b.get_noise_3d(mid_x, sq_y_m, mid_z)
			var mid_d = sqrt(na_m * na_m + nb_m * nb_m)
			if mid_d <= (eff_thresh * mid_supp):
				return true

		var max_supp = mid_supp
		var min_d_scaled = 999.0
		for cx in [min_p.x, max_p.x]:
			for cy in [min_p.y, max_p.y]:
				for cz in [min_p.z, max_p.z]:
					var supp = get_arena_suppression(cx, cz)
					max_supp = maxf(max_supp, supp)
					if supp <= 0.0:
						continue
					var sq_y = cy * config.tunnel_vertical_squish
					var na = tunnel_noise_a.get_noise_3d(cx, sq_y, cz)
					var nb = tunnel_noise_b.get_noise_3d(cx, sq_y, cz)
					var d = sqrt(na * na + nb * nb)
					if d <= (eff_thresh * supp):
						return true
					min_d_scaled = minf(min_d_scaled, d / maxf(0.01, supp))

		if max_supp <= 0.0:
			return false
		return min_d_scaled <= (eff_thresh + 0.12)

	var step_x = minf(8.0, span_x)
	var step_y = minf(8.0, span_y)
	var step_z = minf(8.0, span_z)

	var y = min_p.y
	while y <= max_p.y:
		var sq_y = y * config.tunnel_vertical_squish
		var z = min_p.z
		while z <= max_p.z:
			var x = min_p.x
			while x <= max_p.x:
				var supp = get_arena_suppression(x, z)
				if supp > 0.0:
					var pt_eff_thresh = config.tunnel_radius_base * supp * 0.05 * 0.85
					var pt_max_safe_d = pt_eff_thresh + (0.25 * supp)
					var na = tunnel_noise_a.get_noise_3d(x, sq_y, z)
					var nb = tunnel_noise_b.get_noise_3d(x, sq_y, z)
					var d = sqrt(na * na + nb * nb)
					if d <= pt_max_safe_d:
						return true
				x += step_x
			z += step_z
		y += step_y

	return false

func get_tunnel_carve(wx: float, wy: float, wz: float) -> float:
	var arena_supp = get_arena_suppression(wx, wz)
	if arena_supp <= 0.0:
		return 0.0

	if (config == null or config.use_directed_worm_corridors) and worm_registry != null and worm_registry.get_registered_chunk_count() > 0:
		var c = worm_registry.world_to_chunk(Vector3(wx, wy, wz))
		var segs = worm_registry.get_segments_for_chunk(c)
		if segs.is_empty():
			return 0.0

		var p = Vector3(wx, wy, wz)
		var min_dist = INF
		var eff_radius = config.tunnel_radius_base
		for seg in segs:
			var d = seg.distance_to_point(p)
			if d < min_dist:
				min_dist = d
				eff_radius = seg.get_interpolated_radius(p)

		if arena_supp < 1.0:
			eff_radius *= arena_supp

		if eff_radius <= 0.0:
			return 0.0

		var perturb = perturb_noise.get_noise_3d(wx, wy, wz) * config.tunnel_radius_variation
		var final_radius = eff_radius + perturb

		if min_dist < final_radius:
			var factor = 1.0 - (min_dist / final_radius)
			return factor * factor * (3.0 - 2.0 * factor)
		return 0.0

	var squished_y = wy * config.tunnel_vertical_squish
	var na = tunnel_noise_a.get_noise_3d(wx, squished_y, wz)
	var nb = tunnel_noise_b.get_noise_3d(wx, squished_y, wz)
	var centerline_dist = sqrt(na * na + nb * nb)

	var eff_radius = config.tunnel_radius_base
	var is_pinched = false

	if arena_supp < 1.0:
		eff_radius *= arena_supp
		is_pinched = true

	var cont = continuity_noise.get_noise_3d(wx, wy * 0.8, wz)
	if cont <= config.dead_end_threshold:
		eff_radius -= (config.dead_end_threshold - cont) * config.pinch_rate
		is_pinched = true

	if eff_radius <= 0.0:
		return 0.0

	if not is_pinched:
		eff_radius = maxf(config.min_clearance, eff_radius)

	var tunnel_threshold = eff_radius * 0.05
	if centerline_dist < tunnel_threshold:
		var factor = 1.0 - (centerline_dist / tunnel_threshold)
		return factor * factor * (3.0 - 2.0 * factor)

	return 0.0

func is_dead_end_zone(wx: float, wy: float, wz: float) -> bool:
	return continuity_noise.get_noise_3d(wx, wy * 0.8, wz) <= config.dead_end_threshold

func sample_trilinear_cell_corners(min_p: Vector3, max_p: Vector3) -> PackedFloat32Array:
	## Evaluates tunnel carve densities at the 8 corners of a 3D cell [min_p, max_p].
	## Corner ordering: [c000, c100, c010, c110, c001, c101, c011, c111]
	var corners = PackedFloat32Array()
	corners.resize(8)
	corners[0] = get_tunnel_carve(min_p.x, min_p.y, min_p.z)
	corners[1] = get_tunnel_carve(max_p.x, min_p.y, min_p.z)
	corners[2] = get_tunnel_carve(min_p.x, max_p.y, min_p.z)
	corners[3] = get_tunnel_carve(max_p.x, max_p.y, min_p.z)
	corners[4] = get_tunnel_carve(min_p.x, min_p.y, max_p.z)
	corners[5] = get_tunnel_carve(max_p.x, min_p.y, max_p.z)
	corners[6] = get_tunnel_carve(min_p.x, max_p.y, max_p.z)
	corners[7] = get_tunnel_carve(max_p.x, max_p.y, max_p.z)
	return corners

func evaluate_trilinear(corners: PackedFloat32Array, u: float, v: float, w: float) -> float:
	## Trilinearly interpolates corner densities for normalized coordinates (u, v, w) in [0.0, 1.0].
	var c00 = lerpf(corners[0], corners[1], u)
	var c01 = lerpf(corners[4], corners[5], u)
	var c10 = lerpf(corners[2], corners[3], u)
	var c11 = lerpf(corners[6], corners[7], u)

	var c0 = lerpf(c00, c10, v)
	var c1 = lerpf(c01, c11, v)

	return lerpf(c0, c1, w)

