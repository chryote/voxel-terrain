class_name ChunkStreamer
extends RefCounted

## Pure logic for calculating chunk load and unload sets with distance sorting and hysteresis.

var hysteresis_margin: int = 1

func get_chunks_to_load(
	focus_chunk: ChunkCoord,
	loaded_chunks: Dictionary,
	view_distance: int,
	bounds: WorldBounds
) -> Array[ChunkCoord]:
	var to_load: Array[ChunkCoord] = []
	var focus_pos = focus_chunk.to_vector2i()

	for dz in range(-view_distance, view_distance + 1):
		for dx in range(-view_distance, view_distance + 1):
			# Use Euclidean radius for circular view horizon
			var dist_sq = dx * dx + dz * dz
			if dist_sq > (view_distance * view_distance):
				continue

			var target_coord = ChunkCoord.new(focus_pos.x + dx, focus_pos.y + dz)
			if not bounds.contains_chunk(target_coord):
				continue

			var key = target_coord.to_key()
			if not loaded_chunks.has(key):
				to_load.append(target_coord)

	# Sort by distance from center ascending (closest chunks generate first)
	to_load.sort_custom(func(a: ChunkCoord, b: ChunkCoord) -> bool:
		var d_a = focus_chunk.euclidean_distance_to(a)
		var d_b = focus_chunk.euclidean_distance_to(b)
		return d_a < d_b
	)

	return to_load

func get_chunks_to_unload(
	focus_chunk: ChunkCoord,
	loaded_chunks: Dictionary,
	view_distance: int
) -> Array[ChunkCoord]:
	var to_unload: Array[ChunkCoord] = []
	var max_dist = float(view_distance + hysteresis_margin)
	var max_dist_sq = max_dist * max_dist

	for key in loaded_chunks.keys():
		var coord = loaded_chunks[key]
		if not (coord is ChunkCoord):
			coord = ChunkCoord.from_key(key)

		var dx = float(coord.x - focus_chunk.x)
		var dz = float(coord.z - focus_chunk.z)
		if (dx * dx + dz * dz) > max_dist_sq:
			to_unload.append(coord)

	return to_unload
