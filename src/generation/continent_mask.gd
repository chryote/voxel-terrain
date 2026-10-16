class_name ContinentMask
extends RefCounted

## Pure utility for calculating continent land factor [0.0..1.0] with organic coastlines.

var warp_noise: FastNoiseLite
var coast_falloff_distance: float = 600.0
var coast_warp_amplitude: float = 250.0

func _init(seed_val: int = 1337, config: ContinentGeneratorConfig = null) -> void:
	warp_noise = FastNoiseLite.new()
	warp_noise.seed = seed_val + 101
	warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	
	if config != null:
		coast_falloff_distance = config.coast_falloff_distance
		coast_warp_amplitude = config.coast_warp_amplitude
		warp_noise.frequency = config.coast_warp_frequency
	else:
		warp_noise.frequency = 0.002

func get_factor(gx: int, gz: int, bounds: WorldBounds) -> float:
	var wx = (float(gx) + 0.5) * bounds.voxel_size
	var wz = (float(gz) + 0.5) * bounds.voxel_size
	return get_factor_world(wx, wz, bounds)

func get_factor_world(wx: float, wz: float, bounds: WorldBounds) -> float:
	var dist_left = wx - bounds.min_world_x
	var dist_right = bounds.max_world_x - wx
	var dist_bottom = wz - bounds.min_world_z
	var dist_top = bounds.max_world_z - wz

	var min_border_dist = minf(minf(dist_left, dist_right), minf(dist_bottom, dist_top))
	if min_border_dist <= 0.0:
		return 0.0

	var warp = warp_noise.get_noise_2d(wx, wz) * coast_warp_amplitude
	var effective_dist = min_border_dist + warp

	if effective_dist <= 0.0:
		return 0.0

	var t = clampf(effective_dist / coast_falloff_distance, 0.0, 1.0)
	# Cubic smoothstep for natural transition
	return t * t * (3.0 - 2.0 * t)
