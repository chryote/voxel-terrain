class_name ContinentMapBaker
extends RefCounted

## Pure component responsible for baking a complete topographic and material map
## of a procedural continent into an Image.
##
## Decoupled from scene nodes, UI, and rendering servers for thread-safety and testing.

const ContinentMapColorPaletteClass = preload("res://src/map/continent_map_color_palette.gd")

func bake_map(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	resolution: int = 512,
	palette: ContinentMapColorPaletteClass = null
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

	return img
