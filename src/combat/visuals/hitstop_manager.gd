class_name HitstopManager
extends RefCounted

## Manages impact freezes (hitstop) for high-kinetic melee combat (procedural_todo_combo_depth.md).
## Pauses the game engine (Engine.time_scale = 0.02) on high-energy impacts to deliver tactile weight.
## Safely restores original time scale using timers that ignore time scaling.

const HYPERSONIC_THRESHOLD: float = 1000000.0    # 1,000,000 J -> 0.08s hitstop
const CATACLYSM_THRESHOLD: float = 1000000000.0  # 1,000,000,000 J -> 0.12s hitstop

static var _is_hitstopping: bool = false
static var _restore_time_scale: float = 1.0
static var _active_timer: SceneTreeTimer

## Evaluates kinetic energy of a landed strike and triggers hitstop if above threshold.
## Returns the hitstop duration applied (0.0 if below threshold).
static func evaluate_kinetic_hitstop(
	tree: SceneTree,
	kinetic_energy: float,
	target_node: Node3D = null,
	impact_normal: Vector3 = Vector3.UP
) -> float:
	var duration: float = 0.0
	if kinetic_energy >= CATACLYSM_THRESHOLD:
		duration = 0.12 # 1-Billion Joule event: ~7-10 frames freeze
	elif kinetic_energy >= HYPERSONIC_THRESHOLD:
		duration = 0.08 # Hypersonic strike: ~5 frames freeze
	else:
		return 0.0

	if tree != null:
		request_hitstop(tree, duration, target_node, impact_normal)
	return duration

## Requests an impact freeze of specific duration.
static func request_hitstop(
	tree: SceneTree,
	duration: float = 0.08,
	target_node: Node3D = null,
	impact_normal: Vector3 = Vector3.UP,
	attacker_node: Node3D = null
) -> void:
	if tree == null or duration <= 0.0:
		return

	if not _is_hitstopping:
		_restore_time_scale = Engine.time_scale if Engine.time_scale > 0.05 else 1.0
		_is_hitstopping = true

	Engine.time_scale = 0.02

	# Target mesh jitter along impact normal (skip static world terrain)
	if target_node != null and is_instance_valid(target_node):
		if not (target_node is StaticBody3D):
			_apply_target_jitter(tree, target_node, impact_normal, duration)

	# Attacker mesh micro-shudder along impact normal
	if attacker_node != null and is_instance_valid(attacker_node):
		_apply_attacker_jitter(tree, attacker_node, impact_normal, duration)

	# SceneTreeTimer with ignore_time_scale = true runs in unscaled real wall-clock seconds!
	var timer = tree.create_timer(duration, true, false, true)
	_active_timer = timer
	timer.timeout.connect(func():
		# Only restore if this is still the active timer
		if _active_timer == timer:
			Engine.time_scale = _restore_time_scale
			_is_hitstopping = false
			_active_timer = null
	)

## Applies high-frequency mesh jitter along impact normal during freeze
static func _apply_target_jitter(tree: SceneTree, target: Node3D, normal: Vector3, freeze_duration: float) -> void:
	if not is_instance_valid(target):
		return

	var orig_pos = target.position
	var jitter_axis = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var jitter_mag = 0.06

	# Quick 3-pulse jitter
	var t1 = tree.create_timer(freeze_duration * 0.25, true, false, true)
	t1.timeout.connect(func():
		if is_instance_valid(target):
			target.position = orig_pos + jitter_axis * jitter_mag
	)
	var t2 = tree.create_timer(freeze_duration * 0.50, true, false, true)
	t2.timeout.connect(func():
		if is_instance_valid(target):
			target.position = orig_pos - jitter_axis * (jitter_mag * 0.7)
	)
	var t3 = tree.create_timer(freeze_duration * 0.75, true, false, true)
	t3.timeout.connect(func():
		if is_instance_valid(target):
			target.position = orig_pos + jitter_axis * (jitter_mag * 0.4)
	)
	var t_end = tree.create_timer(freeze_duration, true, false, true)
	t_end.timeout.connect(func():
		if is_instance_valid(target):
			target.position = orig_pos
	)

## Applies subtle micro-shudder to the attacker along impact normal during freeze
static func _apply_attacker_jitter(tree: SceneTree, attacker: Node3D, normal: Vector3, freeze_duration: float) -> void:
	if not is_instance_valid(attacker):
		return

	var jitter_target: Node3D = attacker
	if "visual_assembler" in attacker and attacker.get("visual_assembler") != null:
		jitter_target = attacker.get("visual_assembler") as Node3D
	elif attacker.has_node("VisualsRoot"):
		jitter_target = attacker.get_node("VisualsRoot") as Node3D

	var orig_pos = jitter_target.position
	var jitter_axis = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var jitter_mag = 0.035

	var t1 = tree.create_timer(freeze_duration * 0.25, true, false, true)
	t1.timeout.connect(func():
		if is_instance_valid(jitter_target):
			jitter_target.position = orig_pos - jitter_axis * jitter_mag
	)
	var t2 = tree.create_timer(freeze_duration * 0.50, true, false, true)
	t2.timeout.connect(func():
		if is_instance_valid(jitter_target):
			jitter_target.position = orig_pos + jitter_axis * (jitter_mag * 0.6)
	)
	var t3 = tree.create_timer(freeze_duration * 0.75, true, false, true)
	t3.timeout.connect(func():
		if is_instance_valid(jitter_target):
			jitter_target.position = orig_pos - jitter_axis * (jitter_mag * 0.3)
	)
	var t_end = tree.create_timer(freeze_duration, true, false, true)
	t_end.timeout.connect(func():
		if is_instance_valid(jitter_target):
			jitter_target.position = orig_pos
	)

## Cleans up hitstop immediately (e.g. on scene unload or death)
static func force_end_hitstop() -> void:
	if _is_hitstopping:
		Engine.time_scale = _restore_time_scale
		_is_hitstopping = false
		_active_timer = null
