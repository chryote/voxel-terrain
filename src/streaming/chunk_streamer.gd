class_name ChunkStreamer
extends RefCounted

## Pure logic for calculating chunk load and unload sets with distance sorting and hysteresis.

var hysteresis_margin: int = 1
static var _sorted_offsets_cache: Dictionary = {} # int (view_distance) -> Array[Vector2i]

static func _get_sorted_offsets(view_distance: int) -> Array[Vector2i]:
	if _sorted_offsets_cache.has(view_distance):
		return _sorted_offsets_cache[view_distance]

	var offsets: Array[Vector2i] = []
	var vd_sq = view_distance * view_distance
	for dz in range(-view_distance, view_distance + 1):
		for dx in range(-view_distance, view_distance + 1):
			var dist_sq = dx * dx + dz * dz
			if dist_sq <= vd_sq:
				offsets.append(Vector2i(dx, dz))

	# Sort by squared distance ascending (pre-computed once)
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var d_a = a.x * a.x + a.y * a.y
		var d_b = b.x * b.x + b.y * b.y
		return d_a < d_b
	)

	_sorted_offsets_cache[view_distance] = offsets
	return offsets

func get_chunks_to_load(
	focus_chunk: ChunkCoord,
	loaded_chunks: Dictionary,
	view_distance: int,
	bounds: WorldBounds
) -> Array[ChunkCoord]:
	var to_load: Array[ChunkCoord] = []
	var focus_pos = focus_chunk.to_vector2i()
	var sorted_offsets = _get_sorted_offsets(view_distance)

	for offset in sorted_offsets:
		var target_coord = ChunkCoord.new(focus_pos.x + offset.x, focus_pos.y + offset.y)
		if not bounds.contains_chunk(target_coord):
			continue

		var key = target_coord.to_key()
		if not loaded_chunks.has(key):
			to_load.append(target_coord)

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
