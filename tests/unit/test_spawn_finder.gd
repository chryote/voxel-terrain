class_name TestSpawnFinder
extends "res://tests/framework/test_case.gd"

const SpawnFinder = preload("res://src/world/spawn_finder.gd")

class MockTerrainGenerator extends TerrainGenerator:
	var heights: Dictionary = {}
	var water_heights: Dictionary = {}

	func _init() -> void:
		pass

	func set_col(col: Vector2i, h: int, wh: int = 0) -> void:
		heights[col] = h
		water_heights[col] = wh

	func height_at(col: Vector2i, _bounds: WorldBounds) -> int:
		return heights.get(col, 20)

	func water_height_at(col: Vector2i, _bounds: WorldBounds) -> int:
		return water_heights.get(col, 0)

	func is_water_at(col: Vector2i, bounds: WorldBounds) -> bool:
		return height_at(col, bounds) < water_height_at(col, bounds)

func test_spawn_finder_flat_dry_terrain() -> void:
	var finder = SpawnFinder.new()
	var mock = MockTerrainGenerator.new()
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var sea_level = 24

	# Set all columns to flat dry land at height 30
	for dz in range(-10, 11):
		for dx in range(-10, 11):
			mock.set_col(Vector2i(dx, dz), 30, 24)

	var spawn_pos = finder.find_spawn_point(mock, bounds, sea_level, Vector2i.ZERO)
	var spawn_col = bounds.world_to_column(spawn_pos)

	assert_eq(spawn_col, Vector2i.ZERO, "Flat dry terrain should spawn at center (0, 0)")
	assert_almost_eq(spawn_pos.y, 31.0, 0.01, "Spawn Y should be 1 unit above terrain height 30")

func test_spawn_finder_skips_submerged_lake() -> void:
	var finder = SpawnFinder.new()
	var mock = MockTerrainGenerator.new()
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var sea_level = 24

	# Create a lake at center with radius 3 (submerged: ground 20, water 45)
	for dz in range(-15, 16):
		for dx in range(-15, 16):
			var dist = maxi(absi(dx), absi(dz))
			if dist <= 3:
				mock.set_col(Vector2i(dx, dz), 20, 45) # submerged lake
			else:
				mock.set_col(Vector2i(dx, dz), 48, 45) # dry shore/bank

	var spawn_pos = finder.find_spawn_point(mock, bounds, sea_level, Vector2i.ZERO)
	var spawn_col = bounds.world_to_column(spawn_pos)

	# Center lake should be skipped; spawn must be on dry land (dist >= 4)
	var dist_from_center = maxi(absi(spawn_col.x), absi(spawn_col.y))
	assert_true(dist_from_center >= 4, "Spawn must be outside the submerged lake basin")
	assert_true(spawn_pos.y >= 48.0, "Spawn Y must be on elevated dry ground")

func test_spawn_finder_skips_steep_cliffs() -> void:
	var finder = SpawnFinder.new()
	var mock = MockTerrainGenerator.new()
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var sea_level = 24

	# Flat terrain around center
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			mock.set_col(Vector2i(dx, dz), 30, 24)

	# Make (0,0) a steep spire
	mock.set_col(Vector2i.ZERO, 50, 24)

	var spawn_pos = finder.find_spawn_point(mock, bounds, sea_level, Vector2i.ZERO)
	var spawn_col = bounds.world_to_column(spawn_pos)

	assert_ne(spawn_col, Vector2i.ZERO, "Spawn finder must skip steep spire at (0, 0)")
	var h = mock.height_at(spawn_col, bounds)
	assert_eq(h, 30, "Spawn should be on flat terrain at height 30")

func test_spawn_finder_with_continent_generator() -> void:
	var bounds = WorldBounds.new(Vector2i(16, 16), 32, 1.0)
	var config = ContinentGeneratorConfig.new()
	var gen = ContinentGenerator.new(1337, config)
	var finder = SpawnFinder.new()

	var spawn_pos = finder.find_spawn_point(gen, bounds, config.sea_level, Vector2i.ZERO)
	var spawn_col = bounds.world_to_column(spawn_pos)

	var h = gen.height_at(spawn_col, bounds)
	var wh = gen.water_height_at(spawn_col, bounds)

	assert_true(bounds.contains_column(spawn_col.x, spawn_col.y), "Spawn column must be inside world bounds")
	assert_true(h > config.sea_level + 1, "Spawn must be above sea level")
	assert_true(h >= wh, "Spawn must not be submerged under water")
	assert_false(gen.is_water_at(spawn_col, bounds), "is_water_at must be false for spawn column")
