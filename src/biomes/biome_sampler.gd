class_name BiomeSampler
extends RefCounted

## Procedural climate and biome sampler using multi-octave simplex noise
## to determine temperature, humidity, and biome classifications.

const BiomeRegistryClass = preload("res://src/biomes/biome_registry.gd")
const BiomeDefClass = preload("res://src/biomes/biome_def.gd")

var registry: BiomeRegistry
var world_seed: int = 1337
var sea_level: float = 24.0

var _temp_noise: FastNoiseLite
var _hum_noise: FastNoiseLite

func _init(p_registry: BiomeRegistry = null, p_seed: int = 1337, p_sea_level: float = 24.0) -> void:
	registry = p_registry if p_registry != null else BiomeRegistryClass.create_default_registry()
	world_seed = p_seed
	sea_level = p_sea_level

	_temp_noise = FastNoiseLite.new()
	_temp_noise.seed = world_seed + 101
	_temp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_temp_noise.frequency = 0.0008
	_temp_noise.fractal_octaves = 3

	_hum_noise = FastNoiseLite.new()
	_hum_noise.seed = world_seed + 202
	_hum_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hum_noise.frequency = 0.0008
	_hum_noise.fractal_octaves = 3

## Returns (temperature, humidity) normalized to [-1.0, 1.0]
func sample_climate(world_x: float, world_z: float) -> Vector2:
	var temp = _temp_noise.get_noise_2d(world_x, world_z)
	var hum = _hum_noise.get_noise_2d(world_x, world_z)
	return Vector2(temp, hum)

## Classifies the dominant biome at the given world coordinates and elevation
func get_biome_at(world_x: float, world_z: float, elevation: float) -> BiomeDef:
	if registry == null or registry.biomes.is_empty():
		return null

	# 1. Height-based priority overrides (Ocean, Beach, Mountain Peaks)
	if elevation < (sea_level - 1.0):
		var ocean = registry.get_biome(BiomeRegistry.BIOME_OCEAN)
		if ocean != null:
			return ocean
	elif elevation <= (sea_level + 2.5):
		var beach = registry.get_biome(BiomeRegistry.BIOME_BEACH)
		if beach != null:
			return beach
	elif elevation >= 130.0:
		var mountain = registry.get_biome(BiomeRegistry.BIOME_MOUNTAINS)
		if mountain != null:
			return mountain

	# 2. Climate-based selection (Temperature & Humidity)
	var climate = sample_climate(world_x, world_z)
	var best_biome: BiomeDef = null
	var min_dist_sq: float = INF

	for b in registry.biomes:
		if b == null:
			continue
		# Skip extreme altitude biomes during inland climate evaluation
		if b.id == BiomeRegistry.BIOME_OCEAN or b.id == BiomeRegistry.BIOME_BEACH or b.id == BiomeRegistry.BIOME_MOUNTAINS:
			continue
		var dist_sq = b.climate_distance_sq(climate.x, climate.y)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_biome = b

	return best_biome if best_biome != null else registry.biomes[0]

## Computes smooth blend weights among neighboring biomes for transition blending
func sample_biome_blend(world_x: float, world_z: float, elevation: float, sample_radius: float = 16.0) -> Dictionary:
	var weights: Dictionary = {} # int (biome_id) -> float
	var offsets = [
		Vector2(0, 0),
		Vector2(sample_radius, 0),
		Vector2(-sample_radius, 0),
		Vector2(0, sample_radius),
		Vector2(0, -sample_radius)
	]

	var weight_per_sample = 1.0 / float(offsets.size())
	for off in offsets:
		var b = get_biome_at(world_x + off.x, world_z + off.y, elevation)
		if b != null:
			weights[b.id] = weights.get(b.id, 0.0) + weight_per_sample

	return weights
