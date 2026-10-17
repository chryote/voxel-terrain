class_name LayerVisibilityCoordinator
extends RefCounted

## Manages visibility and activation of subterranean layers across loaded chunks.
## Gates cave rendering when the player is on the surface to eliminate GPU triangle throughput,
## while activating cave visibility near cave mouths and when the player descends underground.

enum PlayerLayerState {
	SURFACE,
	NEAR_CAVE_MOUTH,
	SUBTERRANEAN
}

var last_state: PlayerLayerState = PlayerLayerState.SURFACE
var last_chunk_coord: ChunkCoord = null
var mouth_visibility_radius_chunks: int = 1
var _last_chunk_count: int = -1

func determine_player_state(
	player_pos: Vector3,
	surface_height: float,
	is_near_mouth: bool,
	sea_level_height: float = 9.0
) -> PlayerLayerState:
	var water_margin = sea_level_height + 0.5
	var is_open_water = (surface_height <= water_margin and player_pos.y >= (surface_height - 1.0))
	var low_elevation_threshold = maxf(12.0, sea_level_height + 3.0)
	if not is_open_water and (player_pos.y < (surface_height - 3.0) or (player_pos.y <= low_elevation_threshold and surface_height > low_elevation_threshold)):
		return PlayerLayerState.SUBTERRANEAN
	elif is_near_mouth:
		return PlayerLayerState.NEAR_CAVE_MOUTH
	return PlayerLayerState.SURFACE

func update_chunk_visibility(
	focus_pos: Vector3,
	focus_coord: ChunkCoord,
	surface_height: float,
	loaded_chunks: Dictionary,
	mouth_cache: Dictionary, # key -> bool
	force: bool = false,
	sea_level_height: float = 9.0
) -> PlayerLayerState:
	var is_near_mouth = false
	if focus_coord != null:
		# Check if focus chunk or adjacent chunk contains a mouth
		for dz in range(-mouth_visibility_radius_chunks, mouth_visibility_radius_chunks + 1):
			for dx in range(-mouth_visibility_radius_chunks, mouth_visibility_radius_chunks + 1):
				var neighbor_coord = ChunkCoord.new(focus_coord.x + dx, focus_coord.z + dz)
				var key = neighbor_coord.to_key()
				if mouth_cache.get(key, false):
					is_near_mouth = true
					break
			if is_near_mouth:
				break

	var current_state = determine_player_state(focus_pos, surface_height, is_near_mouth, sea_level_height)

	# Avoid redundant iterations if neither chunk position nor state nor loaded chunk count changed
	if not force and last_chunk_coord != null and last_chunk_coord.equals(focus_coord) and current_state == last_state and loaded_chunks.size() == _last_chunk_count:
		return current_state

	last_chunk_coord = focus_coord
	last_state = current_state
	_last_chunk_count = loaded_chunks.size()

	for key in loaded_chunks:
		var node = loaded_chunks[key]
		if not (node is ChunkNode):
			continue

		var coord: ChunkCoord = node.coord
		var chunk_has_mouth_nearby = false
		for dz in range(-mouth_visibility_radius_chunks, mouth_visibility_radius_chunks + 1):
			for dx in range(-mouth_visibility_radius_chunks, mouth_visibility_radius_chunks + 1):
				var n_coord = ChunkCoord.new(coord.x + dx, coord.z + dz)
				if mouth_cache.get(n_coord.to_key(), false):
					chunk_has_mouth_nearby = true
					break
			if chunk_has_mouth_nearby:
				break

		match current_state:
			PlayerLayerState.SURFACE:
				# On surface: only chunks near active cave mouths are visible
				node.set_subterranean_visible(chunk_has_mouth_nearby)

			PlayerLayerState.NEAR_CAVE_MOUTH:
				# Near cave mouth: mouth neighborhood is visible
				node.set_subterranean_visible(chunk_has_mouth_nearby)

			PlayerLayerState.SUBTERRANEAN:
				# Underground: all loaded cave chunks are visible
				node.set_subterranean_visible(true)

	return current_state
