class_name MacroTopography
extends RefCounted

## Pure component responsible for synthesizing continental macro-elevation:
## Coasts, Lowlands, Rolling Hills, Highlands, Mountainous Regions, and Offshore Cliff Islands.

var config: ContinentGeneratorConfig
var mask: ContinentMask

var cont_noise: FastNoiseLite
var erosion_noise: FastNoiseLite
var lowland_noise: FastNoiseLite
var hills_noise: FastNoiseLite
var highland_noise: FastNoiseLite
var mountain_noise: FastNoiseLite

func _init(seed_val: int, p_config: ContinentGeneratorConfig, p_mask: ContinentMask) -> void:
	config = p_config
	mask = p_mask

	# 1. Continentalness Noise (macro distance from ocean)
	cont_noise = FastNoiseLite.new()
	cont_noise.seed = seed_val
	cont_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cont_noise.frequency = config.continent_noise_frequency
	cont_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	cont_noise.fractal_octaves = 3

	# 2. Erosion / Relief Noise (flat plains vs rugged relief)
	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = seed_val + 101
	erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion_noise.frequency = config.erosion_frequency
	erosion_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	erosion_noise.fractal_octaves = 3

	# 3. Lowland Noise (gentle micro-undulations)
	lowland_noise = FastNoiseLite.new()
	lowland_noise.seed = seed_val + 202
	lowland_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lowland_noise.frequency = config.lowland_frequency
	lowland_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	lowland_noise.fractal_octaves = 2

	# 4. Rolling Hills Noise (harmonic billowy crests)
	hills_noise = FastNoiseLite.new()
	hills_noise.seed = seed_val + 303
	hills_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills_noise.frequency = config.rolling_hills_frequency
	hills_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	hills_noise.fractal_octaves = 3

	# 5. Highland Plateau Noise
	highland_noise = FastNoiseLite.new()
	highland_noise.seed = seed_val + 404
	highland_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	highland_noise.frequency = config.highland_frequency
	highland_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	highland_noise.fractal_octaves = 3

	# 6. Mountain Noise (ridged multifractal chains)
	mountain_noise = FastNoiseLite.new()
	mountain_noise.seed = seed_val + 777
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain_noise.frequency = config.mountain_frequency
	mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	mountain_noise.fractal_octaves = config.mountain_octaves
	mountain_noise.fractal_gain = config.mountain_fractal_gain
	mountain_noise.fractal_lacunarity = config.mountain_lacunarity

## Evaluates strictly offshore cliff island elevation and material zone at exact 1x1 resolution.
## Returns Vector3(elevation, island_zone_type, isl_norm):
##   island_zone_type == 0.0 -> Not an offshore island
##   island_zone_type == 1.0 -> Submerged island pedestal (ID_SEABED)
##   island_zone_type == 2.0 -> Raised stone cliff wall, stone stair-terrace entry, or stone cliff rim (ID_STONE)
##   island_zone_type == 3.0 -> Innermost flat plateau cap (ID_GRASS top, ID_STONE side)
func sample_offshore_island(wx: float, wz: float, bounds: WorldBounds) -> Vector3:
	if not mask.islands_enabled or not mask.has_method("sample_offshore_island"):
		return Vector3.ZERO

	var isl_info = mask.sample_offshore_island(wx, wz, bounds)
	var isl_norm = isl_info.x
	if isl_norm <= 0.001:
		return Vector3.ZERO

	var entry_blend = isl_info.y
	var seabed = float(config.seabed_level)
	var sea = float(config.sea_level)
	var cliff_h = maxf(4.0, config.island_cliff_height)

	# 1. Underwater island pedestal rising from seabed to sea_level - 1
	var shore_threshold = 0.15
	if isl_norm < shore_threshold:
		var base_t = isl_norm / shore_threshold
		var smooth_base = base_t * base_t * (3.0 - 2.0 * base_t)
		var sub_h = lerpf(seabed, sea - 1.0, smooth_base)
		return Vector3(sub_h, 1.0, isl_norm)

	# 2. Above sea level: flat vertical cliff raise with regular stair-terrace entry sector
	var u = clampf((isl_norm - shore_threshold) / (1.0 - shore_threshold), 0.0, 1.0)
	var terrace_span = clampf(config.island_terrace_span, 0.15, 0.85)
	var stair_span = lerpf(0.02, terrace_span, entry_blend)
	var stair_progress = clampf(u / stair_span, 0.0, 1.0)

	var step_h = maxf(1.0, float(config.island_terrace_step_height))
	var num_steps = maxf(1.0, roundf(cliff_h / step_h))
	var terrace_raise = (floorf(stair_progress * num_steps) / num_steps) * cliff_h if stair_progress < 1.0 else cliff_h

	var final_h = sea + terrace_raise
	var is_inner_plateau = (stair_progress >= 1.0) and (u >= (terrace_span + 0.10))
	var zone_type = 3.0 if is_inner_plateau else 2.0
	return Vector3(final_h, zone_type, isl_norm)

func sample_macro(wx: float, wz: float, bounds: WorldBounds) -> Dictionary:
	var isl = sample_offshore_island(wx, wz, bounds)
	if isl.y > 0.0:
		return {
			"elevation": isl.x,
			"land_factor": clampf(isl.z, 0.0, 1.0),
			"continentalness": 0.0,
			"erosion": 1.0,
			"is_highland": false,
			"is_mountain": false,
			"is_offshore_island": true,
			"island_zone_type": int(isl.y)
		}

	var main_raw = mask.get_main_continent_raw(wx, wz, bounds) if mask.has_method("get_main_continent_raw") else mask.get_land_raw(wx, wz, bounds)
	if main_raw <= 0.0:
		return {
			"elevation": float(config.seabed_level),
			"land_factor": 0.0,
			"continentalness": 0.0,
			"erosion": 1.0,
			"is_highland": false,
			"is_mountain": false,
			"is_offshore_island": false,
			"island_zone_type": 0
		}

	var dist_left = wx - bounds.min_world_x
	var dist_right = bounds.max_world_x - wx
	var dist_bottom = wz - bounds.min_world_z
	var dist_top = bounds.max_world_z - wz
	var border_dist = minf(minf(dist_left, dist_right), minf(dist_bottom, dist_top))
	var border_fade = clampf(border_dist / maxf(1.0, mask.coast_falloff_distance), 0.0, 1.0)
	border_fade = border_fade * border_fade * (3.0 - 2.0 * border_fade)
	var t_mask = clampf(main_raw / 0.16, 0.0, 1.0)
	var land_factor = clampf(t_mask * t_mask * (3.0 - 2.0 * t_mask) * border_fade, 0.0, 1.0)

	if land_factor <= 0.001:
		return {
			"elevation": float(config.seabed_level),
			"land_factor": 0.0,
			"continentalness": 0.0,
			"erosion": 1.0,
			"is_highland": false,
			"is_mountain": false,
			"is_offshore_island": false,
			"island_zone_type": 0
		}

	# Continentalness [0.0..1.0] naturally increases towards continent interior
	var inland_gradient = clampf(main_raw, 0.0, 1.0)
	var c_sample = (cont_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var continentalness = land_factor * (inland_gradient * 0.6 + c_sample * 0.4)

	# Erosion [0.0..1.0] (0 = jagged/mountainous, 1 = flat/smooth)
	var erosion = (erosion_noise.get_noise_2d(wx, wz) + 1.0) * 0.5

	# 1. Lowland layer
	var low_n = (lowland_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var h_low = config.lowland_base_elevation + low_n * config.lowland_amplitude

	# 2. Rolling hills layer (billowy wave-like rounded peaks)
	var hill_raw = hills_noise.get_noise_2d(wx, wz)
	var hill_billow = absf(hill_raw) * 2.0 - 1.0
	var h_hills = config.lowland_base_elevation + (hill_billow * 0.5 + 0.5) * config.rolling_hills_amplitude

	# 3. Highland plateau uplift
	var is_highland = false
	var h_highland = 0.0
	if continentalness > config.highland_threshold:
		var hl_n = (highland_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
		var plateau_t = clampf((continentalness - config.highland_threshold) / 0.25, 0.0, 1.0)
		var plateau_step = plateau_t * plateau_t * (3.0 - 2.0 * plateau_t)
		h_highland = plateau_step * (config.highland_boost + hl_n * 12.0)
		if plateau_step > 0.5:
			is_highland = true

	# 4. Mountain ridges
	var is_mountain = false
	var h_mountain = 0.0
	var m_sample = (mountain_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if m_sample > config.mountain_threshold:
		var m_norm = (m_sample - config.mountain_threshold) / (1.0 - config.mountain_threshold)
		var m_ridge = pow(m_norm, config.mountain_power) * config.mountain_amplitude
		var mountain_weight = (1.0 - erosion) * clampf((continentalness - 0.25) / 0.35, 0.0, 1.0)
		h_mountain = m_ridge * mountain_weight
		if h_mountain > 15.0:
			is_mountain = true

	# Blend rolling hills into lowlands based on erosion
	var base_relief = lerpf(h_hills, h_low, erosion)
	var total_land_h = base_relief + h_highland + h_mountain + config.inland_elevation_bias

	# Smooth coastal transition: slopes from seabed up through beaches to land
	var coast_t = clampf(continentalness / 0.12, 0.0, 1.0)
	coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t)
	var final_h = lerpf(float(config.seabed_level), total_land_h, coast_t)

	return {
		"elevation": final_h,
		"land_factor": land_factor,
		"continentalness": continentalness,
		"erosion": erosion,
		"is_highland": is_highland,
		"is_mountain": is_mountain,
		"is_offshore_island": false,
		"island_zone_type": 0
	}

func sample_macro_v2(wx: float, wz: float, bounds: WorldBounds) -> Vector2:
	var main_raw = mask.get_main_continent_raw(wx, wz, bounds) if mask.has_method("get_main_continent_raw") else mask.get_land_raw(wx, wz, bounds)
	if main_raw <= 0.0:
		return Vector2(float(config.seabed_level), 0.0)

	var dist_left = wx - bounds.min_world_x
	var dist_right = bounds.max_world_x - wx
	var dist_bottom = wz - bounds.min_world_z
	var dist_top = bounds.max_world_z - wz
	var border_dist = minf(minf(dist_left, dist_right), minf(dist_bottom, dist_top))
	if border_dist <= 0.0:
		return Vector2(float(config.seabed_level), 0.0)

	var border_fade = clampf(border_dist / maxf(1.0, mask.coast_falloff_distance), 0.0, 1.0)
	border_fade = border_fade * border_fade * (3.0 - 2.0 * border_fade)
	var t_mask = clampf(main_raw / 0.16, 0.0, 1.0)
	var land_factor = clampf(t_mask * t_mask * (3.0 - 2.0 * t_mask) * border_fade, 0.0, 1.0)
	if land_factor <= 0.001:
		return Vector2(float(config.seabed_level), 0.0)

	var inland_gradient = clampf(main_raw, 0.0, 1.0)
	var c_sample = (cont_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var continentalness = land_factor * (inland_gradient * 0.6 + c_sample * 0.4)
	var erosion = (erosion_noise.get_noise_2d(wx, wz) + 1.0) * 0.5

	var low_n = (lowland_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var h_low = config.lowland_base_elevation + low_n * config.lowland_amplitude

	var hill_raw = hills_noise.get_noise_2d(wx, wz)
	var hill_billow = absf(hill_raw) * 2.0 - 1.0
	var h_hills = config.lowland_base_elevation + (hill_billow * 0.5 + 0.5) * config.rolling_hills_amplitude

	var h_highland = 0.0
	if continentalness > config.highland_threshold:
		var hl_n = (highland_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
		var plateau_t = clampf((continentalness - config.highland_threshold) / 0.25, 0.0, 1.0)
		var plateau_step = plateau_t * plateau_t * (3.0 - 2.0 * plateau_t)
		h_highland = plateau_step * (config.highland_boost + hl_n * 12.0)

	var h_mountain = 0.0
	var m_sample = (mountain_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if m_sample > config.mountain_threshold:
		var m_norm = (m_sample - config.mountain_threshold) / (1.0 - config.mountain_threshold)
		var m_ridge = pow(m_norm, config.mountain_power) * config.mountain_amplitude
		var mountain_weight = (1.0 - erosion) * clampf((continentalness - 0.25) / 0.35, 0.0, 1.0)
		h_mountain = m_ridge * mountain_weight

	var base_relief = lerpf(h_hills, h_low, erosion)
	var total_land_h = base_relief + h_highland + h_mountain + config.inland_elevation_bias

	var coast_t = clampf(continentalness / 0.12, 0.0, 1.0)
	coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t)
	var final_h = lerpf(float(config.seabed_level), total_land_h, coast_t)

	return Vector2(final_h, continentalness)

## Fast coarse-grid bilinear interpolation for single-column sampling
func sample_macro_interpolated(wx: float, wz: float, bounds: WorldBounds, stride: int = 4) -> Vector2:
	var gx = int(floor(wx / bounds.voxel_size - 0.5))
	var gz = int(floor(wz / bounds.voxel_size - 0.5))
	var gx0 = int(floor(float(gx) / float(stride))) * stride
	var gx1 = gx0 + stride
	var gz0 = int(floor(float(gz) / float(stride))) * stride
	var gz1 = gz0 + stride
	var tx = float(gx - gx0) / float(stride)
	var tz = float(gz - gz0) / float(stride)

	var wx0 = (float(gx0) + 0.5) * bounds.voxel_size
	var wx1 = (float(gx1) + 0.5) * bounds.voxel_size
	var wz0 = (float(gz0) + 0.5) * bounds.voxel_size
	var wz1 = (float(gz1) + 0.5) * bounds.voxel_size

	var c00 = sample_macro_v2(wx0, wz0, bounds)
	var c10 = sample_macro_v2(wx1, wz0, bounds)
	var c01 = sample_macro_v2(wx0, wz1, bounds)
	var c11 = sample_macro_v2(wx1, wz1, bounds)

	var c0 = c00.lerp(c10, tx)
	var c1 = c01.lerp(c11, tx)
	return c0.lerp(c1, tz)
