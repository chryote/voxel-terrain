class_name WormTrajectory
extends RefCounted

## Pure data structure representing a continuous, ordered 3D worm corridor trajectory.
## Composed of sequential 3D waypoints and tapered WormCorridorSegment instances connecting them.
## Manages composite bounding envelopes, distance queries, and corridor sampling.

const WormCorridorSegmentClass = preload("res://src/generation/caves/worm_corridor_segment.gd")

var id: int = 0
var source_anchor: Vector3 = Vector3.ZERO
var target_anchor: Vector3 = Vector3.ZERO

var waypoints: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var segments: Array[WormCorridorSegment] = []

var total_length: float = 0.0
var bounds_aabb: AABB = AABB()
var traversed_chunks: Array[ChunkCoord] = []

func _init(p_id: int = 0, p_source: Vector3 = Vector3.ZERO, p_target: Vector3 = Vector3.ZERO) -> void:
	id = p_id
	source_anchor = p_source
	target_anchor = p_target

## Appends a new 3D waypoint with its local tunnel radius.
## If preceding waypoints exist, creates and links a new WormCorridorSegment connecting the previous point.
func add_waypoint(point: Vector3, radius: float = 3.5, margin: float = 0.0) -> void:
	var safe_r = maxf(0.01, radius)
	var count = waypoints.size()

	waypoints.append(point)
	radii.append(safe_r)

	if count > 0:
		var prev_point = waypoints[count - 1]
		var prev_r = radii[count - 1]
		var seg = WormCorridorSegmentClass.new(prev_point, point, prev_r, safe_r, margin)
		segments.append(seg)
		total_length += seg.length

		if segments.size() == 1:
			bounds_aabb = seg.aabb
		else:
			bounds_aabb = bounds_aabb.merge(seg.aabb)
	else:
		# Initial single-sphere bounding box
		var r = safe_r + margin
		bounds_aabb = AABB(point - Vector3(r, r, r), Vector3(r * 2.0, r * 2.0, r * 2.0))

func get_segment_count() -> int:
	return segments.size()

func get_segment(index: int) -> WormCorridorSegment:
	if index >= 0 and index < segments.size():
		return segments[index]
	return null

## Returns the minimum Euclidean distance from point p to any segment along this corridor.
func distance_to_point(p: Vector3) -> float:
	if segments.is_empty():
		return INF
	# Fast broad-phase reject if p is farther from composite AABB than a known threshold
	var min_dist = INF
	for seg in segments:
		var d = seg.distance_to_point(p)
		if d < min_dist:
			min_dist = d
	return min_dist

## Returns the segment in this trajectory closest to point p.
func get_closest_segment(p: Vector3) -> WormCorridorSegment:
	if segments.is_empty():
		return null
	var best_seg: WormCorridorSegment = null
	var min_dist = INF
	for seg in segments:
		var d = seg.distance_to_point(p)
		if d < min_dist:
			min_dist = d
			best_seg = seg
	return best_seg

## Returns signed distance to the corridor surface across all segments.
## Negative means inside hollow tunnel, positive means inside solid stone.
func distance_to_surface(p: Vector3) -> float:
	if segments.is_empty():
		return INF
	var min_surf_dist = INF
	for seg in segments:
		var sd = seg.distance_to_surface(p)
		if sd < min_surf_dist:
			min_surf_dist = sd
	return min_surf_dist

## Returns true if any segment in this trajectory intersects the given AABB.
func intersects_aabb(box: AABB) -> bool:
	if not bounds_aabb.intersects(box):
		return false
	for seg in segments:
		if seg.intersects_aabb(box):
			return true
	return false

## Samples a 3D coordinate at a specified linear distance along the trajectory spine.
func sample_point_at_distance(dist: float) -> Vector3:
	if waypoints.is_empty():
		return Vector3.ZERO
	if segments.is_empty() or dist <= 0.0:
		return waypoints[0]
	if dist >= total_length:
		return waypoints[waypoints.size() - 1]

	var accumulated = 0.0
	for seg in segments:
		if (accumulated + seg.length) >= dist:
			var remain = dist - accumulated
			var t = remain / maxf(0.00001, seg.length)
			return seg.start_pos + (seg.end_pos - seg.start_pos) * t
		accumulated += seg.length

	return waypoints[waypoints.size() - 1]

func clear() -> void:
	waypoints.clear()
	radii.clear()
	segments.clear()
	traversed_chunks.clear()
	total_length = 0.0
	bounds_aabb = AABB()
