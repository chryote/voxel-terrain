class_name ClimateModel
extends RefCounted

## Pure component responsible for continuous moisture and climate simulation
## across the procedural continent.
##
## Decoupled from scene nodes, UI, and world layers for testability and performance.

var config: ContinentGeneratorConfig
var moisture_noise: FastNoiseLite

func _init(seed_val: int = 1337, p_config: ContinentGeneratorConfig = null) -> void:
	config = p_config if p_config != null else ContinentGeneratorConfig.new()

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = seed_val + 808
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = config.moisture_frequency
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = config.moisture_octaves
	moisture_noise.fractal_gain = config.moisture_fractal_gain

## Samples normalized moisture in range [0.0..1.0] at world coordinate (wx, wz).
## Lower values represent arid/dry areas (e.g. sand banks), higher values represent lush/humid areas.
func sample_moisture(wx: float, wz: float) -> float:
	var raw_n = moisture_noise.get_noise_2d(wx, wz)
	return clampf((raw_n + 1.0) * 0.5, 0.0, 1.0)

## Returns true if the sampled moisture satisfies the humid threshold (e.g. forest lake).
func is_humid(moisture: float) -> bool:
	return moisture >= config.moisture_beach_threshold

## Returns true if the sampled moisture represents an arid / dry zone.
func is_arid(moisture: float) -> bool:
	return moisture < config.moisture_beach_threshold
