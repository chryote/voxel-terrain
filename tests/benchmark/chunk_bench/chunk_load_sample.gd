class_name ChunkLoadSample
extends RefCounted

## Immutable metrics record for a single chunk's loading pipeline execution.
## Encapsulates stage timings and geometry statistics without retaining heavy mesh/voxel data in memory.

var coord: ChunkCoord
var gen_ms: float = 0.0
var mesh_ms: float = 0.0
var bake_ms: float = 0.0
var total_ms: float = 0.0

var vertex_count: int = 0
var triangle_count: int = 0
var cave_vertex_count: int = 0
var cave_triangle_count: int = 0

var has_subterranean: bool = false
var is_dual_bundle: bool = false

func _init(
	p_coord: ChunkCoord,
	p_gen_ms: float,
	p_mesh_ms: float,
	p_bake_ms: float,
	p_vertex_count: int,
	p_triangle_count: int,
	p_cave_verts: int = 0,
	p_cave_tris: int = 0,
	p_has_sub: bool = false,
	p_is_dual: bool = false
) -> void:
	coord = p_coord
	gen_ms = p_gen_ms
	mesh_ms = p_mesh_ms
	bake_ms = p_bake_ms
	total_ms = p_gen_ms + p_mesh_ms + p_bake_ms
	vertex_count = p_vertex_count
	triangle_count = p_triangle_count
	cave_vertex_count = p_cave_verts
	cave_triangle_count = p_cave_tris
	has_subterranean = p_has_sub
	is_dual_bundle = p_is_dual

func to_dict() -> Dictionary:
	return {
		"coord": [coord.x, coord.z],
		"gen_ms": gen_ms,
		"mesh_ms": mesh_ms,
		"bake_ms": bake_ms,
		"total_ms": total_ms,
		"vertex_count": vertex_count,
		"triangle_count": triangle_count,
		"cave_vertex_count": cave_vertex_count,
		"cave_triangle_count": cave_triangle_count,
		"has_subterranean": has_subterranean,
		"is_dual_bundle": is_dual_bundle
	}
