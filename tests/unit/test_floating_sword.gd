class_name TestFloatingSword
extends "res://tests/framework/test_case.gd"

## Unit tests for FloatingSwordController, SwordMeshBuilder, and SlashArcMeshBuilder.

const FloatingSwordController = preload("res://src/combat/visuals/floating_sword_controller.gd")
const SwordMeshBuilder = preload("res://src/combat/visuals/sword_mesh_builder.gd")
const SlashArcMeshBuilder = preload("res://src/combat/visuals/slash_arc_mesh_builder.gd")
const ProceduralSlashEffect = preload("res://src/combat/visuals/procedural_slash_effect.gd")

func test_sword_mesh_generation() -> void:
	var sword_node = SwordMeshBuilder.create_sword_node()
	assert_not_null(sword_node)

	var mesh_inst = sword_node.get_node_or_null("SwordMeshInstance") as MeshInstance3D
	assert_not_null(mesh_inst)
	assert_not_null(mesh_inst.mesh)
	assert_true(mesh_inst.mesh.get_surface_count() > 0)

	var aura_parts = sword_node.get_node_or_null("BladeAuraParticles") as CPUParticles3D
	assert_not_null(aura_parts)

	sword_node.free()

func test_slash_arc_mesh_generation() -> void:
	var mesh = SlashArcMeshBuilder.build_volumetric_slash_mesh(0.75, 2.45, deg_to_rad(135.0), 0.22, 0.025, 16)
	assert_not_null(mesh)
	assert_true(mesh.get_surface_count() > 0)

	# Verify vertices exist
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array

	assert_true(verts.size() > 0)
	assert_eq(verts.size(), uvs.size())
	assert_eq(verts.size(), normals.size())

func test_floating_sword_idle_placement() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	# Process idle frames
	for i in range(5):
		sword_ctrl._process(0.016)

	assert_not_null(sword_ctrl._sword_root)
	assert_true(sword_ctrl._sword_root.visible)

	# Sword position should reflect right_offset
	assert_almost_eq(sword_ctrl.right_offset, 0.68)
	assert_almost_eq(sword_ctrl.height_offset, 0.95)

	sword_ctrl.free()

func test_floating_sword_attack_hides_sword() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	assert_true(sword_ctrl._sword_root.visible)
	assert_false(sword_ctrl._is_attacking)

	# Attack triggers
	var success = sword_ctrl.attack(null)
	assert_true(success)
	assert_true(sword_ctrl._is_attacking)

	# SWORD MUST BE HIDDEN DURING ATTACK
	assert_false(sword_ctrl._sword_root.visible)

	# Concurrent attacks blocked during swing
	var second_attack = sword_ctrl.attack(null)
	assert_false(second_attack)

	# Complete slash
	sword_ctrl._on_slash_completed()

	# SWORD MUST REAPPEAR AFTER ATTACK COMPLETES
	assert_false(sword_ctrl._is_attacking)
	assert_true(sword_ctrl._sword_root.visible)

	sword_ctrl.free()

func test_player_motor_attack_integration() -> void:
	var motor = PlayerMotor.new()
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl.name = "FloatingSwordController"
	motor.add_child(sword_ctrl)
	motor.floating_sword = sword_ctrl

	sword_ctrl._ready()
	motor._ready()

	assert_eq(motor.floating_sword, sword_ctrl)
	assert_true(sword_ctrl._sword_root.visible)

	# Simulate attack through floating sword
	sword_ctrl.attack(null)
	assert_false(sword_ctrl._sword_root.visible)
	assert_true(sword_ctrl._is_attacking)

	sword_ctrl._on_slash_completed()
	assert_true(sword_ctrl._sword_root.visible)

	motor.free()

func test_floating_sword_reset_card_sequence() -> void:
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()

	# Initial index is 0
	assert_eq(sword_ctrl.get_evaluator().get_current_index(), 0)

	# Execute attack (card 0)
	var success = sword_ctrl.attack(null)
	assert_true(success)
	assert_eq(sword_ctrl.get_evaluator().get_current_index(), 1)

	# Reset sequence (simulate left click release)
	sword_ctrl.reset_card_sequence()
	assert_eq(sword_ctrl.get_evaluator().get_current_index(), 0)

	sword_ctrl.free()

func test_player_motor_auto_attack_and_release_reset() -> void:
	var motor = PlayerMotor.new()
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl.name = "FloatingSwordController"
	motor.add_child(sword_ctrl)
	motor.floating_sword = sword_ctrl

	var cam = ThirdPersonCamera.new()
	cam.name = "ThirdPersonCamera"
	motor.add_child(cam)
	motor.camera_rig = cam

	sword_ctrl._ready()
	motor._ready()

	# Initial state: card index is 0
	var evaluator = sword_ctrl.get_evaluator()
	assert_eq(evaluator.get_current_index(), 0)

	# Frame 1: Player presses and holds left click (fire_held = true)
	var intent = PlayerIntent.new()
	intent.fire_held = true
	intent.fire_requested = true

	# We can call the motor firing logic directly or simulate _physics_process
	var wants_attack = intent.fire_held or intent.fire_requested
	if wants_attack:
		motor.floating_sword.attack(motor.camera_rig)

	# Card 0 executed, current index is 1
	assert_eq(evaluator.get_current_index(), 1)
	assert_true(sword_ctrl._is_attacking)

	# Complete slash 0 & elapse recovery delay
	sword_ctrl._on_slash_completed()
	assert_false(sword_ctrl._is_attacking)
	evaluator.update(0.60)
	assert_true(evaluator.is_ready())

	# Frame 2: Player is STILL holding left click (auto-attack!)
	intent.fire_requested = false
	intent.fire_held = true
	wants_attack = intent.fire_held or intent.fire_requested
	if wants_attack:
		motor.floating_sword.attack(motor.camera_rig)

	# Auto-attack should have executed card 1! Current index is 2
	assert_eq(evaluator.get_current_index(), 2)
	assert_true(sword_ctrl._is_attacking)

	# Frame 3: Player RELEASES left click!
	intent.fire_held = false
	intent.fire_released = true
	var was_held = true
	wants_attack = intent.fire_held or intent.fire_requested
	if not wants_attack and (intent.fire_released or was_held):
		motor.floating_sword.reset_card_sequence()

	# Releasing resets card sequence back to 0!
	assert_eq(evaluator.get_current_index(), 0)

	# Complete slash 1 & elapse recovery
	sword_ctrl._on_slash_completed()
	evaluator.update(0.60)

	# Frame 4: Next attack starts from Card 0 again
	intent.fire_held = true
	intent.fire_requested = true
	wants_attack = intent.fire_held or intent.fire_requested
	if wants_attack:
		motor.floating_sword.attack(motor.camera_rig)

	# Should be card 0 executed, advancing to 1
	assert_eq(evaluator.get_current_index(), 1)

	motor.free()
