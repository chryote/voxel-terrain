class_name FlightController
extends Node

## Manages 3D flight locomotion state, speed parameters, and velocity integration.

const FlightMath = preload("res://src/player/flight_math.gd")

signal flight_mode_changed(is_flying: bool)

@export var fly_speed: float = 12.0
@export var fly_sprint_speed: float = 24.0
@export var acceleration: float = 8.0
@export var deceleration: float = 6.0
@export var can_fly: bool = true

var is_flying: bool = false:
	set = set_flying,
	get = is_flight_active

func is_flight_active() -> bool:
	return is_flying

func set_flying(value: bool) -> void:
	if not can_fly and value:
		return
	if is_flying == value:
		return
	is_flying = value
	flight_mode_changed.emit(is_flying)

func toggle_flight() -> bool:
	if can_fly:
		set_flying(not is_flying)
	return is_flying

func handle_intent(intent: PlayerIntent) -> void:
	if intent == null:
		return
	if intent.toggle_fly_requested:
		toggle_flight()

func compute_flight_velocity(current_velocity: Vector3, intent: PlayerIntent, cam_yaw: float, cam_pitch: float, delta: float) -> Vector3:
	if not is_flying or intent == null:
		return current_velocity

	var vertical_axis = FlightMath.calculate_vertical_axis(intent.fly_up_requested, intent.fly_down_requested)
	var move_dir = FlightMath.compute_flight_direction(cam_yaw, cam_pitch, intent.move_vector, vertical_axis)
	var target_speed = FlightMath.calculate_target_speed(intent.sprint_requested, fly_speed, fly_sprint_speed)
	var target_velocity = move_dir * target_speed

	return FlightMath.accelerate_flight_velocity(current_velocity, target_velocity, delta, acceleration, deceleration)
