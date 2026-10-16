class_name FluvialCarver
extends RefCounted

## Pure component responsible for fluvial drainage networks:
## Wide rivers, small winding streams, and lake basin carving.

var config: ContinentGeneratorConfig

var wide_noise: FastNoiseLite
var wide_warp: FastNoiseLite
var small_noise: FastNoiseLite
var small_warp: FastNoiseLite
var lake_noise: FastNoiseLite

func _init(seed_val: int, p_config: ContinentGeneratorConfig) -> void:
	config = p_config

	# 1. Wide river network + large domain warp
	wide_noise = FastNoiseLite.new()
	wide_noise.seed = seed_val + 505
	wide_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wide_noise.frequency = config.wide_river_frequency

	wide_warp = FastNoiseLite.new()
	wide_warp.seed = seed_val + 506
	wide_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wide_warp.frequency = 0.0012

	# 2. Small winding river network + high-frequency sinuous warp
	small_noise = FastNoiseLite.new()
	small_noise.seed = seed_val + 606
	small_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	small_noise.frequency = config.small_river_frequency

	small_warp = FastNoiseLite.new()
	small_warp.seed = seed_val + 607
	small_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	small_warp.frequency = 0.004

	# 3. Lake basin depression noise
	lake_noise = FastNoiseLite.new()
	lake_noise.seed = seed_val + 707
	lake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lake_noise.frequency = config.lake_frequency
	lake_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	lake_noise.fractal_octaves = 2

func sample_fluvial(wx: float, wz: float, base_elevation: float, continentalness: float) -> Dictionary:
	# In deep ocean / near shelf, water level is sea level and no inland carving is needed
	if continentalness < 0.06:
		return {
			"carve_depth": 0.0,
			"water_elevation": config.sea_level,
			"is_water": base_elevation < float(config.sea_level),
			"is_river": false,
			"is_lake": false
		}

	var carve_wide = 0.0
	var is_wide_river = false
	var wide_water_level = float(config.sea_level)

	# 1. Wide River Evaluation
	var w_wx = wx + wide_warp.get_noise_2d(wx, wz) * config.wide_river_warp_amplitude
	var w_wz = wz + wide_warp.get_noise_2d(wx + 3456.0, wz + 3456.0) * config.wide_river_warp_amplitude
	var w_dist = absf(wide_noise.get_noise_2d(w_wx, w_wz))

	if w_dist < config.wide_river_width_threshold:
		is_wide_river = true
		var f_wide = 1.0 - (w_dist / config.wide_river_width_threshold)
		# Smooth U-shaped parabolic cross section
		carve_wide = f_wide * f_wide * (3.0 - 2.0 * f_wide) * config.wide_river_depth
		# River surface naturally follows valley floor towards sea level
		wide_water_level = maxf(float(config.sea_level), base_elevation - carve_wide * 0.45)

	# 2. Small Winding River Evaluation
	var carve_small = 0.0
	var is_small_river = false
	var small_water_level = float(config.sea_level)

	var s_wx = wx + small_warp.get_noise_2d(wx, wz) * config.small_river_warp_amplitude
	var s_wz = wz + small_warp.get_noise_2d(wx + 7890.0, wz + 7890.0) * config.small_river_warp_amplitude
	var s_dist = absf(small_noise.get_noise_2d(s_wx, s_wz))

	if s_dist < config.small_river_width_threshold:
		is_small_river = true
		var f_small = 1.0 - (s_dist / config.small_river_width_threshold)
		carve_small = f_small * f_small * config.small_river_depth
		small_water_level = maxf(float(config.sea_level), base_elevation - carve_small * 0.40)

	# 3. Lake Basin Evaluation
	var carve_lake = 0.0
	var is_lake = false
	var lake_water_level = float(config.sea_level)

	var l_sample = (lake_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if l_sample > config.lake_threshold and continentalness > 0.12:
		is_lake = true
		var f_lake = (l_sample - config.lake_threshold) / (1.0 - config.lake_threshold)
		carve_lake = pow(f_lake, 1.4) * config.lake_depth
		# Lake water level sits near the outer basin rim
		lake_water_level = maxf(float(config.sea_level), base_elevation - carve_lake * 0.35)

	# Combine fluvial carving: take the dominant depression
	var total_carve = 0.0
	var water_elevation_f = float(config.sea_level)

	if carve_wide > 0.0 or carve_small > 0.0 or carve_lake > 0.0:
		if carve_wide >= carve_small and carve_wide >= carve_lake:
			total_carve = carve_wide
			water_elevation_f = wide_water_level
		elif carve_small >= carve_lake:
			total_carve = carve_small
			water_elevation_f = small_water_level
		else:
			total_carve = carve_lake
			water_elevation_f = lake_water_level
	else:
		return {
			"carve_depth": 0.0,
			"water_elevation": config.sea_level,
			"is_water": base_elevation < float(config.sea_level),
			"is_river": false,
			"is_lake": false
		}

	var final_ground = base_elevation - total_carve
	var is_water = final_ground < water_elevation_f

	return {
		"carve_depth": total_carve,
		"water_elevation": int(round(water_elevation_f)),
		"is_water": is_water,
		"is_river": is_wide_river or is_small_river,
		"is_lake": is_lake
	}

func sample_fluvial_v3(wx: float, wz: float, base_elevation: float, continentalness: float) -> Vector3:
	if continentalness < 0.06:
		return Vector3(0.0, float(config.sea_level), 4.0 if base_elevation < float(config.sea_level) else 0.0)

	var carve_wide = 0.0
	var is_wide_river = false
	var wide_water_level = float(config.sea_level)

	var w_wx = wx + wide_warp.get_noise_2d(wx, wz) * config.wide_river_warp_amplitude
	var w_wz = wz + wide_warp.get_noise_2d(wx + 3456.0, wz + 3456.0) * config.wide_river_warp_amplitude
	var w_dist = absf(wide_noise.get_noise_2d(w_wx, w_wz))

	if w_dist < config.wide_river_width_threshold:
		is_wide_river = true
		var f_wide = 1.0 - (w_dist / config.wide_river_width_threshold)
		carve_wide = f_wide * f_wide * (3.0 - 2.0 * f_wide) * config.wide_river_depth
		wide_water_level = maxf(float(config.sea_level), base_elevation - carve_wide * 0.45)

	var carve_small = 0.0
	var is_small_river = false
	var small_water_level = float(config.sea_level)

	var s_wx = wx + small_warp.get_noise_2d(wx, wz) * config.small_river_warp_amplitude
	var s_wz = wz + small_warp.get_noise_2d(wx + 7890.0, wz + 7890.0) * config.small_river_warp_amplitude
	var s_dist = absf(small_noise.get_noise_2d(s_wx, s_wz))

	if s_dist < config.small_river_width_threshold:
		is_small_river = true
		var f_small = 1.0 - (s_dist / config.small_river_width_threshold)
		carve_small = f_small * f_small * config.small_river_depth
		small_water_level = maxf(float(config.sea_level), base_elevation - carve_small * 0.40)

	var carve_lake = 0.0
	var is_lake = false
	var lake_water_level = float(config.sea_level)

	var l_sample = (lake_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if l_sample > config.lake_threshold and continentalness > 0.12:
		is_lake = true
		var f_lake = (l_sample - config.lake_threshold) / (1.0 - config.lake_threshold)
		carve_lake = pow(f_lake, 1.4) * config.lake_depth
		lake_water_level = maxf(float(config.sea_level), base_elevation - carve_lake * 0.35)

	if carve_wide <= 0.0 and carve_small <= 0.0 and carve_lake <= 0.0:
		return Vector3(0.0, float(config.sea_level), 4.0 if base_elevation < float(config.sea_level) else 0.0)

	var total_carve = 0.0
	var water_elevation_f = float(config.sea_level)

	if carve_wide >= carve_small and carve_wide >= carve_lake:
		total_carve = carve_wide
		water_elevation_f = wide_water_level
	elif carve_small >= carve_lake:
		total_carve = carve_small
		water_elevation_f = small_water_level
	else:
		total_carve = carve_lake
		water_elevation_f = lake_water_level

	var flags = 0
	if is_wide_river or is_small_river:
		flags |= 1
	if is_lake:
		flags |= 2
	if (base_elevation - total_carve) < water_elevation_f:
		flags |= 4

	return Vector3(total_carve, water_elevation_f, float(flags))
