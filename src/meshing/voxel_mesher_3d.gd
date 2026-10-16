class_name VoxelMesher3D
extends Mesher

## 3D greedy voxel mesher with 6-directional face culling.
## Merges co-planar quads on all axes to minimize draw calls and triangle counts.

func build_mesh(p_data: RefCounted, registry: MaterialRegistry) -> MeshData:
	var data = p_data as VoxelChunkData
	var mesh = MeshData.new()
	if data == null:
		return mesh

	_mesh_y_faces(data, registry, mesh)
	_mesh_x_faces(data, registry, mesh)
	_mesh_z_faces(data, registry, mesh)

	return mesh

func _mesh_y_faces(data: VoxelChunkData, registry: MaterialRegistry, mesh: MeshData) -> void:
	var c_size = data.chunk_size
	var h = data.height
	var mask_top = PackedByteArray()
	var mask_bot = PackedByteArray()
	mask_top.resize(c_size * c_size)
	mask_bot.resize(c_size * c_size)

	for ly in range(h):
		var has_top = false
		var has_bot = false
		mask_top.fill(0)
		mask_bot.fill(0)

		for lz in range(c_size):
			for lx in range(c_size):
				var val = data.get_voxel(lx, ly, lz)
				if val == 0:
					continue
				var idx = lx + lz * c_size

				# Top face (+Y)
				if data.get_voxel(lx, ly + 1, lz) == 0:
					mask_top[idx] = val
					has_top = true

				# Bottom face (-Y)
				if ly == 0 or data.get_voxel(lx, ly - 1, lz) == 0:
					mask_bot[idx] = val
					has_bot = true

		var fy = float(ly)
		if has_top:
			var top_quads = GreedySliceMerger.merge_slice(mask_top, c_size, c_size)
			for q in top_quads:
				var col = registry.get_top_color(q.mat)
				VoxelQuadBuilder.add_top_quad(mesh, float(q.u), fy + 1.0, float(q.v), float(q.w), float(q.d), col)

		if has_bot:
			var bot_quads = GreedySliceMerger.merge_slice(mask_bot, c_size, c_size)
			for q in bot_quads:
				var col = registry.get_side_color(q.mat)
				VoxelQuadBuilder.add_bottom_quad(mesh, float(q.u), fy, float(q.v), float(q.w), float(q.d), col)

func _mesh_x_faces(data: VoxelChunkData, registry: MaterialRegistry, mesh: MeshData) -> void:
	var c_size = data.chunk_size
	var h = data.height
	var mask_east = PackedByteArray()
	var mask_west = PackedByteArray()
	mask_east.resize(c_size * h)
	mask_west.resize(c_size * h)

	for lx in range(c_size):
		var has_east = false
		var has_west = false
		mask_east.fill(0)
		mask_west.fill(0)

		for ly in range(h):
			for lz in range(c_size):
				var val = data.get_voxel(lx, ly, lz)
				if val == 0:
					continue
				var idx = lz + ly * c_size

				# East face (+X)
				if data.get_voxel(lx + 1, ly, lz) == 0:
					mask_east[idx] = val
					has_east = true

				# West face (-X)
				if data.get_voxel(lx - 1, ly, lz) == 0:
					mask_west[idx] = val
					has_west = true

		var fx = float(lx)
		if has_east:
			var east_quads = GreedySliceMerger.merge_slice(mask_east, c_size, h)
			for q in east_quads:
				var col = registry.get_side_color(q.mat)
				VoxelQuadBuilder.add_east_quad(mesh, fx + 1.0, float(q.v), float(q.u), float(q.d), float(q.w), col)

		if has_west:
			var west_quads = GreedySliceMerger.merge_slice(mask_west, c_size, h)
			for q in west_quads:
				var col = registry.get_side_color(q.mat)
				VoxelQuadBuilder.add_west_quad(mesh, fx, float(q.v), float(q.u), float(q.d), float(q.w), col)

func _mesh_z_faces(data: VoxelChunkData, registry: MaterialRegistry, mesh: MeshData) -> void:
	var c_size = data.chunk_size
	var h = data.height
	var mask_north = PackedByteArray()
	var mask_south = PackedByteArray()
	mask_north.resize(c_size * h)
	mask_south.resize(c_size * h)

	for lz in range(c_size):
		var has_north = false
		var has_south = false
		mask_north.fill(0)
		mask_south.fill(0)

		for ly in range(h):
			for lx in range(c_size):
				var val = data.get_voxel(lx, ly, lz)
				if val == 0:
					continue
				var idx = lx + ly * c_size

				# North face (+Z)
				if data.get_voxel(lx, ly, lz + 1) == 0:
					mask_north[idx] = val
					has_north = true

				# South face (-Z)
				if data.get_voxel(lx, ly, lz - 1) == 0:
					mask_south[idx] = val
					has_south = true

		var fz = float(lz)
		if has_north:
			var north_quads = GreedySliceMerger.merge_slice(mask_north, c_size, h)
			for q in north_quads:
				var col = registry.get_side_color(q.mat)
				VoxelQuadBuilder.add_north_quad(mesh, float(q.u), float(q.v), fz + 1.0, float(q.w), float(q.d), col)

		if has_south:
			var south_quads = GreedySliceMerger.merge_slice(mask_south, c_size, h)
			for q in south_quads:
				var col = registry.get_side_color(q.mat)
				VoxelQuadBuilder.add_south_quad(mesh, float(q.u), float(q.v), fz, float(q.w), float(q.d), col)
