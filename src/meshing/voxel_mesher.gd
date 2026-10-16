class_name VoxelMesher
extends Mesher

## High-performance 3D greedy voxel mesher with multi-axis planar face merging
## and planar subterranean water meshing.
## Slashing triangle count by 80-90% to maintain 160 FPS and fast physics baking.

const SurfaceShellMesher = preload("res://src/meshing/surface_shell_mesher.gd")

var sea_level: int = 24
var _shell_mesher: SurfaceShellMesher = SurfaceShellMesher.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	# Polymorphic fallback: if passed 2.5D surface shell data, delegate to surface shell mesher
	if data is SurfaceChunkData:
		return _shell_mesher.build_mesh(data, registry)

	if not (data is VoxelChunkData):
		push_error("VoxelMesher: Unsupported data type")
		return MeshData.new()

	var v_data: VoxelChunkData = data
	var mesh = MeshData.new()

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	var inds = PackedInt32Array()

	var n = v_data.chunk_size
	var max_h = v_data.max_height

	# -------------------------------------------------------------------------
	# 1. Top (+Y) and Bottom (-Y) faces: horizontal slices (X, Z)
	# -------------------------------------------------------------------------
	var top_mask = PackedByteArray()
	var bot_mask = PackedByteArray()
	top_mask.resize(n * n)
	bot_mask.resize(n * n)

	for ly in range(max_h):
		top_mask.fill(0)
		bot_mask.fill(0)
		var has_top = false
		var has_bot = false

		for lz in range(n):
			for lx in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lx + lz * n

				# Top (+Y): neighbor above is air
				var above_mat = v_data.get_voxel(lx, ly + 1, lz) if (ly + 1 < max_h) else 0
				if above_mat == 0:
					top_mask[idx] = mat
					has_top = true

				# Bottom (-Y): neighbor below is air
				var below_mat = v_data.get_voxel(lx, ly - 1, lz) if (ly - 1 >= 0) else 0
				if below_mat == 0:
					bot_mask[idx] = mat
					has_bot = true

		if has_top:
			_greedy_merge_horizontal(top_mask, n, ly, true, registry, verts, norms, cols, inds)
		if has_bot:
			_greedy_merge_horizontal(bot_mask, n, ly, false, registry, verts, norms, cols, inds)

	# -------------------------------------------------------------------------
	# 2. West (-X) and East (+X) faces: vertical slices along X (Z, Y)
	# -------------------------------------------------------------------------
	var west_mask = PackedByteArray()
	var east_mask = PackedByteArray()
	west_mask.resize(n * max_h)
	east_mask.resize(n * max_h)

	for lx in range(n):
		west_mask.fill(0)
		east_mask.fill(0)
		var has_west = false
		var has_east = false

		for ly in range(max_h):
			for lz in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lz + ly * n

				# West (-X)
				if v_data.get_voxel(lx - 1, ly, lz) == 0:
					west_mask[idx] = mat
					has_west = true

				# East (+X)
				if v_data.get_voxel(lx + 1, ly, lz) == 0:
					east_mask[idx] = mat
					has_east = true

		if has_west:
			_greedy_merge_x_aligned(west_mask, n, max_h, lx, false, registry, verts, norms, cols, inds)
		if has_east:
			_greedy_merge_x_aligned(east_mask, n, max_h, lx, true, registry, verts, norms, cols, inds)

	# -------------------------------------------------------------------------
	# 3. South (-Z) and North (+Z) faces: vertical slices along Z (X, Y)
	# -------------------------------------------------------------------------
	var south_mask = PackedByteArray()
	var north_mask = PackedByteArray()
	south_mask.resize(n * max_h)
	north_mask.resize(n * max_h)

	for lz in range(n):
		south_mask.fill(0)
		north_mask.fill(0)
		var has_south = false
		var has_north = false

		for ly in range(max_h):
			for lx in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lx + ly * n

				# South (-Z)
				if v_data.get_voxel(lx, ly, lz - 1) == 0:
					south_mask[idx] = mat
					has_south = true

				# North (+Z)
				if v_data.get_voxel(lx, ly, lz + 1) == 0:
					north_mask[idx] = mat
					has_north = true

		if has_south:
			_greedy_merge_z_aligned(south_mask, n, max_h, lz, false, registry, verts, norms, cols, inds)
		if has_north:
			_greedy_merge_z_aligned(north_mask, n, max_h, lz, true, registry, verts, norms, cols, inds)

	mesh.vertices = verts
	mesh.normals = norms
	mesh.colors = cols
	mesh.indices = inds

	# -------------------------------------------------------------------------
	# 4. Subterranean & surface water meshing
	# -------------------------------------------------------------------------
	mesh.water_mesh_data = _build_water_mesh(v_data)

	return mesh

func _greedy_merge_horizontal(
	mask: PackedByteArray, n: int, ly: int, is_top: bool,
	registry: MaterialRegistry,
	verts: PackedVector3Array, norms: PackedVector3Array,
	cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var visited = PackedByteArray()
	visited.resize(n * n)
	visited.fill(0)

	var y_pos = float(ly + 1) if is_top else float(ly)
	var norm = Vector3(0.0, 1.0, 0.0) if is_top else Vector3(0.0, -1.0, 0.0)

	for lz in range(n):
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1 or mask[idx] == 0:
				continue

			var mat = mask[idx]
			var w = 1
			while (lx + w) < n and visited[(lx + w) + lz * n] == 0 and mask[(lx + w) + lz * n] == mat:
				w += 1

			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				for cx in range(lx, lx + w):
					var row_idx = cx + (lz + d) * n
					if visited[row_idx] == 1 or mask[row_idx] != mat:
						can_expand = false
						break
				if can_expand:
					d += 1

			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			var color = registry.get_top_color(mat) if is_top else registry.get_side_color(mat)
			var base_idx = verts.size()
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			if is_top:
				verts.append(Vector3(flx, y_pos, flz))
				verts.append(Vector3(flx, y_pos, flz + fd))
				verts.append(Vector3(flx + fw, y_pos, flz + fd))
				verts.append(Vector3(flx + fw, y_pos, flz))
			else:
				verts.append(Vector3(flx + fw, y_pos, flz))
				verts.append(Vector3(flx + fw, y_pos, flz + fd))
				verts.append(Vector3(flx, y_pos, flz + fd))
				verts.append(Vector3(flx, y_pos, flz))

			for _k in range(4):
				norms.append(norm)
				cols.append(color)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

func _greedy_merge_x_aligned(
	mask: PackedByteArray, n: int, max_h: int, lx: int, is_east: bool,
	registry: MaterialRegistry,
	verts: PackedVector3Array, norms: PackedVector3Array,
	cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var visited = PackedByteArray()
	visited.resize(n * max_h)
	visited.fill(0)

	var x_pos = float(lx + 1) if is_east else float(lx)
	var norm = Vector3(1.0, 0.0, 0.0) if is_east else Vector3(-1.0, 0.0, 0.0)

	for ly in range(max_h):
		for lz in range(n):
			var idx = lz + ly * n
			if visited[idx] == 1 or mask[idx] == 0:
				continue

			var mat = mask[idx]
			var w = 1 # along Z
			while (lz + w) < n and visited[(lz + w) + ly * n] == 0 and mask[(lz + w) + ly * n] == mat:
				w += 1

			var h = 1 # along Y
			var can_expand = true
			while (ly + h) < max_h and can_expand:
				for cz in range(lz, lz + w):
					var row_idx = cz + (ly + h) * n
					if visited[row_idx] == 1 or mask[row_idx] != mat:
						can_expand = false
						break
				if can_expand:
					h += 1

			for ry in range(ly, ly + h):
				for rz in range(lz, lz + w):
					visited[rz + ry * n] = 1

			var color = registry.get_side_color(mat)
			var base_idx = verts.size()
			var flz = float(lz)
			var fly = float(ly)
			var fw = float(w)
			var fh = float(h)

			if is_east:
				verts.append(Vector3(x_pos, fly, flz + fw))
				verts.append(Vector3(x_pos, fly, flz))
				verts.append(Vector3(x_pos, fly + fh, flz))
				verts.append(Vector3(x_pos, fly + fh, flz + fw))
			else:
				verts.append(Vector3(x_pos, fly, flz))
				verts.append(Vector3(x_pos, fly, flz + fw))
				verts.append(Vector3(x_pos, fly + fh, flz + fw))
				verts.append(Vector3(x_pos, fly + fh, flz))

			for _k in range(4):
				norms.append(norm)
				cols.append(color)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

func _greedy_merge_z_aligned(
	mask: PackedByteArray, n: int, max_h: int, lz: int, is_north: bool,
	registry: MaterialRegistry,
	verts: PackedVector3Array, norms: PackedVector3Array,
	cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var visited = PackedByteArray()
	visited.resize(n * max_h)
	visited.fill(0)

	var z_pos = float(lz + 1) if is_north else float(lz)
	var norm = Vector3(0.0, 0.0, 1.0) if is_north else Vector3(0.0, 0.0, -1.0)

	for ly in range(max_h):
		for lx in range(n):
			var idx = lx + ly * n
			if visited[idx] == 1 or mask[idx] == 0:
				continue

			var mat = mask[idx]
			var w = 1 # along X
			while (lx + w) < n and visited[(lx + w) + ly * n] == 0 and mask[(lx + w) + ly * n] == mat:
				w += 1

			var h = 1 # along Y
			var can_expand = true
			while (ly + h) < max_h and can_expand:
				for cx in range(lx, lx + w):
					var row_idx = cx + (ly + h) * n
					if visited[row_idx] == 1 or mask[row_idx] != mat:
						can_expand = false
						break
				if can_expand:
					h += 1

			for ry in range(ly, ly + h):
				for rx in range(lx, lx + w):
					visited[rx + ry * n] = 1

			var color = registry.get_side_color(mat)
			var base_idx = verts.size()
			var flx = float(lx)
			var fly = float(ly)
			var fw = float(w)
			var fh = float(h)

			if is_north:
				verts.append(Vector3(flx, fly, z_pos))
				verts.append(Vector3(flx + fw, fly, z_pos))
				verts.append(Vector3(flx + fw, fly + fh, z_pos))
				verts.append(Vector3(flx, fly + fh, z_pos))
			else:
				verts.append(Vector3(flx + fw, fly, z_pos))
				verts.append(Vector3(flx, fly, z_pos))
				verts.append(Vector3(flx, fly + fh, z_pos))
				verts.append(Vector3(flx + fw, fly + fh, z_pos))

			for _k in range(4):
				norms.append(norm)
				cols.append(color)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

func _build_water_mesh(v_data: VoxelChunkData) -> MeshData:
	var n = v_data.chunk_size
	var max_h = v_data.max_height

	var w_verts = PackedVector3Array()
	var w_norms = PackedVector3Array()
	var w_cols = PackedColorArray()
	var w_inds = PackedInt32Array()

	var water_color = Color(0.12, 0.38, 0.65, 0.75)
	var norm = Vector3(0.0, 1.0, 0.0)

	var mask = PackedByteArray()
	mask.resize(n * n)

	for ly in range(max_h):
		mask.fill(0)
		var has_water_surface = false

		for lz in range(n):
			for lx in range(n):
				if v_data.has_water(lx, ly, lz):
					# If voxel above does not have water and is air, mesh the water surface
					var above_has_water = (ly + 1 < max_h) and v_data.has_water(lx, ly + 1, lz)
					if not above_has_water:
						mask[lx + lz * n] = 1
						has_water_surface = true

		if not has_water_surface:
			continue

		# Greedy merge horizontal water surface at level ly
		var visited = PackedByteArray()
		visited.resize(n * n)
		visited.fill(0)
		var y_pos = float(ly + 1)

		for lz in range(n):
			for lx in range(n):
				var idx = lx + lz * n
				if visited[idx] == 1 or mask[idx] == 0:
					continue

				var w = 1
				while (lx + w) < n and visited[(lx + w) + lz * n] == 0 and mask[(lx + w) + lz * n] == 1:
					w += 1

				var d = 1
				var can_expand = true
				while (lz + d) < n and can_expand:
					for cx in range(lx, lx + w):
						if visited[cx + (lz + d) * n] == 1 or mask[cx + (lz + d) * n] == 0:
							can_expand = false
							break
					if can_expand:
						d += 1

				for rz in range(lz, lz + d):
					for rx in range(lx, lx + w):
						visited[rx + rz * n] = 1

				var base_idx = w_verts.size()
				var flx = float(lx)
				var flz = float(lz)
				var fw = float(w)
				var fd = float(d)

				w_verts.append(Vector3(flx, y_pos, flz))
				w_verts.append(Vector3(flx, y_pos, flz + fd))
				w_verts.append(Vector3(flx + fw, y_pos, flz + fd))
				w_verts.append(Vector3(flx + fw, y_pos, flz))

				for _k in range(4):
					w_norms.append(norm)
					w_cols.append(water_color)

				w_inds.append(base_idx)
				w_inds.append(base_idx + 2)
				w_inds.append(base_idx + 1)
				w_inds.append(base_idx)
				w_inds.append(base_idx + 3)
				w_inds.append(base_idx + 2)

	if w_verts.is_empty():
		return null

	var w_mesh = MeshData.new()
	w_mesh.vertices = w_verts
	w_mesh.normals = w_norms
	w_mesh.colors = w_cols
	w_mesh.indices = w_inds
	return w_mesh
