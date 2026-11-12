class_name TestTwentySlotCyclotron
extends "res://tests/framework/test_case.gd"

## Unit tests for 20-slot weapon crafting, the Cyclotron Staged Particle Accelerator,
## Passive Engine Overclock modules, and Decoupled Player Locomotion (procedural_todo_20_slots.md).

const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MeleeAttackContext = preload("res://src/combat/core/melee_attack_context.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const ProceduralWeaponEngine = preload("res://src/combat/generator/procedural_weapon_engine.gd")

func test_twenty_slot_frame_generation_and_crafting() -> void:
	# 1. Direct Cyclotron frame crafting method
	var w_crafted = ProceduralWeaponEngine.craft_cyclotron_frame(777, {
		"name": "Singularity Collider #777"
	})
	assert_eq(w_crafted.slot_capacity, 20)
	assert_gt(w_crafted.mass, 10.0)
	assert_lte(w_crafted.deck_recharge_time, 0.35)

	# 2. Procedural generation with FrameTier.CYCLOTRON
	var w_tier = ProceduralWeaponEngine.generate_weapon(888, {
		"crafting_tier": ProceduralWeaponEngine.FrameTier.CYCLOTRON
	})
	assert_gte(w_tier.slot_capacity, 18)
	assert_lte(w_tier.slot_capacity, 20)
	assert_lte(w_tier.deck_recharge_time, 0.35)

func test_passive_engine_overclock_zero_point_flywheel() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 25.0

	var flywheel = ModifierCard.new()
	flywheel.stamina_multiplier = 0.0 # Replaces stamina drain with stored momentum
	flywheel.momentum_retention = 0.35

	var strike = MotionCard.new()
	strike.stamina_cost = 25.0

	weapon.slotted_techniques = [flywheel, strike]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_almost_eq(ctx.stamina_cost, 0.0)
	assert_almost_eq(ctx.momentum_retention, 0.35)

func test_passive_engine_overclock_kinetic_heat_sink() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.deck_recharge_time = 0.60

	var heat_sink = ModifierCard.new()
	heat_sink.deck_recharge_multiplier = 0.0 # Nullifies deck recharge delay
	heat_sink.recovery_delay_multiplier = 0.0

	var strike = MotionCard.new()
	strike.recovery_delay = 0.0

	weapon.slotted_techniques = [heat_sink, strike]
	var evaluator = MeleeDeckEvaluator.new(weapon)

	# Strike the single card in the deck -> cycles the full deck
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	# Evaluator should be immediately READY because recharge timer was reduced to 0.0s!
	assert_eq(evaluator.get_state(), MeleeDeckEvaluator.State.READY)
	assert_true(evaluator.is_ready())

func test_decoupled_locomotion_modes() -> void:
	# 1. Backward evasive retreat
	var backstep = MotionCard.new()
	backstep.locomotion_mode = MeleeAttackContext.LocomotionVectorMode.BACKWARD
	backstep.player_lunge_distance = 6.0
	backstep.locomotion_vertical_impulse = 3.0

	var ctx_back = MeleeAttackContext.new()
	backstep.apply_to_context(ctx_back)
	assert_eq(ctx_back.locomotion_mode, MeleeAttackContext.LocomotionVectorMode.BACKWARD)
	assert_almost_eq(ctx_back.player_lunge_distance, 6.0)
	assert_almost_eq(ctx_back.locomotion_vertical_impulse, 3.0)

	# 2. Input-relative omnidirectional phase shift
	var phase_dash = MotionCard.new()
	phase_dash.is_blink = true
	phase_dash.blink_distance = 8.0
	phase_dash.locomotion_mode = MeleeAttackContext.LocomotionVectorMode.INPUT_RELATIVE

	var ctx_phase = MeleeAttackContext.new()
	phase_dash.apply_to_context(ctx_phase)
	assert_true(ctx_phase.is_blink)
	assert_almost_eq(ctx_phase.blink_distance, 8.0)
	assert_eq(ctx_phase.locomotion_mode, MeleeAttackContext.LocomotionVectorMode.INPUT_RELATIVE)

	# 3. Lateral strafe override via modifier
	var strafe_mod = ModifierCard.new()
	strafe_mod.override_locomotion_mode = true
	strafe_mod.locomotion_mode = MeleeAttackContext.LocomotionVectorMode.LATERAL_LEFT

	var cleave = MotionCard.new()
	var ctx_strafe = MeleeAttackContext.new()
	cleave.apply_to_context(ctx_strafe)
	strafe_mod.apply_to_context(ctx_strafe)
	assert_eq(ctx_strafe.locomotion_mode, MeleeAttackContext.LocomotionVectorMode.LATERAL_LEFT)

func test_gravitational_gyroscope_free_movement() -> void:
	var gyro = ModifierCard.new()
	gyro.allows_free_movement = true
	gyro.move_speed_multiplier = 1.35

	var ctx = MeleeAttackContext.new()
	gyro.apply_to_context(ctx)

	assert_true(ctx.allows_free_movement)
	assert_almost_eq(ctx.move_speed_multiplier, 1.35)

func test_gravity_vortex_negative_knockback_implosion() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.mass = 16.0

	var vortex = MotionCard.new()
	vortex.card_id = "vortex"
	vortex.is_implosion = true
	vortex.knockback_force = -28.0
	vortex.arc_sweep_degrees = 360.0
	vortex.outer_radius = 4.0
	vortex.execution_duration = 0.18

	weapon.slotted_techniques = [vortex]
	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_true(ctx.is_implosion)
	# Negative knockback pulling entities inward
	assert_lt(ctx.knockback_force, 0.0)
	assert_almost_eq(ctx.knockback_force, -28.0)

func test_20_slot_cyclotron_full_particle_accelerator_pipeline() -> void:
	# Construct a complete 20-slot weapon embodying the 5-stage kinetic cyclotron
	# Stage 1 (Slots 0-3): Spin-up RPM
	# Stage 2 (Slots 4-7): Mass Densification (+150% mass)
	# Stage 3 (Slots 8-11): Relativistic Compression & Radius Extension
	# Stage 4 (Slots 12-15): Momentum Retention Latch (100% transfer)
	# Stage 5 (Slots 16-19): The Cataclysm Singularity Payload
	var weapon = MeleeWeaponDef.new()
	weapon.slot_capacity = 20
	weapon.mass = 35.0 # Colossal Frame

	# Stage 1: Spin-up RPM (accelerator sweep with momentum relay)
	var spinup_motion = MotionCard.new()
	spinup_motion.card_id = "stage1_spinup"
	spinup_motion.outer_radius = 3.0
	spinup_motion.arc_sweep_degrees = 360.0
	spinup_motion.execution_duration = 0.08
	spinup_motion.recovery_delay = 0.04

	var relay_mod = ModifierCard.new()
	relay_mod.momentum_retention = 1.0 # 100% momentum retention latch

	# Stage 2: Mass Densification (mass x 2.5)
	var densifier_mod = ModifierCard.new()
	densifier_mod.mass_multiplier = 2.5

	var sweep_stage2 = MotionCard.new()
	sweep_stage2.card_id = "stage2_sweep"
	sweep_stage2.outer_radius = 3.2
	sweep_stage2.arc_sweep_degrees = 360.0
	sweep_stage2.execution_duration = 0.06
	sweep_stage2.recovery_delay = 0.03

	# Stage 3: Relativistic Compression & Radius Extension
	var compress_mod = ModifierCard.new()
	compress_mod.execution_duration_multiplier = 0.015
	compress_mod.radius_multiplier = 1.6
	compress_mod.arc_sweep_multiplier = 1.2

	# Stage 4: Overclock Modules (Flywheel + Momentum Relay)
	var flywheel = ModifierCard.new()
	flywheel.stamina_multiplier = 0.0
	flywheel.momentum_retention = 0.35

	# Stage 5: Apex Singularity Cleave (matching motion_cataclysm_singularity)
	var apex_singularity = MotionCard.new()
	apex_singularity.card_id = "stage5_singularity"
	apex_singularity.outer_radius = 4.2
	apex_singularity.arc_sweep_degrees = 360.0
	apex_singularity.execution_duration = 0.06
	apex_singularity.player_lunge_distance = 6.0
	apex_singularity.mass_multiplier = 3.0
	apex_singularity.kinetic_efficiency = 1.6

	# Slot cards across the 20-slot frame
	weapon.slotted_techniques = [
		spinup_motion,
		relay_mod,
		densifier_mod,
		sweep_stage2,
		relay_mod,
		densifier_mod,
		compress_mod,
		flywheel,
		apex_singularity
	]

	var evaluator = MeleeDeckEvaluator.new(weapon)

	# --- Stage 1: Spin-up ---
	var a1 = evaluator.evaluate_attack()
	assert_eq(a1.size(), 1)
	assert_gt(a1[0].tip_velocity, 200.0)

	evaluator.update(0.05)

	# --- Stage 2: Densified Mass Swing ---
	var a2 = evaluator.evaluate_attack()
	assert_eq(a2.size(), 1)
	assert_gt(a2[0].kinetic_energy, 1000000.0) # > 1M Joules

	evaluator.update(0.04)

	# --- Stage 5: Cataclysm Singularity Release ---
	var a3 = evaluator.evaluate_attack()
	assert_eq(a3.size(), 1)
	var final_ctx = a3[0]

	# Must scale beyond 100 Billion Joules into the Singularity Tier!
	assert_gte(final_ctx.kinetic_energy, 100000000000.0) # 100 Billion+ Joules
	assert_eq(final_ctx.get_kinetic_tier(), MeleeAttackContext.KineticTier.SINGULARITY)
	assert_true(final_ctx.is_singularity)
	assert_true(final_ctx.is_cataclysm)
	assert_true(final_ctx.is_negative_space)
	assert_true(final_ctx.has_mach_ring)
