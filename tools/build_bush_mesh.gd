@tool
extends SceneTree

func _init() -> void:
	print("Building stylized bush mesh assets (high detail + lowest detail LOD)...")
	DirAccess.make_dir_recursive_absolute("res://assets/models")

	var width = 1.5
	var height = 1.15
	var half_w = width * 0.5
	var root_color = Color(0.20, 0.40, 0.18, 1.0)
	var tip_color = Color(0.55, 0.82, 0.30, 1.0)
	var normal_center = Vector3(0.0, height * 0.35, 0.0)

	# 1. High Detail Mesh (4 crossed quads = 8 triangles, 16 vertices)
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()

	var angles = [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]
	for angle in angles:
		var dir = Vector3(cos(angle), 0.0, sin(angle))
		var v0 = -dir * (half_w * 0.8)
		var v1 = dir * (half_w * 0.8)
		var v2 = dir * half_w + Vector3(0.0, height, 0.0)
		var v3 = -dir * half_w + Vector3(0.0, height, 0.0)

		var n0 = (v0 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n1 = (v1 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n2 = (v2 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n3 = (v3 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()

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
	var save_path = "res://assets/models/bush.tres"
	ResourceSaver.save(array_mesh, save_path)
	print("Saved high detail bush mesh to: ", save_path)

	# 2. Lowest Detail LOD Mesh (2 crossed quads = 4 triangles, 8 vertices)
	var lod_verts = PackedVector3Array()
	var lod_norms = PackedVector3Array()
	var lod_uvs = PackedVector2Array()
	var lod_colors = PackedColorArray()
	var lod_indices = PackedInt32Array()

	var lod_angles = [0.0, PI / 2.0]
	for angle in lod_angles:
		var dir = Vector3(cos(angle), 0.0, sin(angle))
		var v0 = -dir * (half_w * 0.8)
		var v1 = dir * (half_w * 0.8)
		var v2 = dir * half_w + Vector3(0.0, height, 0.0)
		var v3 = -dir * half_w + Vector3(0.0, height, 0.0)

		var n0 = (v0 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n1 = (v1 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n2 = (v2 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()
		var n3 = (v3 - normal_center + Vector3(0.0, 0.2, 0.0)).normalized()

		var base_idx = lod_verts.size()
		lod_verts.append_array([v0, v1, v2, v3])
		lod_norms.append_array([n0, n1, n2, n3])
		lod_uvs.append_array([
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, 0.0)
		])
		lod_colors.append_array([root_color, root_color, tip_color, tip_color])

		lod_indices.append_array([
			base_idx + 0, base_idx + 1, base_idx + 2,
			base_idx + 0, base_idx + 2, base_idx + 3
		])

	var lod_arrays = []
	lod_arrays.resize(Mesh.ARRAY_MAX)
	lod_arrays[Mesh.ARRAY_VERTEX] = lod_verts
	lod_arrays[Mesh.ARRAY_NORMAL] = lod_norms
	lod_arrays[Mesh.ARRAY_TEX_UV] = lod_uvs
	lod_arrays[Mesh.ARRAY_COLOR] = lod_colors
	lod_arrays[Mesh.ARRAY_INDEX] = lod_indices

	var lod_mesh = ArrayMesh.new()
	lod_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lod_arrays)
	var lod_path = "res://assets/models/bush_lod.tres"
	ResourceSaver.save(lod_mesh, lod_path)
	print("Saved lowest detail bush LOD mesh to: ", lod_path)

	quit()

