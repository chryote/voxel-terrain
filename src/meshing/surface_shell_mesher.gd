class_name SurfaceShellMesher
extends Mesher

const WaterSurfaceMesher = preload("res://src/meshing/water_surface_mesher.gd")

var sea_level: int = 24
var _water_mesher: WaterSurfaceMesher = WaterSurfaceMesher.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	var mesh = MeshData.new()
	var s_data: SurfaceChunkData = data as SurfaceChunkData
	if s_data == null:
		return mesh
	var n = s_data.chunk_size

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	var inds = PackedInt32Array()

	var heights: PackedInt32Array = s_data.heights
	var top_mats: PackedByteArray = s_data.top_material
	var side_mats: PackedByteArray = s_data.side_material
	var apron_w: int = s_data.apron_size

	# -------------------------------------------------------------------------
	# 1. Top horizontal faces (2D greedy merging)
	# -------------------------------------------------------------------------
	var visited = PackedByteArray()
	visited.resize(n * n)
	visited.fill(0)

	for lz in range(n):
		var row_start = (lz + 1) * apron_w
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1:
				continue

			var col_idx = (lx + 1) + row_start
			var h = heights[col_idx]
			var mat = top_mats[col_idx]
			if mat == 0:
				continue

			# Find width w along X
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				var next_col = (lx + w + 1) + row_start
				if heights[next_col] != h or top_mats[next_col] != mat:
					break
				w += 1

			# Find depth d along Z
			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				var exp_row = (lz + d + 1) * apron_w
				for check_x in range(lx, lx + w):
					var row_idx = check_x + (lz + d) * n
					if visited[row_idx] == 1:
						can_expand = false
						break
					var exp_col = (check_x + 1) + exp_row
					if heights[exp_col] != h or top_mats[exp_col] != mat:
						can_expand = false
						break
				if can_expand:
					d += 1

			# Mark visited
			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			# Add merged top quad
			var top_color = registry.get_top_color(mat)
			var norm = Vector3(0.0, 1.0, 0.0)

			var base_idx = verts.size()
			var fh = float(h)
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			verts.append(Vector3(flx, fh, flz))
			verts.append(Vector3(flx, fh, flz + fd))
			verts.append(Vector3(flx + fw, fh, flz + fd))
			verts.append(Vector3(flx + fw, fh, flz))

			norms.append(norm)
			norms.append(norm)
			norms.append(norm)
			norms.append(norm)

			cols.append(top_color)
			cols.append(top_color)
			cols.append(top_color)
			cols.append(top_color)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

	# -------------------------------------------------------------------------
	# 2. Side vertical walls (greedy run-length merged cliff/step faces)
	# -------------------------------------------------------------------------
	# West (-X) and East (+X) merge along Z
	var norm_west = Vector3(-1.0, 0.0, 0.0)
	var norm_east = Vector3(1.0, 0.0, 0.0)

	for lx in range(n):
		var flx = float(lx)
		var col_base = (lx + 1) + apron_w

		# West (-X)
		var lz = 0
		while lz < n:
			var col_idx = col_base + lz * apron_w
			var side_mat = side_mats[col_idx]
			if side_mat == 0:
				lz += 1
				continue
			var h = heights[col_idx]
			var h_w = heights[col_idx - 1]
			if h_w >= h:
				lz += 1
				continue

			var run_z = 1
			while (lz + run_z) < n:
				var next_idx = col_base + (lz + run_z) * apron_w
				if side_mats[next_idx] != side_mat:
					break
				if heights[next_idx] != h:
					break
				if heights[next_idx - 1] != h_w:
					break
				run_z += 1

			var side_col = registry.get_side_color(side_mat)
			var fnh = float(h_w)
			var fh = float(h)
			var z_start = float(lz)
			var z_end = float(lz + run_z)
			var base_idx = verts.size()

			verts.append(Vector3(flx, fnh, z_start))
			verts.append(Vector3(flx, fnh, z_end))
			verts.append(Vector3(flx, fh, z_end))
			verts.append(Vector3(flx, fh, z_start))

			for _k in range(4):
				norms.append(norm_west)
				cols.append(side_col)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

			lz += run_z

		# East (+X)
		lz = 0
		while lz < n:
			var col_idx = col_base + lz * apron_w
			var side_mat = side_mats[col_idx]
			if side_mat == 0:
				lz += 1
				continue
			var h = heights[col_idx]
			var h_e = heights[col_idx + 1]
			if h_e >= h:
				lz += 1
				continue

			var run_z = 1
			while (lz + run_z) < n:
				var next_idx = col_base + (lz + run_z) * apron_w
				if side_mats[next_idx] != side_mat:
					break
				if heights[next_idx] != h:
					break
				if heights[next_idx + 1] != h_e:
					break
				run_z += 1

			var side_col = registry.get_side_color(side_mat)
			var fnh = float(h_e)
			var fh = float(h)
			var z_start = float(lz)
			var z_end = float(lz + run_z)
			var base_idx = verts.size()

			verts.append(Vector3(flx + 1.0, fnh, z_end))
			verts.append(Vector3(flx + 1.0, fnh, z_start))
			verts.append(Vector3(flx + 1.0, fh, z_start))
			verts.append(Vector3(flx + 1.0, fh, z_end))

			for _k in range(4):
				norms.append(norm_east)
				cols.append(side_col)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

			lz += run_z

	# South (-Z) and North (+Z) merge along X
	var norm_south = Vector3(0.0, 0.0, -1.0)
	var norm_north = Vector3(0.0, 0.0, 1.0)

	for lz in range(n):
		var flz = float(lz)
		var row_base = 1 + (lz + 1) * apron_w

		# South (-Z)
		var lx = 0
		while lx < n:
			var col_idx = row_base + lx
			var side_mat = side_mats[col_idx]
			if side_mat == 0:
				lx += 1
				continue
			var h = heights[col_idx]
			var h_s = heights[col_idx - apron_w]
			if h_s >= h:
				lx += 1
				continue

			var run_x = 1
			while (lx + run_x) < n:
				var next_idx = row_base + (lx + run_x)
				if side_mats[next_idx] != side_mat:
					break
				if heights[next_idx] != h:
					break
				if heights[next_idx - apron_w] != h_s:
					break
				run_x += 1

			var side_col = registry.get_side_color(side_mat)
			var fnh = float(h_s)
			var fh = float(h)
			var x_start = float(lx)
			var x_end = float(lx + run_x)
			var base_idx = verts.size()

			verts.append(Vector3(x_end, fnh, flz))
			verts.append(Vector3(x_start, fnh, flz))
			verts.append(Vector3(x_start, fh, flz))
			verts.append(Vector3(x_end, fh, flz))

			for _k in range(4):
				norms.append(norm_south)
				cols.append(side_col)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

			lx += run_x

		# North (+Z)
		lx = 0
		while lx < n:
			var col_idx = row_base + lx
			var side_mat = side_mats[col_idx]
			if side_mat == 0:
				lx += 1
				continue
			var h = heights[col_idx]
			var h_n = heights[col_idx + apron_w]
			if h_n >= h:
				lx += 1
				continue

			var run_x = 1
			while (lx + run_x) < n:
				var next_idx = row_base + (lx + run_x)
				if side_mats[next_idx] != side_mat:
					break
				if heights[next_idx] != h:
					break
				if heights[next_idx + apron_w] != h_n:
					break
				run_x += 1

			var side_col = registry.get_side_color(side_mat)
			var fnh = float(h_n)
			var fh = float(h)
			var x_start = float(lx)
			var x_end = float(lx + run_x)
			var base_idx = verts.size()

			verts.append(Vector3(x_start, fnh, flz + 1.0))
			verts.append(Vector3(x_end, fnh, flz + 1.0))
			verts.append(Vector3(x_end, fh, flz + 1.0))
			verts.append(Vector3(x_start, fh, flz + 1.0))

			for _k in range(4):
				norms.append(norm_north)
				cols.append(side_col)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

			lx += run_x

	mesh.vertices = verts
	mesh.normals = norms
	mesh.colors = cols
	mesh.indices = inds
	mesh.has_cave_mouth = s_data.has_cave_mouth
	mesh.water_mesh_data = _water_mesher.build_water_mesh(s_data, sea_level)

	return mesh
