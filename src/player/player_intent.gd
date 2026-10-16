class_name PlayerIntent
extends RefCounted

## Pure data structure representing user or AI input actions for a single frame.

var move_vector: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var jump_requested: bool = false
var sprint_requested: bool = false
var aim_requested: bool = false
var fire_requested: bool = false
var swap_shoulder_requested: bool = false
var toggle_mouse_requested: bool = false
var toggle_debug_requested: bool = false
var toggle_map_requested: bool = false

func reset() -> void:
	move_vector = Vector2.ZERO
	look_delta = Vector2.ZERO
	jump_requested = false
	sprint_requested = false
	aim_requested = false
	fire_requested = false
	swap_shoulder_requested = false
	toggle_mouse_requested = false
	toggle_debug_requested = false
	toggle_map_requested = false
