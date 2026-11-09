class_name TestPawnAppearanceData
extends "res://tests/framework/test_case.gd"

## Unit tests for PawnAppearanceData, BodyTypeDef, HeadTypeDef, and ApparelDef.

func test_body_and_head_type_def_defaults() -> void:
	var body = BodyTypeDef.new()
	assert_eq(body.id, &"fallback_pill")
	assert_null(body.torso_mesh)
	assert_eq(body.neck_mount_offset, Vector3(0.0, 0.45, 0.0))
	assert_eq(body.scale_modifier, Vector3.ONE)
	assert_false(body.is_fallback)

	var head = HeadTypeDef.new()
	assert_eq(head.id, &"default_head")
	assert_null(head.head_mesh)
	assert_eq(head.hair_mount_offset, Vector3(0.0, 0.25, 0.0))

func test_apparel_layer_and_body_type_mapping() -> void:
	var apparel = ApparelDef.new()
	apparel.id = &"jacket"
	apparel.layer = ApparelDef.Layer.MIDDLE
	
	var mock_mesh = BoxMesh.new()
	apparel.meshes_by_body_type[&"male_standard"] = mock_mesh
	
	assert_eq(apparel.get_mesh_for_body(&"male_standard"), mock_mesh)
	assert_null(apparel.get_mesh_for_body(&"female"))
	
	apparel.meshes_by_body_type[&"default"] = mock_mesh
	assert_eq(apparel.get_mesh_for_body(&"female"), mock_mesh)

func test_pawn_appearance_signal_emission_and_equip() -> void:
	var appearance = PawnAppearanceData.new()
	var signal_box = [0]
	appearance.appearance_changed.connect(func(): signal_box[0] += 1)

	var body = BodyTypeDef.new()
	body.id = &"standard"
	appearance.body_type = body
	assert_eq(signal_box[0], 1)

	# Equipping apparel
	var shirt = ApparelDef.new()
	shirt.id = &"shirt"
	shirt.layer = ApparelDef.Layer.ON_SKIN

	var vest = ApparelDef.new()
	vest.id = &"vest"
	vest.layer = ApparelDef.Layer.MIDDLE

	appearance.equip(shirt, Color.RED)
	assert_eq(signal_box[0], 2)
	assert_true(appearance.has_apparel(&"shirt"))
	assert_eq(appearance.get_apparel_color(&"shirt"), Color.RED)

	appearance.equip(vest, Color.BLUE)
	assert_eq(signal_box[0], 3)
	assert_eq(appearance.equipped_apparel.size(), 2)

	# Equipping another ON_SKIN item replaces the existing one in the same layer
	var parka_skin = ApparelDef.new()
	parka_skin.id = &"undershirt"
	parka_skin.layer = ApparelDef.Layer.ON_SKIN
	appearance.equip(parka_skin, Color.GREEN)
	assert_eq(signal_box[0], 4)
	assert_false(appearance.has_apparel(&"shirt"))
	assert_true(appearance.has_apparel(&"undershirt"))
	assert_eq(appearance.equipped_apparel.size(), 2)

	# Unequip
	appearance.unequip(&"undershirt")
	assert_eq(signal_box[0], 5)
	assert_false(appearance.has_apparel(&"undershirt"))
	assert_eq(appearance.equipped_apparel.size(), 1)

	# Reset
	appearance.reset_to_fallback()
	assert_eq(signal_box[0], 6)
	assert_null(appearance.body_type)
	assert_eq(appearance.equipped_apparel.size(), 0)
