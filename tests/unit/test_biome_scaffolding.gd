class_name TestBiomeScaffolding
extends "res://tests/framework/test_case.gd"

## Unit tests verifying biome definitions, registry lookups, climate sampling,
## and elevation/climate biome classification.

const BiomeDefClass = preload("res://src/biomes/biome_def.gd")
const BiomeRegistryClass = preload("res://src/biomes/biome_registry.gd")
const BiomeSamplerClass = preload("res://src/biomes/biome_sampler.gd")

func test_biome_def_distance_calculation() -> void:
	var biome = BiomeDefClass.new(1, "Test", 0.5, 0.5)
	# Distance squared to same climate is 0
	assert_almost_eq(biome.climate_distance_sq(0.5, 0.5), 0.0, 0.001)
	# Distance squared to (0.2, 0.1) is (0.3)^2 + (0.4)^2 = 0.09 + 0.16 = 0.25
	assert_almost_eq(biome.climate_distance_sq(0.2, 0.1), 0.25, 0.001)

func test_biome_registry_defaults() -> void:
	var reg = BiomeRegistryClass.create_default_registry()
	assert_not_null(reg)
	assert_true(reg.get_all_biomes().size() > 4, "Default registry should contain at least 5 biomes")

	var plains = reg.get_biome(BiomeRegistryClass.BIOME_PLAINS)
	assert_not_null(plains)
	assert_eq(plains.name, "Plains")
	assert_eq(plains.surface_material_id, MaterialDef.ID_GRASS)

	var desert = reg.get_biome(BiomeRegistryClass.BIOME_DESERT)
	assert_not_null(desert)
	assert_eq(desert.surface_material_id, MaterialDef.ID_SAND)
	assert_almost_eq(desert.foliage_density, 0.05, 0.01)

func test_biome_sampler_altitude_overrides() -> void:
	var reg = BiomeRegistryClass.create_default_registry()
	var sampler = BiomeSamplerClass.new(reg, 42, 24.0)

	# Below sea level should evaluate to Ocean
	var ocean_biome = sampler.get_biome_at(100.0, 100.0, 15.0)
	assert_not_null(ocean_biome)
	assert_eq(ocean_biome.id, BiomeRegistryClass.BIOME_OCEAN)

	# High elevation should evaluate to Mountains
	var mountain_biome = sampler.get_biome_at(100.0, 100.0, 160.0)
	assert_not_null(mountain_biome)
	assert_eq(mountain_biome.id, BiomeRegistryClass.BIOME_MOUNTAINS)

	# Shoreline elevation should evaluate to Beach
	var beach_biome = sampler.get_biome_at(100.0, 100.0, 24.5)
	assert_not_null(beach_biome)
	assert_eq(beach_biome.id, BiomeRegistryClass.BIOME_BEACH)

func test_biome_sampler_climate_determinism() -> void:
	var sampler1 = BiomeSamplerClass.new(null, 999, 24.0)
	var sampler2 = BiomeSamplerClass.new(null, 999, 24.0)

	var c1 = sampler1.sample_climate(45.5, -120.3)
	var c2 = sampler2.sample_climate(45.5, -120.3)
	assert_almost_eq(c1.x, c2.x, 0.0001, "Climate temperature must be deterministic")
	assert_almost_eq(c1.y, c2.y, 0.0001, "Climate humidity must be deterministic")

func test_biome_sampler_blend_weights_sum_to_one() -> void:
	var sampler = BiomeSamplerClass.new(null, 1337, 24.0)
	var weights = sampler.sample_biome_blend(50.0, 50.0, 45.0, 20.0)

	assert_false(weights.is_empty(), "Weights dictionary must not be empty")
	var sum = 0.0
	for w in weights.values():
		sum += w
	assert_almost_eq(sum, 1.0, 0.01, "Sampled blend weights must sum to 1.0")
