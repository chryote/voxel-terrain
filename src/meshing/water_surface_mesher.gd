class_name WaterSurfaceMesher
extends RefCounted

## Pure component responsible for greedy merging and buffer generation
## of elevated water surfaces and 3D vertical cascading waterfall drops.

var water_color: Color = Color(0.12, 0.38, 0.65, 0.75)

func build_water_mesh(data: SurfaceChunkData, sea_level: int = 24) -> MeshData:
	var n = data.chunk_size
	var has_any_elevated_water = false

	# Fast pre-check: determine if this chunk has any elevated water columns
	for lz in range(n):
		for lx in range(n):
			if data.has_water(lx, lz) and data.get_water_height(lx, lz) > sea_level:
				has_any_elevated_water = true
				break
		if has_any_elevated_water:
			break

	if not has_any_elevated_water:
		return null

	var mesh = MeshData.new()
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	var inds = PackedInt32Array()

	_build_top_quads(data, sea_level, verts, norms, cols, inds)
	_build_side_quads_west(data, sea_level, verts, norms, cols, inds)
	_build_side_quads_east(data, sea_level, verts, norms, cols, inds)
	_build_side_quads_south(data, sea_level, verts, norms, cols, inds)
	_build_side_quads_north(data, sea_level, verts, norms, cols, inds)

	if verts.is_empty():
		return null

	mesh.vertices = verts
	mesh.normals = norms
	mesh.colors = cols
	mesh.indices = inds
	return mesh

func _get_neighbor_surface_level(data: SurfaceChunkData, nx: int, nz: int, sea_level: int) -> int:
	var gh = data.get_height(nx, nz)
	var wh = data.get_water_height(nx, nz)
	if data.has_water(nx, nz):
		return wh
	if gh <= sea_level:
		return sea_level
	return gh

func _append_quad(
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array,
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3
) -> void:
	var base_idx = verts.size()
	verts.append(p0)
	verts.append(p1)
	verts.append(p2)
	verts.append(p3)
	for _k in range(4):
		norms.append(normal)
		cols.append(water_color)
	inds.append(base_idx)
	inds.append(base_idx + 2)
	inds.append(base_idx + 1)
	inds.append(base_idx)
	inds.append(base_idx + 3)
	inds.append(base_idx + 2)

func _find_top_span_x(data: SurfaceChunkData, lx: int, lz: int, n: int, wh: int, visited: PackedByteArray) -> int:
	var w = 1
	while (lx + w) < n:
		var next_idx = (lx + w) + lz * n
		if visited[next_idx] == 1 or not data.has_water(lx + w, lz) or data.get_water_height(lx + w, lz) != wh:
			break
		w += 1
	return w

func _find_top_span_z(data: SurfaceChunkData, lx: int, lz: int, n: int, w: int, wh: int, visited: PackedByteArray) -> int:
	var d = 1
	var can_expand = true
	while (lz + d) < n and can_expand:
		for check_x in range(lx, lx + w):
			var row_idx = check_x + (lz + d) * n
			if visited[row_idx] == 1 or not data.has_water(check_x, lz + d) or data.get_water_height(check_x, lz + d) != wh:
				can_expand = false
				break
		if can_expand:
			d += 1
	return d

func _mark_visited(visited: PackedByteArray, lx: int, lz: int, w: int, d: int, n: int) -> void:
	for rz in range(lz, lz + d):
		for rx in range(lx, lx + w):
			visited[rx + rz * n] = 1

func _build_top_quads(
	data: SurfaceChunkData, sea_level: int,
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var n = data.chunk_size
	var visited = PackedByteArray()
	visited.resize(n * n)
	visited.fill(0)
	var up_norm = Vector3(0.0, 1.0, 0.0)

	for lz in range(n):
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1 or not data.has_water(lx, lz):
				continue
			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				continue

			var w = _find_top_span_x(data, lx, lz, n, wh, visited)
			var d = _find_top_span_z(data, lx, lz, n, w, wh, visited)
			_mark_visited(visited, lx, lz, w, d, n)

			var fwh = float(wh)
			var flx = float(lx)
			var flz = float(lz)
			_append_quad(
				verts, norms, cols, inds,
				Vector3(flx, fwh, flz),
				Vector3(flx, fwh, flz + float(d)),
				Vector3(flx + float(w), fwh, flz + float(d)),
				Vector3(flx + float(w), fwh, flz),
				up_norm
			)

func _build_side_quads_west(
	data: SurfaceChunkData, sea_level: int,
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var n = data.chunk_size
	var norm_west = Vector3(-1.0, 0.0, 0.0)

	for lx in range(n):
		var flx = float(lx)
		var lz = 0
		while lz < n:
			if not data.has_water(lx, lz):
				lz += 1
				continue
			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				lz += 1
				continue
			var n_surface = _get_neighbor_surface_level(data, lx - 1, lz, sea_level)
			if n_surface >= wh:
				lz += 1
				continue

			var run_z = 1
			while (lz + run_z) < n:
				var next_z = lz + run_z
				if not data.has_water(lx, next_z) or data.get_water_height(lx, next_z) != wh:
					break
				if _get_neighbor_surface_level(data, lx - 1, next_z, sea_level) != n_surface:
					break
				run_z += 1

			var px = flx - 0.01
			_append_quad(
				verts, norms, cols, inds,
				Vector3(px, float(n_surface), float(lz)),
				Vector3(px, float(n_surface), float(lz + run_z)),
				Vector3(px, float(wh), float(lz + run_z)),
				Vector3(px, float(wh), float(lz)),
				norm_west
			)
			lz += run_z

func _build_side_quads_east(
	data: SurfaceChunkData, sea_level: int,
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var n = data.chunk_size
	var norm_east = Vector3(1.0, 0.0, 0.0)

	for lx in range(n):
		var flx = float(lx)
		var lz = 0
		while lz < n:
			if not data.has_water(lx, lz):
				lz += 1
				continue
			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				lz += 1
				continue
			var n_surface = _get_neighbor_surface_level(data, lx + 1, lz, sea_level)
			if n_surface >= wh:
				lz += 1
				continue

			var run_z = 1
			while (lz + run_z) < n:
				var next_z = lz + run_z
				if not data.has_water(lx, next_z) or data.get_water_height(lx, next_z) != wh:
					break
				if _get_neighbor_surface_level(data, lx + 1, next_z, sea_level) != n_surface:
					break
				run_z += 1

			var px = flx + 1.01
			_append_quad(
				verts, norms, cols, inds,
				Vector3(px, float(n_surface), float(lz + run_z)),
				Vector3(px, float(n_surface), float(lz)),
				Vector3(px, float(wh), float(lz)),
				Vector3(px, float(wh), float(lz + run_z)),
				norm_east
			)
			lz += run_z

func _build_side_quads_south(
	data: SurfaceChunkData, sea_level: int,
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var n = data.chunk_size
	var norm_south = Vector3(0.0, 0.0, -1.0)

	for lz in range(n):
		var flz = float(lz)
		var lx = 0
		while lx < n:
			if not data.has_water(lx, lz):
				lx += 1
				continue
			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				lx += 1
				continue
			var n_surface = _get_neighbor_surface_level(data, lx, lz - 1, sea_level)
			if n_surface >= wh:
				lx += 1
				continue

			var run_x = 1
			while (lx + run_x) < n:
				var next_x = lx + run_x
				if not data.has_water(next_x, lz) or data.get_water_height(next_x, lz) != wh:
					break
				if _get_neighbor_surface_level(data, next_x, lz - 1, sea_level) != n_surface:
					break
				run_x += 1

			var pz = flz - 0.01
			_append_quad(
				verts, norms, cols, inds,
				Vector3(float(lx + run_x), float(n_surface), pz),
				Vector3(float(lx), float(n_surface), pz),
				Vector3(float(lx), float(wh), pz),
				Vector3(float(lx + run_x), float(wh), pz),
				norm_south
			)
			lx += run_x

func _build_side_quads_north(
	data: SurfaceChunkData, sea_level: int,
	verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, inds: PackedInt32Array
) -> void:
	var n = data.chunk_size
	var norm_north = Vector3(0.0, 0.0, 1.0)

	for lz in range(n):
		var flz = float(lz)
		var lx = 0
		while lx < n:
			if not data.has_water(lx, lz):
				lx += 1
				continue
			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				lx += 1
				continue
			var n_surface = _get_neighbor_surface_level(data, lx, lz + 1, sea_level)
			if n_surface >= wh:
				lx += 1
				continue

			var run_x = 1
			while (lx + run_x) < n:
				var next_x = lx + run_x
				if not data.has_water(next_x, lz) or data.get_water_height(next_x, lz) != wh:
					break
				if _get_neighbor_surface_level(data, next_x, lz + 1, sea_level) != n_surface:
					break
				run_x += 1

			var pz = flz + 1.01
			_append_quad(
				verts, norms, cols, inds,
				Vector3(float(lx), float(n_surface), pz),
				Vector3(float(lx + run_x), float(n_surface), pz),
				Vector3(float(lx + run_x), float(wh), pz),
				Vector3(float(lx), float(wh), pz),
				norm_north
			)
			lx += run_x
