class_name SubterraneanStreamCoordinator
extends RefCounted

## Pure decoupled coordinator tracking subterranean generation states for terrain chunks.
## Determines when subterranean cave carving must be scheduled on-demand (e.g., cave mouth
## candidate detection, player descent toward subterranean strata, or entrance proximity),
## enabling high-speed ~22 ms surface streaming without sacrificing seamless cave exploration.

enum ChunkSubterraneanState {
	STATE_SURFACE_ONLY,
	STATE_SUBTERRANEAN_QUEUED,
	STATE_SUBTERRANEAN_READY
}

var enabled: bool = true
var subterranean_elevation_offset: float = 4.0
var subterranean_radius_chunks: int = 2
var mouth_trigger_radius_chunks: int = 1

# Dictionary: chunk key -> ChunkSubterraneanState
var _chunk_states: Dictionary = {}

# Dictionary: chunk key -> SurfaceChunkData (cached for Phase B reuse)
var _surface_cache: Dictionary = {}

func register_surface_chunk(coord: ChunkCoord, has_mouth: bool, surface_data: SurfaceChunkData = null) -> void:
	var key = coord.to_key()
	if not _chunk_states.has(key) or _chunk_states[key] == ChunkSubterraneanState.STATE_SURFACE_ONLY:
		_chunk_states[key] = ChunkSubterraneanState.STATE_SURFACE_ONLY
		if surface_data != null:
			_surface_cache[key] = surface_data

func mark_subterranean_queued(coord: ChunkCoord) -> void:
	_chunk_states[coord.to_key()] = ChunkSubterraneanState.STATE_SUBTERRANEAN_QUEUED

func mark_subterranean_ready(coord: ChunkCoord) -> void:
	var key = coord.to_key()
	_chunk_states[key] = ChunkSubterraneanState.STATE_SUBTERRANEAN_READY
	# Once subterranean is ready, surface cache can be safely discarded to save memory
	_surface_cache.erase(key)

func unregister_chunk(coord: ChunkCoord) -> void:
	var key = coord.to_key()
	_chunk_states.erase(key)
	_surface_cache.erase(key)

func get_cached_surface_data(coord: ChunkCoord) -> SurfaceChunkData:
	return _surface_cache.get(coord.to_key(), null)

func get_state(coord: ChunkCoord) -> int:
	return _chunk_states.get(coord.to_key(), -1)

func is_subterranean_ready(coord: ChunkCoord) -> bool:
	return _chunk_states.get(coord.to_key(), -1) == ChunkSubterraneanState.STATE_SUBTERRANEAN_READY

func is_subterranean_queued(coord: ChunkCoord) -> bool:
	return _chunk_states.get(coord.to_key(), -1) == ChunkSubterraneanState.STATE_SUBTERRANEAN_QUEUED

func is_surface_only(coord: ChunkCoord) -> bool:
	return _chunk_states.get(coord.to_key(), -1) == ChunkSubterraneanState.STATE_SURFACE_ONLY

## Evaluates whether the player's current elevation or proximity to a cave mouth warrants
## triggering subterranean generation for surface-only chunks.
## Returns an array of ChunkCoord sorted by proximity to focus_chunk.
func get_chunks_to_promote(
	player_pos: Vector3,
	focus_chunk: ChunkCoord,
	surface_height: float,
	mouth_cache: Dictionary # key -> bool
) -> Array[ChunkCoord]:
	var candidates: Array[ChunkCoord] = []
	if not enabled or focus_chunk == null:
		return candidates

	var is_player_subterranean = player_pos.y < (surface_height - subterranean_elevation_offset)

	# Check if player is near any known cave mouth
	var is_player_near_mouth = false
	for dz in range(-mouth_trigger_radius_chunks, mouth_trigger_radius_chunks + 1):
		for dx in range(-mouth_trigger_radius_chunks, mouth_trigger_radius_chunks + 1):
			var n_coord = ChunkCoord.new(focus_chunk.x + dx, focus_chunk.z + dz)
			if mouth_cache.get(n_coord.to_key(), false):
				is_player_near_mouth = true
				break
		if is_player_near_mouth:
			break

	for key in _chunk_states:
		if _chunk_states[key] != ChunkSubterraneanState.STATE_SURFACE_ONLY:
			continue

		var coord = ChunkCoord.from_key(key)
		var has_mouth = mouth_cache.get(key, false)
		var dist_to_focus = focus_chunk.chebyshev_distance_to(coord)

		# Promotion rules:
		# 1. Any chunk containing a cave mouth must generate subterranean geometry
		# 2. When player descends toward cave elevation, promote chunks in subterranean radius
		# 3. When player is near a cave mouth, promote chunks in subterranean radius
		var should_promote = false
		if has_mouth:
			should_promote = true
		elif (is_player_subterranean or is_player_near_mouth) and dist_to_focus <= subterranean_radius_chunks:
			should_promote = true

		if should_promote:
			candidates.append(coord)

	# Sort candidates by Euclidean distance to focus_chunk (closest first)
	candidates.sort_custom(func(a: ChunkCoord, b: ChunkCoord) -> bool:
		return focus_chunk.euclidean_distance_to(a) < focus_chunk.euclidean_distance_to(b)
	)

	return candidates

func clear() -> void:
	_chunk_states.clear()
	_surface_cache.clear()
