class_name TestPlayerVisualIntegration
extends "res://tests/framework/test_case.gd"

## Integration test validating scenes/player.tscn loads with PawnVisualAssembler and fallback pill.

func test_player_scene_instantiation_and_assembler_linkage() -> void:
	var player_scene = load("res://scenes/player.tscn") as PackedScene
	assert_not_null(player_scene, "player.tscn should load successfully")

	var player = player_scene.instantiate() as PlayerMotor
	assert_not_null(player, "player instance should be a PlayerMotor")

	# Node tree verification
	assert_not_null(player.visual_assembler, "visual_assembler exported property should be bound")
	var assembler = player.get_node_or_null("PawnVisualAssembler") as PawnVisualAssembler
	assert_not_null(assembler, "PawnVisualAssembler node must exist in player.tscn")
	assert_eq(player.visual_assembler, assembler, "player.visual_assembler must reference PawnVisualAssembler child")

	var waddler = player.get_node_or_null("PawnLocomotionWaddler") as PawnLocomotionWaddler
	assert_not_null(waddler, "PawnLocomotionWaddler node must exist in player.tscn")
	assert_eq(waddler.character_body, player, "waddler character_body must be player")
	assert_eq(waddler.visual_target, assembler, "waddler visual_target must be assembler")

	# Verify fallback pill is constructed and visible
	assembler._ready()
	assert_not_null(assembler.fallback_mesh)
	assert_true(assembler.fallback_mesh.visible, "Fallback pill mesh must be visible by default")
	assert_true(assembler.fallback_mesh.mesh is CapsuleMesh, "Fallback mesh must be CapsuleMesh")

	player.free()

