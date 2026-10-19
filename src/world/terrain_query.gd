class_name TerrainQuery
extends RefCounted

## Decoupled query interface for player, physics, and gameplay entities.

func get_height_at(_world_x: float, _world_z: float) -> float:
	push_error("TerrainQuery.get_height_at() must be overridden")
	return 0.0

func get_spawn_point() -> Vector3:
	push_error("TerrainQuery.get_spawn_point() must be overridden")
	return Vector3.ZERO

func get_surface_spawn_point() -> Vector3:
	return get_spawn_point()

func get_underground_spawn_point() -> Vector3:
	return get_spawn_point()

func get_world_bounds() -> WorldBounds:
	push_error("TerrainQuery.get_world_bounds() must be overridden")
	return null
