@tool
extends SceneTree

func _init() -> void:
	print("Building stylized grass tuft mesh asset...")
	DirAccess.make_dir_recursive_absolute("res://assets/models")

	var width = 0.75
	var height = 0.85

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()

	# 3 intersecting planes at 0, 60, and 120 degrees
	var angles = [0.0, PI / 3.0, 2.0 * PI / 3.0]
	var root_color = Color(0.25, 0.45, 0.20, 1.0)
	var tip_color = Color(0.65, 0.88, 0.35, 1.0)

	for angle in angles:
		var dir = Vector3(cos(angle), 0.0, sin(angle))
		var perp = Vector3(-sin(angle), 0.0, cos(angle)) # normal to the plane
		var half_w = width * 0.5

		# 4 vertices per quad:
		# v0: bottom-left (-half_w, 0)
		# v1: bottom-right (+half_w, 0)
		# v2: top-right (+half_w * 1.15, height) - slightly flared
		# v3: top-left (-half_w * 1.15, height)
		var v0 = -dir * half_w
		var v1 = dir * half_w
		var v2 = dir * (half_w * 1.15) + Vector3(0.0, height, 0.0)
		var v3 = -dir * (half_w * 1.15) + Vector3(0.0, height, 0.0)

		# Upward & gently flared radial normals for soft, uniform cel lighting
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

		# Two triangles (front face)
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
	var err = ResourceSaver.save(array_mesh, save_path)
	if err == OK:
		print("Successfully saved stylized grass mesh asset to: ", save_path)
	else:
		printerr("Failed to save grass mesh asset, error: ", err)

	quit()

