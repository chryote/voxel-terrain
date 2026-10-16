class_name ChunkCoord
extends RefCounted

## Represents 2D integer coordinates of a chunk on the continent grid.

var x: int = 0
var z: int = 0

func _init(px: int = 0, pz: int = 0) -> void:
	x = px
	z = pz

func equals(other: ChunkCoord) -> bool:
	if other == null:
		return false
	return x == other.x and z == other.z

func to_key() -> int:
	# 64-bit integer combining two signed 32-bit integers
	return (x & 0xFFFFFFFF) | ((z & 0xFFFFFFFF) << 32)

static func from_key(key: int) -> ChunkCoord:
	var px = key & 0xFFFFFFFF
	if px & 0x80000000:
		px -= 0x100000000
	var pz = (key >> 32) & 0xFFFFFFFF
	if pz & 0x80000000:
		pz -= 0x100000000
	return ChunkCoord.new(int(px), int(pz))

static func from_vector2i(v: Vector2i) -> ChunkCoord:
	return ChunkCoord.new(v.x, v.y)

func to_vector2i() -> Vector2i:
	return Vector2i(x, z)

func manhattan_distance_to(other: ChunkCoord) -> int:
	return absi(x - other.x) + absi(z - other.z)

func chebyshev_distance_to(other: ChunkCoord) -> int:
	return maxi(absi(x - other.x), absi(z - other.z))

func euclidean_distance_to(other: ChunkCoord) -> float:
	var dx = float(x - other.x)
	var dz = float(z - other.z)
	return sqrt(dx * dx + dz * dz)

func _to_string() -> String:
	return "(%d, %d)" % [x, z]
