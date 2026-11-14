class_name TestCardPackedVisuals
extends "res://tests/framework/test_case.gd"

## Unit tests for Card-Packed (Explicit) visual identity, VFX triggers, and impact escalation.

const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")
const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const ProceduralSlashEffect = preload("res://src/combat/visuals/procedural_slash_effect.gd")
const VoxelAfterimageSpawner = preload("res://src/combat/visuals/voxel_afterimage_spawner.gd")

func test_motion_card_explicit_visual_identity_on_low_energy_weapon() -> void:
	# Even on a lightweight, low-mass dagger (< 50k Joules / NORMAL tier),
	# a motion card can explicitly define its visual identity and impact.
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 3.0

	var void_slash = MotionCard.new()
	void_slash.card_id = "custom_void_slash"
	void_slash.outer_radius = 2.0
	void_slash.arc_sweep_degrees = 120.0
	void_slash.execution_duration = 0.25 # Low speed
	void_slash.visual_shader_mode = MeleeAttackContext.VisualShaderMode.VOID_INVERSION
	void_slash.has_mach_ring = true
	void_slash.triggers_gravitational_implosion = true
	void_slash.hitstop_duration = 0.08
	void_slash.screen_shake_intensity = 1.2
	void_slash.camera_impact_snap = 14.0

	weapon.slotted_techniques = [void_slash]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	# Kinetic energy is in NORMAL tier
	assert_lt(ctx.kinetic_energy, 50000.0)
	assert_eq(ctx.get_kinetic_tier(), MeleeAttackContext.KineticTier.NORMAL)

	# But Card-Packed explicit visuals are faithfully triggered!
	assert_eq(ctx.visual_shader_mode, MeleeAttackContext.VisualShaderMode.VOID_INVERSION)
	assert_true(ctx.is_negative_space)
	assert_true(ctx.has_mach_ring)
	assert_true(ctx.triggers_gravitational_implosion)
	assert_almost_eq(ctx.hitstop_duration, 0.08)
	assert_almost_eq(ctx.screen_shake_intensity, 1.2)
	assert_almost_eq(ctx.camera_impact_snap, 14.0)

func test_modifier_card_visual_infusion() -> void:
	# Modifier cards can infuse visual shaders, black holes, and shockwaves into any motion.
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 8.0

	var lens_mod = ModifierCard.new()
	lens_mod.override_shader_mode = true
	lens_mod.visual_shader_mode = MeleeAttackContext.VisualShaderMode.VOID_INVERSION
	lens_mod.infuse_gravitational_implosion = true
	lens_mod.add_hitstop_duration = 0.06
	lens_mod.add_camera_impact_snap = 10.0

	var standard_motion = MotionCard.new()
	standard_motion.outer_radius = 2.4
	standard_motion.arc_sweep_degrees = 135.0
	standard_motion.execution_duration = 0.24
	standard_motion.visual_shader_mode = MeleeAttackContext.VisualShaderMode.PLASMA
	standard_motion.hitstop_duration = 0.0

	weapon.slotted_techniques = [lens_mod, standard_motion]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_eq(ctx.visual_shader_mode, MeleeAttackContext.VisualShaderMode.VOID_INVERSION)
	assert_true(ctx.is_negative_space)
	assert_true(ctx.triggers_gravitational_implosion)
	assert_almost_eq(ctx.hitstop_duration, 0.06)
	assert_almost_eq(ctx.camera_impact_snap, 10.0)

func test_sonic_condenser_infuses_mach_ring() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 5.0

	var sonic_mod = ModifierCard.new()
	sonic_mod.infuse_mach_ring = true
	sonic_mod.add_camera_impact_snap = 8.0

	var sweep = MotionCard.new()
	sweep.outer_radius = 2.2
	sweep.arc_sweep_degrees = 110.0
	sweep.execution_duration = 0.30
	sweep.has_mach_ring = false

	weapon.slotted_techniques = [sonic_mod, sweep]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_true(ctx.has_mach_ring)
	assert_almost_eq(ctx.camera_impact_snap, 8.0)

func test_motion_cataclysm_singularity_resource_explicit_profile() -> void:
	var c_sing = load("res://assets/combat/cards/motion_cataclysm_singularity.tres") as MotionCard
	assert_not_null(c_sing)

	var weapon = MeleeWeaponDef.new()
	weapon.mass = 12.0
	weapon.slotted_techniques = [c_sing]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_eq(ctx.visual_shader_mode, MeleeAttackContext.VisualShaderMode.VOID_INVERSION)
	assert_true(ctx.is_negative_space)
	assert_true(ctx.has_mach_ring)
	assert_true(ctx.is_cataclysm)
	assert_true(ctx.is_singularity)
	assert_true(ctx.triggers_screen_flash)
	assert_true(ctx.triggers_arena_shockwave)
	assert_true(ctx.triggers_gravitational_implosion)
	assert_almost_eq(ctx.hitstop_duration, 0.14)
	assert_almost_eq(ctx.screen_shake_intensity, 1.8)
	assert_almost_eq(ctx.camera_impact_snap, 22.0)

func test_hitstop_duration_and_shake_compounding() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 15.0

	var mod_heavy = ModifierCard.new()
	mod_heavy.add_hitstop_duration = 0.05
	mod_heavy.screen_shake_multiplier = 1.3

	var mod_compress = ModifierCard.new()
	mod_compress.add_hitstop_duration = 0.06
	mod_compress.screen_shake_multiplier = 1.5

	var cleave = MotionCard.new()
	cleave.hitstop_duration = 0.04
	cleave.screen_shake_intensity = 0.5

	weapon.slotted_techniques = [mod_heavy, mod_compress, cleave]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	# 0.04 (base) + 0.05 + 0.06 = 0.15s hitstop
	assert_almost_eq(ctx.hitstop_duration, 0.15)
	# 0.5 * 1.3 * 1.5 = 0.975 shake
	assert_almost_eq(ctx.screen_shake_intensity, 0.975)

func test_procedural_slash_effect_void_shader_binding() -> void:
	var effect = ProceduralSlashEffect.new()
	effect._ready()

	var ctx = MeleeAttackContext.new()
	ctx.visual_shader_mode = MeleeAttackContext.VisualShaderMode.VOID_INVERSION
	ctx.is_negative_space = true
	ctx.core_color = Color(1.0, 1.0, 1.0, 1.0)
	ctx.edge_color = Color(0.8, 0.2, 1.0, 1.0)
	ctx.execution_duration = 0.20

	effect.play_context(Transform3D.IDENTITY, ctx)

	var mat = effect._slash_material
	assert_not_null(mat)
	assert_not_null(mat.shader)
	assert_true(mat.shader.resource_path.contains("slash_void_inversion.gdshader"))

	effect.free()

func test_afterimage_trajectory_spacing_and_no_clumping() -> void:
	assert_gte(VoxelAfterimageSpawner.MIN_GHOST_SPATIAL_SPACING, 1.2)
	assert_gte(VoxelAfterimageSpawner.MIN_DISPLACEMENT_FOR_AFTERIMAGES, 1.0)

	var root_parent = Node3D.new()
	var test_source = Node3D.new()
	root_parent.add_child(test_source)
	var tree = (Engine.get_main_loop() as SceneTree)
	if tree != null and tree.root != null:
		tree.root.add_child(root_parent)

	# 1. Short displacement (< MIN_DISPLACEMENT_FOR_AFTERIMAGES): Zero ghosts spawned
	var child_count_before = root_parent.get_child_count()
	VoxelAfterimageSpawner.spawn_trajectory_sequence(
		root_parent,
		test_source,
		Vector3.ZERO,
		Vector3(0.5, 0.0, 0.0), # Only 0.5m distance
		0.1,
		4
	)
	# Only test_source should be a child (no ghosts spawned to prevent clumping inside player)
	assert_eq(root_parent.get_child_count(), child_count_before)

	# 2. Substantial displacement (6.0m) with instantaneous blink (duration <= 0.05)
	VoxelAfterimageSpawner.spawn_trajectory_sequence(
		root_parent,
		test_source,
		Vector3.ZERO,
		Vector3(6.0, 0.0, 0.0), # 6.0m distance
		0.04, # Instantaneous
		4,
		Color.CYAN
	)

	# Effective count = 4 ghosts spawned immediately
	var ghost_nodes: Array[Node3D] = []
	for child in root_parent.get_children():
		if child != test_source and child is Node3D:
			ghost_nodes.append(child as Node3D)

	assert_eq(ghost_nodes.size(), 4)

	# Verify strict spatial spacing: no ghosts closer than MIN_GHOST_SPATIAL_SPACING
	for i in range(ghost_nodes.size() - 1):
		var pos_curr = ghost_nodes[i].global_position if ghost_nodes[i].is_inside_tree() else ghost_nodes[i].position
		var pos_next = ghost_nodes[i + 1].global_position if ghost_nodes[i + 1].is_inside_tree() else ghost_nodes[i + 1].position
		var dist_between = (pos_next - pos_curr).length()
		assert_gte(dist_between, VoxelAfterimageSpawner.MIN_GHOST_SPATIAL_SPACING)

	# Verify last ghost is spaced safely before arrival position (6.0, 0, 0)
	var last_pos = ghost_nodes[ghost_nodes.size() - 1].global_position if ghost_nodes[ghost_nodes.size() - 1].is_inside_tree() else ghost_nodes[ghost_nodes.size() - 1].position
	var dist_to_arrival = (Vector3(6.0, 0.0, 0.0) - last_pos).length()
	assert_gte(dist_to_arrival, VoxelAfterimageSpawner.MIN_GHOST_SPATIAL_SPACING)

	root_parent.free()

func test_prismatic_rainbow_dispersion_spectrum() -> void:
	# 1. Full rainbow spectrum distribution
	var rainbow = VoxelAfterimageSpawner.get_prismatic_palette(6)
	assert_eq(rainbow.size(), 6)

	# Opacity gradient: leading ghost is vibrant and punchy, tail is faded
	assert_gte(rainbow[0].a, 0.75)
	assert_lte(rainbow[rainbow.size() - 1].a, 0.40)

	# Verify multi-hue chromatic dispersion across the spectrum
	var distinct_hues: Array[float] = []
	for col in rainbow:
		distinct_hues.append(col.h)
	# At least 4 distinct hue sectors represented in a 6-ghost rainbow
	assert_ne(distinct_hues[0], distinct_hues[distinct_hues.size() - 1])

	# 2. Anchored custom base color dispersion (e.g. Cyan base color)
	var cyan_base = Color(0.2, 0.85, 1.0, 1.0)
	var anchored_palette = VoxelAfterimageSpawner.get_prismatic_palette(4, cyan_base)
	assert_eq(anchored_palette.size(), 4)
	# Head color starts close to anchor hue
	assert_almost_eq(anchored_palette[0].h, cyan_base.h, 0.05)
	# Tail color shifts substantially along the chromatic wheel
	assert_ne(anchored_palette[0].h, anchored_palette[anchored_palette.size() - 1].h)

func test_afterimage_filters_out_floating_weapon_square() -> void:
	var player = Node3D.new()
	player.name = "Player"

	# 1. Body mesh
	var body_mesh_instance = MeshInstance3D.new()
	body_mesh_instance.name = "FallbackCapsule"
	var cap = CapsuleMesh.new()
	body_mesh_instance.mesh = cap
	player.add_child(body_mesh_instance)

	# 2. Floating weapon mesh (the voxel weapon box/square)
	var weapon_ctrl = Node3D.new()
	weapon_ctrl.name = "FloatingWeaponController"
	var weapon_root = Node3D.new()
	weapon_root.name = "WeaponVisualRoot"
	var weapon_mesh_instance = MeshInstance3D.new()
	weapon_mesh_instance.name = "WeaponMeshInstance"
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	weapon_mesh_instance.mesh = box
	weapon_root.add_child(weapon_mesh_instance)
	weapon_ctrl.add_child(weapon_root)
	player.add_child(weapon_ctrl)

	var extracted = VoxelAfterimageSpawner._extract_mesh_data(player)
	# Should only extract the body mesh (1 mesh), completely ignoring the floating weapon box/square
	assert_eq(extracted.size(), 1)
	assert_eq(extracted[0]["mesh"], cap)

	player.free()

func test_afterimage_weapon_dynamic_move_snapshot() -> void:
	var ctx = MeleeAttackContext.new()
	ctx.arc_sweep_degrees = 140.0
	ctx.inner_radius = 0.8
	ctx.outer_radius = 2.5
	ctx.tilt_degrees = -15.0
	ctx.is_reversed_sweep = false

	# 1. Transform calculations along the slash arc
	var xform_start = VoxelAfterimageSpawner.compute_dynamic_weapon_transform(ctx, 0.15)
	var xform_mid = VoxelAfterimageSpawner.compute_dynamic_weapon_transform(ctx, 0.50)
	var xform_end = VoxelAfterimageSpawner.compute_dynamic_weapon_transform(ctx, 0.85)

	# Verify progressive spatial sweeping across the arc
	assert_ne(xform_start.origin, xform_mid.origin)
	assert_ne(xform_mid.origin, xform_end.origin)
	assert_ne(xform_start.origin, xform_end.origin)

	# Verify basis orientation rotates along with the arc
	assert_ne(xform_start.basis, xform_mid.basis)
	assert_ne(xform_mid.basis, xform_end.basis)

	# Right-handed orthonormal bases (determinant ~ 1.0, no flipped normals)
	assert_almost_eq(xform_start.basis.determinant(), 1.0, 0.01)
	assert_almost_eq(xform_mid.basis.determinant(), 1.0, 0.01)
	assert_almost_eq(xform_end.basis.determinant(), 1.0, 0.01)

	# 2. Spawn ghost instance includes body mesh and GhostWeaponSnapshot
	var root_parent = Node3D.new()
	var dummy_cap = CapsuleMesh.new()
	var dummy_weapon = BoxMesh.new()
	var mesh_data = [{
		"mesh": dummy_cap,
		"local_transform": Transform3D(Basis(), Vector3(0.0, 0.7, 0.0))
	}]

	var ghost = VoxelAfterimageSpawner._spawn_ghost_instance(
		root_parent,
		mesh_data,
		Transform3D.IDENTITY,
		Color(1.0, 0.5, 0.2, 0.8),
		0.3,
		dummy_weapon,
		xform_mid
	)

	assert_not_null(ghost)
	assert_eq(ghost.get_child_count(), 2)

	var weapon_snapshot = ghost.get_node_or_null("GhostWeaponSnapshot") as MeshInstance3D
	assert_not_null(weapon_snapshot)
	assert_eq(weapon_snapshot.mesh, dummy_weapon)
	assert_almost_eq(weapon_snapshot.transform.origin.x, xform_mid.origin.x, 0.001)
	assert_almost_eq(weapon_snapshot.transform.origin.y, xform_mid.origin.y, 0.001)
	assert_almost_eq(weapon_snapshot.transform.origin.z, xform_mid.origin.z, 0.001)

	# Both body and weapon snapshot share the same unshaded additive material
	var body_mi = ghost.get_child(0) as MeshInstance3D
	assert_not_null(body_mi)
	assert_eq(body_mi.material_override, weapon_snapshot.material_override)

	# 3. Trajectory sequence automatically equips weapon snapshots across all ghosts
	var player = Node3D.new()
	var cap_inst = MeshInstance3D.new()
	cap_inst.mesh = dummy_cap
	player.add_child(cap_inst)

	VoxelAfterimageSpawner.spawn_trajectory_sequence(
		root_parent,
		player,
		Vector3.ZERO,
		Vector3(0.0, 0.0, -8.0),
		0.04, # Instantaneous
		4,
		Color.MAGENTA,
		0.28,
		dummy_weapon,
		ctx
	)

	var ghost_nodes: Array[Node3D] = []
	for child in root_parent.get_children():
		if child != ghost and child != player and child is Node3D:
			ghost_nodes.append(child as Node3D)

	assert_eq(ghost_nodes.size(), 4)
	for g in ghost_nodes:
		var snap = g.get_node_or_null("GhostWeaponSnapshot") as MeshInstance3D
		assert_not_null(snap)
		assert_eq(snap.mesh, dummy_weapon)

	# Verify progressive dynamic snapshot poses across trajectory ghosts
	var snap0 = ghost_nodes[0].get_node("GhostWeaponSnapshot") as MeshInstance3D
	var snap3 = ghost_nodes[3].get_node("GhostWeaponSnapshot") as MeshInstance3D
	assert_ne(snap0.transform.origin, snap3.transform.origin)
	assert_ne(snap0.transform.basis, snap3.transform.basis)

	player.free()
	root_parent.free()


