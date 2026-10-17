class_name ChasmShellMesher
extends Mesher

## Ultra-fast 2.5D Direct Heightfield Mesher for deep subterranean chasms and battle arenas.
## Replaces 3D voxel iteration (185k voxels) with direct 2D greedy floor, ceiling, and curtain wall passes.
## Produces a DualMeshBundle with decoupled surface, subterranean, and water meshes.

const SurfaceShellMesher = preload("res://src/meshing/surface_shell_mesher.gd")
const ChasmChunkData = preload("res://src/core/chasm_chunk_data.gd")

var _surface_mesher: SurfaceShellMesher = SurfaceShellMesher.new()

func build_mesh(data: RefCounted, registry: MaterialRegistry) -> MeshData:
	if data is SurfaceChunkData:
		return _surface_mesher.build_mesh(data, registry)

	var chasm_data = data as ChasmChunkData
	if chasm_data == null:
		push_error("ChasmShellMesher: Unsupported data type")
		return MeshData.new()

	var bundle = DualMeshBundle.new()

	# 1. Surface Shell Meshing
	if chasm_data.surface_data != null:
		var s_mesh = _surface_mesher.build_mesh(chasm_data.surface_data, registry)
		bundle.vertices = s_mesh.vertices
		bundle.normals = s_mesh.normals
		bundle.colors = s_mesh.colors
		bundle.indices = s_mesh.indices
		bundle.water_mesh_data = s_mesh.water_mesh_data
		bundle.has_cave_mouth = s_mesh.has_cave_mouth

	# If chunk has no subterranean chasm geometry, return surface bundle immediately
	if not chasm_data.has_chasm:
		return bundle

	# 2. Direct 2D Subterranean Cave Meshing
	_mesh_subterranean_chasm(chasm_data, registry, bundle)

	return bundle

func _mesh_subterranean_chasm(chasm_data: ChasmChunkData, registry: MaterialRegistry, bundle: DualMeshBundle) -> void:
	var n = chasm_data.chunk_size
	var apron_w = chasm_data.apron_size
	var c_verts = PackedVector3Array()
	var c_norms = PackedVector3Array()
	var c_cols = PackedColorArray()
	var c_inds = PackedInt32Array()

	var sub_water_verts = PackedVector3Array()
	var sub_water_norms = PackedVector3Array()
	var sub_water_cols = PackedColorArray()
	var sub_water_inds = PackedInt32Array()

	var fl_heights = chasm_data.floor_heights
	var cl_heights = chasm_data.ceil_heights
	var flags = chasm_data.chasm_flags
	var mats = chasm_data.materials
	var water_lvl = chasm_data.chasm_water_level

	# -------------------------------------------------------------------------
	# Pass A: Floor (+Y faces, upward facing) with 2D greedy merging
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
			var flag = flags[col_idx]
			if (flag & ChasmChunkData.FLAG_CHASM) == 0 or (flag & ChasmChunkData.FLAG_PILLAR) != 0:
				continue

			var fl_y = fl_heights[col_idx]
			var mat = mats[col_idx]

			# Find width w along X
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				var next_col = (lx + w + 1) + row_start
				var next_flag = flags[next_col]
				if (next_flag & ChasmChunkData.FLAG_CHASM) == 0 or (next_flag & ChasmChunkData.FLAG_PILLAR) != 0:
					break
				if fl_heights[next_col] != fl_y or mats[next_col] != mat:
					break
				w += 1

			# Find depth d along Z
			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				var exp_row = (lz + d + 1) * apron_w
				for check_x in range(lx, lx + w):
					var r_idx = check_x + (lz + d) * n
					if visited[r_idx] == 1:
						can_expand = false
						break
					var exp_col = (check_x + 1) + exp_row
					var exp_flag = flags[exp_col]
					if (exp_flag & ChasmChunkData.FLAG_CHASM) == 0 or (exp_flag & ChasmChunkData.FLAG_PILLAR) != 0:
						can_expand = false
						break
					if fl_heights[exp_col] != fl_y or mats[exp_col] != mat:
						can_expand = false
						break
				if can_expand:
					d += 1

			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			# Emit merged floor quad (+Y normal)
			# Floor top face sits at fl_y + 1.0
			var fy = float(fl_y + 1)
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			var base_idx = c_verts.size()
			c_verts.append(Vector3(flx, fy, flz))
			c_verts.append(Vector3(flx, fy, flz + fd))
			c_verts.append(Vector3(flx + fw, fy, flz + fd))
			c_verts.append(Vector3(flx + fw, fy, flz))

			var norm = Vector3.UP
			c_norms.append(norm)
			c_norms.append(norm)
			c_norms.append(norm)
			c_norms.append(norm)

			var col = registry.get_top_color(mat)
			c_cols.append(col)
			c_cols.append(col)
			c_cols.append(col)
			c_cols.append(col)

			c_inds.append(base_idx)
			c_inds.append(base_idx + 1)
			c_inds.append(base_idx + 2)
			c_inds.append(base_idx)
			c_inds.append(base_idx + 2)
			c_inds.append(base_idx + 3)

	# -------------------------------------------------------------------------
	# Pass B: Ceiling (-Y faces, downward facing with inverted normals)
	# -------------------------------------------------------------------------
	visited.fill(0)

	for lz in range(n):
		var row_start = (lz + 1) * apron_w
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1:
				continue

			var col_idx = (lx + 1) + row_start
			var flag = flags[col_idx]
			if (flag & ChasmChunkData.FLAG_CHASM) == 0 or (flag & ChasmChunkData.FLAG_PILLAR) != 0:
				continue

			var cl_y = cl_heights[col_idx]
			var mat = mats[col_idx]

			# Find width w along X
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				var next_col = (lx + w + 1) + row_start
				var next_flag = flags[next_col]
				if (next_flag & ChasmChunkData.FLAG_CHASM) == 0 or (next_flag & ChasmChunkData.FLAG_PILLAR) != 0:
					break
				if cl_heights[next_col] != cl_y or mats[next_col] != mat:
					break
				w += 1

			# Find depth d along Z
			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				var exp_row = (lz + d + 1) * apron_w
				for check_x in range(lx, lx + w):
					var r_idx = check_x + (lz + d) * n
					if visited[r_idx] == 1:
						can_expand = false
						break
					var exp_col = (check_x + 1) + exp_row
					var exp_flag = flags[exp_col]
					if (exp_flag & ChasmChunkData.FLAG_CHASM) == 0 or (exp_flag & ChasmChunkData.FLAG_PILLAR) != 0:
						can_expand = false
						break
					if cl_heights[exp_col] != cl_y or mats[exp_col] != mat:
						can_expand = false
						break
				if can_expand:
					d += 1

			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			# Emit merged ceiling quad (-Y normal, inverted winding)
			# Ceiling bottom face sits at cl_y
			var cy = float(cl_y)
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			var base_idx = c_verts.size()
			c_verts.append(Vector3(flx, cy, flz))
			c_verts.append(Vector3(flx + fw, cy, flz))
			c_verts.append(Vector3(flx + fw, cy, flz + fd))
			c_verts.append(Vector3(flx, cy, flz + fd))

			var norm = Vector3.DOWN
			c_norms.append(norm)
			c_norms.append(norm)
			c_norms.append(norm)
			c_norms.append(norm)

			var col = registry.get_side_color(mat)
			c_cols.append(col)
			c_cols.append(col)
			c_cols.append(col)
			c_cols.append(col)

			c_inds.append(base_idx)
			c_inds.append(base_idx + 1)
			c_inds.append(base_idx + 2)
			c_inds.append(base_idx)
			c_inds.append(base_idx + 2)
			c_inds.append(base_idx + 3)

	# -------------------------------------------------------------------------
	# Pass C: Vertical Curtain Walls along X-boundaries (normal +X and -X)
	# -------------------------------------------------------------------------
	for lx in range(n + 1):
		# Compare column lx - 1 with lx
		var lz = 0
		while lz < n:
			var left_col = lx + (lz + 1) * apron_w
			var right_col = (lx + 1) + (lz + 1) * apron_w

			var left_flag = flags[left_col]
			var right_flag = flags[right_col]

			var left_void = (left_flag & ChasmChunkData.FLAG_CHASM) != 0 and (left_flag & ChasmChunkData.FLAG_PILLAR) == 0
			var right_void = (right_flag & ChasmChunkData.FLAG_CHASM) != 0 and (right_flag & ChasmChunkData.FLAG_PILLAR) == 0

			# Face facing -X: left is void, right is solid
			if left_void and not right_void and lx < n:
				var y_min = fl_heights[left_col] + 1
				var y_max = cl_heights[left_col]
				var mat = mats[right_col]

				var d = 1
				while (lz + d) < n:
					var nl_col = lx + (lz + d + 1) * apron_w
					var nr_col = (lx + 1) + (lz + d + 1) * apron_w
					var nl_flag = flags[nl_col]
					var nr_flag = flags[nr_col]
					var nl_void = (nl_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nl_flag & ChasmChunkData.FLAG_PILLAR) == 0
					var nr_void = (nr_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nr_flag & ChasmChunkData.FLAG_PILLAR) == 0
					if not nl_void or nr_void:
						break
					if (fl_heights[nl_col] + 1) != y_min or cl_heights[nl_col] != y_max or mats[nr_col] != mat:
						break
					d += 1

				if y_max > y_min:
					_emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, float(lx), float(y_min), float(y_max), float(lz), float(d), registry.get_side_color(mat))
				lz += d
				continue

			# Face facing +X: left is solid, right is void
			if not left_void and right_void and lx > 0:
				var y_min = fl_heights[right_col] + 1
				var y_max = cl_heights[right_col]
				var mat = mats[left_col]

				var d = 1
				while (lz + d) < n:
					var nl_col = lx + (lz + d + 1) * apron_w
					var nr_col = (lx + 1) + (lz + d + 1) * apron_w
					var nl_flag = flags[nl_col]
					var nr_flag = flags[nr_col]
					var nl_void = (nl_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nl_flag & ChasmChunkData.FLAG_PILLAR) == 0
					var nr_void = (nr_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nr_flag & ChasmChunkData.FLAG_PILLAR) == 0
					if nl_void or not nr_void:
						break
					if (fl_heights[nr_col] + 1) != y_min or cl_heights[nr_col] != y_max or mats[nl_col] != mat:
						break
					d += 1

				if y_max > y_min:
					_emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, float(lx), float(y_min), float(y_max), float(lz), float(d), registry.get_side_color(mat))
				lz += d
				continue

			# Floor step face between two void columns
			if left_void and right_void:
				var left_fl = fl_heights[left_col]
				var right_fl = fl_heights[right_col]
				if left_fl > right_fl and lx > 0:
					# Left floor higher than right floor: wall faces +X into right column
					_emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, float(lx), float(right_fl + 1), float(left_fl + 1), float(lz), 1.0, registry.get_side_color(mats[left_col]))
				elif right_fl > left_fl and lx < n:
					# Right floor higher than left floor: wall faces -X into left column
					_emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, float(lx), float(left_fl + 1), float(right_fl + 1), float(lz), 1.0, registry.get_side_color(mats[right_col]))

				var left_cl = cl_heights[left_col]
				var right_cl = cl_heights[right_col]
				if left_cl < right_cl and lx > 0:
					# Left ceiling lower: wall faces +X into right column
					_emit_quad_x_pos(c_verts, c_norms, c_cols, c_inds, float(lx), float(left_cl), float(right_cl), float(lz), 1.0, registry.get_side_color(mats[left_col]))
				elif right_cl < left_cl and lx < n:
					# Right ceiling lower: wall faces -X into left column
					_emit_quad_x_neg(c_verts, c_norms, c_cols, c_inds, float(lx), float(right_cl), float(left_cl), float(lz), 1.0, registry.get_side_color(mats[right_col]))

			lz += 1

	# -------------------------------------------------------------------------
	# Pass D: Vertical Curtain Walls along Z-boundaries (normal +Z and -Z)
	# -------------------------------------------------------------------------
	for lz in range(n + 1):
		var lx = 0
		while lx < n:
			var back_col = (lx + 1) + lz * apron_w
			var front_col = (lx + 1) + (lz + 1) * apron_w

			var back_flag = flags[back_col]
			var front_flag = flags[front_col]

			var back_void = (back_flag & ChasmChunkData.FLAG_CHASM) != 0 and (back_flag & ChasmChunkData.FLAG_PILLAR) == 0
			var front_void = (front_flag & ChasmChunkData.FLAG_CHASM) != 0 and (front_flag & ChasmChunkData.FLAG_PILLAR) == 0

			# Face facing -Z: back is void, front is solid
			if back_void and not front_void and lz < n:
				var y_min = fl_heights[back_col] + 1
				var y_max = cl_heights[back_col]
				var mat = mats[front_col]

				var w = 1
				while (lx + w) < n:
					var nb_col = (lx + w + 1) + lz * apron_w
					var nf_col = (lx + w + 1) + (lz + 1) * apron_w
					var nb_flag = flags[nb_col]
					var nf_flag = flags[nf_col]
					var nb_void = (nb_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nb_flag & ChasmChunkData.FLAG_PILLAR) == 0
					var nf_void = (nf_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nf_flag & ChasmChunkData.FLAG_PILLAR) == 0
					if not nb_void or nf_void:
						break
					if (fl_heights[nb_col] + 1) != y_min or cl_heights[nb_col] != y_max or mats[nf_col] != mat:
						break
					w += 1

				if y_max > y_min:
					_emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, float(lz), float(y_min), float(y_max), float(lx), float(w), registry.get_side_color(mat))
				lx += w
				continue

			# Face facing +Z: back is solid, front is void
			if not back_void and front_void and lz > 0:
				var y_min = fl_heights[front_col] + 1
				var y_max = cl_heights[front_col]
				var mat = mats[back_col]

				var w = 1
				while (lx + w) < n:
					var nb_col = (lx + w + 1) + lz * apron_w
					var nf_col = (lx + w + 1) + (lz + 1) * apron_w
					var nb_flag = flags[nb_col]
					var nf_flag = flags[nf_col]
					var nb_void = (nb_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nb_flag & ChasmChunkData.FLAG_PILLAR) == 0
					var nf_void = (nf_flag & ChasmChunkData.FLAG_CHASM) != 0 and (nf_flag & ChasmChunkData.FLAG_PILLAR) == 0
					if nb_void or not nf_void:
						break
					if (fl_heights[nf_col] + 1) != y_min or cl_heights[nf_col] != y_max or mats[nb_col] != mat:
						break
					w += 1

				if y_max > y_min:
					_emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, float(lz), float(y_min), float(y_max), float(lx), float(w), registry.get_side_color(mat))
				lx += w
				continue

			# Floor step face between two void columns
			if back_void and front_void:
				var back_fl = fl_heights[back_col]
				var front_fl = fl_heights[front_col]
				if back_fl > front_fl and lz > 0:
					_emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, float(lz), float(front_fl + 1), float(back_fl + 1), float(lx), 1.0, registry.get_side_color(mats[back_col]))
				elif front_fl > back_fl and lz < n:
					_emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, float(lz), float(back_fl + 1), float(front_fl + 1), float(lx), 1.0, registry.get_side_color(mats[front_col]))

				var back_cl = cl_heights[back_col]
				var front_cl = cl_heights[front_col]
				if back_cl < front_cl and lz > 0:
					_emit_quad_z_pos(c_verts, c_norms, c_cols, c_inds, float(lz), float(back_cl), float(front_cl), float(lx), 1.0, registry.get_side_color(mats[back_col]))
				elif front_cl < back_cl and lz < n:
					_emit_quad_z_neg(c_verts, c_norms, c_cols, c_inds, float(lz), float(front_cl), float(back_cl), float(lx), 1.0, registry.get_side_color(mats[front_col]))

			lx += 1

	# -------------------------------------------------------------------------
	# Pass E: Subterranean Water Table (+Y faces at water_lvl + 1)
	# -------------------------------------------------------------------------
	visited.fill(0)
	for lz in range(n):
		var row_start = (lz + 1) * apron_w
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1:
				continue

			var col_idx = (lx + 1) + row_start
			var flag = flags[col_idx]
			if (flag & ChasmChunkData.FLAG_CHASM) == 0 or (flag & ChasmChunkData.FLAG_PILLAR) != 0:
				continue

			var fl_y = fl_heights[col_idx]
			if fl_y >= water_lvl:
				continue

			# Greedily expand water rectangle
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				var next_col = (lx + w + 1) + row_start
				var next_flag = flags[next_col]
				if (next_flag & ChasmChunkData.FLAG_CHASM) == 0 or (next_flag & ChasmChunkData.FLAG_PILLAR) != 0:
					break
				if fl_heights[next_col] >= water_lvl:
					break
				w += 1

			var d = 1
			var can_expand = true
			while (lz + d) < n and can_expand:
				var exp_row = (lz + d + 1) * apron_w
				for check_x in range(lx, lx + w):
					var r_idx = check_x + (lz + d) * n
					if visited[r_idx] == 1:
						can_expand = false
						break
					var exp_col = (check_x + 1) + exp_row
					var exp_flag = flags[exp_col]
					if (exp_flag & ChasmChunkData.FLAG_CHASM) == 0 or (exp_flag & ChasmChunkData.FLAG_PILLAR) != 0:
						can_expand = false
						break
					if fl_heights[exp_col] >= water_lvl:
						can_expand = false
						break
				if can_expand:
					d += 1

			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			var wy = float(water_lvl + 1)
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			var base_idx = sub_water_verts.size()
			sub_water_verts.append(Vector3(flx, wy, flz))
			sub_water_verts.append(Vector3(flx, wy, flz + fd))
			sub_water_verts.append(Vector3(flx + fw, wy, flz + fd))
			sub_water_verts.append(Vector3(flx + fw, wy, flz))

			var norm = Vector3.UP
			sub_water_norms.append(norm)
			sub_water_norms.append(norm)
			sub_water_norms.append(norm)
			sub_water_norms.append(norm)

			var water_col = Color(0.15, 0.45, 0.85, 0.7)
			sub_water_cols.append(water_col)
			sub_water_cols.append(water_col)
			sub_water_cols.append(water_col)
			sub_water_cols.append(water_col)

			sub_water_inds.append(base_idx)
			sub_water_inds.append(base_idx + 1)
			sub_water_inds.append(base_idx + 2)
			sub_water_inds.append(base_idx)
			sub_water_inds.append(base_idx + 2)
			sub_water_inds.append(base_idx + 3)

	# -------------------------------------------------------------------------
	# Store subterranean cave mesh into bundle
	# -------------------------------------------------------------------------
	bundle.cave_mesh_data.vertices = c_verts
	bundle.cave_mesh_data.normals = c_norms
	bundle.cave_mesh_data.colors = c_cols
	bundle.cave_mesh_data.indices = c_inds

	if not sub_water_verts.is_empty():
		if bundle.water_mesh_data == null:
			bundle.water_mesh_data = MeshData.new()
		var base_w_idx = bundle.water_mesh_data.vertices.size()
		bundle.water_mesh_data.vertices.append_array(sub_water_verts)
		bundle.water_mesh_data.normals.append_array(sub_water_norms)
		bundle.water_mesh_data.colors.append_array(sub_water_cols)
		for ind in sub_water_inds:
			bundle.water_mesh_data.indices.append(base_w_idx + ind)


# Helper quad emitter methods for curtain walls
static func _emit_quad_x_pos(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array, x: float, y_min: float, y_max: float, z: float, d: float, color: Color) -> void:
	var base_idx = verts.size()
	verts.append(Vector3(x, y_min, z + d))
	verts.append(Vector3(x, y_min, z))
	verts.append(Vector3(x, y_max, z))
	verts.append(Vector3(x, y_max, z + d))

	var norm = Vector3.RIGHT
	norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm)
	cols.append(color); cols.append(color); cols.append(color); cols.append(color)

	inds.append(base_idx); inds.append(base_idx + 1); inds.append(base_idx + 2)
	inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 3)

static func _emit_quad_x_neg(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array, x: float, y_min: float, y_max: float, z: float, d: float, color: Color) -> void:
	var base_idx = verts.size()
	verts.append(Vector3(x, y_min, z))
	verts.append(Vector3(x, y_min, z + d))
	verts.append(Vector3(x, y_max, z + d))
	verts.append(Vector3(x, y_max, z))

	var norm = Vector3.LEFT
	norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm)
	cols.append(color); cols.append(color); cols.append(color); cols.append(color)

	inds.append(base_idx); inds.append(base_idx + 1); inds.append(base_idx + 2)
	inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 3)

static func _emit_quad_z_pos(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array, z: float, y_min: float, y_max: float, x: float, w: float, color: Color) -> void:
	var base_idx = verts.size()
	verts.append(Vector3(x, y_min, z))
	verts.append(Vector3(x + w, y_min, z))
	verts.append(Vector3(x + w, y_max, z))
	verts.append(Vector3(x, y_max, z))

	var norm = Vector3.BACK
	norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm)
	cols.append(color); cols.append(color); cols.append(color); cols.append(color)

	inds.append(base_idx); inds.append(base_idx + 1); inds.append(base_idx + 2)
	inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 3)

static func _emit_quad_z_neg(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array, z: float, y_min: float, y_max: float, x: float, w: float, color: Color) -> void:
	var base_idx = verts.size()
	verts.append(Vector3(x + w, y_min, z))
	verts.append(Vector3(x, y_min, z))
	verts.append(Vector3(x, y_max, z))
	verts.append(Vector3(x + w, y_max, z))

	var norm = Vector3.FORWARD
	norms.append(norm); norms.append(norm); norms.append(norm); norms.append(norm)
	cols.append(color); cols.append(color); cols.append(color); cols.append(color)

	inds.append(base_idx); inds.append(base_idx + 1); inds.append(base_idx + 2)
	inds.append(base_idx); inds.append(base_idx + 2); inds.append(base_idx + 3)
