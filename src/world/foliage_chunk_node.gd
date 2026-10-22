class_name FoliageChunkNode
extends Node3D

## Visual batching node using MultiMeshInstance3D to efficiently render
## instanced foliage (grass, flowers, shrubs, trees) for a chunk.

const FoliageChunkDataClass = preload("res://src/foliage/foliage_chunk_data.gd")
const FoliageRegistryClass = preload("res://src/foliage/foliage_registry.gd")
const FoliageDefClass = preload("res://src/foliage/foliage_def.gd")

var _instances: Dictionary = {} # int (foliage_id) -> MultiMeshInstance3D
static var _fallback_meshes: Dictionary = {} # int (foliage_id) -> Mesh

func apply_foliage_data(data: FoliageChunkData, registry: FoliageRegistry) -> void:
	clear()
	if data == null or registry == null or data.is_empty():
		return

	for type_id in data.get_types():
		var foliage_def = registry.get_foliage(type_id)
		if foliage_def == null:
			continue

		var xforms = data.get_instances(type_id)
		var colors = data.get_colors(type_id)
		var count = xforms.size()
		if count == 0:
			continue

		var mesh_instance = _get_or_create_mesh_instance(type_id)
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _get_mesh_for_type(foliage_def)
		multimesh.instance_count = count

		for i in range(count):
			multimesh.set_instance_transform(i, xforms[i])
			multimesh.set_instance_color(i, colors[i])

		mesh_instance.multimesh = multimesh
		mesh_instance.visible = true

func _get_or_create_mesh_instance(type_id: int) -> MultiMeshInstance3D:
	if _instances.has(type_id):
		return _instances[type_id]
	var mmi = MultiMeshInstance3D.new()
	mmi.name = "Foliage_%d" % type_id
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
	_instances[type_id] = mmi
	return mmi

func _get_mesh_for_type(def: FoliageDef) -> Mesh:
	if def.mesh != null:
		return def.mesh
	if _fallback_meshes.has(def.id):
		return _fallback_meshes[def.id]

	# Generate simple procedural quad/cross mesh fallback for foliage
	var mesh = _create_fallback_cross_mesh(def)
	_fallback_meshes[def.id] = mesh
	return mesh

func _create_fallback_cross_mesh(def: FoliageDef) -> ArrayMesh:
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	var inds = PackedInt32Array()

	var w = 0.5
	var h = 1.0

	# Plane 1 (facing Z)
	var base_idx = verts.size()
	verts.append(Vector3(-w, 0.0, 0.0))
	verts.append(Vector3(w, 0.0, 0.0))
	verts.append(Vector3(w, h, 0.0))
	verts.append(Vector3(-w, h, 0.0))
	for _k in range(4):
		norms.append(Vector3.UP)
		cols.append(def.tint_color)
	inds.append_array([base_idx, base_idx + 1, base_idx + 2, base_idx, base_idx + 2, base_idx + 3])

	# Plane 2 (facing X)
	base_idx = verts.size()
	verts.append(Vector3(0.0, 0.0, -w))
	verts.append(Vector3(0.0, 0.0, w))
	verts.append(Vector3(0.0, h, w))
	verts.append(Vector3(0.0, h, -w))
	for _k in range(4):
		norms.append(Vector3.UP)
		cols.append(def.tint_color)
	inds.append_array([base_idx, base_idx + 1, base_idx + 2, base_idx, base_idx + 2, base_idx + 3])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = inds

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh

func clear() -> void:
	for mmi in _instances.values():
		mmi.multimesh = null
		mmi.visible = false

func prepare_for_pool() -> void:
	clear()
	visible = false
