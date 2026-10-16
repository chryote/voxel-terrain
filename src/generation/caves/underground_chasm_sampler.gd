class_name UndergroundChasmSampler
extends RefCounted

## Pure component responsible for deep-strata 3D cavern voids, natural support pillars,
## and subterranean water table allocation (Layered Arena ready).
## Restricts massive abyssal hollows to deep elevation levels (Y: 4-22), leaving an intact
## vaulted ceiling above and solid bedrock below, while pooling subterranean water at Y <= 10.

var config: CaveGeneratorConfig

var chasm_noise: FastNoiseLite
var pillar_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: CaveGeneratorConfig = null) -> void:
	config = p_config if p_config != null else CaveGeneratorConfig.new()

	# 1. Macro 3D cavern void FBM noise
	chasm_noise = FastNoiseLite.new()
	chasm_noise.seed = seed_val + 1010
	chasm_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	chasm_noise.frequency = config.chasm_frequency
	chasm_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	chasm_noise.fractal_octaves = 3
	chasm_noise.fractal_lacunarity = 2.0
	chasm_noise.fractal_gain = 0.5

	# 2. Support pillar noise (vertical natural stone columns)
	pillar_noise = FastNoiseLite.new()
	pillar_noise.seed = seed_val + 1011
	pillar_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	pillar_noise.frequency = config.pillar_frequency

func get_depth_envelope(wy: float) -> float:
	var min_y = float(config.chasm_min_y)
	var max_y = float(config.chasm_max_y)

	if wy <= min_y or wy >= max_y:
		return 0.0

	var fade_dist = 3.0
	var bottom_fade = clampf((wy - min_y) / fade_dist, 0.0, 1.0)
	var top_fade = clampf((max_y - wy) / fade_dist, 0.0, 1.0)
	return minf(bottom_fade, top_fade)

func sample_chasm(wx: float, wy: float, wz: float) -> Dictionary:
	var envelope = get_depth_envelope(wy)
	if envelope <= 0.0001:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": false
		}

	# Check for natural vertical support pillars
	var pil_val = (pillar_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if pil_val > config.pillar_threshold:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": true
		}

	# Sample 3D chasm cavity
	var raw_chasm = (chasm_noise.get_noise_3d(wx, wy * 0.7, wz) + 1.0) * 0.5
	if raw_chasm < config.chasm_threshold:
		return {
			"is_chasm": false,
			"density": 0.0,
			"is_water": false,
			"is_pillar": false
		}

	# Calculate carve density scaled by vertical depth envelope
	var raw_factor = (raw_chasm - config.chasm_threshold) / (1.0 - config.chasm_threshold)
	var carve_density = raw_factor * envelope

	# Subterranean water allocation: voids below chasm_water_level pool water
	var is_water = wy <= float(config.chasm_water_level)

	return {
		"is_chasm": carve_density > 0.05,
		"density": carve_density,
		"is_water": is_water,
		"is_pillar": false
	}

func get_chasm_carve(wx: float, wy: float, wz: float) -> float:
	var envelope = get_depth_envelope(wy)
	if envelope <= 0.0001:
		return 0.0

	var pil_val = (pillar_noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	if pil_val > config.pillar_threshold:
		return 0.0

	var raw_chasm = (chasm_noise.get_noise_3d(wx, wy * 0.7, wz) + 1.0) * 0.5
	if raw_chasm < config.chasm_threshold:
		return 0.0

	var raw_factor = (raw_chasm - config.chasm_threshold) / (1.0 - config.chasm_threshold)
	return raw_factor * envelope

func is_subterranean_water(wx: float, wy: float, wz: float) -> bool:
	if wy > float(config.chasm_water_level):
		return false
	return get_chasm_carve(wx, wy, wz) > 0.05
