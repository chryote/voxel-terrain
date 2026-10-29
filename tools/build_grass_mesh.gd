@tool
extends SceneTree

func _init() -> void:
	print("Building stylized grass tuft mesh assets (high detail + lowest detail LOD)...")
	DirAccess.make_dir_recursive_absolute("res://assets/models")

	var width = 0.75
	var height = 0.85
	var half_w = width * 0.5
	var root_color = Color(0.25, 0.45, 0.20, 1.0)
	var tip_color = Color(0.65, 0.88, 0.35, 1.0)

	# 1. High Detail Mesh (3 crossed quads = 6 triangles, 12 vertices)
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()

	var angles = [0.0, PI / 3.0, 2.0 * PI / 3.0]
	for angle in angles:
		var dir = Vector3(cos(angle), 0.0, sin(angle))
		var v0 = -dir * half_w
		var v1 = dir * half_w
		var v2 = dir * (half_w * 1.15) + Vector3(0.0, height, 0.0)
		var v3 = -dir * (half_w * 1.15) + Vector3(0.0, height, 0.0)

		var n0 = Vector3(v0.x * 0.3, 0.8, v0.z * 0.3).normalized()
		var n1 = Vector3(v1.x * 0.3, 0.8, v1.z * 0.3).normalized()
		var n2 = Vector3(v2.x * 0.5, 0.7, v2.z * 0.5).normalized()
		var n3 = Vector3(v3.x * 0.5, 0.7, v3.z * 0.5).normalized()

		var base_idx = verts.size()
		verts.append_array([v0, v1, v2, v3])
		norms.append_array([n0, n1, n2, n3])
		uvs.append_array([
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, 0.0)
		])
		colors.append_array([root_color, root_color, tip_color, tip_color])

		indices.append_array([
			base_idx + 0, base_idx + 1, base_idx + 2,
			base_idx + 0, base_idx + 2, base_idx + 3
		])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var save_path = "res://assets/models/grass_tuft.tres"
	ResourceSaver.save(array_mesh, save_path)
	print("Saved high detail mesh to: ", save_path)

	# 2. Lowest Detail Mesh (1 single quad = 2 triangles, 4 vertices)
	var lod_verts = PackedVector3Array([
		Vector3(-half_w, 0.0, 0.0),
		Vector3(half_w, 0.0, 0.0),
		Vector3(half_w * 1.15, height, 0.0),
		Vector3(-half_w * 1.15, height, 0.0)
	])
	var lod_norms = PackedVector3Array([
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0)
	])
	var lod_uvs = PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0)
	])
	var lod_colors = PackedColorArray([root_color, root_color, tip_color, tip_color])
	var lod_indices = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var lod_arrays = []
	lod_arrays.resize(Mesh.ARRAY_MAX)
	lod_arrays[Mesh.ARRAY_VERTEX] = lod_verts
	lod_arrays[Mesh.ARRAY_NORMAL] = lod_norms
	lod_arrays[Mesh.ARRAY_TEX_UV] = lod_uvs
	lod_arrays[Mesh.ARRAY_COLOR] = lod_colors
	lod_arrays[Mesh.ARRAY_INDEX] = lod_indices

	var lod_mesh = ArrayMesh.new()
	lod_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lod_arrays)
	var lod_path = "res://assets/models/grass_tuft_lod.tres"
	ResourceSaver.save(lod_mesh, lod_path)
	print("Saved lowest detail LOD mesh to: ", lod_path)

	quit()
