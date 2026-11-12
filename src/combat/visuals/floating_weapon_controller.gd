class_name FloatingWeaponController
extends Node3D

## Controller for the player's telekinetically floating procedurally generated weapon.
## Operates as the physical and visual execution bridge for MeleeDeckEvaluator.
## The weapon is purely a modular data container; all attack kinematics (VFX slash, execution speed,
## and attack frequency) are strictly driven by the slotted TechniqueCards.

const ProceduralWeaponEngine = preload("res://src/combat/generator/procedural_weapon_engine.gd")
const ProceduralSlashEffect = preload("res://src/combat/visuals/procedural_slash_effect.gd")
const HitImpactSpawner = preload("res://src/combat/visuals/hit_impact_spawner.gd")
const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")

signal attack_started(card_id: String)
signal attack_hit(hit_info: Dictionary)
signal attack_finished
signal weapon_equipped(weapon: MeleeWeaponDef)
signal inventory_updated()

@export var weapons: Array[MeleeWeaponDef] = []
@export var active_weapon_index: int = 0
@export var inventory_cards: Array = []

@export var weapon_def: MeleeWeaponDef:
	set(value):
		weapon_def = value
		if _evaluator != null:
			_evaluator.weapon = weapon_def
		_apply_weapon_profile()
		weapon_equipped.emit(weapon_def)

@export var right_offset: float = 0.68
@export var height_offset: float = 0.95
@export var forward_offset: float = -0.12
@export var float_bob_speed: float = 2.6
@export var float_bob_amount: float = 0.045
@export var float_tilt_amount: float = 0.05

@export var player_motor: PlayerMotor
@export var camera_rig: ThirdPersonCamera

var _evaluator: MeleeDeckEvaluator
var _weapon_root: Node3D
var _is_attacking: bool = false
var _hover_time: float = 0.0
var _smoothed_yaw: float = 0.0
var _reappear_tween: Tween
var _active_slashes: Array[ProceduralSlashEffect] = []

## Compatibility alias for code checking _sword_root
var _sword_root: Node3D:
	get:
		return _weapon_root
	set(val):
		_weapon_root = val

func _ready() -> void:
	if player_motor == null and get_parent() is PlayerMotor:
		player_motor = get_parent() as PlayerMotor
	if camera_rig == null and player_motor != null:
		camera_rig = player_motor.camera_rig

	_init_weapons_and_inventory()

	_evaluator = MeleeDeckEvaluator.new(weapon_def)
	_apply_weapon_profile()
	_create_weapon()
	if weapon_def != null:
		weapon_equipped.emit(weapon_def)
	inventory_updated.emit()

func _init_weapons_and_inventory() -> void:
	# Default procedurally generated weapons list
	if weapons.is_empty():
		var w0 = ProceduralWeaponEngine.generate_weapon(101, {
			"profile": ProceduralWeaponEngine.WeaponProfile.BALANCED,
			"name": "Balanced Weapon #101"
		})
		var w1 = ProceduralWeaponEngine.generate_weapon(202, {
			"profile": ProceduralWeaponEngine.WeaponProfile.SLENDER,
			"name": "Slender Weapon #202"
		})
		weapons.append(w0)
		weapons.append(w1)

	# Starter unslotted inventory cards
	if inventory_cards.is_empty():
		var starter_card_paths = [
			"res://assets/combat/cards/mod_heavy_impact.tres",
			"res://assets/combat/cards/mod_swift_edge.tres",
			"res://assets/combat/cards/motion_piercing_thrust.tres",
			"res://assets/combat/cards/multi_double_slash.tres",
			"res://assets/combat/cards/trigger_on_hit.tres"
		]
		for path in starter_card_paths:
			if ResourceLoader.exists(path):
				inventory_cards.append(load(path))

	# Starter slotted cards for active weapon if empty
	if not weapons.is_empty():
		var primary = weapons[0]
		if primary.slotted_techniques.is_empty():
			var default_motion_paths = [
				"res://assets/combat/cards/motion_horizontal_sweep.tres",
				"res://assets/combat/cards/motion_upswing.tres",
				"res://assets/combat/cards/motion_downcleave.tres"
			]
			for m_path in default_motion_paths:
				if ResourceLoader.exists(m_path):
					primary.slotted_techniques.append(load(m_path))

	if weapon_def == null and not weapons.is_empty():
		weapon_def = weapons[0]
		active_weapon_index = 0
	elif weapon_def != null and weapons.is_empty():
		weapons.append(weapon_def)

func equip_weapon_index(idx: int) -> bool:
	if idx < 0 or idx >= weapons.size() or weapons[idx] == null:
		return false
	if active_weapon_index == idx and weapon_def == weapons[idx]:
		return true

	active_weapon_index = idx
	weapon_def = weapons[idx]
	_apply_weapon_profile()
	_create_weapon()
	inventory_updated.emit()
	return true

func slot_inventory_card(inventory_idx: int, socket_idx: int = -1) -> bool:
	if weapon_def == null or inventory_idx < 0 or inventory_idx >= inventory_cards.size():
		return false

	var card = inventory_cards[inventory_idx]
	if card == null:
		return false

	var capacity = weapon_def.slot_capacity
	if socket_idx >= 0 and socket_idx < capacity:
		if socket_idx < weapon_def.slotted_techniques.size():
			var existing = weapon_def.slotted_techniques[socket_idx]
			weapon_def.slotted_techniques[socket_idx] = card
			inventory_cards[inventory_idx] = existing
		else:
			inventory_cards.remove_at(inventory_idx)
			while weapon_def.slotted_techniques.size() < socket_idx:
				weapon_def.slotted_techniques.append(null)
			weapon_def.slotted_techniques.append(card)
	else:
		# Auto-slot into first free slot
		if weapon_def.slotted_techniques.size() < capacity:
			inventory_cards.remove_at(inventory_idx)
			weapon_def.slotted_techniques.append(card)
		else:
			return false

	if _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func unslot_card(socket_idx: int) -> bool:
	if weapon_def == null or socket_idx < 0 or socket_idx >= weapon_def.slotted_techniques.size():
		return false

	var card = weapon_def.slotted_techniques[socket_idx]
	if card == null:
		return false

	weapon_def.slotted_techniques.remove_at(socket_idx)
	inventory_cards.append(card)

	if _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func swap_weapons(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_b < 0 or idx_a >= 4 or idx_b >= 4:
		return false
	if idx_a == idx_b:
		return true

	var max_idx = maxi(idx_a, idx_b)
	while weapons.size() <= max_idx:
		weapons.append(null)

	if weapons[idx_a] == null and weapons[idx_b] == null:
		return false

	var temp = weapons[idx_a]
	weapons[idx_a] = weapons[idx_b]
	weapons[idx_b] = temp

	if active_weapon_index == idx_a:
		active_weapon_index = idx_b
	elif active_weapon_index == idx_b:
		active_weapon_index = idx_a

	if active_weapon_index >= 0 and active_weapon_index < weapons.size() and weapons[active_weapon_index] != null:
		weapon_def = weapons[active_weapon_index]

	inventory_updated.emit()
	return true

func swap_weapon_sockets(slot_a: int, slot_b: int) -> bool:
	if weapon_def == null:
		return false
	var capacity = weapon_def.slot_capacity
	if slot_a < 0 or slot_a >= capacity or slot_b < 0 or slot_b >= capacity:
		return false

	var max_slot = maxi(slot_a, slot_b)
	while weapon_def.slotted_techniques.size() <= max_slot:
		weapon_def.slotted_techniques.append(null)

	var temp = weapon_def.slotted_techniques[slot_a]
	weapon_def.slotted_techniques[slot_a] = weapon_def.slotted_techniques[slot_b]
	weapon_def.slotted_techniques[slot_b] = temp

	if _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func swap_inventory_slots(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_b < 0:
		return false
	var max_idx = maxi(idx_a, idx_b)
	while inventory_cards.size() <= max_idx:
		inventory_cards.append(null)

	var temp = inventory_cards[idx_a]
	inventory_cards[idx_a] = inventory_cards[idx_b]
	inventory_cards[idx_b] = temp
	inventory_updated.emit()
	return true

func swap_weapon_and_inventory(weapon_idx: int, socket_idx: int, inv_idx: int) -> bool:
	if weapon_idx < 0 or weapon_idx >= weapons.size() or weapons[weapon_idx] == null:
		return false
	var target_w = weapons[weapon_idx]
	if socket_idx < 0 or socket_idx >= target_w.slot_capacity or inv_idx < 0:
		return false

	while target_w.slotted_techniques.size() <= socket_idx:
		target_w.slotted_techniques.append(null)
	while inventory_cards.size() <= inv_idx:
		inventory_cards.append(null)

	var temp = target_w.slotted_techniques[socket_idx]
	target_w.slotted_techniques[socket_idx] = inventory_cards[inv_idx]
	inventory_cards[inv_idx] = temp

	if target_w == weapon_def and _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func swap_between_weapons(weapon_a_idx: int, socket_a: int, weapon_b_idx: int, socket_b: int) -> bool:
	if weapon_a_idx < 0 or weapon_a_idx >= weapons.size() or weapons[weapon_a_idx] == null:
		return false
	if weapon_b_idx < 0 or weapon_b_idx >= weapons.size() or weapons[weapon_b_idx] == null:
		return false
	var wa = weapons[weapon_a_idx]
	var wb = weapons[weapon_b_idx]
	if socket_a < 0 or socket_a >= wa.slot_capacity or socket_b < 0 or socket_b >= wb.slot_capacity:
		return false

	while wa.slotted_techniques.size() <= socket_a:
		wa.slotted_techniques.append(null)
	while wb.slotted_techniques.size() <= socket_b:
		wb.slotted_techniques.append(null)

	var temp = wa.slotted_techniques[socket_a]
	wa.slotted_techniques[socket_a] = wb.slotted_techniques[socket_b]
	wb.slotted_techniques[socket_b] = temp

	if (wa == weapon_def or wb == weapon_def) and _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func quick_unslot_card(w_idx: int, s_idx: int) -> bool:
	if w_idx < 0 or w_idx >= weapons.size() or weapons[w_idx] == null:
		return false
	var target_w = weapons[w_idx]
	if s_idx < 0 or s_idx >= target_w.slotted_techniques.size():
		return false

	var card = target_w.slotted_techniques[s_idx]
	if card == null:
		return false

	target_w.slotted_techniques[s_idx] = null
	# Trim trailing nulls
	while target_w.slotted_techniques.size() > 0 and target_w.slotted_techniques.back() == null:
		target_w.slotted_techniques.pop_back()

	# Find first empty inventory slot
	var placed = false
	for i in range(inventory_cards.size()):
		if inventory_cards[i] == null:
			inventory_cards[i] = card
			placed = true
			break
	if not placed:
		inventory_cards.append(card)

	if target_w == weapon_def and _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func quick_slot_card(inv_idx: int) -> bool:
	if weapon_def == null or inv_idx < 0 or inv_idx >= inventory_cards.size():
		return false
	var card = inventory_cards[inv_idx]
	if card == null:
		return false

	var capacity = weapon_def.slot_capacity
	var free_socket = -1
	for s in range(capacity):
		if s >= weapon_def.slotted_techniques.size() or weapon_def.slotted_techniques[s] == null:
			free_socket = s
			break

	if free_socket < 0:
		return false

	while weapon_def.slotted_techniques.size() <= free_socket:
		weapon_def.slotted_techniques.append(null)

	weapon_def.slotted_techniques[free_socket] = card
	inventory_cards[inv_idx] = null

	if _evaluator != null:
		_evaluator.rebuild_deck()
	inventory_updated.emit()
	return true

func _apply_weapon_profile() -> void:
	if weapon_def == null:
		return

	right_offset = weapon_def.float_offset_right
	height_offset = weapon_def.float_offset_height
	forward_offset = weapon_def.float_offset_forward

	if _weapon_root != null:
		_weapon_root.position = Vector3(right_offset, height_offset, forward_offset)
		_weapon_root.rotation_degrees = weapon_def.float_tilt_degrees

func _create_weapon() -> void:
	if _weapon_root != null:
		_weapon_root.queue_free()
		_weapon_root = null

	var builder = weapon_def.mesh_builder if weapon_def != null and weapon_def.mesh_builder != null else ProceduralWeaponEngine
	if builder.has_method("create_weapon_node"):
		_weapon_root = builder.create_weapon_node(weapon_def)
	elif builder.has_method("create_sword_node"):
		_weapon_root = builder.create_sword_node()
	else:
		_weapon_root = Node3D.new()

	_weapon_root.name = "FloatingWeaponVisual"
	add_child(_weapon_root)

	_weapon_root.position = Vector3(right_offset, height_offset, forward_offset)
	if weapon_def != null:
		_weapon_root.rotation_degrees = weapon_def.float_tilt_degrees
	else:
		_weapon_root.rotation_degrees = Vector3(18.0, -12.0, 10.0)

## Compatibility alias for _create_sword
func _create_sword() -> void:
	_create_weapon()

func _process(delta: float) -> void:
	_hover_time += delta

	# Update evaluator cooldowns and recovery timers
	if _evaluator != null:
		_evaluator.update(delta)

	# When idle (not attacking), update floating physics & bobbing
	if not _is_attacking and _weapon_root != null and _weapon_root.visible and is_inside_tree():
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

	# Speed drag tilt: weapon pitches back when sprinting forward
	var speed_lean = clampf(move_speed / 10.0, 0.0, 1.0) * 0.22

	# Target local position relative to player
	var target_pos = right * (right_offset + bob_x) + Vector3(0.0, height_offset + bob_y, 0.0) + forward * forward_offset
	var rot_target = Vector3(
		deg_to_rad(18.0) + tilt_pitch + speed_lean,
		_smoothed_yaw + deg_to_rad(-12.0),
		deg_to_rad(10.0) + tilt_roll
	)

	if is_inside_tree():
		_weapon_root.global_position = global_position + target_pos
		_weapon_root.global_rotation = rot_target
	else:
		_weapon_root.position = target_pos
		_weapon_root.rotation = rot_target

## Executes an attack when left clicked.
## Evaluates slotted technique cards to compile MeleeAttackContexts.
## All execution speeds, frequencies, and VFX properties are dictated by the evaluated cards.
func attack(target_camera: ThirdPersonCamera = null) -> bool:
	if _is_attacking:
		return false

	if _evaluator != null and not _evaluator.is_ready():
		return false

	var cam = target_camera
	if cam == null:
		cam = camera_rig
	if cam == null and player_motor != null:
		cam = player_motor.camera_rig

	# Evaluate next card in weapon sockets
	var contexts: Array[MeleeAttackContext] = []
	if _evaluator != null:
		contexts = _evaluator.evaluate_attack()

	if contexts.is_empty():
		return false

	_is_attacking = true
	var primary_card_id = contexts[0].source_card_id
	attack_started.emit(primary_card_id)

	# 1. HIDE THE WEAPON DURING SWING
	if _reappear_tween != null and _reappear_tween.is_valid():
		_reappear_tween.kill()
	_weapon_root.visible = false

	# 2. GENERATE CARD-DRIVEN 3D VOLUMETRIC SLASH VFX
	_spawn_card_slashes(cam, contexts)

	return true

func _spawn_card_slashes(cam: ThirdPersonCamera, contexts: Array[MeleeAttackContext]) -> void:
	var cam_yaw = cam.get_camera_yaw() if cam != null else 0.0
	var cam_forward = -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))

	var pitch = 0.0
	if cam != null and cam.pitch_pivot != null:
		pitch = cam.pitch_pivot.rotation.x

	var base_origin = global_position if is_inside_tree() else position
	var chest_pos = base_origin + Vector3(0.0, height_offset + 0.1, 0.0) + cam_forward * 0.45

	var slash_xform = Transform3D()
	slash_xform = slash_xform.rotated(Vector3.UP, cam_yaw)
	slash_xform = slash_xform.rotated_local(Vector3.RIGHT, pitch)
	slash_xform.origin = chest_pos

	var max_duration = 0.20
	for ctx in contexts:
		if ctx.execution_duration > max_duration:
			max_duration = ctx.execution_duration

	# Apply kinematic player lunge if card specifies
	for ctx in contexts:
		if ctx.player_lunge_distance > 0.0 and player_motor != null:
			var lunge_speed = (ctx.player_lunge_distance / maxf(ctx.execution_duration, 0.1)) * 0.8
			player_motor.velocity += cam_forward * lunge_speed

	if not is_inside_tree():
		return

	var tree = get_tree()
	if tree == null or tree.root == null:
		return

	_active_slashes.clear()

	# Instantiate and play 3D volume slash VFX for each evaluated motion
	for ctx in contexts:
		var slash = ProceduralSlashEffect.new()
		tree.root.add_child(slash)
		slash.play_context(slash_xform, ctx)
		_active_slashes.append(slash)

		# Perform 3D volume hit detection
		var exclude_rid: RID = player_motor.get_rid() if player_motor != null else RID()
		var hit = slash.check_hit_volume(get_world_3d(), [exclude_rid])

		if hit.get("hit", false):
			var hit_pos = hit.get("target_point", chest_pos + cam_forward * ctx.outer_radius)
			var hit_norm = hit.get("normal", Vector3.UP)
			HitImpactSpawner.spawn_hit_sparks(tree.root, hit_pos, hit_norm)

			if player_motor != null:
				player_motor.fired.emit(hit)
			attack_hit.emit(hit)

			# Resolve On-Hit triggers if attached to the card
			_resolve_hit_triggers(ctx, hit)
		else:
			if player_motor != null and cam != null:
				var aim_hit = cam.get_aim_raycast(ctx.outer_radius)
				if aim_hit.get("hit", false):
					player_motor.fired.emit(aim_hit)

	# Timing for restoring the weapon governed by card execution_duration
	var finish_timer = tree.create_timer(max_duration)
	finish_timer.timeout.connect(_on_slash_completed)

func _resolve_hit_triggers(ctx: MeleeAttackContext, hit: Dictionary) -> void:
	for trig in ctx.nested_triggers:
		if trig.trigger_type == 0: # ON_HIT
			for payload in trig.payload_cards:
				if payload is MotionCard:
					var sub_ctx = MeleeAttackContext.new()
					payload.apply_to_context(sub_ctx)
					sub_ctx.outer_radius *= 0.85
					sub_ctx.execution_duration = 0.16

					var hit_pos = hit.get("target_point", global_position)
					var sub_xform = Transform3D().rotated(Vector3.UP, _smoothed_yaw)
					sub_xform.origin = hit_pos

					var sub_slash = ProceduralSlashEffect.new()
					get_tree().root.add_child(sub_slash)
					sub_slash.play_context(sub_xform, sub_ctx)

func _on_slash_completed() -> void:
	_is_attacking = false
	attack_finished.emit()

	# 3. RESTORE / UNHIDE THE WEAPON WITH DYNAMIC REAPPEAR
	if _weapon_root != null:
		_weapon_root.visible = true
		_weapon_root.scale = Vector3(0.2, 0.2, 0.2)

		_reappear_tween = create_tween()
		_reappear_tween.tween_property(_weapon_root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_evaluator() -> MeleeDeckEvaluator:
	return _evaluator

## Resets the technique card evaluation pointer back to the first card in the slotted sequence.
func reset_card_sequence() -> void:
	if _evaluator != null:
		_evaluator.reset_sequence()

## Debug method (F7): Generates 4 new stylized weapons and populates the player's weapon slots.
func generate_debug_weapons() -> Array[MeleeWeaponDef]:
	var new_weapons: Array[MeleeWeaponDef] = []
	var stylized_topos = [
		ProceduralWeaponEngine.TopologyType.VOLUMETRIC_EROSION,
		ProceduralWeaponEngine.TopologyType.PARAMETRIC_HELIX,
		ProceduralWeaponEngine.TopologyType.BRANCHING_FRACTAL,
		ProceduralWeaponEngine.TopologyType.NOISE_SHATTERED,
		ProceduralWeaponEngine.TopologyType.KALEIDOSCOPIC,
		ProceduralWeaponEngine.TopologyType.FUNGAL_BRACKET,
		ProceduralWeaponEngine.TopologyType.OSTEOLOGICAL_CAGE,
		ProceduralWeaponEngine.TopologyType.INSECTOID_HIVE,
		ProceduralWeaponEngine.TopologyType.ABYSSAL_MARINE,
		ProceduralWeaponEngine.TopologyType.CARNIVOROUS_BOTANICAL
	]
	stylized_topos.shuffle()

	for i in range(4):
		var topo = stylized_topos[i % stylized_topos.size()]
		var seed_val = int(Time.get_ticks_usec()) + i * 1337 + (randi() % 9999)
		var w = ProceduralWeaponEngine.generate_weapon(seed_val, {
			"topology": topo
		})
		# Populate starter slotted technique cards on primary weapon if needed
		if i == 0:
			var default_motion_paths = [
				"res://assets/combat/cards/motion_horizontal_sweep.tres",
				"res://assets/combat/cards/motion_upswing.tres",
				"res://assets/combat/cards/motion_downcleave.tres"
			]
			for m_path in default_motion_paths:
				if ResourceLoader.exists(m_path):
					w.slotted_techniques.append(load(m_path))
		new_weapons.append(w)

	weapons = new_weapons
	active_weapon_index = 0
	weapon_def = weapons[0]
	_apply_weapon_profile()
	_create_weapon()
	weapon_equipped.emit(weapon_def)
	inventory_updated.emit()
	return new_weapons

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F7 or event.keycode == KEY_F7 or event.is_action_pressed("debug_generate_weapons"):
			generate_debug_weapons()

