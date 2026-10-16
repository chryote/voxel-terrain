class_name WorldBoundary
extends Node3D

## Invisible physics barriers at the continent map perimeter.

func setup(bounds: WorldBounds) -> void:
	# Clear existing children
	for c in get_children():
		c.queue_free()

	var static_body = StaticBody3D.new()
	add_child(static_body)

	var wall_height = 600.0
	var thickness = 20.0
	var total_w = bounds.max_world_x - bounds.min_world_x
	var total_d = bounds.max_world_z - bounds.min_world_z

	# West wall (-X)
	_add_box_wall(static_body,
		Vector3(bounds.min_world_x - thickness * 0.5, wall_height * 0.5, 0.0),
		Vector3(thickness, wall_height, total_d + thickness * 2.0)
	)

	# East wall (+X)
	_add_box_wall(static_body,
		Vector3(bounds.max_world_x + thickness * 0.5, wall_height * 0.5, 0.0),
		Vector3(thickness, wall_height, total_d + thickness * 2.0)
	)

	# South wall (-Z)
	_add_box_wall(static_body,
		Vector3(0.0, wall_height * 0.5, bounds.min_world_z - thickness * 0.5),
		Vector3(total_w + thickness * 2.0, wall_height, thickness)
	)

	# North wall (+Z)
	_add_box_wall(static_body,
		Vector3(0.0, wall_height * 0.5, bounds.max_world_z + thickness * 0.5),
		Vector3(total_w + thickness * 2.0, wall_height, thickness)
	)

func _add_box_wall(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
