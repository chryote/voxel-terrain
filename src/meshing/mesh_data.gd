class_name MeshData
extends RefCounted

## Pure data container for vertex, normal, color, and index buffers.
## Safe to generate and manipulate across background worker threads.

var vertices: PackedVector3Array
var normals: PackedVector3Array
var colors: PackedColorArray
var uvs: PackedVector2Array
var uv2s: PackedVector2Array
var indices: PackedInt32Array
var water_mesh_data: MeshData = null
var has_cave_mouth: bool = false

func is_empty() -> bool:
	return vertices.is_empty() or indices.is_empty()

func clear() -> void:
	vertices.clear()
	normals.clear()
	colors.clear()
	uvs.clear()
	uv2s.clear()
	indices.clear()
	has_cave_mouth = false

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
	if uvs.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if uv2s.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func get_triangle_count() -> int:
	return indices.size() / 3

func get_vertex_count() -> int:
	return vertices.size()
