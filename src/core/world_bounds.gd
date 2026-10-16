class_name WorldBounds
extends RefCounted

## Manages map limits, coordinate conversions, and bounding queries.

const MAX_MAP_SIZE_CHUNKS: int = 512

var size_chunks: Vector2i = Vector2i(256, 256)
var chunk_size: int = 32
var voxel_size: float = 1.0

var min_chunk_x: int = -128
var max_chunk_x: int = 127
var min_chunk_z: int = -128
var max_chunk_z: int = 127

var min_world_x: float = -4096.0
var max_world_x: float = 4096.0
var min_world_z: float = -4096.0
var max_world_z: float = 4096.0

func _init(p_size_chunks: Vector2i = Vector2i(256, 256), p_chunk_size: int = 32, p_voxel_size: float = 1.0) -> void:
	set_dimensions(p_size_chunks, p_chunk_size, p_voxel_size)

func set_dimensions(p_size_chunks: Vector2i, p_chunk_size: int = 32, p_voxel_size: float = 1.0) -> void:
	var clamped_x = clampi(p_size_chunks.x, 2, MAX_MAP_SIZE_CHUNKS)
	var clamped_z = clampi(p_size_chunks.y, 2, MAX_MAP_SIZE_CHUNKS)
	size_chunks = Vector2i(clamped_x, clamped_z)
	chunk_size = maxi(4, p_chunk_size)
	voxel_size = maxf(0.1, p_voxel_size)

	min_chunk_x = int(float(-size_chunks.x) / 2.0)
	max_chunk_x = min_chunk_x + size_chunks.x - 1
	min_chunk_z = int(float(-size_chunks.y) / 2.0)
	max_chunk_z = min_chunk_z + size_chunks.y - 1

	var chunk_world_size = float(chunk_size) * voxel_size
	min_world_x = float(min_chunk_x) * chunk_world_size
	max_world_x = float(max_chunk_x + 1) * chunk_world_size
	min_world_z = float(min_chunk_z) * chunk_world_size
	max_world_z = float(max_chunk_z + 1) * chunk_world_size

func contains_chunk(c: ChunkCoord) -> bool:
	if c == null:
		return false
	return c.x >= min_chunk_x and c.x <= max_chunk_x and c.z >= min_chunk_z and c.z <= max_chunk_z

func contains_column(col_x: int, col_z: int) -> bool:
	var min_col_x = min_chunk_x * chunk_size
	var max_col_x = (max_chunk_x + 1) * chunk_size - 1
	var min_col_z = min_chunk_z * chunk_size
	var max_col_z = (max_chunk_z + 1) * chunk_size - 1
	return col_x >= min_col_x and col_x <= max_col_x and col_z >= min_col_z and col_z <= max_col_z

func chunk_origin(c: ChunkCoord) -> Vector3:
	var chunk_world_size = float(chunk_size) * voxel_size
	return Vector3(float(c.x) * chunk_world_size, 0.0, float(c.z) * chunk_world_size)

func world_to_chunk(pos: Vector3) -> ChunkCoord:
	var chunk_world_size = float(chunk_size) * voxel_size
	var cx = floori(pos.x / chunk_world_size)
	var cz = floori(pos.z / chunk_world_size)
	return ChunkCoord.new(cx, cz)

func world_to_column(pos: Vector3) -> Vector2i:
	var col_x = floori(pos.x / voxel_size)
	var col_z = floori(pos.z / voxel_size)
	return Vector2i(col_x, col_z)

func column_to_world(col: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(
		(float(col.x) + 0.5) * voxel_size,
		height * voxel_size,
		(float(col.y) + 0.5) * voxel_size
	)

func clamp_position(pos: Vector3, margin: float = 2.0) -> Vector3:
	return Vector3(
		clampf(pos.x, min_world_x + margin, max_world_x - margin),
		pos.y,
		clampf(pos.z, min_world_z + margin, max_world_z - margin)
	)

func world_rect() -> Rect2:
	return Rect2(min_world_x, min_world_z, max_world_x - min_world_x, max_world_z - min_world_z)

func total_chunks() -> int:
	return size_chunks.x * size_chunks.y
