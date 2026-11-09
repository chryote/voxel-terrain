class_name PawnLocomotionWaddler
extends Node

## Procedural locomotion component providing RimWorld-style waddling, bobbing, and squash/stretch.
## Operates independently of underlying character physics.

@export var enabled: bool = true
@export var step_frequency: float = 12.0
@export var bounce_height: float = 0.08
@export var waddle_roll_degrees: float = 4.5
@export var forward_lean_degrees: float = 3.5
@export var squash_amount: float = 0.04
@export var idle_breath_frequency: float = 2.0
@export var idle_breath_amount: float = 0.015

@export var character_body: CharacterBody3D
@export var visual_target: Node3D

var _step_phase: float = 0.0
var _idle_phase: float = 0.0
var _current_offset_y: float = 0.0
var _current_roll_z: float = 0.0
var _current_lean_x: float = 0.0
var _current_scale_y: float = 1.0
var _current_scale_xz: float = 1.0

# Base rest transform values
var _base_position_y: float = 0.0
var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if visual_target != null:
		_base_position_y = visual_target.position.y
		_base_scale = visual_target.scale

func _process(delta: float) -> void:
	update_locomotion(delta)

func update_locomotion(delta: float) -> void:
	if not enabled or visual_target == null:
		return

	var horizontal_speed: float = 0.0
	var is_grounded: bool = true

	if character_body != null:
		var horiz_vel = Vector2(character_body.velocity.x, character_body.velocity.z)
		horizontal_speed = horiz_vel.length()
		is_grounded = character_body.is_on_floor()

	var target_offset_y: float = 0.0
	var target_roll_z: float = 0.0
	var target_lean_x: float = 0.0
	var target_scale_y: float = 1.0
	var target_scale_xz: float = 1.0

	if horizontal_speed > 0.1 and is_grounded:
		# Moving on ground -> active waddle
		var speed_norm = clampf(horizontal_speed / 8.0, 0.2, 1.5)
		_step_phase += delta * step_frequency * speed_norm
		if _step_phase > TAU:
			_step_phase = fmod(_step_phase, TAU)

		var step_sin = sin(_step_phase)
		var bounce_norm = absf(step_sin)

		target_offset_y = bounce_norm * bounce_height
		target_roll_z = step_sin * deg_to_rad(waddle_roll_degrees)
		target_lean_x = -clampf(horizontal_speed / 10.0, 0.0, 1.0) * deg_to_rad(forward_lean_degrees)

		# Squash on foot contact (when bounce_norm is near 0)
		var contact = 1.0 - bounce_norm
		target_scale_y = 1.0 - contact * squash_amount
		target_scale_xz = 1.0 + contact * (squash_amount * 0.5)
	else:
		# Idle or mid-air -> subtle breathing or dampening
		_idle_phase += delta * idle_breath_frequency
		if _idle_phase > TAU:
			_idle_phase = fmod(_idle_phase, TAU)

		if is_grounded:
			var breath = sin(_idle_phase)
			target_offset_y = breath * (idle_breath_amount * 0.5)
			target_scale_y = 1.0 + breath * idle_breath_amount
			target_scale_xz = 1.0 - breath * (idle_breath_amount * 0.5)
		else:
			# In air (jumping/falling) -> neutral stretch
			target_offset_y = 0.0
			target_roll_z = 0.0
			target_lean_x = 0.0
			target_scale_y = 1.05
			target_scale_xz = 0.98

	# Smooth blending
	var blend_weight = clampf(delta * 14.0, 0.0, 1.0)
	_current_offset_y = lerpf(_current_offset_y, target_offset_y, blend_weight)
	_current_roll_z = lerpf(_current_roll_z, target_roll_z, blend_weight)
	_current_lean_x = lerpf(_current_lean_x, target_lean_x, blend_weight)
	_current_scale_y = lerpf(_current_scale_y, target_scale_y, blend_weight)
	_current_scale_xz = lerpf(_current_scale_xz, target_scale_xz, blend_weight)

	visual_target.position.y = _base_position_y + _current_offset_y
	visual_target.rotation.z = _current_roll_z
	visual_target.rotation.x = _current_lean_x
	visual_target.scale = Vector3(
		_base_scale.x * _current_scale_xz,
		_base_scale.y * _current_scale_y,
		_base_scale.z * _current_scale_xz
	)

func reset_to_rest() -> void:
	_step_phase = 0.0
	_idle_phase = 0.0
	_current_offset_y = 0.0
	_current_roll_z = 0.0
	_current_lean_x = 0.0
	_current_scale_y = 1.0
	_current_scale_xz = 1.0
	if visual_target != null:
		visual_target.position.y = _base_position_y
		visual_target.rotation.z = 0.0
		visual_target.rotation.x = 0.0
		visual_target.scale = _base_scale

