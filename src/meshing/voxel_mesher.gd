class_name VoxelMesher
extends Mesher

## High-performance 3D greedy voxel mesher with dual-layer surface and subterranean separation.
## Physically decouples the surface crust from subterranean caves into a DualMeshBundle,
## eliminating 80%+ of GPU triangle throughput when the player is on the surface.

const SurfaceShellMesher = preload("res://src/meshing/surface_shell_mesher.gd")

var sea_level: int = 24
var crust_depth: int = 3
var _shell_mesher: SurfaceShellMesher = SurfaceShellMesher.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	# Polymorphic fallback: if passed 2.5D surface shell data, delegate to surface shell mesher
	if data is SurfaceChunkData:
		return _shell_mesher.build_mesh(data, registry)

	if not (data is VoxelChunkData):
		push_error("VoxelMesher: Unsupported data type")
		return MeshData.new()

	var v_data: VoxelChunkData = data
	var bundle = DualMeshBundle.new()

	var s_verts = PackedVector3Array()
	var s_norms = PackedVector3Array()
	var s_cols = PackedColorArray()
	var s_inds = PackedInt32Array()

	var c_verts = PackedVector3Array()
	var c_norms = PackedVector3Array()
	var c_cols = PackedColorArray()
	var c_inds = PackedInt32Array()

	var n = v_data.chunk_size
	var max_h = v_data.max_height

	# If synthetic/test chunk data without surface_heights, treat all voxels as surface
	var has_heights = v_data.has_surface_data()

	# -------------------------------------------------------------------------
	# 1. Top (+Y) and Bottom (-Y) faces: horizontal slices (X, Z)
	# -------------------------------------------------------------------------
	var s_top_mask = PackedByteArray()
	var s_bot_mask = PackedByteArray()
	var c_top_mask = PackedByteArray()
	var c_bot_mask = PackedByteArray()
	s_top_mask.resize(n * n)
	s_bot_mask.resize(n * n)
	c_top_mask.resize(n * n)
	c_bot_mask.resize(n * n)

	for ly in range(max_h):
		s_top_mask.fill(0)
		s_bot_mask.fill(0)
		c_top_mask.fill(0)
		c_bot_mask.fill(0)
		var has_s_top = false
		var has_s_bot = false
		var has_c_top = false
		var has_c_bot = false

		for lz in range(n):
			for lx in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lx + lz * n

				var is_surf = true
				if has_heights:
					var boundary_y = v_data.get_surface_height(lx, lz) - crust_depth
					is_surf = (ly >= boundary_y)

				# Top (+Y): neighbor above is air
				var above_mat = v_data.get_voxel(lx, ly + 1, lz) if (ly + 1 < max_h) else 0
				# Bottom (-Y): neighbor below is air
				var below_mat = v_data.get_voxel(lx, ly - 1, lz) if (ly - 1 >= 0) else 0

				if is_surf:
					if above_mat == 0:
						s_top_mask[idx] = mat
						has_s_top = true
					if below_mat == 0:
						s_bot_mask[idx] = mat
						has_s_bot = true
				else:
					if above_mat == 0:
						c_top_mask[idx] = mat
						has_c_top = true
					if below_mat == 0:
						c_bot_mask[idx] = mat
						has_c_bot = true

		if has_s_top:
			_greedy_merge_horizontal(s_top_mask, n, ly, true, registry, s_verts, s_norms, s_cols, s_inds)
		if has_s_bot:
			_greedy_merge_horizontal(s_bot_mask, n, ly, false, registry, s_verts, s_norms, s_cols, s_inds)
		if has_c_top:
			_greedy_merge_horizontal(c_top_mask, n, ly, true, registry, c_verts, c_norms, c_cols, c_inds)
		if has_c_bot:
			_greedy_merge_horizontal(c_bot_mask, n, ly, false, registry, c_verts, c_norms, c_cols, c_inds)

	# -------------------------------------------------------------------------
	# 2. West (-X) and East (+X) faces: vertical slices along X (Z, Y)
	# -------------------------------------------------------------------------
	var s_west_mask = PackedByteArray()
	var s_east_mask = PackedByteArray()
	var c_west_mask = PackedByteArray()
	var c_east_mask = PackedByteArray()
	s_west_mask.resize(n * max_h)
	s_east_mask.resize(n * max_h)
	c_west_mask.resize(n * max_h)
	c_east_mask.resize(n * max_h)

	for lx in range(n):
		s_west_mask.fill(0)
		s_east_mask.fill(0)
		c_west_mask.fill(0)
		c_east_mask.fill(0)
		var has_s_west = false
		var has_s_east = false
		var has_c_west = false
		var has_c_east = false

		for ly in range(max_h):
			for lz in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lz + ly * n

				var is_surf = true
				if has_heights:
					var boundary_y = v_data.get_surface_height(lx, lz) - crust_depth
					is_surf = (ly >= boundary_y)

				var w_air = (v_data.get_voxel(lx - 1, ly, lz) == 0)
				var e_air = (v_data.get_voxel(lx + 1, ly, lz) == 0)

				if is_surf:
					if w_air:
						s_west_mask[idx] = mat
						has_s_west = true
					if e_air:
						s_east_mask[idx] = mat
						has_s_east = true
				else:
					if w_air:
						c_west_mask[idx] = mat
						has_c_west = true
					if e_air:
						c_east_mask[idx] = mat
						has_c_east = true

		if has_s_west:
			_greedy_merge_x_aligned(s_west_mask, n, max_h, lx, false, registry, s_verts, s_norms, s_cols, s_inds)
		if has_s_east:
			_greedy_merge_x_aligned(s_east_mask, n, max_h, lx, true, registry, s_verts, s_norms, s_cols, s_inds)
		if has_c_west:
			_greedy_merge_x_aligned(c_west_mask, n, max_h, lx, false, registry, c_verts, c_norms, c_cols, c_inds)
		if has_c_east:
			_greedy_merge_x_aligned(c_east_mask, n, max_h, lx, true, registry, c_verts, c_norms, c_cols, c_inds)

	# -------------------------------------------------------------------------
	# 3. South (-Z) and North (+Z) faces: vertical slices along Z (X, Y)
	# -------------------------------------------------------------------------
	var s_south_mask = PackedByteArray()
	var s_north_mask = PackedByteArray()
	var c_south_mask = PackedByteArray()
	var c_north_mask = PackedByteArray()
	s_south_mask.resize(n * max_h)
	s_north_mask.resize(n * max_h)
	c_south_mask.resize(n * max_h)
	c_north_mask.resize(n * max_h)

	for lz in range(n):
		s_south_mask.fill(0)
		s_north_mask.fill(0)
		c_south_mask.fill(0)
		c_north_mask.fill(0)
		var has_s_south = false
		var has_s_north = false
		var has_c_south = false
		var has_c_north = false

		for ly in range(max_h):
			for lx in range(n):
				var mat = v_data.get_voxel(lx, ly, lz)
				if mat == 0:
					continue
				var idx = lx + ly * n

				var is_surf = true
				if has_heights:
					var boundary_y = v_data.get_surface_height(lx, lz) - crust_depth
					is_surf = (ly >= boundary_y)

				var s_air = (v_data.get_voxel(lx, ly, lz - 1) == 0)
				var n_air = (v_data.get_voxel(lx, ly, lz + 1) == 0)

				if is_surf:
					if s_air:
						s_south_mask[idx] = mat
						has_s_south = true
					if n_air:
						s_north_mask[idx] = mat
						has_s_north = true
				else:
					if s_air:
						c_south_mask[idx] = mat
						has_c_south = true
					if n_air:
						c_north_mask[idx] = mat
						has_c_north = true

		if has_s_south:
			_greedy_merge_z_aligned(s_south_mask, n, max_h, lz, false, registry, s_verts, s_norms, s_cols, s_inds)
		if has_s_north:
			_greedy_merge_z_aligned(s_north_mask, n, max_h, lz, true, registry, s_verts, s_norms, s_cols, s_inds)
		if has_c_south:
			_greedy_merge_z_aligned(c_south_mask, n, max_h, lz, false, registry, c_verts, c_norms, c_cols, c_inds)
		if has_c_north:
			_greedy_merge_z_aligned(c_north_mask, n, max_h, lz, true, registry, c_verts, c_norms, c_cols, c_inds)

	# Assign surface geometry to bundle primary buffers
	bundle.vertices = s_verts
	bundle.normals = s_norms
	bundle.colors = s_cols
	bundle.indices = s_inds
	bundle.has_cave_mouth = v_data.has_cave_mouth

	# Assign subterranean geometry to bundle cave mesh data
	if not c_verts.is_empty():
		var cave_mesh = MeshData.new()
		cave_mesh.vertices = c_verts
		cave_mesh.normals = c_norms
		cave_mesh.colors = c_cols
		cave_mesh.indices = c_inds
		bundle.cave_mesh_data = cave_mesh
	else:
		bundle.cave_mesh_data = null

	# -------------------------------------------------------------------------
	# 4. Subterranean & surface water meshing
	# -------------------------------------------------------------------------
	_build_dual_water_mesh(v_data, bundle, has_heights)

	return bundle

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

func _build_dual_water_mesh(v_data: VoxelChunkData, bundle: DualMeshBundle, has_heights: bool) -> void:
	var n = v_data.chunk_size
	var max_h = v_data.max_height

	var s_w_verts = PackedVector3Array()
	var s_w_norms = PackedVector3Array()
	var s_w_cols = PackedColorArray()
	var s_w_inds = PackedInt32Array()

	var c_w_verts = PackedVector3Array()
	var c_w_norms = PackedVector3Array()
	var c_w_cols = PackedColorArray()
	var c_w_inds = PackedInt32Array()

	var water_color = Color(0.12, 0.38, 0.65, 0.75)
	var norm = Vector3(0.0, 1.0, 0.0)

	var s_mask = PackedByteArray()
	var c_mask = PackedByteArray()
	s_mask.resize(n * n)
	c_mask.resize(n * n)

	for ly in range(max_h):
		s_mask.fill(0)
		c_mask.fill(0)
		var has_s_water = false
		var has_c_water = false

		for lz in range(n):
			for lx in range(n):
				if v_data.has_water(lx, ly, lz):
					var above_has_water = (ly + 1 < max_h) and v_data.has_water(lx, ly + 1, lz)
					if not above_has_water:
						var idx = lx + lz * n
						var is_surf = true
						if has_heights:
							var boundary_y = v_data.get_surface_height(lx, lz) - crust_depth
							is_surf = (ly >= boundary_y)

						if is_surf:
							s_mask[idx] = 1
							has_s_water = true
						else:
							c_mask[idx] = 1
							has_c_water = true

		if has_s_water:
			_greedy_merge_water_slice(s_mask, n, ly, water_color, norm, s_w_verts, s_w_norms, s_w_cols, s_w_inds)
		if has_c_water:
			_greedy_merge_water_slice(c_mask, n, ly, water_color, norm, c_w_verts, c_w_norms, c_w_cols, c_w_inds)

	if not s_w_verts.is_empty():
		var s_water = MeshData.new()
		s_water.vertices = s_w_verts
		s_water.normals = s_w_norms
		s_water.colors = s_w_cols
		s_water.indices = s_w_inds
		bundle.water_mesh_data = s_water
	else:
		bundle.water_mesh_data = null

	if not c_w_verts.is_empty() and bundle.cave_mesh_data != null:
		var c_water = MeshData.new()
		c_water.vertices = c_w_verts
		c_water.normals = c_w_norms
		c_water.colors = c_w_cols
		c_water.indices = c_w_inds
		bundle.cave_mesh_data.water_mesh_data = c_water

func _greedy_merge_water_slice(
	mask: PackedByteArray, n: int, ly: int,
	water_color: Color, norm: Vector3,
	w_verts: PackedVector3Array, w_norms: PackedVector3Array,
	w_cols: PackedColorArray, w_inds: PackedInt32Array
) -> void:
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
