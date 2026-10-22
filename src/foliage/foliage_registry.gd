class_name FoliageRegistry
extends Resource

## Registry managing all foliage definitions and preset catalogs.

const FoliageDefClass = preload("res://src/foliage/foliage_def.gd")

const FOLIAGE_GRASS_TUFT: int = 0
const FOLIAGE_WILDFLOWER: int = 1
const FOLIAGE_FERN: int = 2
const FOLIAGE_SHRUB: int = 3
const FOLIAGE_PINE_TREE: int = 4
const FOLIAGE_PEBBLE: int = 5

@export var foliage_items: Array[FoliageDef] = []
var _lookup: Dictionary = {}

func _init() -> void:
	_rebuild_lookup()

func _rebuild_lookup() -> void:
	_lookup.clear()
	for f in foliage_items:
		if f != null:
			_lookup[f.id] = f

func register_foliage(f: FoliageDef) -> void:
	if f == null:
		return
	_lookup[f.id] = f
	if not foliage_items.has(f):
		foliage_items.append(f)

func get_foliage(id: int) -> FoliageDef:
	if _lookup.is_empty() and foliage_items.size() > 0:
		_rebuild_lookup()
	return _lookup.get(id, null)

static func create_default_registry() -> FoliageRegistry:
	var reg = FoliageRegistry.new()
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_GRASS_TUFT, "Grass Tuft", 0.8, 1.2, 35.0,
		[MaterialDef.ID_GRASS], 24.5, 120.0, Color(0.9, 1.0, 0.9)
	))
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_WILDFLOWER, "Wildflower", 0.6, 1.0, 25.0,
		[MaterialDef.ID_GRASS], 25.0, 90.0, Color(1.0, 0.9, 0.95)
	))
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_FERN, "Fern", 0.9, 1.4, 30.0,
		[MaterialDef.ID_GRASS, MaterialDef.ID_DIRT], 24.5, 80.0, Color(0.8, 1.0, 0.8)
	))
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_SHRUB, "Shrub", 1.0, 2.0, 30.0,
		[MaterialDef.ID_GRASS, MaterialDef.ID_DIRT], 25.0, 110.0, Color(0.85, 0.95, 0.8)
	))
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_PINE_TREE, "Pine Tree", 2.0, 4.5, 22.0,
		[MaterialDef.ID_GRASS, MaterialDef.ID_DIRT], 26.0, 140.0, Color(0.7, 0.85, 0.7)
	))
	reg.register_foliage(FoliageDefClass.new(
		FOLIAGE_PEBBLE, "Pebble / Rock", 0.4, 0.9, 50.0,
		[MaterialDef.ID_STONE, MaterialDef.ID_GRAVEL, MaterialDef.ID_DIRT], 20.0, 250.0, Color(0.8, 0.8, 0.8)
	))
	return reg
