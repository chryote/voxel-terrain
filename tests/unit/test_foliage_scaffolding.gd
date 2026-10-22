class_name TestFoliageScaffolding
extends "res://tests/framework/test_case.gd"

## Unit tests verifying foliage definitions, chunk instance buffering,
## slope and material placement rules, and painting exclusion zones.

const FoliageDefClass = preload("res://src/foliage/foliage_def.gd")
const FoliageRegistryClass = preload("res://src/foliage/foliage_registry.gd")
const FoliageChunkDataClass = preload("res://src/foliage/foliage_chunk_data.gd")
const FoliageSpawnerClass = preload("res://src/foliage/foliage_spawner.gd")
const FoliageChunkNodeClass = preload("res://src/world/foliage_chunk_node.gd")
const TerrainPaintDataClass = preload("res://src/painting/terrain_paint_data.gd")
const BiomeDefClass = preload("res://src/biomes/biome_def.gd")

func test_foliage_def_surface_validation() -> void:
	var def = FoliageDefClass.new(
		0, "Grass Tuft", 0.8, 1.2, 30.0,
		[MaterialDef.ID_GRASS], 24.0, 100.0
	)

	# Valid flat grass
	assert_true(def.is_valid_surface(MaterialDef.ID_GRASS, 50.0, 10.0),
		"Flat grass at mid elevation should be valid")

	# Invalid material
	assert_false(def.is_valid_surface(MaterialDef.ID_SAND, 50.0, 10.0),
		"Sand should be rejected for grass tuft")

	# Too steep
	assert_false(def.is_valid_surface(MaterialDef.ID_GRASS, 50.0, 45.0),
		"Slope exceeding 30 degrees should be rejected")

	# Submerged underwater
	assert_false(def.is_valid_surface(MaterialDef.ID_GRASS, 10.0, 5.0),
		"Elevation below min_elevation should be rejected")

func test_foliage_chunk_data_buffering() -> void:
	var data = FoliageChunkDataClass.new()
	assert_true(data.is_empty())

	data.add_instance(0, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)))
	data.add_instance(0, Transform3D(Basis.IDENTITY, Vector3(4, 5, 6)))
	data.add_instance(1, Transform3D(Basis.IDENTITY, Vector3(7, 8, 9)))

	assert_false(data.is_empty())
	assert_eq(data.get_instance_count(0), 2)
	assert_eq(data.get_instance_count(1), 1)
	assert_eq(data.get_total_count(), 3)

	data.clear()
	assert_true(data.is_empty())

func test_foliage_spawner_placement_and_paint_exclusion() -> void:
	var spawner = FoliageSpawnerClass.new()
	var s_data = SurfaceChunkData.new(32, 3)
	s_data.fill(40, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT)

	var coord = ChunkCoord.new(0, 0)
	var biome = BiomeDefClass.new(0, "Plains", 0.0, 0.0, 20.0, 100.0, MaterialDef.ID_GRASS, MaterialDef.ID_DIRT, 0.8)

	# 1. Spawn without painted road -> should produce instances
	var foliage_clean = spawner.generate_foliage_chunk(s_data, coord, biome, null, 1.0)
	assert_false(foliage_clean.is_empty(), "Foliage should spawn on flat grassy terrain")
	assert_true(foliage_clean.get_total_count() > 10, "High density should generate dozens of foliage instances")

	# 2. Spawn with whole chunk painted as dirt road -> should suppress foliage
	var paint_data = TerrainPaintDataClass.new(32)
	for z in range(32):
		for x in range(32):
			paint_data.set_weight(x, z, 0, 1.0) # Channel 0 = Dirt Path

	var foliage_road = spawner.generate_foliage_chunk(s_data, coord, biome, paint_data, 1.0)
	assert_eq(foliage_road.get_total_count(), 0, "Painted road must completely suppress foliage placement")

func test_foliage_chunk_node_instantiation() -> void:
	var node = FoliageChunkNodeClass.new()
	var reg = FoliageRegistryClass.create_default_registry()

	var data = FoliageChunkDataClass.new()
	data.add_instance(0, Transform3D(Basis.IDENTITY, Vector3(2, 10, 2)))
	data.add_instance(0, Transform3D(Basis.IDENTITY, Vector3(5, 10, 5)))

	node.apply_foliage_data(data, reg)
	assert_true(node.get_child_count() > 0, "Node should create MultiMeshInstance3D children")

	node.clear()
	node.queue_free()
