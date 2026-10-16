class_name ContinentMask
extends RefCounted

## Pure utility for calculating continent land factor [0.0..1.0] with organic coastlines
## forming a single natural continental landmass surrounded by ocean.

var warp_macro: FastNoiseLite
var warp_meso: FastNoiseLite
var warp_detail: FastNoiseLite
var shape_noise: FastNoiseLite

var coast_falloff_distance: float = 600.0
var coast_warp_amplitude: float = 250.0

func _init(seed_val: int = 1337, config: ContinentGeneratorConfig = null) -> void:
	# 1. Macro warp: broad continental asymmetry (period ~4000-5000m)
	warp_macro = FastNoiseLite.new()
	warp_macro.seed = seed_val + 101
	warp_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_macro.frequency = 0.00022
	warp_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_macro.fractal_octaves = 2
	warp_macro.fractal_gain = 0.5

	# 2. Meso warp: large bays, gulfs, and peninsulas (period ~1500m)
	warp_meso = FastNoiseLite.new()
	warp_meso.seed = seed_val + 202
	warp_meso.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_meso.frequency = 0.00065
	warp_meso.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_meso.fractal_octaves = 2
	warp_meso.fractal_gain = 0.5

	# 3. Detail warp: natural coastal roughness (period ~550m)
	warp_detail = FastNoiseLite.new()
	warp_detail.seed = seed_val + 303
	warp_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_detail.fractal_octaves = 2
	warp_detail.fractal_gain = 0.4

	# 4. Shape noise: multi-fractal organic coastline details
	shape_noise = FastNoiseLite.new()
	shape_noise.seed = seed_val + 404
	shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	shape_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	shape_noise.fractal_octaves = 4
	shape_noise.fractal_lacunarity = 2.1
	shape_noise.fractal_gain = 0.45

	if config != null:
		coast_falloff_distance = config.coast_falloff_distance
		coast_warp_amplitude = config.coast_warp_amplitude
		warp_detail.frequency = config.coast_warp_frequency
		shape_noise.frequency = config.continent_noise_frequency
	else:
		warp_detail.frequency = 0.0018
		shape_noise.frequency = 0.00065

func get_land_raw(wx: float, wz: float, bounds: WorldBounds) -> float:
	var dist_left = wx - bounds.min_world_x
	var dist_right = bounds.max_world_x - wx
	var dist_bottom = wz - bounds.min_world_z
	var dist_top = bounds.max_world_z - wz
	var border_dist = minf(minf(dist_left, dist_right), minf(dist_bottom, dist_top))
	if border_dist <= 0.0:
		return -1.0

	var center_x = (bounds.min_world_x + bounds.max_world_x) * 0.5
	var center_z = (bounds.min_world_z + bounds.max_world_z) * 0.5
	var half_w = (bounds.max_world_x - bounds.min_world_x) * 0.5
	var half_h = (bounds.max_world_z - bounds.min_world_z) * 0.5
	var max_radius = minf(half_w, half_h)

	var macro_amp = max_radius * 0.28
	var meso_amp = max_radius * 0.12
	var detail_amp = max_radius * 0.04

	var mw_x = warp_macro.get_noise_2d(wx, wz) * macro_amp
	var mw_z = warp_macro.get_noise_2d(wx + 4321.0, wz + 4321.0) * macro_amp

	var me_x = warp_meso.get_noise_2d(wx + 1111.0, wz + 2222.0) * meso_amp
	var me_z = warp_meso.get_noise_2d(wx + 3333.0, wz + 4444.0) * meso_amp

	var dw_x = warp_detail.get_noise_2d(wx, wz) * detail_amp
	var dw_z = warp_detail.get_noise_2d(wx + 8765.0, wz + 8765.0) * detail_amp

	var warped_x = wx + mw_x + me_x + dw_x
	var warped_z = wz + mw_z + me_z + dw_z

	var dx = warped_x - center_x
	var dz = warped_z - center_z
	# Slight elliptical stretch (1.1:0.9 ratio) for a natural, non-circular continental mass
	var warped_dist = sqrt(dx * dx * 0.95 + dz * dz * 1.08)
	var norm_dist = warped_dist / max_radius

	# Target continent radius: ~65% of map extent
	var continent_radius = 0.65
	var base_falloff = (continent_radius - norm_dist) / continent_radius

	var shape_n = shape_noise.get_noise_2d(warped_x, warped_z)
	var land_raw = base_falloff + shape_n * 0.38
	return land_raw

func get_factor(gx: int, gz: int, bounds: WorldBounds) -> float:
	var wx = (float(gx) + 0.5) * bounds.voxel_size
	var wz = (float(gz) + 0.5) * bounds.voxel_size
	return get_factor_world(wx, wz, bounds)

func get_factor_world(wx: float, wz: float, bounds: WorldBounds) -> float:
	var dist_left = wx - bounds.min_world_x
	var dist_right = bounds.max_world_x - wx
	var dist_bottom = wz - bounds.min_world_z
	var dist_top = bounds.max_world_z - wz
	var border_dist = minf(minf(dist_left, dist_right), minf(dist_bottom, dist_top))
	if border_dist <= 0.0:
		return 0.0

	var land_raw = get_land_raw(wx, wz, bounds)
	if land_raw <= 0.0:
		return 0.0

	var border_margin = coast_falloff_distance
	var border_fade = clampf(border_dist / border_margin, 0.0, 1.0)
	border_fade = border_fade * border_fade * (3.0 - 2.0 * border_fade)

	var t = clampf(land_raw / 0.16, 0.0, 1.0)
	var factor = t * t * (3.0 - 2.0 * t) * border_fade
	return clampf(factor, 0.0, 1.0)
