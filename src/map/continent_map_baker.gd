class_name ContinentMapBaker
extends RefCounted

## Pure component responsible for baking a complete topographic and material map
## of a procedural continent into an Image.
##
## Decoupled from scene nodes, UI, and rendering servers for thread-safety and testing.

const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")
const CaveMouthDetectorClass = preload("res://src/map/cave_mouth_detector.gd")
const ChasmColumnResultClass = preload("res://src/generation/caves/chasm_column_result.gd")
const MIN_UNDERGROUND_ISLAND_PIXELS: int = 600 ## Reference threshold at 512x512 resolution below which isolated subterranean cavern pockets are culled to solid bedrock

enum MapLevel {
	SURFACE = 0,
	UNDERGROUND = 1
}

var detector: CaveMouthDetectorClass = CaveMouthDetectorClass.new()
var last_baked_cave_mouths: Array = []

func bake_map(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	palette: ContinentMapColorPaletteClass = null,
	level: int = MapLevel.SURFACE
) -> Image:
	if level == MapLevel.UNDERGROUND:
		return bake_underground_map(generator, bounds, resolution, palette)

	if bounds == null or generator == null or resolution <= 0:
		return null

	if palette == null:
		palette = ContinentMapColorPaletteClass.new()

	var img = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)

	var min_x = bounds.min_world_x
	var max_x = bounds.max_world_x
	var min_z = bounds.min_world_z
	var max_z = bounds.max_world_z

	var step_x = (max_x - min_x) / float(resolution)
	var step_z = (max_z - min_z) / float(resolution)

	var total_pixels = resolution * resolution
	var heights = PackedInt32Array()
	heights.resize(total_pixels)
	var water_heights = PackedInt32Array()
	water_heights.resize(total_pixels)
	var fluvial_flags = PackedByteArray()
	fluvial_flags.resize(total_pixels)

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

	# -------------------------------------------------------------------------
	# Pass 1: Grid Sampling
	# -------------------------------------------------------------------------
	for py in range(resolution):
		var wz = min_z + (float(py) + 0.5) * step_z
		var row_idx = py * resolution

		for px in range(resolution):
			var wx = min_x + (float(px) + 0.5) * step_x
			var idx = row_idx + px

			if is_cont_gen and cont_gen != null:
				var m_v2 = cont_gen.macro.sample_macro_v2(wx, wz, bounds)
				var f_v3 = cont_gen.fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)
				var h = clampi(int(round(m_v2.x - f_v3.x)), seabed_level, 255)
				var wh = int(round(f_v3.y))
				heights[idx] = h
				water_heights[idx] = wh
				fluvial_flags[idx] = int(f_v3.z)
			else:
				var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
				var h = generator.height_at(col, bounds)
				var wh = generator.water_height_at(col, bounds)
				heights[idx] = h
				water_heights[idx] = wh
				fluvial_flags[idx] = 4 if generator.is_water_at(col, bounds) else 0

	# -------------------------------------------------------------------------
	# Pass 2: Relief Shading, Material Classification, and Pixel Painting
	# -------------------------------------------------------------------------
	for py in range(resolution):
		var row_idx = py * resolution
		for px in range(resolution):
			var idx = row_idx + px
			var h = heights[idx]
			var wh = water_heights[idx]
			var flags = fluvial_flags[idx]
			var is_river = (flags & 1) != 0
			var is_lake = (flags & 2) != 0
			var is_water = (h < sea_level) or (h < wh)

			# 4-neighbor elevation samples for normal and slope gradient
			var h_l = heights[row_idx + maxi(0, px - 1)]
			var h_r = heights[row_idx + mini(resolution - 1, px + 1)]
			var h_d = heights[maxi(0, py - 1) * resolution + px]
			var h_u = heights[mini(resolution - 1, py + 1) * resolution + px]

			var dh_dx = float(h_r - h_l) / (step_x * 2.0)
			var dh_dz = float(h_u - h_d) / (step_z * 2.0)
			var slope_grade = maxf(absf(dh_dx), absf(dh_dz))

			var pixel_color: Color

			if is_water:
				pixel_color = palette.get_water_color(h, sea_level)
			else:
				var moist = 0.5
				if is_cont_gen and cont_gen != null and cont_gen.climate != null:
					var wx = min_x + (float(px) + 0.5) * step_x
					var wz = min_z + (float(py) + 0.5) * step_z
					moist = cont_gen.climate.sample_moisture(wx, wz)

				var base_color = palette.get_land_color(
					h,
					slope_grade,
					wh,
					sea_level,
					sand_offset,
					snow_height,
					stone_height,
					is_river or is_lake,
					moist
				)
				var shade = palette.compute_hillshade(dh_dx, dh_dz)
				pixel_color = palette.apply_relief(base_color, shade, h, sea_level)

			pixel_color.a = 1.0
			img.set_pixel(px, py, pixel_color)

	# -------------------------------------------------------------------------
	# Pass 3: Cave Mouth Detection & Classification
	# -------------------------------------------------------------------------
	last_baked_cave_mouths = detector.detect_cave_mouths(generator, bounds, resolution)

	return img

func bake_underground_map(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	palette: ContinentMapColorPaletteClass = null,
	min_island_pixels: int = MIN_UNDERGROUND_ISLAND_PIXELS
) -> Image:
	if bounds == null or generator == null or resolution <= 0:
		return null

	if palette == null:
		palette = ContinentMapColorPaletteClass.new()

	var img = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)

	var min_x = bounds.min_world_x
	var max_x = bounds.max_world_x
	var min_z = bounds.min_world_z
	var max_z = bounds.max_world_z

	var step_x = (max_x - min_x) / float(resolution)
	var step_z = (max_z - min_z) / float(resolution)

	var total_pixels = resolution * resolution
	var floor_heights = PackedInt32Array()
	floor_heights.resize(total_pixels)
	var flags = PackedByteArray()
	flags.resize(total_pixels)

	var is_cont_gen = generator is ContinentGenerator
	var cont_gen: ContinentGenerator = generator if is_cont_gen else null
	if cont_gen == null and "continent_gen" in generator and generator.continent_gen is ContinentGenerator:
		cont_gen = generator.continent_gen
		is_cont_gen = true

	var cave_carver: CaveCarver = null
	if "cave_carver" in generator and generator.cave_carver != null:
		cave_carver = generator.cave_carver
	elif cont_gen != null and "cave_carver" in cont_gen and cont_gen.cave_carver != null:
		cave_carver = cont_gen.cave_carver

	if cave_carver != null and cave_carver.chasm_sampler != null:
		if cont_gen != null and cont_gen.mask != null:
			cave_carver.set_continent_mask(cont_gen.mask, bounds)
		elif "topography" in generator and generator.topography != null and generator.topography.continent_mask != null:
			cave_carver.set_continent_mask(generator.topography.continent_mask, bounds)

	# -------------------------------------------------------------------------
	# Pass 1: Grid Sampling for Subterranean Columns
	# -------------------------------------------------------------------------
	var chasm_col = ChasmColumnResultClass.new()
	var default_surf_h = 40.0

	for py in range(resolution):
		var wz = min_z + (float(py) + 0.5) * step_z
		var row_idx = py * resolution

		for px in range(resolution):
			var wx = min_x + (float(px) + 0.5) * step_x
			var idx = row_idx + px

			if cave_carver != null and cave_carver.chasm_sampler != null:
				var surf_h = default_surf_h
				if is_cont_gen and cont_gen != null:
					var m_v2 = cont_gen.macro.sample_macro_v2(wx, wz, bounds)
					var f_v3 = cont_gen.fluvial.sample_fluvial_v3(wx, wz, m_v2.x, m_v2.y)
					surf_h = m_v2.x - f_v3.x
				elif generator.has_method("height_at"):
					var col = bounds.world_to_column(Vector3(wx, 0.0, wz))
					surf_h = float(generator.height_at(col, bounds))

				cave_carver.sample_chasm_column(wx, wz, chasm_col, surf_h)

				if chasm_col.is_arena or chasm_col.is_chasm or chasm_col.is_pillar:
					var f: int = 0
					if chasm_col.is_arena:
						f |= 1
					if chasm_col.is_arena_ledge:
						f |= 2
					if chasm_col.is_chasm:
						f |= 4
					if chasm_col.is_pillar:
						f |= 8
					if chasm_col.is_basalt_column:
						f |= 16
					var is_water = chasm_col.is_chasm and cave_carver.config.cave_water_enabled and (not chasm_col.is_arena) and (chasm_col.floor_y <= cave_carver.config.chasm_water_level)
					if is_water:
						f |= 32
					if not chasm_col.is_pillar:
						f |= 64 # is_void

					flags[idx] = f
					floor_heights[idx] = chasm_col.floor_y
				else:
					flags[idx] = 0
					floor_heights[idx] = 0
			else:
				flags[idx] = 0
				floor_heights[idx] = 0

	# -------------------------------------------------------------------------
	# Pass 1.5: Small-Island Pruning (Cull isolated subterranean pockets)
	# -------------------------------------------------------------------------
	if min_island_pixels > 0:
		var effective_min = maxi(2, int(round(float(min_island_pixels) * (float(resolution * resolution) / (512.0 * 512.0)))))
		_cull_small_underground_islands(flags, floor_heights, resolution, effective_min)

	# -------------------------------------------------------------------------
	# Pass 2: Relief Shading, Palette Mapping, and Pixel Painting
	# -------------------------------------------------------------------------
	for py in range(resolution):
		var row_idx = py * resolution
		for px in range(resolution):
			var idx = row_idx + px
			var f = flags[idx]
			var is_arena = (f & 1) != 0
			var is_arena_ledge = (f & 2) != 0
			var is_chasm = (f & 4) != 0
			var is_pillar = (f & 8) != 0
			var is_basalt_column = (f & 16) != 0
			var is_water = (f & 32) != 0
			var is_void = (f & 64) != 0
			var floor_y = floor_heights[idx]

			var base_color = palette.get_underground_color(
				is_arena,
				is_arena_ledge,
				is_chasm,
				is_pillar,
				is_basalt_column,
				is_water,
				floor_y
			)

			var pixel_color = base_color
			if is_void:
				var h_l = floor_heights[row_idx + maxi(0, px - 1)]
				var h_r = floor_heights[row_idx + mini(resolution - 1, px + 1)]
				var h_d = floor_heights[maxi(0, py - 1) * resolution + px]
				var h_u = floor_heights[mini(resolution - 1, py + 1) * resolution + px]

				var dh_dx = float(h_r - h_l) / (step_x * 2.0)
				var dh_dz = float(h_u - h_d) / (step_z * 2.0)
				var shade = palette.compute_hillshade(dh_dx, dh_dz, 2.5)
				pixel_color = palette.apply_underground_relief(base_color, shade, floor_y, true)

			pixel_color.a = 1.0
			img.set_pixel(px, py, pixel_color)

	# -------------------------------------------------------------------------
	# Pass 3: Cave Mouth Detection (shared cache)
	# -------------------------------------------------------------------------
	if last_baked_cave_mouths.is_empty():
		last_baked_cave_mouths = detector.detect_cave_mouths(generator, bounds, resolution)

	return img

func _cull_small_underground_islands(
	p_flags: PackedByteArray,
	p_floor_heights: PackedInt32Array,
	p_resolution: int,
	p_min_island_pixels: int
) -> int:
	## High-performance BFS component culling: resets isolated subterranean pockets smaller
	## than p_min_island_pixels back to solid bedrock (zero-allocation flat integer queue).
	var total_pixels = p_resolution * p_resolution
	var visited = PackedByteArray()
	visited.resize(total_pixels)

	var queue = PackedInt32Array()
	queue.resize(total_pixels)

	var culled_pixels = 0

	for y in range(p_resolution):
		var row_offset = y * p_resolution
		for x in range(p_resolution):
			var start_idx = row_offset + x
			if p_flags[start_idx] != 0 and visited[start_idx] == 0:
				var head = 0
				var tail = 0
				queue[tail] = start_idx
				tail += 1
				visited[start_idx] = 1

				while head < tail:
					var curr_idx = queue[head]
					head += 1

					var cx = curr_idx % p_resolution
					var cy = curr_idx / p_resolution

					# 4-directional flood fill
					if cx > 0:
						var n_idx = curr_idx - 1
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cx < p_resolution - 1:
						var n_idx = curr_idx + 1
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cy > 0:
						var n_idx = curr_idx - p_resolution
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1
					if cy < p_resolution - 1:
						var n_idx = curr_idx + p_resolution
						if p_flags[n_idx] != 0 and visited[n_idx] == 0:
							visited[n_idx] = 1
							queue[tail] = n_idx
							tail += 1

				if tail < p_min_island_pixels:
					for i in range(tail):
						var c_idx = queue[i]
						p_flags[c_idx] = 0
						p_floor_heights[c_idx] = 0
					culled_pixels += tail

	return culled_pixels
