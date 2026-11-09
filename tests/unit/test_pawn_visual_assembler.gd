class_name TestPawnVisualAssembler
extends "res://tests/framework/test_case.gd"

## Unit tests for PawnVisualAssembler fallback and modular assembly.

func test_assembler_initializes_with_fallback_pill() -> void:
	var assembler = PawnVisualAssembler.new()
	assembler._ready()

	assert_not_null(assembler.fallback_mesh)
	assert_true(assembler.fallback_mesh.visible)
	assert_eq(assembler.fallback_mesh.position, Vector3(0.0, 0.9, 0.0))
	assert_not_null(assembler.fallback_mesh.mesh)
	assert_true(assembler.fallback_mesh.mesh is CapsuleMesh)

	# Verify modular mounts are hidden in fallback mode
	assert_false(assembler.torso_mount.visible)
	assert_false(assembler.head_mesh.visible)
	assert_false(assembler.on_skin_mount.visible)

	assembler.free()

func test_assembler_transitions_to_modular_mesh() -> void:
	var assembler = PawnVisualAssembler.new()
	assembler._ready()

	var appearance = PawnAppearanceData.new()
	var body = BodyTypeDef.new()
	body.id = &"male_standard"
	body.torso_mesh = BoxMesh.new()
	body.neck_mount_offset = Vector3(0.0, 0.5, 0.0)

	var head = HeadTypeDef.new()
	head.id = &"average"
	head.head_mesh = SphereMesh.new()
	head.hair_mount_offset = Vector3(0.0, 0.2, 0.0)

	appearance.body_type = body
	appearance.head_type = head
	assembler.appearance_data = appearance

	# Fallback should now be deactivated
	assert_false(assembler.fallback_mesh.visible)
	assert_true(assembler.torso_mount.visible)
	assert_eq(assembler.torso_mount.mesh, body.torso_mesh)
	assert_true(assembler.head_mesh.visible)
	assert_eq(assembler.head_mesh.mesh, head.head_mesh)
	assert_eq(assembler.head_mount.position, Vector3(0.0, 0.5, 0.0))

	# Test reset reverts to fallback
	appearance.reset_to_fallback()
	assert_true(assembler.fallback_mesh.visible)
	assert_false(assembler.torso_mount.visible)
	assert_false(assembler.head_mesh.visible)

	assembler.free()

func test_assembler_apparel_mounting_and_part_culling() -> void:
	var assembler = PawnVisualAssembler.new()
	assembler._ready()

	var appearance = PawnAppearanceData.new()
	var body = BodyTypeDef.new()
	body.id = &"standard"
	body.torso_mesh = BoxMesh.new()
	appearance.body_type = body

	var jacket = ApparelDef.new()
	jacket.id = &"jacket"
	jacket.layer = ApparelDef.Layer.MIDDLE
	var jacket_mesh = BoxMesh.new()
	jacket.meshes_by_body_type[&"standard"] = jacket_mesh

	appearance.equip(jacket)
	assembler.appearance_data = appearance

	assert_true(assembler.middle_mount.visible)
	assert_eq(assembler.middle_mount.mesh, jacket_mesh)
	assert_true(assembler.torso_mount.visible)

	# Heavy armor that hides the torso
	var power_armor = ApparelDef.new()
	power_armor.id = &"power_armor"
	power_armor.layer = ApparelDef.Layer.SHELL
	var armor_mesh = BoxMesh.new()
	power_armor.meshes_by_body_type[&"standard"] = armor_mesh
	power_armor.hides_body_parts = ["Torso"]

	appearance.equip(power_armor)
	assert_true(assembler.shell_mount.visible)
	assert_eq(assembler.shell_mount.mesh, armor_mesh)
	# Torso mount must be culled/hidden!
	assert_false(assembler.torso_mount.visible)

	assembler.free()

