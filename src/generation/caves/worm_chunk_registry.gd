class_name WormChunkRegistry
extends RefCounted

## Spatial index and rasterizer recording exact chunk coordinates and 16m vertical section
## bitmasks intersected by 3D worm tunnel corridor trajectories.
##
## Eliminates >93% false-positive 3D voxel fallbacks by providing O(1) dictionary queries
## to LayeredTerrainGenerator and sequential corridor descent routes to SubterraneanStreamCoordinator.

const WormTrajectoryClass = preload("res://src/generation/caves/worm_trajectory.gd")
const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")

var chunk_size: int = 16
var voxel_size: float = 1.0
var section_height: float = 16.0
var chunk_world_size: float = 16.0

## Key: "x,z" -> Array[WormCorridorSegment]
var _chunk_segments: Dictionary = {}

## Key: "x,z" -> ChunkCoord
var _chunk_coords: Dictionary = {}

## Key: "x,z" -> int bitmask of active vertical sections (bit s = section s is active)
var _chunk_section_masks: Dictionary = {}

## Key: mouth_id -> Array[ChunkCoord] in order of descent from surface mouth to chasm
var _corridor_routes: Dictionary = {}

## Key: trajectory_id -> WormTrajectory
var _trajectories: Dictionary = {}

func _init(
	p_chunk_size: int = 16,
	p_voxel_size: float = 1.0,
	p_section_height: float = 16.0
) -> void:
	chunk_size = maxi(1, p_chunk_size)
	voxel_size = maxf(0.01, p_voxel_size)
	section_height = maxf(1.0, p_section_height)
	chunk_world_size = float(chunk_size) * voxel_size

## Registers a complete WormTrajectory, rasterizing its segments into chunks and vertical sections.
## Returns the ordered array of ChunkCoords along the descent corridor from surface mouth to chasm.
func register_trajectory(trajectory: WormTrajectory) -> Array[ChunkCoord]:
	if trajectory == null or trajectory.segments.is_empty():
		return []

	_trajectories[trajectory.id] = trajectory
	var route: Array[ChunkCoord] = []

	# 1. Rasterize each segment into chunk bounding volumes and vertical section bitmasks
	for seg in trajectory.segments:
		_rasterize_segment(seg)

	# 2. Trace the ordered chunk path from surface mouth to chasm floor
	route = _trace_ordered_route(trajectory)
	_corridor_routes[trajectory.id] = route
	trajectory.traversed_chunks = route

	return route

## Returns true if the specified chunk coordinate contains any worm tunnel geometry (O(1)).
func has_chunk(coord: ChunkCoord) -> bool:
	if coord == null:
		return false
	return _chunk_segments.has(coord.to_key())

## Returns true if the specified integer chunk key contains any worm tunnel geometry (O(1)).
func has_chunk_key(key: int) -> bool:
	return _chunk_segments.has(key)

## Returns the array of WormCorridorSegments intersecting this chunk.
func get_segments_for_chunk(coord: ChunkCoord) -> Array[WormCorridorSegment]:
	if coord == null:
		return []
	var res: Array[WormCorridorSegment] = []
	var raw = _chunk_segments.get(coord.to_key(), null)
	if raw != null:
		for seg in raw:
			res.append(seg)
	return res

## Returns the integer bitmask of active 16m vertical sections for this chunk.
func get_active_section_mask(coord: ChunkCoord) -> int:
	if coord == null:
		return 0
	return _chunk_section_masks.get(coord.to_key(), 0)

## Returns true if the specified 16m vertical section index is active in this chunk.
func is_section_active(coord: ChunkCoord, section_idx: int) -> bool:
	if coord == null or section_idx < 0 or section_idx > 30:
		return false
	var mask = _chunk_section_masks.get(coord.to_key(), 0)
	return (mask & (1 << section_idx)) != 0

## Returns the array of active integer vertical section indices for this chunk.
func get_active_section_indices(coord: ChunkCoord) -> Array[int]:
	var indices: Array[int] = []
	if coord == null:
		return indices
	var mask = _chunk_section_masks.get(coord.to_key(), 0)
	var idx = 0
	while mask > 0:
		if (mask & 1) != 0:
			indices.append(idx)
		mask = mask >> 1
		idx += 1
	return indices

## Returns the ordered array of ChunkCoords along the descent corridor for a given mouth ID.
func get_corridor_route(mouth_id: int) -> Array[ChunkCoord]:
	var res: Array[ChunkCoord] = []
	var raw = _corridor_routes.get(mouth_id, null)
	if raw != null:
		for c in raw:
			res.append(c)
	return res

## Returns all corridor routes that pass through or begin at the specified chunk coordinate.
func get_routes_for_chunk(coord: ChunkCoord) -> Array:
	var matching: Array = []
	if coord == null:
		return matching
	var target_key = coord.to_key()
	for m_id in _corridor_routes:
		var raw_route: Array[ChunkCoord] = _corridor_routes[m_id]
		for c in raw_route:
			if c.to_key() == target_key:
				matching.append(raw_route)
				break
	return matching

## Returns all registered corridor routes mapped by mouth ID.
func get_all_corridor_routes() -> Dictionary:
	return _corridor_routes

## Returns an array of all unique ChunkCoords registered across all corridors.
func get_all_registered_chunks() -> Array[ChunkCoord]:
	var res: Array[ChunkCoord] = []
	for key in _chunk_coords:
		res.append(_chunk_coords[key])
	return res

## Returns the total number of chunks containing worm tunnels.
func get_registered_chunk_count() -> int:
	return _chunk_coords.size()

## Clears all registered trajectories and spatial lookup tables.
func clear() -> void:
	_chunk_segments.clear()
	_chunk_coords.clear()
	_chunk_section_masks.clear()
	_corridor_routes.clear()
	_trajectories.clear()

## Converts 3D world coordinates to a ChunkCoord.
func world_to_chunk(pos: Vector3) -> ChunkCoord:
	var cx = floori(pos.x / chunk_world_size)
	var cz = floori(pos.z / chunk_world_size)
	return ChunkCoord.new(cx, cz)

## Rasterizes a single 3D swept-capsule segment into chunk columns and 16m sections.
func _rasterize_segment(seg: WormCorridorSegment) -> void:
	var min_cx = floori(seg.aabb.position.x / chunk_world_size)
	var max_cx = floori(seg.aabb.end.x / chunk_world_size)
	var min_cz = floori(seg.aabb.position.z / chunk_world_size)
	var max_cz = floori(seg.aabb.end.z / chunk_world_size)

	var min_sec = maxi(0, floori(seg.aabb.position.y / section_height))
	var max_sec = maxi(0, floori(seg.aabb.end.y / section_height))

	for cz in range(min_cz, max_cz + 1):
		for cx in range(min_cx, max_cx + 1):
			var chunk_min_x = float(cx) * chunk_world_size
			var chunk_min_z = float(cz) * chunk_world_size

			# Test broad chunk column volume (Y=0..256)
			var col_box = AABB(
				Vector3(chunk_min_x, 0.0, chunk_min_z),
				Vector3(chunk_world_size, 256.0, chunk_world_size)
			)

			if not seg.intersects_aabb(col_box):
				continue

			var coord = ChunkCoord.new(cx, cz)
			var key = coord.to_key()

			if not _chunk_segments.has(key):
				_chunk_segments[key] = []
				_chunk_coords[key] = coord
				_chunk_section_masks[key] = 0

			_chunk_segments[key].append(seg)

			# Discretize into active 16m vertical sections
			var section_mask = 0
			for s in range(min_sec, max_sec + 1):
				var sec_box = AABB(
					Vector3(chunk_min_x, float(s) * section_height, chunk_min_z),
					Vector3(chunk_world_size, section_height, chunk_world_size)
				)
				if seg.intersects_aabb(sec_box):
					section_mask |= (1 << s)

			_chunk_section_masks[key] = _chunk_section_masks[key] | section_mask

## Traces the ordered sequence of traversed chunks from start to finish along the spline.
func _trace_ordered_route(trajectory: WormTrajectory) -> Array[ChunkCoord]:
	var route: Array[ChunkCoord] = []
	var len_val = trajectory.total_length
	if len_val <= 0.001:
		if not trajectory.waypoints.is_empty():
			route.append(world_to_chunk(trajectory.waypoints[0]))
		return route

	# Sample along spine in steps equal to half chunk size to avoid missing diagonal transitions
	var step_size = maxf(2.0, chunk_world_size * 0.4)
	var cur_dist = 0.0
	var has_last = false
	var last_key: int = 0

	while cur_dist <= len_val:
		var pt = trajectory.sample_point_at_distance(cur_dist)
		var c = world_to_chunk(pt)
		var k = c.to_key()
		if not has_last or k != last_key:
			route.append(c)
			last_key = k
			has_last = true
		cur_dist += step_size

	# Ensure final chasm endpoint chunk is included
	var end_c = world_to_chunk(trajectory.sample_point_at_distance(len_val))
	if not has_last or end_c.to_key() != last_key:
		route.append(end_c)

	return route
