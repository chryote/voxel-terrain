class_name WaterSurfaceMesher
extends RefCounted

## Pure component responsible for 2D greedy merging and buffer generation
## of elevated water surfaces (highland lakes, elevated streams, and tarns).

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

	var visited = PackedByteArray()
	visited.resize(n * n)
	visited.fill(0)

	var up_norm = Vector3(0.0, 1.0, 0.0)

	# 2D greedy merging for horizontal water quads
	for lz in range(n):
		for lx in range(n):
			var idx = lx + lz * n
			if visited[idx] == 1:
				continue

			if not data.has_water(lx, lz):
				continue

			var wh = data.get_water_height(lx, lz)
			if wh <= sea_level:
				continue

			# Find width w along X with identical water height
			var w = 1
			while (lx + w) < n:
				var next_idx = (lx + w) + lz * n
				if visited[next_idx] == 1:
					break
				if not data.has_water(lx + w, lz) or data.get_water_height(lx + w, lz) != wh:
					break
				w += 1

			# Find depth d along Z with identical water height
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

			# Mark visited
			for rz in range(lz, lz + d):
				for rx in range(lx, lx + w):
					visited[rx + rz * n] = 1

			# Add merged horizontal water quad
			var base_idx = verts.size()
			var fwh = float(wh)
			var flx = float(lx)
			var flz = float(lz)
			var fw = float(w)
			var fd = float(d)

			verts.append(Vector3(flx, fwh, flz))
			verts.append(Vector3(flx, fwh, flz + fd))
			verts.append(Vector3(flx + fw, fwh, flz + fd))
			verts.append(Vector3(flx + fw, fwh, flz))

			for _k in range(4):
				norms.append(up_norm)
				cols.append(water_color)

			inds.append(base_idx)
			inds.append(base_idx + 2)
			inds.append(base_idx + 1)
			inds.append(base_idx)
			inds.append(base_idx + 3)
			inds.append(base_idx + 2)

	if verts.is_empty():
		return null

	mesh.vertices = verts
	mesh.normals = norms
	mesh.colors = cols
	mesh.indices = inds
	return mesh
