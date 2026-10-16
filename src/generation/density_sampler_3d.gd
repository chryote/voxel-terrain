class_name DensitySampler3D
extends RefCounted

## Pure utility for evaluating 3D overhang shape and cave void fields.
## Thread-safe across WorkerThreadPool worker tasks.

var config: VolumetricGeneratorConfig
var overhang_noise: FastNoiseLite
var cave_cheese_noise: FastNoiseLite
var cave_worm_a: FastNoiseLite
var cave_worm_b: FastNoiseLite

func _init(seed_val: int = 1337, p_config: VolumetricGeneratorConfig = null) -> void:
	config = p_config if p_config != null else VolumetricGeneratorConfig.new()

	overhang_noise = FastNoiseLite.new()
	overhang_noise.seed = seed_val + 303
	overhang_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	overhang_noise.frequency = config.overhang_frequency
	overhang_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	overhang_noise.fractal_octaves = 2

	cave_cheese_noise = FastNoiseLite.new()
	cave_cheese_noise.seed = seed_val + 505
	cave_cheese_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_cheese_noise.frequency = config.cave_cheese_frequency
	cave_cheese_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	cave_worm_a = FastNoiseLite.new()
	cave_worm_a.seed = seed_val + 808
	cave_worm_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_worm_a.frequency = config.cave_worm_frequency
	cave_worm_a.fractal_type = FastNoiseLite.FRACTAL_NONE

	cave_worm_b = FastNoiseLite.new()
	cave_worm_b.seed = seed_val + 909
	cave_worm_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_worm_b.frequency = config.cave_worm_frequency
	cave_worm_b.fractal_type = FastNoiseLite.FRACTAL_NONE

func sample_overhang(wx: float, wy: float, wz: float) -> float:
	return overhang_noise.get_noise_3d(wx, wy, wz)

func is_cave(
	wx: float,
	wy: float,
	wz: float,
	depth_from_surface: float,
	y_voxel: int
) -> bool:
	# 1. Surface crust protection: prevent fragile 1-block surface holes
	if depth_from_surface < float(config.cave_min_depth):
		return false

	# 2. Bedrock & Seabed protection: prevent void fall or ocean draining
	if y_voxel <= config.bedrock_level:
		return false
	if y_voxel <= (config.seabed_level + config.cave_seabed_buffer):
		return false

	# 3. Cheese caves (spacious interconnected chambers)
	var cheese = cave_cheese_noise.get_noise_3d(wx, wy, wz)
	if cheese > config.cave_cheese_threshold:
		return true

	# 4. Worm / noodle caves (twisting subterranean tunnels)
	var wa = cave_worm_a.get_noise_3d(wx, wy, wz)
	var wb = cave_worm_b.get_noise_3d(wx, wy, wz)
	if (wa * wa + wb * wb) < config.cave_worm_threshold:
		return true

	return false
