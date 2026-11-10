class_name TestMeleeDeckEvaluator
extends "res://tests/framework/test_case.gd"

## Unit tests for MeleeDeckEvaluator, MeleeWeaponDef, and TechniqueCards.
## Verifies that weapons act purely as data containers and that technique cards
## strictly dictate 3D volume VFX slash, attack execution speed, and attack frequency.

const MeleeWeaponDef = preload("res://src/combat/core/melee_weapon_def.gd")
const MeleeDeckEvaluator = preload("res://src/combat/core/melee_deck_evaluator.gd")
const MotionCard = preload("res://src/combat/techniques/motions/motion_card.gd")
const ModifierCard = preload("res://src/combat/techniques/modifiers/modifier_card.gd")
const MulticastCard = preload("res://src/combat/techniques/multicast/multicast_card.gd")
const TriggerCard = preload("res://src/combat/techniques/triggers/trigger_card.gd")

func test_weapon_as_data_container() -> void:
	var weapon = MeleeWeaponDef.new()
	weapon.weapon_id = "test_blade"
	weapon.display_name = "Test Blade"
	weapon.slot_capacity = 4
	weapon.float_offset_right = 0.72
	weapon.float_offset_height = 1.05
	weapon.base_damage_multiplier = 1.2

	assert_eq(weapon.weapon_id, "test_blade")
	assert_eq(weapon.slot_capacity, 4)
	assert_almost_eq(weapon.float_offset_right, 0.72)
	assert_almost_eq(weapon.float_offset_height, 1.05)
	assert_almost_eq(weapon.base_damage_multiplier, 1.2)
	assert_eq(weapon.get_active_card_count(), 0)

func test_motion_card_dictates_vfx_and_timing() -> void:
	var motion = MotionCard.new()
	motion.card_id = "test_cleave"
	motion.execution_duration = 0.15
	motion.recovery_delay = 0.10
	motion.outer_radius = 2.8
	motion.inner_radius = 0.8
	motion.arc_sweep_degrees = 140.0
	motion.volume_thickness = 0.28
	motion.base_damage = 35.0

	var weapon = MeleeWeaponDef.new()
	weapon.slotted_techniques = [motion]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	assert_true(evaluator.is_ready())

	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_eq(ctx.source_card_id, "test_cleave")
	# Speed and frequency directly dictated by the card
	assert_almost_eq(ctx.execution_duration, 0.15)
	assert_almost_eq(ctx.recovery_delay, 0.10)
	# 3D Volume VFX geometry dictated by the card
	assert_almost_eq(ctx.outer_radius, 2.8)
	assert_almost_eq(ctx.inner_radius, 0.8)
	assert_almost_eq(ctx.arc_sweep_degrees, 140.0)
	assert_almost_eq(ctx.volume_thickness, 0.28)
	assert_almost_eq(ctx.damage, 35.0)

func test_modifier_card_scales_speed_and_frequency() -> void:
	var swift_mod = ModifierCard.new()
	swift_mod.card_id = "swift"
	swift_mod.execution_duration_multiplier = 0.60 # 40% faster execution
	swift_mod.recovery_delay_multiplier = 0.50     # 50% faster attack frequency
	swift_mod.damage_multiplier = 1.1
	swift_mod.radius_multiplier = 1.2
	swift_mod.color_tint = Color.CYAN

	var motion = MotionCard.new()
	motion.card_id = "slash"
	motion.execution_duration = 0.30
	motion.recovery_delay = 0.20
	motion.outer_radius = 2.0
	motion.base_damage = 20.0

	var weapon = MeleeWeaponDef.new()
	weapon.slotted_techniques = [swift_mod, motion]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	# Execution speed: 0.30 * 0.60 = 0.18
	assert_almost_eq(ctx.execution_duration, 0.18)
	# Attack frequency recovery: 0.20 * 0.50 = 0.10
	assert_almost_eq(ctx.recovery_delay, 0.10)
	# Damage & scale altered
	assert_almost_eq(ctx.damage, 22.0)
	assert_almost_eq(ctx.outer_radius, 2.4)

func test_sequential_card_traversal_and_recharge() -> void:
	var m1 = MotionCard.new()
	m1.card_id = "m1"
	m1.execution_duration = 0.2
	m1.recovery_delay = 0.1

	var m2 = MotionCard.new()
	m2.card_id = "m2"
	m2.execution_duration = 0.3
	m2.recovery_delay = 0.2

	var weapon = MeleeWeaponDef.new()
	weapon.deck_recharge_time = 0.4
	weapon.slotted_techniques = [m1, m2]

	var evaluator = MeleeDeckEvaluator.new(weapon)

	# Cast 1
	assert_true(evaluator.is_ready())
	var a1 = evaluator.evaluate_attack()
	assert_eq(a1.size(), 1)
	assert_eq(a1[0].source_card_id, "m1")
	assert_false(evaluator.is_ready())
	assert_eq(evaluator.get_state(), MeleeDeckEvaluator.State.RECOVERING)

	# Elapse recovery
	evaluator.update(0.12)
	assert_true(evaluator.is_ready())

	# Cast 2 (last card in deck)
	var a2 = evaluator.evaluate_attack()
	assert_eq(a2.size(), 1)
	assert_eq(a2[0].source_card_id, "m2")
	# Reaches end of deck -> RECHARGING
	assert_eq(evaluator.get_state(), MeleeDeckEvaluator.State.RECHARGING)
	assert_almost_eq(evaluator.get_cooldown_remaining(), 0.4)

	# Elapse recharge
	evaluator.update(0.42)
	assert_true(evaluator.is_ready())
	# Loops back to card 1
	var a3 = evaluator.evaluate_attack()
	assert_eq(a3[0].source_card_id, "m1")

func test_multicast_evaluates_multiple_motions() -> void:
	var multi = MulticastCard.new()
	multi.simultaneous_count = 2
	multi.formation_tilt_offset = 40.0

	var m1 = MotionCard.new()
	m1.card_id = "slash_left"
	m1.tilt_degrees = -10.0

	var m2 = MotionCard.new()
	m2.card_id = "slash_right"
	m2.tilt_degrees = 15.0

	var weapon = MeleeWeaponDef.new()
	weapon.slotted_techniques = [multi, m1, m2]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()

	# Both motions evaluated together in single action
	assert_eq(attacks.size(), 2)
	assert_eq(attacks[0].source_card_id, "slash_left")
	assert_eq(attacks[1].source_card_id, "slash_right")

func test_trigger_on_hit_payload_attached() -> void:
	var trigger = TriggerCard.new()
	trigger.trigger_type = TriggerCard.TriggerType.ON_HIT

	var payload_motion = MotionCard.new()
	payload_motion.card_id = "payload_cleave"
	trigger.payload_cards = [payload_motion]

	var strike = MotionCard.new()
	strike.card_id = "lead_thrust"

	var weapon = MeleeWeaponDef.new()
	weapon.slotted_techniques = [trigger, strike]

	var evaluator = MeleeDeckEvaluator.new(weapon)
	var attacks = evaluator.evaluate_attack()
	assert_eq(attacks.size(), 1)

	var ctx = attacks[0]
	assert_eq(ctx.source_card_id, "lead_thrust")
	assert_eq(ctx.nested_triggers.size(), 1)
	assert_eq(ctx.nested_triggers[0].payload_cards.size(), 1)
	assert_eq(ctx.nested_triggers[0].payload_cards[0].card_id, "payload_cleave")

func test_reset_sequence_returns_to_first_card() -> void:
	var m1 = MotionCard.new()
	m1.card_id = "card_alpha"
	m1.execution_duration = 0.2
	m1.recovery_delay = 0.1

	var m2 = MotionCard.new()
	m2.card_id = "card_beta"
	m2.execution_duration = 0.2
	m2.recovery_delay = 0.1

	var weapon = MeleeWeaponDef.new()
	weapon.slotted_techniques = [m1, m2]

	var evaluator = MeleeDeckEvaluator.new(weapon)

	# Execute first card
	var a1 = evaluator.evaluate_attack()
	assert_eq(a1.size(), 1)
	assert_eq(a1[0].source_card_id, "card_alpha")
	assert_eq(evaluator.get_current_index(), 1)

	# Player releases attack -> reset sequence!
	evaluator.reset_sequence()
	assert_eq(evaluator.get_current_index(), 0)

	# Elapse recovery delay
	evaluator.update(0.12)
	assert_true(evaluator.is_ready())

	# Next attack should cast card_alpha again (reset back to first card)
	var a2 = evaluator.evaluate_attack()
	assert_eq(a2.size(), 1)
	assert_eq(a2[0].source_card_id, "card_alpha")
	assert_eq(evaluator.get_current_index(), 1)

