class_name PlayerInput
extends Node

## Handles OS input events, mouse capture state, and produces PlayerIntent.

@export var mouse_sensitivity: float = 0.0025
@export var auto_capture_mouse: bool = true

var _look_delta: Vector2 = Vector2.ZERO
var _is_mouse_captured: bool = false

func _ready() -> void:
	if auto_capture_mouse and not OS.has_feature("editor_hint"):
		capture_mouse()

func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_is_mouse_captured = true

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_mouse_captured = false

func is_mouse_captured() -> bool:
	return _is_mouse_captured

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _is_mouse_captured:
			capture_mouse()

	if event is InputEventMouseMotion and _is_mouse_captured:
		_look_delta += event.relative * mouse_sensitivity

func get_intent() -> PlayerIntent:
	var intent = PlayerIntent.new()

	if Input.is_action_just_pressed("toggle_mouse"):
		if _is_mouse_captured:
			release_mouse()
		else:
			capture_mouse()
		intent.toggle_mouse_requested = true

	intent.toggle_debug_requested = Input.is_action_just_pressed("toggle_debug")

	if _is_mouse_captured:
		intent.look_delta = _look_delta
		_look_delta = Vector2.ZERO

		intent.move_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		intent.jump_requested = Input.is_action_just_pressed("jump")
		intent.sprint_requested = Input.is_action_pressed("sprint")
		intent.aim_requested = Input.is_action_pressed("aim")
		intent.fire_requested = Input.is_action_just_pressed("fire")
		intent.swap_shoulder_requested = Input.is_action_just_pressed("swap_shoulder")

	return intent
