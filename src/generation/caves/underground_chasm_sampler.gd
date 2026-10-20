class_name UndergroundChasmSampler
extends RefCounted

## Pure mathematical sampler for the Dual-2D Heightmap Deep Chasms & Abyssal Caverns system.
## Replaces volumetric 3D Simplex noise with two 2D heightfield noise maps (floor and ceiling)
## bounded laterally by a domain-warped 2D tectonic rift corridor mask with vertical walls.
## Guarantees minimum vertical clearance and indestructible bedrock protection.
const WALL_MARGIN: float = 0.03

var config: CaveGeneratorConfig

var rift_noise: FastNoiseLite
var wall_warp_noise: FastNoiseLite
var floor_noise: FastNoiseLite
var ceil_noise: FastNoiseLite
var pillar_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()
	_init_noises(seed_val)

func _init_noises(seed_val: int) -> void:
	# 1. 2D Rift Corridor Noise (Simplex Smooth, low-octave FBM to suppress high-frequency island chatter)
	rift_noise = FastNoiseLite.new()
	rift_noise.seed = seed_val + 1010
	rift_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rift_noise.frequency = config.chasm_rift_frequency
	rift_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	rift_noise.fractal_octaves = 2
	rift_noise.fractal_lacunarity = 2.0
	rift_noise.fractal_gain = 0.20

	# 2. 2D Wall Domain Warp Noise (2-octave Fractal FBM for organic fracture fault lines)
	wall_warp_noise = FastNoiseLite.new()
	wall_warp_noise.seed = seed_val + 1012
	wall_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wall_warp_noise.frequency = config.chasm_wall_warp_frequency
	wall_warp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	wall_warp_noise.fractal_octaves = 2
	wall_warp_noise.fractal_lacunarity = 2.0
	wall_warp_noise.fractal_gain = 0.5

	# 3. 2D Floor Heightfield Noise
	floor_noise = FastNoiseLite.new()
	floor_noise.seed = seed_val + 1013
	floor_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	floor_noise.frequency = 0.01

	# 4. 2D Ceiling Heightfield Noise
	ceil_noise = FastNoiseLite.new()
	ceil_noise.seed = seed_val + 1014
	ceil_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ceil_noise.frequency = 0.012

	# 5. 2D Natural Support Column Noise
	pillar_noise = FastNoiseLite.new()
	pillar_noise.seed = seed_val + 1011
	pillar_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	pillar_noise.frequency = config.pillar_frequency

func sample_unwarped_rift(wx: float, wz: float) -> float:
	## Fast normalized [0.0, 1.0] 2D rift corridor density without domain warping or continental mask evaluation.
	return (rift_noise.get_noise_2d(wx, wz) + 1.0) * 0.5

func get_wall_warp_margin() -> float:
	## Conservative margin for unwarped rift early-exit.
	## Accounts for maximum horizontal displacement under 2D domain warping
	## (sqrt(2) * amplitude) scaled by rift noise frequency and noise gradient factor.
	var max_reach = config.chasm_wall_warp_amplitude * 1.4142
	return max_reach * config.chasm_rift_frequency * 2.0

func can_column_contain_chasm(wx: float, wz: float) -> bool:
	## Fast unwarped query to determine if (wx, wz) could possibly be within a chasm void.
	var unwarped_rift = sample_unwarped_rift(wx, wz)
	return unwarped_rift >= (config.chasm_rift_threshold - get_wall_warp_margin())

func _reset_column_to_empty(out: ChasmColumnResult, p_raw_rift: float) -> void:
	out.raw_rift = p_raw_rift
	out.is_chasm = false
	out.is_pillar = false
	out.is_wall = false
	out.is_arena = false
	out.is_arena_ledge = false
	out.is_basalt_column = false
	out.floor_y = 0
	out.ceil_y = 0

func get_warped_coordinates(wx: float, wz: float) -> Vector2:
	## Domain-warps horizontal sampling coordinates using decorrelated offsets
	## to eliminate sterile straight cliff walls and generate natural fracture fault lines.
	var warp_x = wall_warp_noise.get_noise_2d(wx, wz) * config.chasm_wall_warp_amplitude
	var warp_z = wall_warp_noise.get_noise_2d(wx + 43.1, wz + 17.4) * config.chasm_wall_warp_amplitude
	return Vector2(wx + warp_x, wz + warp_z)


const DEEP_INLAND_LAND_THRESHOLD: float = 0.20

var continent_mask = null
var world_bounds: WorldBounds = null
var is_deep_inland: bool = false

func set_continent_mask(p_mask, p_bounds: WorldBounds) -> void:
	continent_mask = p_mask
	world_bounds = p_bounds
	is_deep_inland = false

func reset_inland_cache() -> void:
	is_deep_inland = false

func update_deep_inland_status(min_x: float, min_z: float, max_x: float, max_z: float) -> bool:
	## Samples continent land factor at the 4 cell/chunk corners.
	## If all corners exceed DEEP_INLAND_LAND_THRESHOLD (0.20), the entire cell is deep inland,
	## meaning ocean fade is guaranteed to be 1.0 and continent mask sampling can be bypassed.
	if continent_mask == null or world_bounds == null:
		is_deep_inland = false
		return false

	var c0 = continent_mask.get_land_raw(min_x, min_z, world_bounds)
	var c1 = continent_mask.get_land_raw(max_x, min_z, world_bounds)
	var c2 = continent_mask.get_land_raw(min_x, max_z, world_bounds)
	var c3 = continent_mask.get_land_raw(max_x, max_z, world_bounds)

	is_deep_inland = (
		c0 > DEEP_INLAND_LAND_THRESHOLD and
		c1 > DEEP_INLAND_LAND_THRESHOLD and
		c2 > DEEP_INLAND_LAND_THRESHOLD and
		c3 > DEEP_INLAND_LAND_THRESHOLD
	)
	return is_deep_inland

func sample_rift_mask(sample_x: float, sample_z: float) -> float:
	## Normalized [0.0, 1.0] 2D rift corridor density.
	var rift = (rift_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	if not is_deep_inland and continent_mask != null and world_bounds != null:
		var land_raw = continent_mask.get_land_raw(sample_x, sample_z, world_bounds)
		# Encase subterranean chasms and arenas in solid land before ocean falloff:
		# Ocean falloff slope starts at land_raw ~ 0.12 and reaches sea level at land_raw ~ 0.065.
		# Fading between 0.08 and 0.12 guarantees rock walls encase the cave while surface elevation >= 35.
		var ocean_fade = clampf((land_raw - 0.08) / 0.04, 0.0, 1.0)
		ocean_fade = ocean_fade * ocean_fade * (3.0 - 2.0 * ocean_fade)
		rift *= ocean_fade
	return rift

func is_support_pillar(sample_x: float, sample_z: float, raw_rift: float = -1.0) -> bool:
	## Returns true if the 2D column falls inside a solid vertical stone support pillar.
	# 1. Battle Arena & Approach Corridor Protection:
	# Within active battle arenas and their approach/connecting avenues, support pillars
	# are strictly suppressed to guarantee open multi-directional traversal and prevent entombment.
	if config.arena_enabled:
		var rift = raw_rift if raw_rift >= 0.0 else sample_rift_mask(sample_x, sample_z)
		if rift >= (config.arena_rift_threshold - 0.08):
			return false

	# 2. Primary 2D Column Noise Density Check
	var pil_val = (pillar_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	if pil_val <= config.pillar_threshold:
		return false

	# 3. Discrete Column Shaping (Cross-Noise Intersection):
	# Intersecting decorrelated 2D noise restricts support pillars to localized circular/oval
	# columns (3-6m radius) rather than continuous wall-like dams spanning across chunk boundaries.
	var pil_val2 = (pillar_noise.get_noise_2d(sample_x * 1.8 + 61.7, sample_z * 1.8 + 43.1) + 1.0) * 0.5
	return pil_val2 > (config.pillar_threshold * 0.92)

func calculate_floor_and_ceiling(sample_x: float, sample_z: float, raw_rift: float = 0.0) -> Vector2i:
	## Evaluates floor and ceiling elevations, strictly enforcing bedrock protection and clearance.
	var floor_offset = floor_noise.get_noise_2d(sample_x, sample_z) * config.chasm_floor_variation
	var ceil_offset = ceil_noise.get_noise_2d(sample_x, sample_z) * config.chasm_ceil_variation

	var raw_fl_y = float(config.chasm_min_y) + floor_offset
	var fl_y = int(round(raw_fl_y))
	var cl_y = int(round(float(config.chasm_max_y) + ceil_offset))

	# Arena POI feature: wide, flat battle amphitheater floor with perimeter stepped ledges
	if config.arena_enabled:
		var target_floor = float(config.arena_floor_y)
		if raw_rift >= config.arena_rift_threshold:
			var blend = clampf((raw_rift - config.arena_rift_threshold) / 0.02, 0.0, 1.0)
			if blend >= 1.0:
				# Combat Pit / Arena Center: flat floor
				fl_y = int(target_floor)
				cl_y = maxi(cl_y, config.arena_ceiling_y)
			else:
				# Perimeter spectator ledges: stepped tiers overlooking the battle floor
				var ledge_elev = float(config.arena_ledge_step_height) * sin(blend * PI)
				fl_y = int(round(lerpf(raw_fl_y, target_floor, blend) + ledge_elev))
				cl_y = maxi(cl_y, int(lerpf(float(cl_y), float(config.arena_ceiling_y), blend)))
		elif raw_rift >= (config.arena_rift_threshold - 0.06):
			# Approach / Connecting Avenue: smoothly transitions floor and vaults ceiling
			# so adjacent arena chambers are guaranteed connected by open, walkable thoroughfares
			var approach_blend = (raw_rift - (config.arena_rift_threshold - 0.06)) / 0.06
			fl_y = int(round(lerpf(raw_fl_y, target_floor, approach_blend * 0.75)))
			if config.cave_water_enabled:
				fl_y = maxi(fl_y, config.chasm_water_level + 1)
			cl_y = maxi(cl_y, int(lerpf(float(cl_y), float(config.arena_ceiling_y), approach_blend * 0.75)))

	# Bedrock protection: bedrock is Y=0..2, so floor must never drop below Y=3
	fl_y = maxi(fl_y, 3)

	# Ceiling boundary: ensure ceiling never exceeds configured maximum elevation (unless arena or approach dome)
	if not (config.arena_enabled and raw_rift >= (config.arena_rift_threshold - 0.06)):
		cl_y = mini(cl_y, config.chasm_max_y)

	# Enforce minimum vertical clearance invariant (prevent player/camera trap crevices)
	var min_clearance = int(config.min_chasm_height)
	if cl_y - fl_y < min_clearance:
		cl_y = fl_y + min_clearance

	return Vector2i(fl_y, cl_y)

func is_arena(wx: float, wz: float) -> bool:
	## Returns true if world position falls within a subterranean battle arena.
	if not config.arena_enabled:
		return false
	var unwarped_rift = sample_unwarped_rift(wx, wz)
	if unwarped_rift < (config.arena_rift_threshold - get_wall_warp_margin()):
		return false
	var warped_pos = get_warped_coordinates(wx, wz)
	return sample_rift_mask(warped_pos.x, warped_pos.y) >= config.arena_rift_threshold

func can_arena_intersect_box(min_x: float, min_z: float, max_x: float, max_z: float) -> bool:
	## Coarse AABB query: returns true if any part of the horizontal bounding box
	## intersects an active subterranean battle arena or its perimeter spectator ledges.
	if not config.arena_enabled:
		return false

	var mid_x = (min_x + max_x) * 0.5
	var mid_z = (min_z + max_z) * 0.5
	var unwarped_mid = sample_unwarped_rift(mid_x, mid_z)
	var half_diag = Vector2(max_x - min_x, max_z - min_z).length() * 0.5
	var max_reach = half_diag + get_wall_warp_margin()
	var margin = maxf(0.12, max_reach * config.chasm_rift_frequency * 2.5)

	# 1. Fast O(1) early exit: if unwarped rift at box center cannot reach arena threshold
	# even with maximum domain warp reach and radial distance, exit early.
	if unwarped_mid < (config.arena_rift_threshold - margin):
		return false

	# 2. Check box center point
	if is_arena(mid_x, mid_z):
		return true

	# 3. Check 4 corners
	if is_arena(min_x, min_z) or is_arena(max_x, min_z) or is_arena(min_x, max_z) or is_arena(max_x, max_z):
		return true

	# 4. Check edge midpoints (total 9 sample points)
	if is_arena(mid_x, min_z) or is_arena(mid_x, max_z) or is_arena(min_x, mid_z) or is_arena(max_x, mid_z):
		return true

	# 5. Check warped center proximity to arena transition threshold
	var warped_pos = get_warped_coordinates(mid_x, mid_z)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)
	return raw_rift >= (config.arena_rift_threshold - 0.02)

func can_arena_intersect_chunk(coord: ChunkCoord, bounds: WorldBounds) -> bool:
	## High-level chunk query testing whether the specified chunk intersects an arena.
	if bounds == null or not config.arena_enabled:
		return false
	var c_size = bounds.chunk_size
	var min_x = float(coord.x * c_size) * bounds.voxel_size
	var min_z = float(coord.z * c_size) * bounds.voxel_size
	var max_x = float((coord.x + 1) * c_size) * bounds.voxel_size
	var max_z = float((coord.z + 1) * c_size) * bounds.voxel_size
	return can_arena_intersect_box(min_x, min_z, max_x, max_z)

func sample_column(wx: float, wz: float, out: ChasmColumnResult = null, surface_h: float = -1.0) -> ChasmColumnResult:
	## Evaluates the dual-2D heightmap chasm column at world coordinates (wx, wz).
	## Populates 'out' to avoid per-column heap allocations in hot chunk-carving loops.
	if out == null:
		out = ChasmColumnResult.new()

	# Fast Early-Exit Corridor Masking (Task 1.1)
	# Check unwarped rift noise first. If outside conservative corridor boundary,
	# bypass domain warping, continent mask, floor, ceiling, and pillar noise evaluations.
	var unwarped_rift = sample_unwarped_rift(wx, wz)
	var early_exit_margin = get_wall_warp_margin() + WALL_MARGIN
	if unwarped_rift < (config.chasm_rift_threshold - early_exit_margin):
		_reset_column_to_empty(out, unwarped_rift)
		return out

	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)
	out.raw_rift = raw_rift

	if raw_rift < (config.chasm_rift_threshold - WALL_MARGIN):
		_reset_column_to_empty(out, raw_rift)
		return out

	var is_arena_zone = config.arena_enabled and raw_rift >= config.arena_rift_threshold
	var core_arena_threshold = config.arena_rift_threshold + 0.02
	out.is_arena = is_arena_zone
	out.is_arena_ledge = is_arena_zone and raw_rift < core_arena_threshold

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift)

	# Enforce surface crust barrier: subterranean voids cannot pierce outer terrain crust
	if surface_h >= 0.0:
		var max_allowed_ceil = int(surface_h) - int(config.crust_depth)
		if bounds.y > max_allowed_ceil:
			if max_allowed_ceil - bounds.x < int(config.min_chasm_height):
				out.is_chasm = false
				out.is_pillar = false
				out.is_wall = true
				out.is_arena = false
				out.is_arena_ledge = false
				out.is_basalt_column = false
				out.floor_y = bounds.x
				out.ceil_y = bounds.y
				return out
			else:
				bounds.y = max_allowed_ceil

	if raw_rift < config.chasm_rift_threshold:
		out.is_chasm = false
		out.is_pillar = false
		out.is_wall = true
		out.is_basalt_column = false
		out.floor_y = bounds.x
		out.ceil_y = bounds.y
		return out

	var is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift)
	if is_arena_zone:
		# Pillars are strictly suppressed inside the combat arena and its perimeter rings
		is_pillar_col = false
		if raw_rift < core_arena_threshold:
			# On perimeter ledges, basalt column styling can decorate the stepped ledge floor
			# using the column noise pattern, while remaining 100% open traversable void!
			var pil_val = (pillar_noise.get_noise_2d(warped_pos.x, warped_pos.y) + 1.0) * 0.5
			if pil_val > config.pillar_threshold:
				out.is_basalt_column = true

	if is_pillar_col:
		out.is_chasm = false
		out.is_pillar = true
		out.is_wall = false
		out.floor_y = bounds.x
		out.ceil_y = bounds.y
		return out

	out.is_chasm = true
	out.floor_y = bounds.x
	out.ceil_y = bounds.y
	out.is_pillar = false
	out.is_wall = false
	return out

func can_chasm_intersect_cell(min_p: Vector3, max_p: Vector3) -> bool:
	## Coarse lattice culling: returns false if deep chasm voids cannot intersect this AABB cell.
	# 1. Fast bedrock check
	if max_p.y <= float(config.chasm_min_y):
		is_deep_inland = false
		return false

	# 2. Update chunk-level deep inland status across the 4 corners
	update_deep_inland_status(min_p.x, min_p.z, max_p.x, max_p.z)

	# 3. 2D Coarse AABB check with conservative multi-point sampling across cell & apron
	var mid_x = (min_p.x + max_p.x) * 0.5
	var mid_z = (min_p.z + max_p.z) * 0.5

	# Sample center, 4 corners, and 4 edge midpoints to prevent single-sample false negatives
	# near ocean falloff boundaries or localized rift ridges
	var max_rift = maxf(
		sample_rift_mask(mid_x, mid_z),
		maxf(
			maxf(sample_rift_mask(min_p.x, min_p.z), sample_rift_mask(max_p.x, min_p.z)),
			maxf(sample_rift_mask(min_p.x, max_p.z), sample_rift_mask(max_p.x, max_p.z))
		)
	)
	max_rift = maxf(
		max_rift,
		maxf(
			maxf(sample_rift_mask(mid_x, min_p.z), sample_rift_mask(mid_x, max_p.z)),
			maxf(sample_rift_mask(min_p.x, mid_z), sample_rift_mask(max_p.x, mid_z))
		)
	)

	var half_diag = Vector2(max_p.x - min_p.x, max_p.z - min_p.z).length() * 0.5
	# With 9-point sampling, max distance to nearest sample point is half_diag * 0.5
	var max_reach = (half_diag * 0.5) + config.chasm_wall_warp_amplitude
	var margin = maxf(0.12, max_reach * config.chasm_rift_frequency * 2.5)

	if max_rift < (config.chasm_rift_threshold - margin):
		return false

	# 4. Vertical ceiling check: only expand to arena dome ceiling if arena threshold is reachable in this cell
	var can_arena = config.arena_enabled and (max_rift >= (config.arena_rift_threshold - margin))
	var effective_max_y = float(config.arena_ceiling_y) if can_arena else float(config.chasm_max_y)
	if min_p.y >= effective_max_y:
		return false

	return true


func get_chasm_carve(wx: float, wy: float, wz: float) -> float:
	## Point-query compatibility method for CaveCarver.
	## Returns 1.0 if (wx, wy, wz) is inside carved chasm air void, 0.0 otherwise.
	var effective_max_y = float(config.arena_ceiling_y) if config.arena_enabled else float(config.chasm_max_y)
	if wy <= 2.0 or wy >= effective_max_y:
		return 0.0

	if not can_column_contain_chasm(wx, wz):
		return 0.0

	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)
	if raw_rift < config.chasm_rift_threshold:
		return 0.0

	var is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift)
	if config.arena_enabled and raw_rift >= config.arena_rift_threshold:
		is_pillar_col = false

	if is_pillar_col:
		return 0.0

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift)
	if wy > float(bounds.x) and wy < float(bounds.y):
		return 1.0

	return 0.0

func is_subterranean_water(wx: float, wy: float, wz: float) -> bool:
	## Returns true if voxel is hollow chasm void at or below the chasm water level.
	if not config.cave_water_enabled:
		return false
	if wy > float(config.chasm_water_level):
		return false
	if is_arena(wx, wz):
		return false
	return get_chasm_carve(wx, wy, wz) > 0.05

func sample_chasm(wx: float, wy: float, wz: float) -> Dictionary:
	## Structured point-query compatibility method.
	if not can_column_contain_chasm(wx, wz):
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": false
		}

	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)

	if raw_rift < config.chasm_rift_threshold:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": false
		}

	var is_arena_col = config.arena_enabled and raw_rift >= config.arena_rift_threshold
	var is_pillar_col = is_support_pillar(warped_pos.x, warped_pos.y, raw_rift)
	if is_arena_col:
		is_pillar_col = false

	if is_pillar_col:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": true
		}

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y, raw_rift)
	var is_void = wy > float(bounds.x) and wy < float(bounds.y)
	var is_water = is_void and config.cave_water_enabled and (not is_arena_col) and wy <= float(config.chasm_water_level)

	return {
		"is_chasm": is_void,
		"density": 1.0 if is_void else 0.0,
		"is_water": is_water,
		"is_pillar": false
	}

func get_depth_envelope(wy: float) -> float:
	## Normalized vertical envelope fade for compatibility.
	var min_y = float(config.chasm_min_y)
	var max_y = float(config.chasm_max_y)

	if wy <= min_y or wy >= max_y:
		return 0.0

	var fade_dist = 3.0
	var bottom_fade = clampf((wy - min_y) / fade_dist, 0.0, 1.0)
	var top_fade = clampf((max_y - wy) / fade_dist, 0.0, 1.0)
	return minf(bottom_fade, top_fade)
