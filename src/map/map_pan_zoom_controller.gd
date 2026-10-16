class_name MapPanZoomController
extends RefCounted

## Pure component managing pan and zoom state, cursor-anchored scaling,
## and boundary clamping for map viewports.
##
## Decoupled from scene nodes and rendering backends for testability.

var min_zoom: float = 1.0
var max_zoom: float = 8.0
var zoom_step: float = 1.25

var zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var box_size: Vector2 = Vector2(512, 512)

var is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO

func _init(p_box_size: Vector2 = Vector2(512, 512), p_min_zoom: float = 1.0, p_max_zoom: float = 8.0) -> void:
	box_size = p_box_size
	min_zoom = maxf(1.0, p_min_zoom)
	max_zoom = maxf(min_zoom, p_max_zoom)
	zoom = min_zoom
	pan_offset = Vector2.ZERO

func reset() -> void:
	zoom = min_zoom
	pan_offset = Vector2.ZERO
	is_dragging = false

func set_box_size(p_size: Vector2) -> void:
	box_size = p_size
	pan_offset = clamp_offset(pan_offset, zoom)

func clamp_offset(target_offset: Vector2, current_zoom: float) -> Vector2:
	if current_zoom <= 1.0:
		return Vector2.ZERO

	# When zoomed in, the map is larger than the box.
	# The offset can range from (box_size * (1.0 - zoom)) to 0.0.
	var min_x = box_size.x * (1.0 - current_zoom)
	var min_y = box_size.y * (1.0 - current_zoom)

	return Vector2(
		clampf(target_offset.x, min_x, 0.0),
		clampf(target_offset.y, min_y, 0.0)
	)

func zoom_at(cursor_pos: Vector2, zoom_multiplier: float) -> void:
	var target_zoom = clampf(zoom * zoom_multiplier, min_zoom, max_zoom)
	set_zoom_at(cursor_pos, target_zoom)

func set_zoom_at(cursor_pos: Vector2, target_zoom: float) -> void:
	var clamped_zoom = clampf(target_zoom, min_zoom, max_zoom)
	if is_equal_approx(clamped_zoom, zoom):
		return

	# Anchor math: keep the map coordinate under cursor_pos invariant
	# cursor_pos = new_offset + (cursor_pos - old_offset) * (new_zoom / old_zoom)
	var new_offset = cursor_pos - (cursor_pos - pan_offset) * (clamped_zoom / zoom)
	zoom = clamped_zoom
	pan_offset = clamp_offset(new_offset, zoom)

func start_drag(cursor_pos: Vector2) -> void:
	is_dragging = true
	_drag_start_pos = cursor_pos
	_drag_start_offset = pan_offset

func drag_to(cursor_pos: Vector2) -> void:
	if not is_dragging:
		return
	var delta = cursor_pos - _drag_start_pos
	pan_offset = clamp_offset(_drag_start_offset + delta, zoom)

func end_drag() -> void:
	is_dragging = false

func pan_by(delta: Vector2) -> void:
	pan_offset = clamp_offset(pan_offset + delta, zoom)

func map_to_screen(local_map_pos: Vector2) -> Vector2:
	return pan_offset + local_map_pos * zoom

func screen_to_map(screen_pos: Vector2) -> Vector2:
	if zoom <= 0.0:
		return Vector2.ZERO
	return (screen_pos - pan_offset) / zoom
