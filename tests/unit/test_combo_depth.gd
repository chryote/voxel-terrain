class_name TestComboDepth
extends "res://tests/framework/test_case.gd"

## Unit tests for combo depth and kinetic scaling (procedural_todo_combo_depth.md).
## Tests:
## 1. 3-Tier Kinetic Curve (Foundational -> Resonator -> 1-Billion God Engine).
## 2. Visual Kinetic Tiering (Mach Ring, Negative Space, Cataclysm).
## 3. Pillar A: Impact Freeze (Hitstop).
## 4. Pillar B: Director's Lens Camera Math.
## 5. Pillar C: Locomotion Spectacle (Ghosting & Blink).

const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const CameraMath = preload("res://src/player/camera_math.gd")
const HitstopManager = preload("res://src/combat/visuals/hitstop_manager.gd")
const VoxelAfterimageSpawner = preload("res://src/combat/visuals/voxel_afterimage_spawner.gd")

func test_tier_1_foundational_combo() -> void:
	# 3-Card combo: 14kg blade, swift modifier + downcleave
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 14.0

	var swift = ModifierCard.new()
	swift.card_id = "swift"
	swift.execution_duration_multiplier = 0.65 # 35% faster

	var cleave = MotionCard.new()
	cleave.card_id = "downcleave"
	cleave.outer_radius = 2.45
	cleave.arc_sweep_degrees = 135.0
	cleave.execution_duration = 0.24 # With mod -> 0.156s

	weapon.slotted_techniques = [swift, cleave]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	# Tier 1 expected range: 1,000 - 50,000 Joules
	assert_gt(ctx.kinetic_energy, 1000.0)
	assert_lt(ctx.kinetic_energy, 50000.0)
	assert_eq(ctx.get_kinetic_tier(), MeleeAttackContext.KineticTier.NORMAL)
	assert_false(ctx.has_mach_ring)
	assert_false(ctx.is_negative_space)
	assert_false(ctx.is_cataclysm)

func test_tier_2_resonator_combo() -> void:
	# 5-Card Multi-Stage Resonator:
	# Lead-in accelerator sweep -> Momentum relay + Radius Extender + Whirlwind + Payload smash
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 20.0

	# Card 1: Accelerator sweep (builds initial momentum)
	var acc_sweep = MotionCard.new()
	acc_sweep.card_id = "acc_sweep"
	acc_sweep.outer_radius = 2.6
	acc_sweep.arc_sweep_degrees = 360.0
	acc_sweep.execution_duration = 0.10
	acc_sweep.recovery_delay = 0.05

	# Card 2: Radius Extender (R x 1.8)
	var rad_mod = ModifierCard.new()
	rad_mod.radius_multiplier = 1.8

	# Card 3: Momentum Relay (retains 100% velocity)
	var relay_mod = ModifierCard.new()
	relay_mod.momentum_retention = 1.0

	# Card 4: Payload smash
	var smash = MotionCard.new()
	smash.card_id = "payload_smash"
	smash.outer_radius = 2.5
	smash.arc_sweep_degrees = 270.0
	smash.execution_duration = 0.12
	smash.player_lunge_distance = 2.5

	weapon.slotted_techniques = [acc_sweep, rad_mod, relay_mod, smash]
	var evaluator = MeleeDeckEvaluator.new(weapon)

	# Strike 1: Accelerator sweep
	var a1 = evaluator.evaluate_attack()
	assert_eq(a1.size(), 1)
	assert_gt(a1[0].tip_velocity, 150.0)

	evaluator.update(0.06)

	# Strike 2: Compounded Resonator strike
	var a2 = evaluator.evaluate_attack()
	assert_eq(a2.size(), 1)
	var ctx = a2[0]

	# Tier 2 expected: 100,000 - 10,000,000 Joules
	assert_gt(ctx.kinetic_energy, 100000.0)
	assert_lt(ctx.kinetic_energy, 50000000.0)
	assert_true(ctx.kinetic_tier == MeleeAttackContext.KineticTier.SUPERSONIC or ctx.kinetic_tier == MeleeAttackContext.KineticTier.HYPERSONIC)
	assert_true(ctx.has_mach_ring) # Supersonic Mach vapor ring triggered!

func test_tier_3_1_billion_god_engine() -> void:
	# Colossal frame (32kg) with 8 finely-tuned cards compounding all mechanical stages
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 32.0 # Colossal frame

	# Stage 1: Inertia compensator + Spinup accelerator (Card 1 & 2)
	var spinup = MotionCard.new()
	spinup.outer_radius = 3.2
	spinup.arc_sweep_degrees = 360.0
	spinup.execution_duration = 0.08
	spinup.recovery_delay = 0.04

	# Stage 2: Momentum Relay + Mass Compactor (Card 3 & 4)
	var relay_mod = ModifierCard.new()
	relay_mod.momentum_retention = 1.0
	relay_mod.mass_multiplier = 2.0 # Effective 64kg

	# Stage 3: Relativistic Compression + Radius Extender (Card 5 & 6)
	var comp_mod = ModifierCard.new()
	comp_mod.execution_duration_multiplier = 0.04 # Microsecond compression
	comp_mod.radius_multiplier = 1.6
	comp_mod.arc_sweep_multiplier = 1.5

	# Stage 4: Apex Cataclysm cleave (Card 7)
	var apex_cleave = MotionCard.new()
	apex_cleave.card_id = "apex_cataclysm"
	apex_cleave.outer_radius = 3.5
	apex_cleave.arc_sweep_degrees = 360.0
	apex_cleave.execution_duration = 0.12 # Compressed by mod to ~0.0048s
	apex_cleave.player_lunge_distance = 6.0

	weapon.slotted_techniques = [spinup, relay_mod, comp_mod, apex_cleave]
	var evaluator = MeleeDeckEvaluator.new(weapon)

	# Windup accelerator stage
	var a1 = evaluator.evaluate_attack()
	assert_eq(a1.size(), 1)
	assert_gt(a1[0].tip_velocity, 200.0)

	evaluator.update(0.05)

	# Release compressed Cataclysm God-Engine
	var a2 = evaluator.evaluate_attack()
	assert_eq(a2.size(), 1)
	var ctx = a2[0]

	# Breaks 1,000,000,000 Joules!
	assert_gte(ctx.kinetic_energy, 1000000000.0)
	assert_eq(ctx.get_kinetic_tier(), MeleeAttackContext.KineticTier.CATACLYSM)
	assert_true(ctx.has_mach_ring)
	assert_true(ctx.is_negative_space) # Reality-tearing pitch black core
	assert_true(ctx.is_cataclysm)      # 1-Billion Event triggered

func test_hitstop_manager_thresholds() -> void:
	# Tier 1 (< 1M J) -> 0.0s hitstop
	var dur_low = HitstopManager.evaluate_kinetic_hitstop(null, 45000.0)
	assert_almost_eq(dur_low, 0.0)

	# Tier 3 (Hypersonic 1M - 50M J) -> 0.08s hitstop
	var dur_hyper = HitstopManager.evaluate_kinetic_hitstop(null, 5000000.0)
	assert_almost_eq(dur_hyper, 0.08)

	# Tier 4 (Cataclysm 1B+ J) -> 0.12s hitstop
	var dur_cataclysm = HitstopManager.evaluate_kinetic_hitstop(null, 1200000000.0)
	assert_almost_eq(dur_cataclysm, 0.12)

func test_camera_math_directors_lens() -> void:
	# 1. Velocity pull-back
	var base_fov = 75.0
	# Under 500 m/s -> stays at base FOV
	var fov_slow = CameraMath.compute_velocity_fov(base_fov, 300.0, 88.0, 500.0)
	assert_almost_eq(fov_slow, 75.0)

	# Over 500 m/s -> expands smoothly towards 88 degrees
	var fov_fast = CameraMath.compute_velocity_fov(base_fov, 1750.0, 88.0, 500.0, 3000.0)
	assert_gt(fov_fast, 75.0)
	assert_lte(fov_fast, 88.0)

	# 2. Impact Snap (punch inward, then spring back)
	var snap_fov = CameraMath.compute_impact_snap_fov(88.0, 14.0, 0.04, 0.08)
	assert_lt(snap_fov, 88.0)
	var neutral_fov = CameraMath.compute_impact_snap_fov(88.0, 14.0, 0.0, 0.08)
	assert_almost_eq(neutral_fov, 88.0)

	# 3. Directional screen shake along cutting plane
	# Horizontal sweep (0 deg) -> displacement strictly on X
	var shake_horiz = CameraMath.compute_directional_shake(0.0, 0.5, 0.05)
	assert_almost_eq(shake_horiz.y, 0.0, 0.001)

	# Vertical cleave (90 deg) -> displacement strictly on Y
	var shake_vert = CameraMath.compute_directional_shake(90.0, 0.5, 0.05)
	assert_almost_eq(shake_vert.x, 0.0, 0.001)

func test_locomotion_blink_and_afterimage_properties() -> void:
	var blink_card = MotionCard.new()
	blink_card.is_blink = true
	blink_card.blink_distance = 9.0

	var ctx = MeleeAttackContext.new()
	blink_card.apply_to_context(ctx)

	assert_true(ctx.is_blink)
	assert_almost_eq(ctx.blink_distance, 9.0)
	assert_almost_eq(VoxelAfterimageSpawner.LUNGE_GHOSTING_THRESHOLD_SPEED, 15.0)

