class_name BenchmarkChunkSelector
extends RefCounted

## Spatial coordinator discovering and selecting representative 100-chunk regions
## for surface overland terrain vs subterranean combat arena terrain.

const DEFAULT_SURFACE_CENTER = Vector2i(-1, -1)
const DEFAULT_ARENA_CENTER = Vector2i(1, 13)

## Generates a contiguous N-chunk grid for surface testing centered on the specified chunk.
func get_surface_chunks(count: int, bounds: WorldBounds, center: ChunkCoord = null) -> Array[ChunkCoord]:
	var c = center if center != null else ChunkCoord.new(DEFAULT_SURFACE_CENTER.x, DEFAULT_SURFACE_CENTER.y)
	return _build_grid_around_center(c, count, bounds)

## Generates a contiguous N-chunk grid for underground arena testing centered on the specified or discovered arena anchor.
func get_arena_chunks(count: int, bounds: WorldBounds, sampler: UndergroundChasmSampler = null, center: ChunkCoord = null) -> Array[ChunkCoord]:
	var target_center: ChunkCoord = center
	if target_center == null:
		if sampler != null:
			target_center = find_arena_center(sampler, bounds)
		if target_center == null:
			target_center = ChunkCoord.new(DEFAULT_ARENA_CENTER.x, DEFAULT_ARENA_CENTER.y)

	return _build_grid_around_center(target_center, count, bounds)

## Locates the nearest subterranean arena center coordinate by sampling columns near origin.
func find_arena_center(sampler: UndergroundChasmSampler, bounds: WorldBounds) -> ChunkCoord:
	if sampler == null:
		return ChunkCoord.new(DEFAULT_ARENA_CENTER.x, DEFAULT_ARENA_CENTER.y)

	var col = ChasmColumnResult.new()
	var chunk_size = bounds.chunk_size if bounds != null else 16
	var best_rift = -1.0
	var best_coord: ChunkCoord = null

	# Search in a concentric radius around origin (-25 to 25 chunks)
	for cz in range(-25, 26):
		for cx in range(-25, 26):
			var center_wx = float(cx * chunk_size + (chunk_size / 2)) * (bounds.voxel_size if bounds != null else 1.0)
			var center_wz = float(cz * chunk_size + (chunk_size / 2)) * (bounds.voxel_size if bounds != null else 1.0)
			sampler.sample_column(center_wx, center_wz, col)
			if col.is_arena and col.raw_rift > best_rift:
				best_rift = col.raw_rift
				best_coord = ChunkCoord.new(cx, cz)
				# If found a core arena center (rift >= 0.82), we can stop early
				if best_rift >= 0.82:
					return best_coord

	if best_coord != null:
		return best_coord

	return ChunkCoord.new(DEFAULT_ARENA_CENTER.x, DEFAULT_ARENA_CENTER.y)

func _build_grid_around_center(center: ChunkCoord, count: int, bounds: WorldBounds) -> Array[ChunkCoord]:
	var chunks: Array[ChunkCoord] = []
	var side = int(ceil(sqrt(float(count))))
	var half_side = side / 2

	var start_x = center.x - half_side
	var start_z = center.z - half_side

	for dz in range(side):
		for dx in range(side):
			if chunks.size() >= count:
				break
			var cx = start_x + dx
			var cz = start_z + dz
			var coord = ChunkCoord.new(cx, cz)
			if bounds == null or bounds.contains_chunk(coord):
				chunks.append(coord)

	# If boundary clamping dropped some chunks, fill remaining from expanding spiral
	if chunks.size() < count and bounds != null:
		var radius = half_side + 1
		while chunks.size() < count and radius < 120:
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if chunks.size() >= count:
						break
					var coord = ChunkCoord.new(center.x + dx, center.z + dz)
					if bounds.contains_chunk(coord) and not _contains_coord(chunks, coord):
						chunks.append(coord)
			radius += 1

	return chunks

func _contains_coord(list: Array[ChunkCoord], target: ChunkCoord) -> bool:
	for c in list:
		if c.x == target.x and c.z == target.z:
			return true
	return false
