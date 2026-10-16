class_name CaveMouthSampler
extends RefCounted

## Pure component responsible for 2D cave mouth detection and surface portal generation.
## Pinpoints discrete cave entrances on dry land/hillsides and carves downward-descending
## funnels that connect surface terrain to subterranean cave networks while sealing
## surface crust elsewhere to prevent accidental skyward punctures.

var config: CaveGeneratorConfig

var mouth_noise: FastNoiseLite
var mouth_warp: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()

	mouth_noise = FastNoiseLite.new()
	mouth_noise.seed = seed_val + 808
	mouth_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mouth_noise.frequency = config.mouth_frequency

	mouth_warp = FastNoiseLite.new()
	mouth_warp.seed = seed_val + 809
	mouth_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mouth_warp.frequency = config.mouth_frequency * 2.5

func is_dry_land(surface_h: float, sea_level: int) -> bool:
	return surface_h >= float(sea_level) + config.water_safety_margin

func sample_raw_noise(wx: float, wz: float) -> float:
	# Subtle organic domain warp on mouth boundary
	var warp_offset_x = mouth_warp.get_noise_2d(wx, wz) * 12.0
	var warp_offset_z = mouth_warp.get_noise_2d(wx + 1234.0, wz + 5678.0) * 12.0
	return mouth_noise.get_noise_2d(wx + warp_offset_x, wz + warp_offset_z)

func sample_mouth(wx: float, wz: float, surface_h: float, sea_level: int) -> Dictionary:
	# Cave mouths only spawn on dry land well above water table
	if not is_dry_land(surface_h, sea_level):
		return {
			"is_mouth": false,
			"intensity": 0.0,
			"carve_depth": 0.0,
			"bottom_y": surface_h,
			"effective_radius": 0.0
		}

	var raw_n = sample_raw_noise(wx, wz)
	if raw_n < config.mouth_threshold:
		return {
			"is_mouth": false,
			"intensity": 0.0,
			"carve_depth": 0.0,
			"bottom_y": surface_h,
			"effective_radius": 0.0
		}

	# Normalized intensity in [0.0, 1.0] from threshold to noise peak
	var intensity = clampf((raw_n - config.mouth_threshold) / (1.0 - config.mouth_threshold), 0.0, 1.0)
	# Smooth parabolic falloff: maximum depth and radius at epicenter
	var smooth_i = intensity * intensity * (3.0 - 2.0 * intensity)
	var carve_depth = smooth_i * config.max_entrance_depth
	var bottom_y = surface_h - carve_depth
	var eff_radius = smooth_i * config.mouth_radius

	return {
		"is_mouth": true,
		"intensity": smooth_i,
		"carve_depth": carve_depth,
		"bottom_y": bottom_y,
		"effective_radius": eff_radius
	}

func is_mouth_candidate(wx: float, wz: float, surface_h: float, sea_level: int) -> bool:
	if not is_dry_land(surface_h, sea_level):
		return false
	return sample_raw_noise(wx, wz) >= config.mouth_threshold

func can_mouth_intersect_cell(min_p: Vector3, max_p: Vector3, max_surface_h: float, sea_level: int) -> bool:
	## Coarse culling: returns true if an entrance funnel could possibly intersect this cell.
	if max_p.y < (max_surface_h - config.max_entrance_depth):
		return false
	if not is_dry_land(max_surface_h, sea_level):
		return false

	var r = config.mouth_radius
	for mx in [min_p.x - r, min_p.x, max_p.x, max_p.x + r]:
		for mz in [min_p.z - r, min_p.z, max_p.z, max_p.z + r]:
			if is_mouth_candidate(mx, mz, max_surface_h, sea_level):
				return true
	return false

func get_funnel_carve(wx: float, wy: float, wz: float, surface_h: float, sea_level: int) -> float:
	## Returns positive carve density (>0 means hollow air) or 0.0 if not carved by entrance funnel.
	# Early elevation check: funnels cannot extend below max entrance depth or above surface clearance
	if wy < (surface_h - config.max_entrance_depth) or wy > (surface_h + 1.0):
		return 0.0

	var mouth_info = sample_mouth(wx, wz, surface_h, sea_level)
	if not mouth_info.is_mouth:
		return 0.0

	var bottom_y: float = mouth_info.bottom_y
	# Carve an opening starting from bottom_y up to surface_h (and slightly above surface for head clearance)
	if wy >= bottom_y and wy <= surface_h + 1.0:
		# Return positive density: strongest in center, tapering towards edges
		var vertical_factor = 1.0 - absf((wy - (bottom_y + surface_h) * 0.5) / (mouth_info.carve_depth * 0.5 + 0.5))
		return maxf(0.1, mouth_info.intensity * clampf(vertical_factor, 0.2, 1.0))

	return 0.0

func is_crust_sealed(wx: float, wy: float, wz: float, surface_h: float, sea_level: int) -> bool:
	## Returns true if this coordinate falls within the protected surface crust
	## and is NOT inside an active cave mouth.
	var crust_bottom = surface_h - config.crust_depth
	if wy >= crust_bottom and wy <= surface_h:
		# If it's inside an active cave mouth, the crust is open (not sealed)
		var mouth_info = sample_mouth(wx, wz, surface_h, sea_level)
		if mouth_info.is_mouth:
			return false
		return true
	return false
