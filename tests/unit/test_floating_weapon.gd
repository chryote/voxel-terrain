class_name TestFloatingWeapon
extends "res://tests/framework/test_case.gd"

## Unit tests for FloatingWeaponController, procedural weapon initialization,
## and PlayerMotor combat integration.

const FloatingWeaponController = preload("res://src/combat/visuals/floating_weapon_controller.gd")
const FloatingSwordController = preload("res://src/combat/visuals/floating_sword_controller.gd")
const SlashArcMeshBuilder = preload("res://src/combat/visuals/slash_arc_mesh_builder.gd")
const ProceduralWeaponEngine = preload("res://src/combat/generator/procedural_weapon_engine.gd")
const PlayerMotor = preload("res://src/player/player_motor.gd")
const ThirdPersonCamera = preload("res://src/player/third_person_camera.gd")
const PlayerIntent = preload("res://src/player/player_intent.gd")

func test_procedural_weapon_default_initialization() -> void:
	var ctrl = FloatingWeaponController.new()
	ctrl._ready()

	# Defaults must be procedurally generated weapons (not hardcoded swords)
	assert_true(ctrl.weapons.size() >= 2)
	assert_not_null(ctrl.weapon_def)

	var w0 = ctrl.weapons[0]
	assert_true(w0.display_name.to_lower().contains("weapon"))
	assert_false(w0.display_name.to_lower().contains("sword"))
	assert_not_null(w0.icon)
	assert_not_null(w0.procedural_data)
	assert_eq(w0.mesh_builder, ProceduralWeaponEngine)

	# Active weapon has starter slotted techniques for immediate action
	assert_true(w0.slotted_techniques.size() > 0)

	ctrl.free()

func test_floating_weapon_idle_placement() -> void:
	var ctrl = FloatingWeaponController.new()
	ctrl._ready()

	for i in range(5):
		ctrl._process(0.016)

	assert_not_null(ctrl._weapon_root)
	assert_true(ctrl._weapon_root.visible)
	assert_almost_eq(ctrl.right_offset, 0.68)
	assert_almost_eq(ctrl.height_offset, 0.95)

	# Verify compatibility alias _sword_root
	assert_eq(ctrl._sword_root, ctrl._weapon_root)

	ctrl.free()

func test_floating_weapon_attack_hides_and_reappears() -> void:
	var ctrl = FloatingWeaponController.new()
	ctrl._ready()

	assert_true(ctrl._weapon_root.visible)
	assert_false(ctrl._is_attacking)

	# Attack triggers
	var success = ctrl.attack(null)
	assert_true(success)
	assert_true(ctrl._is_attacking)

	# WEAPON MUST BE HIDDEN DURING SWING
	assert_false(ctrl._weapon_root.visible)

	# Complete slash
	ctrl._on_slash_completed()

	# WEAPON MUST REAPPEAR AFTER ATTACK COMPLETES
	assert_false(ctrl._is_attacking)
	assert_true(ctrl._weapon_root.visible)

	ctrl.free()

func test_player_motor_weapon_integration() -> void:
	var motor = PlayerMotor.new()
	var ctrl = FloatingWeaponController.new()
	ctrl.name = "FloatingWeaponController"
	motor.add_child(ctrl)
	motor.floating_weapon = ctrl

	ctrl._ready()
	motor._ready()

	assert_eq(motor.floating_weapon, ctrl)
	# Verify compatibility alias
	assert_eq(motor.floating_sword, ctrl)
	assert_true(ctrl._weapon_root.visible)

	# Attack through motor
	ctrl.attack(null)
	assert_false(ctrl._weapon_root.visible)

	motor.free()

func test_floating_weapon_reset_card_sequence() -> void:
	var ctrl = FloatingWeaponController.new()
	ctrl._ready()

	assert_eq(ctrl.get_evaluator().get_current_index(), 0)

	var success = ctrl.attack(null)
	assert_true(success)
	assert_eq(ctrl.get_evaluator().get_current_index(), 1)

	ctrl.reset_card_sequence()
	assert_eq(ctrl.get_evaluator().get_current_index(), 0)

	ctrl.free()

func test_player_motor_auto_attack_and_release_reset() -> void:
	var motor = PlayerMotor.new()
	var ctrl = FloatingWeaponController.new()
	ctrl.name = "FloatingWeaponController"
	motor.add_child(ctrl)
	motor.floating_weapon = ctrl

	var cam = ThirdPersonCamera.new()
	cam.name = "ThirdPersonCamera"
	motor.add_child(cam)
	motor.camera_rig = cam

	ctrl._ready()
	motor._ready()

	var evaluator = ctrl.get_evaluator()
	assert_eq(evaluator.get_current_index(), 0)

	# Frame 1: Press & hold fire
	var intent = PlayerIntent.new()
	intent.fire_held = true
	intent.fire_requested = true

	motor.floating_weapon.attack(motor.camera_rig)
	assert_eq(evaluator.get_current_index(), 1)
	assert_true(ctrl._is_attacking)

	# Complete slash & advance recovery
	ctrl._on_slash_completed()
	assert_false(ctrl._is_attacking)
	evaluator.update(0.60)
	assert_true(evaluator.is_ready())

	# Frame 2: Still holding fire (auto-attack next technique)
	intent.fire_requested = false
	intent.fire_held = true
	motor.floating_weapon.attack(motor.camera_rig)
	assert_eq(evaluator.get_current_index(), 2)

	# Frame 3: Release fire
	intent.fire_held = false
	intent.fire_released = true
	motor.floating_weapon.reset_card_sequence()
	assert_eq(evaluator.get_current_index(), 0)

	motor.free()

func test_compatibility_layer() -> void:
	var legacy_ctrl = FloatingSwordController.new()
	assert_true(legacy_ctrl is FloatingWeaponController)
	legacy_ctrl._ready()

	assert_not_null(legacy_ctrl._weapon_root)
	assert_eq(legacy_ctrl._sword_root, legacy_ctrl._weapon_root)
	legacy_ctrl.free()

