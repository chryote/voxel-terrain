class_name WorldConfig
extends Resource

## Configuration resource for world dimensions, streaming distances, and limits.

@export_group("World Dimensions")
@export var world_seed: int = 1337
@export var map_size_chunks: Vector2i = Vector2i(256, 256):
	set(val):
		map_size_chunks = Vector2i(
			clampi(val.x, 2, WorldBounds.MAX_MAP_SIZE_CHUNKS),
			clampi(val.y, 2, WorldBounds.MAX_MAP_SIZE_CHUNKS)
		)
@export_range(4, 64) var chunk_size: int = 32
@export_range(0.1, 10.0) var voxel_size: float = 1.0
@export var sea_level: int = 24
@export var max_height: int = 256

@export_group("Streaming & Budget")
@export_range(1, 32) var view_distance_chunks: int = 8
@export_range(0, 16) var collision_distance_chunks: int = 3
@export_range(1, 32) var max_mesh_applies_per_frame: int = 4
@export_range(1, 16) var shell_depth: int = 3

@export_group("World Features")
@export var caves_enabled: bool = true ## Master switch for procedural subterranean caves and chasms

func create_world_bounds() -> WorldBounds:
	return WorldBounds.new(map_size_chunks, chunk_size, voxel_size)
