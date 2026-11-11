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

func test_colossal_monster_hunter_voxel_bounds() -> void:
	var weapon = ProceduralWeaponEngine.generate_weapon(42)
	var data = weapon.procedural_data
	assert_not_null(data)

	var h = data["height"] as int
	var w = data["width"] as int
	var d = data["depth"] as int
	var voxel_size = ProceduralWeaponEngine.DEFAULT_VOXEL_SIZE

	# Height verification: Monster Hunter colossal weapon scale (~1.8m to 2.25m, ~2 world blocks)
	var physical_height = float(h) * voxel_size
	assert_almost_eq(physical_height, 2.00, 0.10)
	assert_true(physical_height >= 1.80 and physical_height <= 2.25, "Physical height must match Monster Hunter scale (~2.0m)")

	# Elongated aspect ratio verification (colossal weapon frame)
	var physical_width = float(w) * voxel_size
	var physical_depth = float(d) * voxel_size
	var aspect_ratio = physical_height / physical_width
	assert_true(aspect_ratio >= 3.0, "Weapon must be elongated along primary axis (aspect ratio >= 3.0)")
	# Volumetric presence (thick 3D heft: 0.20m to 0.35m)
	assert_true(physical_depth >= 0.20 and physical_depth <= 0.35, "Weapon depth must exhibit heavy 3D volumetric presence")

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
	# A colossal 40-height x 11-width x 5-depth voxel weapon with culling stays well-optimized under 4000 triangles
	var triangle_count = verts.size() / 3
	assert_true(triangle_count > 50 and triangle_count < 4000, "Mesh should be well-optimized via face culling")

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

func test_exotic_topologies_generation() -> void:
	var topologies = [
		ProceduralWeaponEngine.TopologyType.VOLUMETRIC_EROSION,
		ProceduralWeaponEngine.TopologyType.PARAMETRIC_HELIX,
		ProceduralWeaponEngine.TopologyType.BRANCHING_FRACTAL,
		ProceduralWeaponEngine.TopologyType.NOISE_SHATTERED,
		ProceduralWeaponEngine.TopologyType.KALEIDOSCOPIC
	]

	for topo in topologies:
		var weapon = ProceduralWeaponEngine.generate_weapon(2026, {"topology": topo})
		assert_not_null(weapon, "Weapon must generate for topology %d" % int(topo))
		assert_eq(weapon.get_meta("topology"), topo)

		var data = weapon.procedural_data
		var grid_3d = data["grid_3d"] as Array
		var w = data["width"] as int
		var h = data["height"] as int
		var d = data["depth"] as int
		var cx = data["center_x"] as int
		var cz = data["center_z"] as int

		var jy = data["junction_y"] as int

		# Handle (y = 1..jy-1) and collar (y = jy) check
		var has_handle = false
		for y in range(1, jy):
			if grid_3d[cx][y][cz] == ProceduralWeaponEngine.VoxelType.HANDLE:
				has_handle = true
		assert_true(has_handle, "Topology %d must have handle voxels" % int(topo))
		assert_eq(grid_3d[cx][jy][cz], ProceduralWeaponEngine.VoxelType.JUNCTION, "Junction collar must be present")

		# Readable locked central spine check: y = jy+1..h-1 must never be empty at central core
		for sy in range(jy + 1, h):
			var spine_voxel = grid_3d[cx][sy][cz]
			assert_true(spine_voxel != ProceduralWeaponEngine.VoxelType.EMPTY,
				"Topology %d spine voxel at y=%d must not be empty" % [int(topo), sy])

		# Check presence of structural components: BODY, EDGE, ENERGY
		var has_body = false
		var has_edge = false
		var has_energy = false
		for x in range(w):
			for y in range(h):
				for z in range(d):
					var v = grid_3d[x][y][z]
					if v == ProceduralWeaponEngine.VoxelType.BODY:
						has_body = true
					elif v == ProceduralWeaponEngine.VoxelType.EDGE:
						has_edge = true
					elif v == ProceduralWeaponEngine.VoxelType.ENERGY:
						has_energy = true

		assert_true(has_body, "Topology %d must contain BODY voxels" % int(topo))
		assert_true(has_edge, "Topology %d must contain EDGE voxels" % int(topo))
		assert_true(has_energy, "Topology %d must contain ENERGY voxels" % int(topo))

		# Mesh & Icon generation for this topology
		var mesh = ProceduralWeaponEngine.build_weapon_mesh(data)
		assert_not_null(mesh)
		assert_true(mesh.get_surface_count() >= 1)

		var icon = ProceduralWeaponEngine.generate_weapon_icon(data, Vector2i(28, 28))
		assert_not_null(icon)
		assert_eq(icon.get_width(), 28)

func test_exotic_topology_string_and_param_overrides() -> void:
	var string_names = ["erosion", "helix", "fractal", "shattered", "kaleidoscopic"]
	var expected_types = [
		ProceduralWeaponEngine.TopologyType.VOLUMETRIC_EROSION,
		ProceduralWeaponEngine.TopologyType.PARAMETRIC_HELIX,
		ProceduralWeaponEngine.TopologyType.BRANCHING_FRACTAL,
		ProceduralWeaponEngine.TopologyType.NOISE_SHATTERED,
		ProceduralWeaponEngine.TopologyType.KALEIDOSCOPIC
	]

	for i in range(string_names.size()):
		var name_str = string_names[i]
		var expected = expected_types[i]
		var w = ProceduralWeaponEngine.generate_weapon(123 + i, {"topology": name_str})
		assert_eq(w.get_meta("topology"), expected, "String '%s' should resolve to topology %d" % [name_str, int(expected)])

	# Test extra wide grid orbital parameters for parametric helix
	var wide_weapon = ProceduralWeaponEngine.generate_weapon(999, {
		"topology": "helix",
		"grid_width": 15,
		"grid_depth": 7,
		"helix_rx": 5.8,
		"helix_rz": 2.6
	})
	var data = wide_weapon.procedural_data
	assert_eq(data["width"], 15)
	assert_eq(data["depth"], 7)
	assert_eq(data["center_x"], 7)
	assert_eq(data["center_z"], 3)

	# Verify wide voxels exist in outer grid coordinates
	var grid_3d = data["grid_3d"] as Array
	var has_wide_voxel = false
	for x in range(15):
		for y in range(8, 40):
			for z in range(7):
				if (x <= 1 or x >= 13 or z == 0 or z == 6) and grid_3d[x][y][z] != ProceduralWeaponEngine.VoxelType.EMPTY:
					has_wide_voxel = true
					break
	assert_true(has_wide_voxel, "Wide helix must plot voxels in outer grid coordinates")

func test_structural_spine_locking_invariance() -> void:
	# Across multiple seeds and all topologies, spine is invariant and always unbroken
	var topologies = [
		ProceduralWeaponEngine.TopologyType.VOLUMETRIC_EROSION,
		ProceduralWeaponEngine.TopologyType.PARAMETRIC_HELIX,
		ProceduralWeaponEngine.TopologyType.BRANCHING_FRACTAL,
		ProceduralWeaponEngine.TopologyType.NOISE_SHATTERED,
		ProceduralWeaponEngine.TopologyType.KALEIDOSCOPIC
	]

	var test_seeds = [1, 42, 101, 777, 9999]
	for s in test_seeds:
		for topo in topologies:
			var weapon = ProceduralWeaponEngine.generate_weapon(s, {"topology": topo})
			var grid = weapon.procedural_data["grid_3d"] as Array
			var cx = weapon.procedural_data["center_x"] as int
			var cz = weapon.procedural_data["center_z"] as int
			var h = weapon.procedural_data["height"] as int

			# Spine from y = 1 to h - 1 is never empty
			for y in range(1, h):
				var v = grid[cx][y][cz]
				assert_true(v != ProceduralWeaponEngine.VoxelType.EMPTY,
					"Spine invariant violated at y=%d for seed %d, topology %d" % [y, s, int(topo)])

func test_no_hollow_cavities_in_kaleidoscopic_weapons() -> void:
	# Verifies that kaleidoscopic procedural weapons do not have missing interior voxels / cavities
	# cutting through the blade body, and that mesh materials use CULL_DISABLED to prevent visual artifacts.
	var test_seeds = [101, 202, 303, 777]
	for seed_val in test_seeds:
		var weapon = ProceduralWeaponEngine.generate_weapon(seed_val, {
			"topology": ProceduralWeaponEngine.TopologyType.KALEIDOSCOPIC
		})
		var data = weapon.procedural_data
		var grid_3d = data["grid_3d"] as Array
		var w = data["width"] as int
		var h = data["height"] as int
		var d = data["depth"] as int
		var jy = data["junction_y"] as int

		# Count interior cavities: an EMPTY voxel fully bounded by solid voxels in the same Z slice
		var interior_cavities = 0
		for y in range(jy + 1, h - 1):
			for x in range(w):
				for z in range(d):
					if grid_3d[x][y][z] == ProceduralWeaponEngine.VoxelType.EMPTY:
						var has_left = false
						var has_right = false
						for lx in range(0, x):
							if grid_3d[lx][y][z] != ProceduralWeaponEngine.VoxelType.EMPTY:
								has_left = true
								break
						for rx in range(x + 1, w):
							if grid_3d[rx][y][z] != ProceduralWeaponEngine.VoxelType.EMPTY:
								has_right = true
								break
						var has_down = false
						var has_up = false
						for dy_down in range(jy + 1, y):
							if grid_3d[x][dy_down][z] != ProceduralWeaponEngine.VoxelType.EMPTY:
								has_down = true
								break
						for dy_up in range(y + 1, h):
							if grid_3d[x][dy_up][z] != ProceduralWeaponEngine.VoxelType.EMPTY:
								has_up = true
								break
						if has_left and has_right and has_down and has_up:
							interior_cavities += 1

		assert_eq(interior_cavities, 0, "Kaleidoscopic weapon seed %d must have 0 interior cavities, got %d" % [seed_val, interior_cavities])

		# Verify mesh material cull mode
		var mesh = ProceduralWeaponEngine.build_weapon_mesh(data)
		assert_not_null(mesh)
		for s in range(mesh.get_surface_count()):
			var mat = mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null:
				assert_eq(mat.cull_mode, BaseMaterial3D.CULL_DISABLED, "Weapon mesh material surface %d must use CULL_DISABLED" % s)

func test_stylized_topologies_generation() -> void:
	# Tests the 5 stylized topologies:
	# Fungal Bracket, Osteological Cage, Insectoid Hive, Abyssal Marine, Carnivorous Botanical
	var stylized_topos = [
		ProceduralWeaponEngine.TopologyType.FUNGAL_BRACKET,
		ProceduralWeaponEngine.TopologyType.OSTEOLOGICAL_CAGE,
		ProceduralWeaponEngine.TopologyType.INSECTOID_HIVE,
		ProceduralWeaponEngine.TopologyType.ABYSSAL_MARINE,
		ProceduralWeaponEngine.TopologyType.CARNIVOROUS_BOTANICAL
	]

	for topo in stylized_topos:
		var seed_val = 5000 + int(topo)
		var weapon = ProceduralWeaponEngine.generate_weapon(seed_val, {"topology": topo})
		assert_not_null(weapon, "Stylized topology %d must generate weapon" % int(topo))
		assert_eq(weapon.get_meta("topology"), topo)

		# Strict terminology verification: generic "weapon"
		var lower_name = weapon.display_name.to_lower()
		assert_true(lower_name.contains("weapon"), "Stylized weapon name must contain 'weapon': %s" % weapon.display_name)
		assert_false(lower_name.contains("sword"), "Must not contain 'sword'")

		var data = weapon.procedural_data
		assert_not_null(data)
		var grid_3d = data["grid_3d"] as Array
		var w = data["width"] as int
		var h = data["height"] as int
		var d = data["depth"] as int
		var cx = data["center_x"] as int
		var cz = data["center_z"] as int
		var jy = data["junction_y"] as int

		# Handle verification
		var has_handle = false
		for y in range(1, jy):
			if grid_3d[cx][y][cz] == ProceduralWeaponEngine.VoxelType.HANDLE:
				has_handle = true
		assert_true(has_handle, "Stylized topology %d must have handle" % int(topo))

		# Spine verification
		for sy in range(jy + 1, h):
			assert_true(grid_3d[cx][sy][cz] != ProceduralWeaponEngine.VoxelType.EMPTY,
				"Topology %d spine at y=%d must not be empty" % [int(topo), sy])

		# Mesh generation & surfaces
		var mesh = ProceduralWeaponEngine.build_weapon_mesh(data)
		assert_not_null(mesh)
		assert_true(mesh.get_surface_count() >= 1, "Must generate at least 1 mesh surface")

		# 2D Icon generation
		var icon = weapon.icon
		assert_not_null(icon)
		assert_eq(icon.get_width(), 28)
		assert_eq(icon.get_height(), 28)

func test_stylized_topology_string_resolution() -> void:
	var string_cases = {
		"fungal": ProceduralWeaponEngine.TopologyType.FUNGAL_BRACKET,
		"mycelial_rot": ProceduralWeaponEngine.TopologyType.FUNGAL_BRACKET,
		"osteological": ProceduralWeaponEngine.TopologyType.OSTEOLOGICAL_CAGE,
		"ribcage": ProceduralWeaponEngine.TopologyType.OSTEOLOGICAL_CAGE,
		"insectoid": ProceduralWeaponEngine.TopologyType.INSECTOID_HIVE,
		"honeycomb": ProceduralWeaponEngine.TopologyType.INSECTOID_HIVE,
		"abyssal": ProceduralWeaponEngine.TopologyType.ABYSSAL_MARINE,
		"coral": ProceduralWeaponEngine.TopologyType.ABYSSAL_MARINE,
		"carnivorous": ProceduralWeaponEngine.TopologyType.CARNIVOROUS_BOTANICAL,
		"pitcher_plant": ProceduralWeaponEngine.TopologyType.CARNIVOROUS_BOTANICAL
	}

	for str_key in string_cases:
		var expected = string_cases[str_key]
		var w = ProceduralWeaponEngine.generate_weapon(700, {"topology": str_key})
		assert_eq(w.get_meta("topology"), expected, "String '%s' should resolve to topology %d" % [str_key, int(expected)])



