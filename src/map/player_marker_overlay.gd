class_name PlayerMarkerOverlay
extends Control

## Single-responsibility UI component that renders a vibrant red dot indicator
## and heading pointer for the player over the continent map.

const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")

var bounds: WorldBounds
var player_world_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var show_heading_pointer: bool = true
var show_coordinate_label: bool = true

var pan_offset: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var map_size: Vector2 = Vector2(512.0, 512.0)

var _pulse_timer: float = 0.0

func _process(delta: float) -> void:
	if visible:
		_pulse_timer += delta * 3.0
		queue_redraw()

func update_player_state(world_pos: Vector3, yaw: float, p_bounds: WorldBounds = null) -> void:
	player_world_pos = world_pos
	player_yaw = yaw
	if p_bounds != null:
		bounds = p_bounds
	queue_redraw()

func update_transform(p_offset: Vector2, p_zoom: float, p_map_size: Vector2 = Vector2.ZERO) -> void:
	pan_offset = p_offset
	zoom = p_zoom
	if p_map_size.x > 0.0 and p_map_size.y > 0.0:
		map_size = p_map_size
	queue_redraw()

func _draw() -> void:
	if bounds == null:
		return

	var effective_size = map_size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = custom_minimum_size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = Vector2(512.0, 512.0)

	var base_pixel = MapCoordinateConverterClass.world_to_map_pixel(
		player_world_pos,
		bounds,
		Rect2(Vector2.ZERO, effective_size)
	)
	var center = pan_offset + base_pixel * zoom

	# Cull only if far outside the visible viewport
	var cull_rect = Rect2(Vector2.ZERO, effective_size).grow(64.0)
	if not cull_rect.has_point(center):
		return

	# 1. Subtle pulsing radar ring
	var pulse_radius = 8.0 + sin(_pulse_timer) * 3.0
	var pulse_color = Color(1.0, 0.2, 0.2, 0.35 + 0.15 * sin(_pulse_timer))
	draw_arc(center, pulse_radius, 0.0, TAU, 24, pulse_color, 1.5, true)

	# 2. White outer outline (ensures visibility against dark deep sea and bright snow)
	draw_circle(center, 5.0, Color.WHITE)

	# 3. Solid high-visibility RED DOT indicating player location
	var red_color = Color(0.92, 0.12, 0.12, 1.0)
	draw_circle(center, 3.5, red_color)

	# 4. Heading arrow / directional indicator
	if show_heading_pointer:
		# Player yaw in Godot: 0 = -Z (North), positive turns counter-clockwise / clockwise depending on rig
		var forward_angle = player_yaw + PI * 0.5
		var dir = Vector2(cos(forward_angle), sin(forward_angle)).normalized()
		var tip = center + dir * 12.0
		var side1 = center + Vector2(-dir.y, dir.x) * 4.0
		var side2 = center + Vector2(dir.y, -dir.x) * 4.0

		var tri_pts = PackedVector2Array([tip, side1, side2])
		draw_colored_polygon(tri_pts, Color(1.0, 1.0, 1.0, 0.95))

	# 5. Coordinate readout near marker
	if show_coordinate_label:
		var font = ThemeDB.fallback_font
		if font != null:
			var font_size = 11
			var text = "X: %d  Z: %d (Alt: %dm)" % [
				int(round(player_world_pos.x)),
				int(round(player_world_pos.z)),
				int(round(player_world_pos.y))
			]
			var text_pos = center + Vector2(10.0, -10.0)
			# Background shadow
			draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.8, 0.95))
