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
var subterranean_forward_radius_chunks: int = 4
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

const TIER_1_IMMEDIATE: int = 1
const TIER_2_NEARBY_ENTRANCE: int = 2
const TIER_3_DEFERRED_PERIPHERAL: int = 3

var max_tier3_promotions_per_frame: int = 2

## Evaluates whether the player's current elevation or proximity to a cave mouth warrants
## triggering subterranean generation for surface-only chunks, categorizing them into priority tiers:
## - Tier 1 (Immediate): Current player chunk, chunk moving toward, and chunks with active mouths.
## - Tier 2 (Nearby Entrance): Chunks adjacent to mouths facing player camera / forward cone.
## - Tier 3 (Deferred Peripheral): Distant / peripheral chunks within subterranean radius.
func get_tiered_chunks_to_promote(
	player_pos: Vector3,
	focus_chunk: ChunkCoord,
	surface_height: float,
	mouth_cache: Dictionary, # key -> bool
	look_dir: Vector3 = Vector3.ZERO
) -> Dictionary:
	var tiers = {
		"tier1": [] as Array[ChunkCoord],
		"tier2": [] as Array[ChunkCoord],
		"tier3": [] as Array[ChunkCoord]
	}
	if not enabled or focus_chunk == null:
		return tiers

	var is_player_subterranean = player_pos.y < (surface_height - subterranean_elevation_offset)

	# Check if player is near any known cave mouth
	var is_player_near_mouth = false
	var nearby_mouths: Array[ChunkCoord] = []
	for dz in range(-mouth_trigger_radius_chunks, mouth_trigger_radius_chunks + 1):
		for dx in range(-mouth_trigger_radius_chunks, mouth_trigger_radius_chunks + 1):
			var n_coord = ChunkCoord.new(focus_chunk.x + dx, focus_chunk.z + dz)
			if mouth_cache.get(n_coord.to_key(), false):
				is_player_near_mouth = true
				nearby_mouths.append(n_coord)

	# 2D horizontal normalized forward vector
	var has_dir = (look_dir.x != 0.0 or look_dir.z != 0.0)
	var forward2d = Vector2(look_dir.x, look_dir.z).normalized() if has_dir else Vector2.ZERO

	for key in _chunk_states:
		if _chunk_states[key] != ChunkSubterraneanState.STATE_SURFACE_ONLY:
			continue

		var coord = ChunkCoord.from_key(key)
		var has_mouth = mouth_cache.get(key, false)
		var dist_to_focus = focus_chunk.chebyshev_distance_to(coord)

		# Directional scoring
		var offset = Vector2(float(coord.x - focus_chunk.x), float(coord.z - focus_chunk.z))
		var offset_len = offset.length()
		var dot = (offset / offset_len).dot(forward2d) if (has_dir and offset_len > 0.0) else 0.0

		# Promotion eligibility
		var should_promote = false
		if has_mouth:
			should_promote = true
		elif (is_player_subterranean or is_player_near_mouth):
			if dist_to_focus <= subterranean_radius_chunks:
				should_promote = true
			elif has_dir and dist_to_focus <= subterranean_forward_radius_chunks and dot >= 0.0:
				should_promote = true

		if not should_promote:
			continue

		# Tier Classification:
		# Tier 1 (Immediate):
		# - Chunk the player is standing on
		# - Any chunk containing an active cave mouth
		# - Immediate neighbor in direct forward movement direction (dist_to_focus == 1 and dot > 0.707)
		# - Direct forward gaze at distance 2 (dist_to_focus == 2 and dot > 0.8)
		if coord.equals(focus_chunk) or has_mouth or (dist_to_focus == 1 and dot > 0.707) or (dist_to_focus == 2 and dot > 0.8):
			tiers["tier1"].append(coord)
		# Tier 2 (Nearby Entrance & Forward View):
		# - Chunks adjacent to any nearby cave mouth
		# - Chunks within distance 1 in forward 180-degree view cone (dot >= 0.0 or not has_dir)
		# - Chunks at distance 2 in forward view cone (dist_to_focus == 2 and dot >= 0.2)
		# - Chunks at distance 3 in direct forward gaze (dist_to_focus == 3 and dot > 0.707)
		elif _is_adjacent_to_any_mouth(coord, nearby_mouths) or (dist_to_focus <= 1 and (dot >= 0.0 or not has_dir)) or (dist_to_focus == 2 and dot >= 0.2) or (dist_to_focus == 3 and dot > 0.707):
			tiers["tier2"].append(coord)
		# Tier 3 (Deferred Peripheral):
		# - All other eligible peripheral chunks
		else:
			tiers["tier3"].append(coord)

	# Sort each tier
	tiers["tier1"].sort_custom(func(a: ChunkCoord, b: ChunkCoord) -> bool:
		return focus_chunk.euclidean_distance_to(a) < focus_chunk.euclidean_distance_to(b)
	)
	tiers["tier2"].sort_custom(func(a: ChunkCoord, b: ChunkCoord) -> bool:
		return focus_chunk.euclidean_distance_to(a) < focus_chunk.euclidean_distance_to(b)
	)
	tiers["tier3"].sort_custom(func(a: ChunkCoord, b: ChunkCoord) -> bool:
		var dist_a = focus_chunk.euclidean_distance_to(a)
		var dist_b = focus_chunk.euclidean_distance_to(b)
		if has_dir:
			var off_a = Vector2(float(a.x - focus_chunk.x), float(a.z - focus_chunk.z))
			var dot_a = (off_a / off_a.length()).dot(forward2d) if off_a.length() > 0.0 else 0.0
			var off_b = Vector2(float(b.x - focus_chunk.x), float(b.z - focus_chunk.z))
			var dot_b = (off_b / off_b.length()).dot(forward2d) if off_b.length() > 0.0 else 0.0
			var score_a = dist_a - dot_a * 2.0
			var score_b = dist_b - dot_b * 2.0
			return score_a < score_b
		return dist_a < dist_b
	)

	return tiers

func _is_adjacent_to_any_mouth(coord: ChunkCoord, mouths: Array[ChunkCoord]) -> bool:
	for m in mouths:
		if coord.chebyshev_distance_to(m) <= 1:
			return true
	return false

## Evaluates whether the player's current elevation or proximity to a cave mouth warrants
## triggering subterranean generation for surface-only chunks.
## Returns an array of ChunkCoord ordered by priority tiers (Tier 1 -> Tier 2 -> Tier 3).
## When rate_limit_tier3 is true, Tier 3 peripheral chunks are throttled to max_tier3_count.
func get_chunks_to_promote(
	player_pos: Vector3,
	focus_chunk: ChunkCoord,
	surface_height: float,
	mouth_cache: Dictionary, # key -> bool
	look_dir: Vector3 = Vector3.ZERO,
	rate_limit_tier3: bool = false,
	max_tier3_count: int = -1
) -> Array[ChunkCoord]:
	var tiered = get_tiered_chunks_to_promote(player_pos, focus_chunk, surface_height, mouth_cache, look_dir)
	var result: Array[ChunkCoord] = []

	# Tier 1 (Immediate) - always scheduled in full
	result.append_array(tiered["tier1"])

	# Tier 2 (Nearby Entrance) - always scheduled in full
	result.append_array(tiered["tier2"])

	# Tier 3 (Deferred Peripheral) - optionally rate-limited to avoid thread pool storms
	var tier3: Array[ChunkCoord] = tiered["tier3"]
	if rate_limit_tier3:
		var limit = max_tier3_count if max_tier3_count >= 0 else max_tier3_promotions_per_frame
		for i in range(mini(limit, tier3.size())):
			result.append(tier3[i])
	else:
		result.append_array(tier3)

	return result

func clear() -> void:
	_chunk_states.clear()
	_surface_cache.clear()
