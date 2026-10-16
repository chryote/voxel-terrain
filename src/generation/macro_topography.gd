class_name MacroTopography
extends RefCounted

## Pure component responsible for synthesizing continental macro-elevation:
## Coasts, Lowlands, Rolling Hills, Highlands, and Mountainous Regions.

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

func sample_macro(wx: float, wz: float, bounds: WorldBounds) -> Dictionary:
	var land_factor = mask.get_factor_world(wx, wz, bounds)
	if land_factor <= 0.001:
		return {
			"elevation": float(config.seabed_level),
			"land_factor": 0.0,
			"continentalness": 0.0,
			"erosion": 1.0,
			"is_highland": false,
			"is_mountain": false
		}

	# Continentalness [0.0..1.0]
	var c_sample = (cont_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var continentalness = land_factor * (0.25 + 0.75 * c_sample)

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
		var mountain_weight = (1.0 - erosion) * clampf((continentalness - 0.20) / 0.30, 0.0, 1.0)
		h_mountain = m_ridge * mountain_weight
		if h_mountain > 15.0:
			is_mountain = true

	# Blend rolling hills into lowlands based on erosion
	var base_relief = lerpf(h_hills, h_low, erosion)
	var total_land_h = base_relief + h_highland + h_mountain

	# Smooth coastal transition: slopes from seabed up through beaches to land
	var coast_t = clampf(continentalness / 0.14, 0.0, 1.0)
	coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t)
	var final_h = lerpf(float(config.seabed_level), total_land_h, coast_t)

	return {
		"elevation": final_h,
		"land_factor": land_factor,
		"continentalness": continentalness,
		"erosion": erosion,
		"is_highland": is_highland,
		"is_mountain": is_mountain
	}

func sample_macro_v2(wx: float, wz: float, bounds: WorldBounds) -> Vector2:
	var land_factor = mask.get_factor_world(wx, wz, bounds)
	if land_factor <= 0.001:
		return Vector2(float(config.seabed_level), 0.0)

	var c_sample = (cont_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var continentalness = land_factor * (0.25 + 0.75 * c_sample)
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
		var mountain_weight = (1.0 - erosion) * clampf((continentalness - 0.20) / 0.30, 0.0, 1.0)
		h_mountain = m_ridge * mountain_weight

	var base_relief = lerpf(h_hills, h_low, erosion)
	var total_land_h = base_relief + h_highland + h_mountain

	var coast_t = clampf(continentalness / 0.14, 0.0, 1.0)
	coast_t = coast_t * coast_t * (3.0 - 2.0 * coast_t)
	var final_h = lerpf(float(config.seabed_level), total_land_h, coast_t)

	return Vector2(final_h, continentalness)
