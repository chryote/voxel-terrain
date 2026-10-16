class_name MeshData
extends RefCounted

## Pure data container for vertex, normal, color, and index buffers.
## Safe to generate and manipulate across background worker threads.

var vertices: PackedVector3Array
var normals: PackedVector3Array
var colors: PackedColorArray
var indices: PackedInt32Array
var water_mesh_data: MeshData = null

func is_empty() -> bool:
	return vertices.is_empty() or indices.is_empty()

func clear() -> void:
	vertices.clear()
	normals.clear()
	colors.clear()
	indices.clear()

func create_array_mesh() -> ArrayMesh:
	if is_empty():
		return null

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if normals.size() == vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = normals
	if colors.size() == vertices.size():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func get_triangle_count() -> int:
	return indices.size() / 3

func get_vertex_count() -> int:
	return vertices.size()
