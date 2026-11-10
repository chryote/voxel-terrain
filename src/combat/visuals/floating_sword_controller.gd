class_name FloatingSwordController
extends Node3D

## Controller for the player's telekinetically floating sword.
## Manages idle levitation on the character's right side, attack animations,
## hiding the sword during swings, and generating 3D volumetric slash VFX.

const SwordMeshBuilder = preload("res://src/combat/visuals/sword_mesh_builder.gd")
const ProceduralSlashEffect = preload("res://src/combat/visuals/procedural_slash_effect.gd")
const HitImpactSpawner = preload("res://src/combat/visuals/hit_impact_spawner.gd")

signal attack_started(combo_index: int)
signal attack_hit(hit_info: Dictionary)
signal attack_finished

@export var right_offset: float = 0.68
@export var height_offset: float = 0.95
@export var forward_offset: float = -0.12
@export var float_bob_speed: float = 2.6
@export var float_bob_amount: float = 0.045
@export var float_tilt_amount: float = 0.05
@export var attack_duration: float = 0.26
@export var combo_reset_delay: float = 0.85

@export var player_motor: PlayerMotor
@export var camera_rig: ThirdPersonCamera

var _sword_root: Node3D
var _is_attacking: bool = false
var _combo_step: int = 0
var _combo_timer: float = 0.0
var _hover_time: float = 0.0
var _smoothed_yaw: float = 0.0
var _reappear_tween: Tween

func _ready() -> void:
	if player_motor == null and get_parent() is PlayerMotor:
		player_motor = get_parent() as PlayerMotor
	if camera_rig == null and player_motor != null:
		camera_rig = player_motor.camera_rig

	_create_sword()

func _create_sword() -> void:
	if _sword_root != null:
		return

	_sword_root = SwordMeshBuilder.create_sword_node()
	_sword_root.name = "FloatingSwordVisual"
	add_child(_sword_root)

	# Initial rest transform: tilted forward/inward ready to guard
	_sword_root.position = Vector3(right_offset, height_offset, forward_offset)
	_sword_root.rotation_degrees = Vector3(18.0, -12.0, 10.0)

func _process(delta: float) -> void:
	_hover_time += delta

	# Combo step timeout
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_step = 0

	# When idle (not attacking), update floating physics & bobbing
	if not _is_attacking and _sword_root != null and _sword_root.visible:
		_update_floating_idle(delta)

func _update_floating_idle(delta: float) -> void:
	var cam_yaw = 0.0
	if camera_rig != null:
		cam_yaw = camera_rig.get_camera_yaw()
	elif player_motor != null and player_motor.camera_rig != null:
		cam_yaw = player_motor.camera_rig.get_camera_yaw()

	# Smoothly follow camera yaw with slight lagging inertia
	_smoothed_yaw = lerp_angle(_smoothed_yaw, cam_yaw, delta * 12.0)

	# Calculate right and forward vectors in world space
	var forward = -Vector3(sin(_smoothed_yaw), 0.0, cos(_smoothed_yaw))
	var right = Vector3(cos(_smoothed_yaw), 0.0, -sin(_smoothed_yaw))

	# Player movement speed for inertia lean
	var move_speed: float = 0.0
	if player_motor != null:
		move_speed = Vector2(player_motor.velocity.x, player_motor.velocity.z).length()

	# Floating bobbing curves
	var bob_y = sin(_hover_time * float_bob_speed) * float_bob_amount
	var bob_x = cos(_hover_time * float_bob_speed * 0.5) * (float_bob_amount * 0.4)
	var tilt_pitch = sin(_hover_time * 1.8) * float_tilt_amount
	var tilt_roll = cos(_hover_time * 2.1) * float_tilt_amount

	# Speed drag tilt: sword pitches back when sprinting forward
	var speed_lean = clampf(move_speed / 10.0, 0.0, 1.0) * 0.22

	# Target local position relative to player
	var target_pos = right * (right_offset + bob_x) + Vector3(0.0, height_offset + bob_y, 0.0) + forward * forward_offset
	var rot_target = Vector3(
		deg_to_rad(18.0) + tilt_pitch + speed_lean,
		_smoothed_yaw + deg_to_rad(-12.0),
		deg_to_rad(10.0) + tilt_roll
	)

	if is_inside_tree():
		_sword_root.global_position = global_position + target_pos
		_sword_root.global_rotation = rot_target
	else:
		_sword_root.position = target_pos
		_sword_root.rotation = rot_target

## Executes an attack when left clicked
func attack(target_camera: ThirdPersonCamera = null) -> bool:
	if _is_attacking:
		return false

	var cam = target_camera
	if cam == null:
		cam = camera_rig
	if cam == null and player_motor != null:
		cam = player_motor.camera_rig

	_is_attacking = true
	_combo_timer = combo_reset_delay
	var current_combo = _combo_step
	_combo_step = (_combo_step + 1) % 3
	attack_started.emit(current_combo)

	# 1. HIDE THE SWORD
	if _reappear_tween != null and _reappear_tween.is_valid():
		_reappear_tween.kill()
	_sword_root.visible = false

	# 2. GENERATE 3D VOLUME OF VFX SLASH
	_spawn_slash_vfx(cam, current_combo)

	return true

func _spawn_slash_vfx(cam: ThirdPersonCamera, combo: int) -> void:
	var cam_yaw = cam.get_camera_yaw() if cam != null else 0.0
	var cam_forward = -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))

	# Pitch tilt from camera pitch if available
	var pitch = 0.0
	if cam != null and cam.pitch_pivot != null:
		pitch = cam.pitch_pivot.rotation.x

	# Combo swing properties
	var tilt_deg = -8.0
	var is_reversed = false
	var reach = 2.45

	match combo:
		0:
			# Combo 0: Horizontal right-to-left cleave
			tilt_deg = -10.0
			is_reversed = false
		1:
			# Combo 1: Diagonal upswing left-to-right
			tilt_deg = 32.0
			is_reversed = true
		2:
			# Combo 2: Heavy diagonal overhead cleave
			tilt_deg = -42.0
			is_reversed = false
			reach = 2.75

	# Slash position: In front of the character at chest height
	var base_origin = global_position if is_inside_tree() else position
	var chest_pos = base_origin + Vector3(0.0, height_offset + 0.1, 0.0) + cam_forward * 0.45

	# Construct transform oriented towards aim direction
	var slash_xform = Transform3D()
	slash_xform = slash_xform.rotated(Vector3.UP, cam_yaw)
	slash_xform = slash_xform.rotated_local(Vector3.RIGHT, pitch)
	slash_xform.origin = chest_pos

	if not is_inside_tree():
		return

	var tree = get_tree()
	if tree == null or tree.root == null:
		return

	# Instantiate procedural slash effect
	var slash = ProceduralSlashEffect.new()
	slash.outer_radius = reach
	tree.root.add_child(slash)
	slash.play(slash_xform, attack_duration, tilt_deg, is_reversed)

	# Perform 3D volume hit detection
	var exclude_rid: RID = player_motor.get_rid() if player_motor != null else RID()
	var hit = slash.check_hit_volume(get_world_3d(), [exclude_rid])

	if hit.get("hit", false):
		# Spawn impact sparks at hit point
		var hit_pos = hit.get("target_point", chest_pos + cam_forward * reach)
		var hit_norm = hit.get("normal", Vector3.UP)
		HitImpactSpawner.spawn_hit_sparks(get_tree().root, hit_pos, hit_norm)

		# Forward to player motor / HUD hitmarker
		if player_motor != null:
			player_motor.fired.emit(hit)
		attack_hit.emit(hit)
	else:
		# If no solid wall hit, still emit raycast for HUD feedback if needed
		if player_motor != null and cam != null:
			var aim_hit = cam.get_aim_raycast(reach)
			if aim_hit.get("hit", false):
				player_motor.fired.emit(aim_hit)

	# Connect slash finish callback to restore the sword
	slash.slash_finished.connect(_on_slash_completed)

func _on_slash_completed() -> void:
	_is_attacking = false
	attack_finished.emit()

	# 3. RESTORE / UNHIDE THE SWORD WITH DYNAMIC REAPPEAR
	if _sword_root != null:
		_sword_root.visible = true
		_sword_root.scale = Vector3(0.2, 0.2, 0.2)

		_reappear_tween = create_tween()
		_reappear_tween.tween_property(_sword_root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
