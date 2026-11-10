class_name TestProceduralWeaponEngine
extends "res://tests/framework/test_case.gd"

## Unit tests for ProceduralWeaponEngine.
## Validates voxel generation, 1-block height bounding, 2D UI/HUD icons,
## generic "weapon" terminology, mesh culling, and deck/controller integration.

const ProceduralWeaponEngine = preload("res://src/combat/generator/procedural_weapon_engine.gd")
const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const FloatingSwordController = preload("res://src/combat/visuals/floating_sword_controller.gd")
const WeaponDeckUI = preload("res://src/combat/ui/weapon_deck_ui.gd")
const WeaponIconFactory = preload("res://src/combat/ui/weapon_icon_factory.gd")

func test_procedural_weapon_generation_basic() -> void:
	var seed_val = 1337
	var weapon = ProceduralWeaponEngine.generate_weapon(seed_val)
	assert_not_null(weapon)
	assert_true(weapon is MeleeWeaponDef)
	assert_eq(weapon.weapon_id, "proc_weapon_1337")

	# STRICT TERMINOLOGY CHECK: Generic "weapon", NOT sword, NOT axe, NOT spear, NOT blade
	var lower_name = weapon.display_name.to_lower()
	assert_true(lower_name.contains("weapon"), "Display name must contain 'weapon': %s" % weapon.display_name)
	assert_false(lower_name.contains("sword"), "Display name must not contain 'sword'")
	assert_false(lower_name.contains("axe"), "Display name must not contain 'axe'")
	assert_false(lower_name.contains("spear"), "Display name must not contain 'spear'")
	assert_false(lower_name.contains("blade"), "Display name must not contain 'blade'")

	var lower_desc = weapon.description.to_lower()
	assert_true(lower_desc.contains("weapon"), "Description must contain 'weapon': %s" % weapon.description)
	assert_false(lower_desc.contains("sword"), "Description must not contain 'sword'")
	assert_false(lower_desc.contains("axe"), "Description must not contain 'axe'")

	# Deck sockets & stats
	assert_true(weapon.slot_capacity >= 4 and weapon.slot_capacity <= 10)
	assert_true(weapon.deck_recharge_time > 0.1 and weapon.deck_recharge_time < 2.0)
	assert_true(weapon.base_damage_multiplier > 0.5 and weapon.base_damage_multiplier < 2.0)
	assert_true(weapon.stamina_cost_multiplier > 0.5 and weapon.stamina_cost_multiplier < 2.0)

	# Procedural data & builder
	assert_true(weapon.procedural_data is Dictionary)
	assert_not_null(weapon.icon)
	assert_true(weapon.icon is Texture2D)
	assert_eq(weapon.mesh_builder, ProceduralWeaponEngine)

func test_1_block_height_voxel_bounds() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(42)
	var data = weapon.procedural_data
	assert_not_null(data)

	var h = data["height"] as int
	var w = data["width"] as int
	var d = data["depth"] as int
	var voxel_size = ProceduralWeaponEngine.DEFAULT_VOXEL_SIZE

	# Height verification: Target is ~1 world block height (0.9m to 1.25m)
	var physical_height = float(h) * voxel_size
	assert_almost_eq(physical_height, 1.08, 0.05)
	assert_true(physical_height >= 0.95 and physical_height <= 1.25, "Physical height must be approximately 1 world block (~1.0m)")

	# Elongated aspect ratio verification (imitating weapon or tool)
	var physical_width = float(w) * voxel_size
	var physical_depth = float(d) * voxel_size
	var aspect_ratio = physical_height / physical_width
	assert_true(aspect_ratio >= 3.0, "Weapon must be elongated along primary axis (aspect ratio >= 3.0)")
	assert_true(physical_depth <= 0.20, "Weapon depth must be slim / micro-voxel thickness")

	# Check presence of structural voxel layers
	var grid_3d = data["grid_3d"] as Array
	var has_handle = false
	var has_junction = false
	var has_body = false
	var has_edge = false

	for x in range(w):
		for y in range(h):
			for z in range(d):
				var v = grid_3d[x][y][z]
				if v == ProceduralWeaponEngine.VoxelType.HANDLE:
					has_handle = true
				elif v == ProceduralWeaponEngine.VoxelType.JUNCTION:
					has_junction = true
				elif v == ProceduralWeaponEngine.VoxelType.BODY:
					has_body = true
				elif v == ProceduralWeaponEngine.VoxelType.EDGE:
					has_edge = true

	assert_true(has_handle, "Must contain handle voxels")
	assert_true(has_junction, "Must contain junction voxels")
	assert_true(has_body, "Must contain body voxels")
	assert_true(has_edge, "Must contain edge voxels")

func test_procedural_profiles() -> void:
	var profiles = [
		ProceduralWeaponEngine.WeaponProfile.BALANCED,
		ProceduralWeaponEngine.WeaponProfile.SLENDER,
		ProceduralWeaponEngine.WeaponProfile.HEAVY,
		ProceduralWeaponEngine.WeaponProfile.SEGMENTED,
		ProceduralWeaponEngine.WeaponProfile.FLANGED
	]

	var weapons: Array[MeleeWeaponDef] = []
	for p in profiles:
		var w = ProceduralWeaponEngine.generate_weapon(100 + int(p), {"profile": p})
		assert_not_null(w)
		weapons.append(w)

	var slender = weapons[ProceduralWeaponEngine.WeaponProfile.SLENDER]
	var heavy = weapons[ProceduralWeaponEngine.WeaponProfile.HEAVY]

	# HEAVY weapon should hit harder and take longer to recharge than SLENDER
	assert_true(heavy.base_damage_multiplier > slender.base_damage_multiplier, "Heavy weapon must deal more damage multiplier")
	assert_true(heavy.deck_recharge_time > slender.deck_recharge_time, "Heavy weapon must have longer deck recharge")
	assert_true(slender.stamina_cost_multiplier < heavy.stamina_cost_multiplier, "Slender weapon must be more stamina efficient")

func test_voxel_face_culling_and_mesh_generation() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(777)
	var mesh = ProceduralWeaponEngine.build_weapon_mesh(weapon.procedural_data)
	assert_not_null(mesh)
	assert_true(mesh.get_surface_count() >= 1)

	# Verify vertex arrays on Surface 0
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var colors = arrays[Mesh.ARRAY_COLOR] as PackedColorArray

	assert_true(verts.size() > 0)
	assert_eq(verts.size(), normals.size())
	assert_eq(verts.size(), colors.size())

	# Ensure internal face culling: solid voxels don't blow up triangle budget
	# A 24-height voxel weapon with culling should easily stay under 1500 triangles
	var triangle_count = verts.size() / 3
	assert_true(triangle_count > 20 and triangle_count < 1500, "Mesh should be well-optimized via face culling")

func test_2d_icon_for_ui_and_hud() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(999, {"icon_size": Vector2i(28, 28)})
	var icon = weapon.icon
	assert_not_null(icon)
	assert_eq(icon.get_width(), 28)
	assert_eq(icon.get_height(), 28)

	var img = icon.get_image()
	assert_not_null(img)

	# Verify non-empty weapon pixels exist on transparent background
	var solid_pixel_count = 0
	var transparent_pixel_count = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var px = img.get_pixel(x, y)
			if px.a > 0.05:
				solid_pixel_count += 1
			else:
				transparent_pixel_count += 1

	assert_true(solid_pixel_count >= 15, "Icon must have visible pixel-art weapon silhouette")
	assert_true(transparent_pixel_count >= 50, "Icon background must be transparent for HUD slots")

	# Test vertical mode as well
	var vert_icon = ProceduralWeaponEngine.generate_weapon_icon(weapon.procedural_data, Vector2i(28, 28), false)
	assert_not_null(vert_icon)
	assert_eq(vert_icon.get_width(), 28)

func test_node_and_controller_integration() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(555)

	# Build 3D visual root node
	var root = ProceduralWeaponEngine.create_weapon_node(weapon)
	assert_not_null(root)
	assert_eq(root.name, "WeaponVisualRoot")

	var mesh_inst = root.get_node_or_null("WeaponMeshInstance") as MeshInstance3D
	assert_not_null(mesh_inst)
	assert_not_null(mesh_inst.mesh)

	var aura_parts = root.get_node_or_null("WeaponAuraParticles") as CPUParticles3D
	assert_not_null(aura_parts)

	root.free()

	# Test compatibility alias
	var sword_node = ProceduralWeaponEngine.create_sword_node()
	assert_not_null(sword_node)
	sword_node.free()

	# Equip into FloatingSwordController
	var sword_ctrl = FloatingSwordController.new()
	sword_ctrl._ready()
	sword_ctrl.weapon_def = weapon

	assert_not_null(sword_ctrl._sword_root)
	assert_true(sword_ctrl._sword_root.visible)

	# Execute attack with technique cards
	var success = sword_ctrl.attack(null)
	assert_true(success)
	assert_false(sword_ctrl._sword_root.visible, "Weapon visual hides during attack slash")

	sword_ctrl._on_slash_completed()
	assert_true(sword_ctrl._sword_root.visible, "Weapon visual reappears after attack completes")

	sword_ctrl.free()

func test_weapon_deck_ui_integration() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(888)
	assert_not_null(weapon.icon)

	# Verify WeaponIconFactory registration
	var factory_icon = WeaponIconFactory.get_weapon_icon(weapon.weapon_id)
	assert_not_null(factory_icon)
	assert_eq(factory_icon, weapon.icon)

	# Check UI loading
	var ui = WeaponDeckUI.new()
	var sword_ctrl = FloatingSwordController.new()
	var w_list: Array[MeleeWeaponDef] = [weapon]
	sword_ctrl.weapons = w_list
	sword_ctrl.weapon_def = weapon
	ui.floating_sword = sword_ctrl

	ui._ready()
	ui._on_inventory_data_changed()

	# Verify quickbar icon matches procedural weapon icon
	assert_true(ui._hud_weapon_boxes.size() > 0)
	var icon_rect = ui._hud_weapon_boxes[0].get_node_or_null("CenterContainer/IconRect") as TextureRect
	assert_not_null(icon_rect)
	assert_eq(icon_rect.texture, weapon.icon)

	ui.free()
	sword_ctrl.free()

func test_attack_pattern_dictated_by_technique_cards() -> void:
	# The weapon itself contains NO hardcoded animations or attack patterns;
	# it is purely a technique frame. TechniqueCards dictate combat patterns.
	var weapon = ProceduralWeaponEngine.generate_weapon(1234, {
		"slot_capacity": 5,
		"base_damage_multiplier": 1.2,
		"is_shuffle": false
	})

	var card_a = MotionCard.new()
	card_a.card_id = "motion_test_sweep"
	card_a.base_damage = 25.0
	card_a.recovery_delay = 0.15
	card_a.execution_duration = 0.20

	var card_b = ModifierCard.new()
	card_b.card_id = "mod_test_impact"
	card_b.damage_multiplier = 1.5

	var card_c = MotionCard.new()
	card_c.card_id = "motion_test_thrust"
	card_c.base_damage = 40.0
	card_c.recovery_delay = 0.25
	card_c.execution_duration = 0.22

	weapon.slotted_techniques = [card_a, card_b, card_c]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	assert_eq(evaluator.weapon, weapon)

	# First evaluation executes card_a (with weapon base damage scaling)
	var attacks1 = evaluator.evaluate_attack()
	assert_eq(attacks1.size(), 1)
	var ctx1 = attacks1[0]
	assert_eq(ctx1.source_card_id, "motion_test_sweep")
	assert_almost_eq(ctx1.damage, 25.0 * 1.2, 0.01)

	# Second evaluation executes card_b (modifier applied to card_c)
	evaluator.update(1.0)
	var attacks2 = evaluator.evaluate_attack()
	assert_eq(attacks2.size(), 1)
	var ctx2 = attacks2[0]
	assert_eq(ctx2.source_card_id, "motion_test_thrust")
	# 40 * 1.5 (mod) * 1.2 (weapon) = 72.0
	assert_almost_eq(ctx2.damage, 40.0 * 1.5 * 1.2, 0.01)
