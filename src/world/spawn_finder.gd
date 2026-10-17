class_name SpawnFinder
extends RefCounted

## Utility responsible for determining a safe, dry, gentle-slope spawn location
## for players and entities on procedural terrain.
##
## Decoupled from scene nodes to allow unit testing without a scene tree.

var max_radius: int = 100
var max_slope: int = 1
var min_height_above_water: int = 2

func find_spawn_point(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	sea_level: int,
	center: Vector2i = Vector2i.ZERO
) -> Vector3:
	var best_col = center
	var best_h = sea_level + 5
	var best_slope = 999999
	var found_gentle = false

	for radius in range(0, max_radius + 1):
		# Traverse concentric square perimeter around center
		var coords: Array[Vector2i] = []
		if radius == 0:
			coords.append(center)
		else:
			for dx in range(-radius, radius + 1):
				coords.append(Vector2i(center.x + dx, center.y - radius))
				coords.append(Vector2i(center.x + dx, center.y + radius))
			for dz in range(-radius + 1, radius):
				coords.append(Vector2i(center.x - radius, center.y + dz))
				coords.append(Vector2i(center.x + radius, center.y + dz))

		for col in coords:
			if not bounds.contains_column(col.x, col.y):
				continue

			var h = generator.height_at(col, bounds)
			var wh = generator.water_height_at(col, bounds)
			var effective_water = maxi(sea_level, wh)

			# Must be dry land above water
			if h < (effective_water + min_height_above_water):
				continue
			if generator.is_water_at(col, bounds):
				continue

			# Calculate 4-neighbor slope
			var col_w = Vector2i(col.x - 1, col.y)
			var col_e = Vector2i(col.x + 1, col.y)
			var col_s = Vector2i(col.x, col.y - 1)
			var col_n = Vector2i(col.x, col.y + 1)

			var h_w = generator.height_at(col_w, bounds)
			var h_e = generator.height_at(col_e, bounds)
			var h_s = generator.height_at(col_s, bounds)
			var h_n = generator.height_at(col_n, bounds)

			# Neighboring columns must also not be submerged
			if h_w < effective_water or h_e < effective_water or h_s < effective_water or h_n < effective_water:
				continue

			var slope = maxi(maxi(absi(h - h_w), absi(h - h_e)), maxi(absi(h - h_s), absi(h - h_n)))

			if slope <= max_slope:
				return bounds.column_to_world(col, float(h) + 1.0)

			if slope < best_slope:
				best_slope = slope
				best_col = col
				best_h = h
				found_gentle = true

	if found_gentle:
		return bounds.column_to_world(best_col, float(best_h) + 1.0)

	return Vector3(0.0, float(sea_level + 5) * bounds.voxel_size, 0.0)

const ChasmColumnResultClass = preload("res://src/generation/caves/chasm_column_result.gd")

func find_underground_arena_spawn_point(
	generator: TerrainGenerator,
	bounds: WorldBounds,
	sea_level: int
) -> Vector3:
	## Locates a flat subterranean combat arena near the continental ocean fall-off.
	if not ("cave_carver" in generator) or generator.cave_carver == null:
		return find_spawn_point(generator, bounds, sea_level)

	if "continent_gen" in generator and generator.continent_gen != null and generator.continent_gen.mask != null:
		generator.cave_carver.set_continent_mask(generator.continent_gen.mask, bounds)
	elif "topography" in generator and generator.topography != null and generator.topography.continent_mask != null:
		generator.cave_carver.set_continent_mask(generator.topography.continent_mask, bounds)

	var col = ChasmColumnResultClass.new()
	var best_score = 999999.0
	var best_pos = Vector3.ZERO
	var found = false

	var c_size = bounds.chunk_size
	var min_cz = bounds.min_chunk_z
	var max_cz = bounds.max_chunk_z
	var min_cx = bounds.min_chunk_x
	var max_cx = bounds.max_chunk_x

	# Search chunks across bounds with step of 2 chunks
	for cz in range(min_cz + 4, max_cz - 4, 2):
		for cx in range(min_cx + 4, max_cx - 4, 2):
			var wx = float(cx * c_size + (c_size / 2)) * bounds.voxel_size
			var wz = float(cz * c_size + (c_size / 2)) * bounds.voxel_size

			var surf_h = 40.0
			if generator.has_method("height_at"):
				var column_coord = bounds.world_to_column(Vector3(wx, 0.0, wz))
				surf_h = float(generator.height_at(column_coord, bounds)) * bounds.voxel_size

			generator.cave_carver.sample_chasm_column(wx, wz, col, surf_h)
			if col.is_arena and not col.is_pillar:
				var clearance = col.ceil_y - col.floor_y
				if clearance >= 5 and surf_h >= float(col.ceil_y + 3) and surf_h >= float(sea_level + 5):
					var land = 0.5
					if "continent_gen" in generator and generator.continent_gen != null and generator.continent_gen.mask != null:
						land = generator.continent_gen.mask.get_land_raw(wx, wz, bounds)
					elif "topography" in generator and generator.topography != null and generator.topography.continent_mask != null:
						land = generator.topography.continent_mask.get_land_raw(wx, wz, bounds)

					# Score: prefer land factor near continental margin (~0.12) where arenas border ocean falloff,
					# but are completely encased and protected from ocean puncture.
					var land_penalty = absf(land - 0.12) * 10.0
					var rift_bonus = 5.0 if col.raw_rift >= 0.82 else 0.0
					var score = land_penalty - rift_bonus

					if score < best_score:
						best_score = score
						best_pos = Vector3(wx, float(col.floor_y + 1), wz)
						found = true

	if found:
		# Fine-tune position within +/- 12 meters to find the core arena flat center (highest raw_rift)
		var center_wx = best_pos.x
		var center_wz = best_pos.z
		var best_local_rift = -1.0
		var fine_pos = best_pos
		for dz in range(-12, 13, 2):
			for dx in range(-12, 13, 2):
				var wx = center_wx + float(dx)
				var wz = center_wz + float(dz)
				var surf_h = 40.0
				if generator.has_method("height_at"):
					var column_coord = bounds.world_to_column(Vector3(wx, 0.0, wz))
					surf_h = float(generator.height_at(column_coord, bounds)) * bounds.voxel_size
				generator.cave_carver.sample_chasm_column(wx, wz, col, surf_h)
				if col.is_arena and not col.is_pillar and (col.ceil_y - col.floor_y) >= 5 and surf_h >= float(col.ceil_y + 3):
					if col.raw_rift > best_local_rift:
						best_local_rift = col.raw_rift
						fine_pos = Vector3(wx, float(col.floor_y + 1), wz)
		return fine_pos

	return find_spawn_point(generator, bounds, sea_level)
