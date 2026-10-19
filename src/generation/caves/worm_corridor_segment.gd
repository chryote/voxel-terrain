class_name WormCorridorSegment
extends RefCounted

## Pure mathematical representation of a single 3D worm tunnel corridor segment.
## Models a swept-capsule volume with linearly tapered radius between two 3D endpoints.
## Designed for high-performance zero-allocation distance queries and spatial culling.

var start_pos: Vector3
var end_pos: Vector3
var start_radius: float
var end_radius: float
var max_radius: float
var length: float
var direction: Vector3
var aabb: AABB

func _init(
	p_start: Vector3 = Vector3.ZERO,
	p_end: Vector3 = Vector3.ZERO,
	p_start_r: float = 3.5,
	p_end_r: float = 3.5,
	p_margin: float = 0.0
) -> void:
	start_pos = p_start
	end_pos = p_end
	start_radius = maxf(0.01, p_start_r)
	end_radius = maxf(0.01, p_end_r)
	max_radius = maxf(start_radius, end_radius)

	var delta = end_pos - start_pos
	var len_sq = delta.length_squared()
	if len_sq > 0.000001:
		length = sqrt(len_sq)
		direction = delta / length
	else:
		length = 0.0
		direction = Vector3.UP

	# Compute conservative AABB enclosing both endpoint spheres plus optional margin
	var min_x = minf(start_pos.x - start_radius, end_pos.x - end_radius) - p_margin
	var min_y = minf(start_pos.y - start_radius, end_pos.y - end_radius) - p_margin
	var min_z = minf(start_pos.z - start_radius, end_pos.z - end_radius) - p_margin
	var max_x = maxf(start_pos.x + start_radius, end_pos.x + end_radius) + p_margin
	var max_y = maxf(start_pos.y + start_radius, end_pos.y + end_radius) + p_margin
	var max_z = maxf(start_pos.z + start_radius, end_pos.z + end_radius) + p_margin

	aabb = AABB(
		Vector3(min_x, min_y, min_z),
		Vector3(max_x - min_x, max_y - min_y, max_z - min_z)
	)

## Returns the projection factor t in [0.0, 1.0] representing where point p projects onto [start_pos, end_pos].
func get_projection_factor(p: Vector3) -> float:
	if length <= 0.000001:
		return 0.0
	var ab = end_pos - start_pos
	var ap = p - start_pos
	return clampf(ap.dot(ab) / (length * length), 0.0, 1.0)

## Returns the closest 3D point on the line segment to point p.
func get_closest_point(p: Vector3) -> Vector3:
	var t = get_projection_factor(p)
	return start_pos + (end_pos - start_pos) * t

## Returns the Euclidean distance from point p to the centerline segment.
func distance_to_point(p: Vector3) -> float:
	var closest = get_closest_point(p)
	return p.distance_to(closest)

## Returns the linearly interpolated tunnel radius at the projection of point p.
func get_interpolated_radius(p: Vector3) -> float:
	var t = get_projection_factor(p)
	return lerpf(start_radius, end_radius, t)

## Returns signed distance to the tunnel surface:
## Negative (< 0.0) means inside the tunnel void (air).
## Zero (== 0.0) means on the tunnel wall perimeter.
## Positive (> 0.0) means outside the tunnel inside solid rock.
func distance_to_surface(p: Vector3) -> float:
	return distance_to_point(p) - get_interpolated_radius(p)

## Returns true if the swept capsule of this segment intersects the given bounding box.
func intersects_aabb(box: AABB) -> bool:
	# 1. Broad-phase AABB overlap
	if not aabb.intersects(box):
		return false

	# 2. Check if either endpoint lies inside the expanded box
	var eff_r = max_radius
	var exp_box = box.grow(eff_r)
	if exp_box.has_point(start_pos) or exp_box.has_point(end_pos):
		return true

	# 3. Check if line segment intersects expanded box
	var hit = exp_box.intersects_segment(start_pos, end_pos)
	if hit != null:
		return true

	# 4. Check distance from the box center to the segment
	var box_center = box.position + box.size * 0.5
	var closest_on_seg = get_closest_point(box_center)
	var clamped_on_box = Vector3(
		clampf(closest_on_seg.x, box.position.x, box.end.x),
		clampf(closest_on_seg.y, box.position.y, box.end.y),
		clampf(closest_on_seg.z, box.position.z, box.end.z)
	)
	var r = get_interpolated_radius(clamped_on_box)
	return closest_on_seg.distance_to(clamped_on_box) <= r
