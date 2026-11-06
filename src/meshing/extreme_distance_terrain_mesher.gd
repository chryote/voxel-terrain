class_name ExtremeDistanceTerrainMesher
extends RefCounted

## Pure component responsible for generating a continent-wide, low-polygon macro heightmap mesh.
## Produces MeshData containing vertices, smooth normals, vertex colors, and indices.
## Completely decoupled from scene nodes and rendering servers for thread safety and headless testability.

const DEFAULT_RESOLUTION: int = 128

func build_mesh(generator: TerrainGenerator, bounds: WorldBounds, registry: MaterialRegistry = null, resolution: int = DEFAULT_RESOLUTION) -> MeshData:
	var mesh_data = MeshData.new()
	if generator == null or bounds == null:
		return mesh_data

	var res = clampi(resolution, 4, 512)
	var total_verts = (res + 1) * (res + 1)
	var total_quads = res * res

	var heights = PackedInt32Array()
	heights.resize(total_verts)
	var water_heights = PackedInt32Array()
	water_heights.resize(total_verts)
	var mat_ids = PackedByteArray()
	mat_ids.resize(total_verts)

	var sea_level = 24
	var seabed_level = 6
	var sand_offset = 2
	var stone_height = 90
	var snow_height = 125

	var is_cont_gen = generator is ContinentGenerator
	var cont_gen: ContinentGenerator = generator if is_cont_gen else null
	if cont_gen == null and "continent_gen" in generator and generator.continent_gen is ContinentGenerator:
		cont_gen = generator.continent_gen
		is_cont_gen = true
	if cont_gen != null and cont_gen.config != null:
		sea_level = cont_gen.config.sea_level
		seabed_level = cont_gen.config.seabed_level
		sand_offset = cont_gen.config.sand_height_offset
		stone_height = cont_gen.config.stone_height
		snow_height = cont_gen.config.snow_height

	var step_x = (bounds.max_world_x - bounds.min_world_x) / float(res)
	var step_z = (bounds.max_world_z - bounds.min_world_z) / float(res)

	# 1. Grid Elevation & Water Table Sampling
	for iz in range(res + 1):
		var wz = bounds.min_world_z + float(iz) * step_z
		var row_offset = iz * (res + 1)
		for ix in range(res + 1):
			var wx = bounds.min_world_x + float(ix) * step_x
			var idx = row_offset + ix
			var h = seabed_level
			var wh = sea_level
			if is_cont_gen and cont_gen != null:
				var m_v2 = cont_gen.macro.sample_macro_v2(wx, wz, bounds)
				if m_v2.y <= 0.01:
					var isl = cont_gen.macro.sample_offshore_island(wx, wz, bounds)
					if isl.y > 0.0:
						h = clampi(int(round(isl.x)), seabed_level, 255)
				else:
					var f_v3 = cont_gen.fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)
					h = clampi(int(round(m_v2.x - f_v3.x)), seabed_level, 255)
					wh = int(round(f_v3.y))
			else:
				var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
				h = generator.height_at(col, bounds)
				wh = generator.water_height_at(col, bounds)
			heights[idx] = h
			water_heights[idx] = wh

			var mat = MaterialDef.ID_GRASS
			if h < sea_level: mat = MaterialDef.ID_SEABED
			elif h < wh: mat = MaterialDef.ID_GRAVEL
			elif h >= snow_height: mat = MaterialDef.ID_SNOW
			elif h >= stone_height: mat = MaterialDef.ID_STONE
			elif h <= sea_level + sand_offset: mat = MaterialDef.ID_SAND
			mat_ids[idx] = mat

	# 2. Geometry Buffers (Vertices, Normals, Colors)
	var verts = PackedVector3Array()
	verts.resize(total_verts)
	var norms = PackedVector3Array()
	norms.resize(total_verts)
	var cols = PackedColorArray()
	cols.resize(total_verts)

	for iz in range(res + 1):
		var wz = bounds.min_world_z + float(iz) * step_z
		var row_offset = iz * (res + 1)
		for ix in range(res + 1):
			var idx = row_offset + ix
			var wx = bounds.min_world_x + float(ix) * step_x
			var h = heights[idx]
			verts[idx] = Vector3(wx, float(h) * bounds.voxel_size, wz)

			var h_l = heights[row_offset + maxi(0, ix - 1)]
			var h_r = heights[row_offset + mini(res, ix + 1)]
			var h_d = heights[maxi(0, iz - 1) * (res + 1) + ix]
			var h_u = heights[mini(res, iz + 1) * (res + 1) + ix]
			var dx_dist = step_x * (2.0 if (ix > 0 and ix < res) else 1.0)
			var dz_dist = step_z * (2.0 if (iz > 0 and iz < res) else 1.0)
			var dh_dx = float(h_r - h_l) * bounds.voxel_size / dx_dist
			var dh_dz = float(h_u - h_d) * bounds.voxel_size / dz_dist
			norms[idx] = Vector3(-dh_dx, 1.0, -dh_dz).normalized()

			var mat = mat_ids[idx]
			if mat == MaterialDef.ID_GRASS and (absf(dh_dx) > 0.75 or absf(dh_dz) > 0.75):
				mat = MaterialDef.ID_STONE

			var color = registry.get_top_color(mat) if registry != null else _fallback_color(mat)
			color.a = float(mat) / 255.0
			cols[idx] = color

	# 3. Index Buffer
	var inds = PackedInt32Array()
	inds.resize(total_quads * 6)
	var ptr = 0
	for iz in range(res):
		for ix in range(res):
			var v00 = iz * (res + 1) + ix
			var v10 = v00 + 1
			var v01 = (iz + 1) * (res + 1) + ix
			var v11 = v01 + 1
			inds[ptr] = v00; inds[ptr + 1] = v11; inds[ptr + 2] = v01
			inds[ptr + 3] = v00; inds[ptr + 4] = v10; inds[ptr + 5] = v11
			ptr += 6

	mesh_data.vertices = verts
	mesh_data.normals = norms
	mesh_data.colors = cols
	mesh_data.indices = inds
	return mesh_data

func _fallback_color(mat_id: int) -> Color:
	match mat_id:
		MaterialDef.ID_SNOW: return Color("#87827a")
		MaterialDef.ID_STONE: return Color("#454442")
		MaterialDef.ID_SAND: return Color("#665b49")
		MaterialDef.ID_SEABED: return Color("#212522")
		MaterialDef.ID_GRAVEL: return Color("#33302c")
		_: return Color("#3d4234")
