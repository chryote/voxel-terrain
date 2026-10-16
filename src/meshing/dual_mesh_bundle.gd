class_name DualMeshBundle
extends MeshData

## Decoupled container storing separated surface, subterranean, and water meshes.
## Inherits from MeshData so it acts as the primary (surface) mesh data container
## while encapsulating independent subterranean cave geometry.

var cave_mesh_data: MeshData = null
var has_cave_mouth: bool = false

var surface_mesh_data: MeshData:
	get:
		return self

func _init() -> void:
	cave_mesh_data = MeshData.new()

func has_cave_geometry() -> bool:
	return cave_mesh_data != null and not cave_mesh_data.is_empty()

func get_surface_triangle_count() -> int:
	return get_triangle_count()

func get_cave_triangle_count() -> int:
	return cave_mesh_data.get_triangle_count() if cave_mesh_data != null else 0

func get_water_triangle_count() -> int:
	return water_mesh_data.get_triangle_count() if water_mesh_data != null else 0

func get_total_triangle_count() -> int:
	return get_surface_triangle_count() + get_cave_triangle_count() + get_water_triangle_count()

func get_total_vertex_count() -> int:
	var total = get_vertex_count()
	if cave_mesh_data != null:
		total += cave_mesh_data.get_vertex_count()
	if water_mesh_data != null:
		total += water_mesh_data.get_vertex_count()
	return total

func clear_all() -> void:
	clear()
	if cave_mesh_data != null:
		cave_mesh_data.clear()
	if water_mesh_data != null:
		water_mesh_data.clear()
