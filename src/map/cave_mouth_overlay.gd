class_name CaveMouthOverlay
extends Control

## UI component responsible for rendering cave mouth indicators over the continent map.
## Displays each entrance with the letter "C" rendered in high-contrast typography:
## - Red font: Dead-end cave (no subterranean connection).
## - Yellow font: Interconnected 3D worm tunnel network.
## - Green font: Cave mouth leading or descending directly into an underground chasm void.
## Supports dynamic coordinate scaling with pan and zoom.

const MapCoordinateConverterClass = preload("res://src/map/map_coordinate_converter.gd")
const CaveMouthDataClass = preload("res://src/map/cave_mouth_data.gd")

var bounds: WorldBounds
var cave_mouths: Array = []
var pan_offset: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var map_size: Vector2 = Vector2(512.0, 512.0)
var show_labels: bool = true

func set_cave_mouths(mouths: Array, p_bounds: WorldBounds = null) -> void:
	cave_mouths = mouths
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
	if bounds == null or cave_mouths.is_empty():
		return

	var effective_size = map_size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = custom_minimum_size
	if effective_size.x <= 0.0 or effective_size.y <= 0.0:
		effective_size = Vector2(512.0, 512.0)

	var font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size = 12

	var cull_rect = Rect2(Vector2.ZERO, effective_size).grow(32.0)

	for mouth in cave_mouths:
		var base_pixel = MapCoordinateConverterClass.world_to_map_pixel(
			mouth.world_pos,
			bounds,
			Rect2(Vector2.ZERO, effective_size)
		)
		var center = pan_offset + base_pixel * zoom

		# Skip offscreen markers (with subtle margin for border ring)
		if not cull_rect.has_point(center):
			continue

		var color = CaveMouthDataClass.get_type_color(mouth.type)

		# 1. High-contrast dark backdrop disc
		draw_circle(center, 9.0, Color(0.04, 0.06, 0.09, 0.88))
		# 2. Outer colored ring indicator
		draw_arc(center, 9.0, 0.0, TAU, 18, color, 1.5, true)

		# 3. Typography: Render "C" in designated color with drop shadow
		var text = "C"
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = center - Vector2(text_size.x * 0.5, -text_size.y * 0.35)

		# Drop shadow
		draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.9))
		# Colored glyph
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		# 4. Detailed label when zoomed in (zoom >= 1.5x)
		if show_labels and zoom >= 1.5:
			var sub_font_size = 10
			var type_text = CaveMouthDataClass.get_type_name(mouth.type)
			var sub_size = font.get_string_size(type_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_font_size)
			var sub_pos = center + Vector2(-sub_size.x * 0.5, 18.0)

			draw_string(font, sub_pos + Vector2(1, 1), type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_font_size, Color.BLACK)
			draw_string(font, sub_pos, type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_font_size, Color(0.9, 0.95, 1.0, 0.95))
