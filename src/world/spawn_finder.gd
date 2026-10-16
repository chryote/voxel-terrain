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
