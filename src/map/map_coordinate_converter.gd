class_name MapCoordinateConverter
extends RefCounted

## Pure utility for mapping between 3D world coordinates, normalized UV [0..1],
## and 2D UI screen rectangle coordinates.

static func world_to_normalized(world_pos: Vector3, bounds: WorldBounds) -> Vector2:
	if bounds == null:
		return Vector2(0.5, 0.5)
	var span_x = bounds.max_world_x - bounds.min_world_x
	var span_z = bounds.max_world_z - bounds.min_world_z
	if span_x <= 0.0 or span_z <= 0.0:
		return Vector2(0.5, 0.5)

	var u = (world_pos.x - bounds.min_world_x) / span_x
	var v = (world_pos.z - bounds.min_world_z) / span_z
	return Vector2(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0))

static func normalized_to_world(uv: Vector2, bounds: WorldBounds, y: float = 0.0) -> Vector3:
	if bounds == null:
		return Vector3.ZERO
	var span_x = bounds.max_world_x - bounds.min_world_x
	var span_z = bounds.max_world_z - bounds.min_world_z

	var wx = bounds.min_world_x + clampf(uv.x, 0.0, 1.0) * span_x
	var wz = bounds.min_world_z + clampf(uv.y, 0.0, 1.0) * span_z
	return Vector3(wx, y, wz)

static func world_to_map_pixel(world_pos: Vector3, bounds: WorldBounds, map_rect: Rect2) -> Vector2:
	var uv = world_to_normalized(world_pos, bounds)
	return Vector2(
		map_rect.position.x + uv.x * map_rect.size.x,
		map_rect.position.y + uv.y * map_rect.size.y
	)

static func is_within_bounds(world_pos: Vector3, bounds: WorldBounds) -> bool:
	if bounds == null:
		return false
	return world_pos.x >= bounds.min_world_x and world_pos.x <= bounds.max_world_x \
		and world_pos.z >= bounds.min_world_z and world_pos.z <= bounds.max_world_z
