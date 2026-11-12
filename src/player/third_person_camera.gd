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
@export var far_clip: float = 10000.0

var yaw_pivot: Node3D
var pitch_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

var is_aiming: bool = false
var shoulder_side: float = 1.0 # 1.0 = right, -1.0 = left
var _current_shoulder_x: float = 0.65
var _current_pitch: float = 0.0

# --- Director's Lens State ---
var _current_tip_velocity: float = 0.0
var _impact_snap_timer: float = 0.0
var _impact_snap_duration: float = 0.08
var _impact_snap_punch: float = 14.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_tilt_deg: float = 0.0

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
	camera.far = far_clip
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

	# Director's Lens: 1. Velocity Pull-back (FOV expands when tip velocity > 500 m/s)
	if not is_aiming:
		target_fov = CameraMath.compute_velocity_fov(target_fov, _current_tip_velocity, 88.0, 500.0)

	# Director's Lens: 2. Impact Snap (punch inward, then spring back)
	if _impact_snap_timer > 0.0:
		_impact_snap_timer -= delta
		target_fov = CameraMath.compute_impact_snap_fov(target_fov, _impact_snap_punch, _impact_snap_timer, _impact_snap_duration)

	# Smoothly decay blade tip velocity
	_current_tip_velocity = move_toward(_current_tip_velocity, 0.0, delta * 2500.0)

	var target_shoulder_x = shoulder_side * (shoulder_offset_x * 0.7 if is_aiming else shoulder_offset_x)

	# Smooth transitions
	spring_arm.spring_length = CameraMath.lerp_arm_length(spring_arm.spring_length, target_arm_len, delta, lerp_speed)
	camera.fov = CameraMath.lerp_fov(camera.fov, target_fov, delta, lerp_speed)
	_current_shoulder_x = CameraMath.lerp_shoulder_x(_current_shoulder_x, target_shoulder_x, delta, lerp_speed)

	# Director's Lens: 3. Directional Screen Shake along slash cutting plane
	var shake_offset = Vector2.ZERO
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var decay = clampf(_shake_timer / maxf(_shake_duration, 0.001), 0.0, 1.0)
		shake_offset = CameraMath.compute_directional_shake(_shake_tilt_deg, _shake_intensity * decay, _shake_timer)

	camera.position = Vector3(_current_shoulder_x + shake_offset.x, shoulder_offset_y + shake_offset.y, 0.0)

## Director's Lens: Informs camera of blade tip velocity for centrifugal pull-back
func apply_velocity_pullback(tip_velocity: float) -> void:
	_current_tip_velocity = maxf(_current_tip_velocity, tip_velocity)

## Director's Lens: Inward FOV punch on impact
func trigger_impact_snap(punch_degrees: float = 14.0, snap_duration: float = 0.08) -> void:
	_impact_snap_punch = punch_degrees
	_impact_snap_duration = snap_duration
	_impact_snap_timer = snap_duration

## Director's Lens: Directional camera shake along cutting plane
func trigger_directional_shake(tilt_degrees: float, intensity: float = 0.28, shake_duration: float = 0.16) -> void:
	_shake_tilt_deg = tilt_degrees
	_shake_intensity = intensity
	_shake_duration = shake_duration
	_shake_timer = shake_duration

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
