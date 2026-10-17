class_name OffThreadCollisionBaker
extends RefCounted

## Pure thread-safe service that compiles ConcavePolygonShape3D physics collision shapes
## from vertex and index buffers on background worker threads.
## Completely avoids RenderingServer/GPU synchronization and eliminates main-thread frame stalls.

func bake_shape(mesh_data: MeshData) -> ConcavePolygonShape3D:
	if mesh_data == null or mesh_data.is_empty():
		return null

	var verts = mesh_data.vertices
	var inds = mesh_data.indices
	var num_indices = inds.size()
	if num_indices == 0:
		return null

	var faces = PackedVector3Array()
	faces.resize(num_indices)
	for i in range(num_indices):
		faces[i] = verts[inds[i]]

	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape

func bake_shapes_for_bundle(mesh_data: MeshData) -> Dictionary:
	var result = {
		"surface_shape": null,
		"cave_shape": null
	}

	if mesh_data == null:
		return result

	# 1. Surface shape
	if not mesh_data.is_empty():
		result.surface_shape = bake_shape(mesh_data)

	# 2. Cave shape (if DualMeshBundle with cave geometry)
	if mesh_data is DualMeshBundle and mesh_data.has_cave_geometry():
		result.cave_shape = bake_shape(mesh_data.cave_mesh_data)

	return result
