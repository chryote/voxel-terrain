class_name UndergroundChasmSampler
extends RefCounted

## Pure mathematical sampler for the Dual-2D Heightmap Deep Chasms & Abyssal Caverns system.
## Replaces volumetric 3D Simplex noise with two 2D heightfield noise maps (floor and ceiling)
## bounded laterally by a domain-warped 2D tectonic rift corridor mask with vertical walls.
## Guarantees minimum vertical clearance and indestructible bedrock protection.

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
	# 1. 2D Rift Corridor Noise (Simplex Smooth)
	rift_noise = FastNoiseLite.new()
	rift_noise.seed = seed_val + 1010
	rift_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rift_noise.frequency = config.chasm_rift_frequency

	# 2. 2D Wall Domain Warp Noise (Perturbs vertical walls for organic fracture look)
	wall_warp_noise = FastNoiseLite.new()
	wall_warp_noise.seed = seed_val + 1012
	wall_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wall_warp_noise.frequency = config.chasm_wall_warp_frequency

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

func get_warped_coordinates(wx: float, wz: float) -> Vector2:
	## Domain-warps horizontal sampling coordinates to eliminate sterile straight cliff walls.
	var warp_x = wall_warp_noise.get_noise_2d(wx, wz) * config.chasm_wall_warp_amplitude
	var warp_z = wall_warp_noise.get_noise_2d(wx + 100.0, wz + 100.0) * config.chasm_wall_warp_amplitude
	return Vector2(wx + warp_x, wz + warp_z)

func sample_rift_mask(sample_x: float, sample_z: float) -> float:
	## Normalized [0.0, 1.0] 2D rift corridor density.
	return (rift_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5

func is_support_pillar(sample_x: float, sample_z: float) -> bool:
	## Returns true if the 2D column falls inside a solid vertical stone support pillar.
	var pil_val = (pillar_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5
	return pil_val > config.pillar_threshold

func calculate_floor_and_ceiling(sample_x: float, sample_z: float) -> Vector2i:
	## Evaluates floor and ceiling elevations, strictly enforcing bedrock protection and clearance.
	var floor_offset = floor_noise.get_noise_2d(sample_x, sample_z) * config.chasm_floor_variation
	var ceil_offset = ceil_noise.get_noise_2d(sample_x, sample_z) * config.chasm_ceil_variation

	var fl_y = int(round(float(config.chasm_min_y) + floor_offset))
	var cl_y = int(round(float(config.chasm_max_y) + ceil_offset))

	# Bedrock protection: bedrock is Y=0..2, so floor must never drop below Y=3
	fl_y = maxi(fl_y, 3)

	# Ceiling boundary: ensure ceiling never exceeds configured maximum elevation
	cl_y = mini(cl_y, config.chasm_max_y)

	# Enforce minimum vertical clearance invariant (prevent player/camera trap crevices)
	var min_clearance = int(config.min_chasm_height)
	if cl_y - fl_y < min_clearance:
		cl_y = fl_y + min_clearance

	return Vector2i(fl_y, cl_y)

func sample_column(wx: float, wz: float, out: ChasmColumnResult = null) -> ChasmColumnResult:
	## Evaluates the dual-2D heightmap chasm column at world coordinates (wx, wz).
	## Populates 'out' to avoid per-column heap allocations in hot chunk-carving loops.
	if out == null:
		out = ChasmColumnResult.new()

	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)

	if raw_rift < config.chasm_rift_threshold:
		out.is_chasm = false
		out.is_pillar = false
		out.floor_y = 0
		out.ceil_y = 0
		return out

	if is_support_pillar(warped_pos.x, warped_pos.y):
		out.is_chasm = false
		out.is_pillar = true
		out.floor_y = 0
		out.ceil_y = 0
		return out

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y)
	out.is_chasm = true
	out.floor_y = bounds.x
	out.ceil_y = bounds.y
	out.is_pillar = false
	return out

func can_chasm_intersect_cell(min_p: Vector3, max_p: Vector3) -> bool:
	## Coarse lattice culling: returns false if deep chasm voids cannot intersect this AABB cell.
	# 1. Fast vertical strata check
	if max_p.y <= float(config.chasm_min_y) or min_p.y >= float(config.chasm_max_y):
		return false

	# 2. 2D Coarse AABB check on center with conservative margin
	var mid_x = (min_p.x + max_p.x) * 0.5
	var mid_z = (min_p.z + max_p.z) * 0.5
	var raw_rift = sample_rift_mask(mid_x, mid_z)
	if raw_rift < (config.chasm_rift_threshold - 0.15):
		return false

	return true

func get_chasm_carve(wx: float, wy: float, wz: float) -> float:
	## Point-query compatibility method for CaveCarver.
	## Returns 1.0 if (wx, wy, wz) is inside carved chasm air void, 0.0 otherwise.
	if wy <= 2.0 or wy >= float(config.chasm_max_y):
		return 0.0

	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)
	if raw_rift < config.chasm_rift_threshold:
		return 0.0

	if is_support_pillar(warped_pos.x, warped_pos.y):
		return 0.0

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y)
	if wy > float(bounds.x) and wy < float(bounds.y):
		return 1.0

	return 0.0

func is_subterranean_water(wx: float, wy: float, wz: float) -> bool:
	## Returns true if voxel is hollow chasm void at or below the chasm water level.
	if wy > float(config.chasm_water_level):
		return false
	return get_chasm_carve(wx, wy, wz) > 0.05

func sample_chasm(wx: float, wy: float, wz: float) -> Dictionary:
	## Structured point-query compatibility method.
	var warped_pos = get_warped_coordinates(wx, wz)
	var raw_rift = sample_rift_mask(warped_pos.x, warped_pos.y)

	if raw_rift < config.chasm_rift_threshold:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": false
		}

	if is_support_pillar(warped_pos.x, warped_pos.y):
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": true
		}

	var bounds = calculate_floor_and_ceiling(warped_pos.x, warped_pos.y)
	var is_void = wy > float(bounds.x) and wy < float(bounds.y)
	var is_water = is_void and wy <= float(config.chasm_water_level)

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
