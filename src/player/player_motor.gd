class_name PlayerMotor
extends CharacterBody3D

## Character controller with camera-relative movement, sprinting, jumping, and step-assist.

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.5
@export var aim_speed: float = 4.2
@export var jump_velocity: float = 8.5
@export var gravity: float = 24.0
@export var step_height: float = 1.15

@export var player_input: PlayerInput
@export var camera_rig: ThirdPersonCamera

signal fired(raycast_hit: Dictionary)

func _ready() -> void:
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(46.0)

func _physics_process(delta: float) -> void:
	if player_input == null or camera_rig == null:
		return

	var intent = player_input.get_intent()
	camera_rig.apply_intent(intent, delta)

	# Firing / shooting query
	if intent.fire_requested:
		var hit = camera_rig.get_aim_raycast(300.0)
		fired.emit(hit)

	# Locomotion direction relative to camera yaw
	var cam_yaw = camera_rig.get_camera_yaw()
	var forward = -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var right = Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var move_dir = (forward * -intent.move_vector.y + right * intent.move_vector.x)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()

	# Speed determination
	var target_speed = walk_speed
	if camera_rig.is_aiming:
		target_speed = aim_speed
	elif intent.sprint_requested:
		target_speed = sprint_speed

	# Horizontal velocity
	velocity.x = move_dir.x * target_speed
	velocity.z = move_dir.z * target_speed

	# Gravity & Jump with proper floor grounding
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if intent.jump_requested:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta
		velocity.y = maxf(velocity.y, -35.0)

	# Step-up assist for 1-block voxel steps
	if is_on_floor() and move_dir.length_squared() > 0.01 and is_on_wall():
		_try_step_up(move_dir)

	move_and_slide()

func _try_step_up(move_dir: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	var foot_pos = global_position
	var check_pos = foot_pos + move_dir.normalized() * 0.6 + Vector3(0.0, step_height, 0.0)

	var ray_params = PhysicsRayQueryParameters3D.create(check_pos, check_pos - Vector3(0.0, step_height, 0.0))
	ray_params.exclude = [get_rid()]
	var hit = space_state.intersect_ray(ray_params)
	if not hit.is_empty():
		var ledge_y = hit.position.y
		if ledge_y > foot_pos.y and (ledge_y - foot_pos.y) <= step_height:
			global_position.y = ledge_y + 0.05
			velocity.y = 0.0
