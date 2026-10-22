class_name BiomeRegistry
extends Resource

## Registry storing and indexing all available biomes.

const BiomeDefClass = preload("res://src/biomes/biome_def.gd")

const BIOME_PLAINS: int = 0
const BIOME_FOREST: int = 1
const BIOME_DESERT: int = 2
const BIOME_TUNDRA: int = 3
const BIOME_MOUNTAINS: int = 4
const BIOME_BEACH: int = 5
const BIOME_OCEAN: int = 6
const BIOME_SWAMP: int = 7

@export var biomes: Array[BiomeDef] = []
var _lookup: Dictionary = {}

func _init() -> void:
	_rebuild_lookup()

func _rebuild_lookup() -> void:
	_lookup.clear()
	for b in biomes:
		if b != null:
			_lookup[b.id] = b

func register_biome(b: BiomeDef) -> void:
	if b == null:
		return
	_lookup[b.id] = b
	if not biomes.has(b):
		biomes.append(b)

func get_biome(id: int) -> BiomeDef:
	if _lookup.is_empty() and biomes.size() > 0:
		_rebuild_lookup()
	return _lookup.get(id, null)

func get_all_biomes() -> Array[BiomeDef]:
	return biomes

static func create_default_registry() -> BiomeRegistry:
	var reg = BiomeRegistry.new()
	reg.register_biome(BiomeDefClass.new(
		BIOME_PLAINS, "Plains", 0.1, 0.1, 25.0, 90.0,
		MaterialDef.ID_GRASS, MaterialDef.ID_DIRT, 0.6, Color(0.95, 1.0, 0.95)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_FOREST, "Forest", 0.0, 0.6, 25.0, 100.0,
		MaterialDef.ID_GRASS, MaterialDef.ID_DIRT, 0.9, Color(0.85, 1.0, 0.85)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_DESERT, "Desert", 0.8, -0.7, 24.0, 120.0,
		MaterialDef.ID_SAND, MaterialDef.ID_SAND, 0.05, Color(1.1, 1.0, 0.9)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_TUNDRA, "Tundra", -0.8, -0.2, 25.0, 150.0,
		MaterialDef.ID_SNOW, MaterialDef.ID_STONE, 0.15, Color(0.9, 0.95, 1.05)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_MOUNTAINS, "Mountain Peaks", -0.5, 0.0, 100.0, 300.0,
		MaterialDef.ID_STONE, MaterialDef.ID_STONE, 0.1, Color(0.95, 0.95, 1.0)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_BEACH, "Beach", 0.2, 0.0, 22.0, 27.0,
		MaterialDef.ID_SAND, MaterialDef.ID_SAND, 0.1, Color(1.0, 1.0, 0.95)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_OCEAN, "Ocean", 0.0, 0.5, -100.0, 23.0,
		MaterialDef.ID_SEABED, MaterialDef.ID_STONE, 0.0, Color(0.7, 0.85, 1.0)
	))
	reg.register_biome(BiomeDefClass.new(
		BIOME_SWAMP, "Swamp", 0.5, 0.8, 23.0, 30.0,
		MaterialDef.ID_GRASS, MaterialDef.ID_DIRT, 0.75, Color(0.8, 0.95, 0.75)
	))
	return reg
