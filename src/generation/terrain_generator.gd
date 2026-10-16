class_name TerrainGenerator
extends RefCounted

## Abstract base class for terrain generation strategies.

func generate(_coord: ChunkCoord, _bounds: WorldBounds) -> RefCounted:
	push_error("TerrainGenerator.generate() must be overridden")
	return null

func height_at(_col: Vector2i, _bounds: WorldBounds) -> int:
	push_error("TerrainGenerator.height_at() must be overridden")
	return 0

func water_height_at(_col: Vector2i, _bounds: WorldBounds) -> int:
	return 0

func is_water_at(col: Vector2i, bounds: WorldBounds) -> bool:
	return height_at(col, bounds) < water_height_at(col, bounds)
