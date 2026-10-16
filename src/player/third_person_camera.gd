class_name ThirdPersonCamera
extends Node3D

## Third-person shooter camera rig with shoulder swapping, aim zoom, and raycasting.

@export var normal_arm_length: float = 3.2
@export var aim_arm_length: float = 1.8
@export var normal_fov: float = 75.0
@export var aim_fov: float = 50.0
@export var shoulder_offset_x: float = 0.65
@export var shoulder_offset_y: float = 0.4
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = 75.0
@export var lerp_speed: float = 10.0

var yaw_pivot: Node3D
var pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

var is_aiming: bool = false
var shoulder_side: float = 1.0 # 1.0 = right, -1.0 = left
var _current_shoulder_x: float = 0.65
var _current_pitch: float = 0.0

func _ready() -> void:
	_setup_hierarchy()

func _setup_hierarchy() -> void:
	yaw_pivot = Node3D.new()
	yaw_pivot.name = "YawPivot"
	add_child(yaw_pivot)

	pitch_pivot = Node3D.new()
	pitch_pivot.name = "PitchPivot"
	yaw_pivot.add_child(pitch_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = normal_arm_length
	spring_arm.margin = 0.2
	pitch_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = normal_fov
	camera.position = Vector3(shoulder_offset_x, shoulder_offset_y, 0.0)
	spring_arm.add_child(camera)

func apply_intent(intent: PlayerIntent, delta: float) -> void:
	if yaw_pivot == null or pitch_pivot == null:
		return

	# Look rotation
	yaw_pivot.rotate_y(-intent.look_delta.x)

	_current_pitch -= intent.look_delta.y
	_current_pitch = CameraMath.clamp_pitch(_current_pitch, min_pitch_deg, max_pitch_deg)
	pitch_pivot.rotation.x = _current_pitch

	# Shoulder swap
	if intent.swap_shoulder_requested:
		shoulder_side = -shoulder_side

	# Aim mode toggle / hold
	is_aiming = intent.aim_requested

	# Target attributes
	var target_arm_len = aim_arm_length if is_aiming else normal_arm_length
	var target_fov = aim_fov if is_aiming else normal_fov
	var target_shoulder_x = shoulder_side * (shoulder_offset_x * 0.7 if is_aiming else shoulder_offset_x)

	# Smooth transitions
	spring_arm.spring_length = CameraMath.lerp_arm_length(spring_arm.spring_length, target_arm_len, delta, lerp_speed)
	camera.fov = CameraMath.lerp_fov(camera.fov, target_fov, delta, lerp_speed)
	_current_shoulder_x = CameraMath.lerp_shoulder_x(_current_shoulder_x, target_shoulder_x, delta, lerp_speed)
	camera.position = Vector3(_current_shoulder_x, shoulder_offset_y, 0.0)

func get_camera_yaw() -> float:
	return yaw_pivot.global_rotation.y if yaw_pivot != null else 0.0

func get_aim_raycast(max_distance: float = 300.0) -> Dictionary:
	if camera == null or not is_inside_tree():
		return {"hit": false}

	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * max_distance

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return {
			"hit": false,
			"target_point": to
		}

	hit["hit"] = true
	hit["target_point"] = hit.position
	return hit
