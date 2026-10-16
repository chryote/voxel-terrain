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

	# -------------------------------------------------------------------------
	# 1. Top horizontal faces (2D greedy merging)
	# -------------------------------------------------------------------------
	var visited = PackedByteArray()
	visited.resize(n * n)
	visited.fill(0)

	for lz in range(n):
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1:
				continue

			var h = data.get_height(lx, lz)
			var mat = data.get_top_material(lx, lz)
			if mat == 0:
				continue

			# Find width w along X
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				if data.get_height(lx + w, lz) != h or data.get_top_material(lx + w, lz) != mat:
					break
				w += 1

			# Find depth d along Z
			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				for check_x in range(lx, lx + w):
					var row_idx = check_x + (lz + d) * n
					if visited[row_idx] == 1 or data.get_height(check_x, lz + d) != h or data.get_top_material(check_x, lz + d) != mat:
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
	# 2. Side vertical walls (exposed cliff/step faces)
	# -------------------------------------------------------------------------
	for lz in range(n):
		var flz = float(lz)
		for lx in range(n):
			var flx = float(lx)
			var h = data.get_height(lx, lz)
			var side_mat = data.get_side_material(lx, lz)
			if side_mat == 0:
				continue
			var side_col = registry.get_side_color(side_mat)
			var fh = float(h)

			# West (-X)
			var h_w = data.get_height(lx - 1, lz)
			if h_w < h:
				var fnh = float(h_w)
				var base_idx = verts.size()
				verts.append(Vector3(flx, fnh, flz))
				verts.append(Vector3(flx, fnh, flz + 1.0))
				verts.append(Vector3(flx, fh, flz + 1.0))
				verts.append(Vector3(flx, fh, flz))
				var norm = Vector3(-1.0, 0.0, 0.0)
				for _k in range(4):
					norms.append(norm)
					cols.append(side_col)
				inds.append(base_idx)
				inds.append(base_idx + 2)
				inds.append(base_idx + 1)
				inds.append(base_idx)
				inds.append(base_idx + 3)
				inds.append(base_idx + 2)

			# East (+X)
			var h_e = data.get_height(lx + 1, lz)
			if h_e < h:
				var fnh = float(h_e)
				var base_idx = verts.size()
				verts.append(Vector3(flx + 1.0, fnh, flz + 1.0))
				verts.append(Vector3(flx + 1.0, fnh, flz))
				verts.append(Vector3(flx + 1.0, fh, flz))
				verts.append(Vector3(flx + 1.0, fh, flz + 1.0))
				var norm = Vector3(1.0, 0.0, 0.0)
				for _k in range(4):
					norms.append(norm)
					cols.append(side_col)
				inds.append(base_idx)
				inds.append(base_idx + 2)
				inds.append(base_idx + 1)
				inds.append(base_idx)
				inds.append(base_idx + 3)
				inds.append(base_idx + 2)

			# South (-Z)
			var h_s = data.get_height(lx, lz - 1)
			if h_s < h:
				var fnh = float(h_s)
				var base_idx = verts.size()
				verts.append(Vector3(flx + 1.0, fnh, flz))
				verts.append(Vector3(flx, fnh, flz))
				verts.append(Vector3(flx, fh, flz))
				verts.append(Vector3(flx + 1.0, fh, flz))
				var norm = Vector3(0.0, 0.0, -1.0)
				for _k in range(4):
					norms.append(norm)
					cols.append(side_col)
				inds.append(base_idx)
				inds.append(base_idx + 2)
				inds.append(base_idx + 1)
				inds.append(base_idx)
				inds.append(base_idx + 3)
				inds.append(base_idx + 2)

			# North (+Z)
			var h_n = data.get_height(lx, lz + 1)
			if h_n < h:
				var fnh = float(h_n)
				var base_idx = verts.size()
				verts.append(Vector3(flx, fnh, flz + 1.0))
				verts.append(Vector3(flx + 1.0, fnh, flz + 1.0))
				verts.append(Vector3(flx + 1.0, fh, flz + 1.0))
				verts.append(Vector3(flx, fh, flz + 1.0))
				var norm = Vector3(0.0, 0.0, 1.0)
				for _k in range(4):
					norms.append(norm)
					cols.append(side_col)
				inds.append(base_idx)
				inds.append(base_idx + 2)
				inds.append(base_idx + 1)
				inds.append(base_idx)
				inds.append(base_idx + 3)
				inds.append(base_idx + 2)

	mesh.vertices = verts
	mesh.normals = norms
	mesh.colors = cols
	mesh.indices = inds
	mesh.has_cave_mouth = s_data.has_cave_mouth
	mesh.water_mesh_data = _water_mesher.build_water_mesh(s_data, sea_level)

	return mesh
